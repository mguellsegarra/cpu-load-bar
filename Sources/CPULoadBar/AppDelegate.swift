import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private enum StatusAppearance: Equatable {
    case normalCPU
    case elevatedCPU
    case elevatedMemory
  }

  private let refreshInterval: TimeInterval = 2
  private let processRefreshInterval: TimeInterval = 10
  private var statusItem: NSStatusItem?
  private var displayedAppearance: StatusAppearance?
  private var displayedText: String?
  private var displayedDarkAppearance: Bool?
  private var refreshTimer: Timer?
  private var processRefreshTask: Task<Void, Never>?
  private var currentProcessMetric: ProcessMetricKind?
  private var lastProcessRefresh = Date.distantPast
  private let loginItemService = SMAppService.mainApp

  private let oneMinuteItem = NSMenuItem(title: "1 min: —", action: nil, keyEquivalent: "")
  private let fiveMinuteItem = NSMenuItem(title: "5 min: —", action: nil, keyEquivalent: "")
  private let fifteenMinuteItem = NSMenuItem(title: "15 min: —", action: nil, keyEquivalent: "")
  private let memoryPressureItem = NSMenuItem(
    title: "Memory pressure: —",
    action: nil,
    keyEquivalent: ""
  )
  private let topProcessesHeading = NSMenuItem(
    title: "Top processes",
    action: nil,
    keyEquivalent: ""
  )
  private lazy var topProcessItems: [NSMenuItem] = (1...3).map { index in
    NSMenuItem(title: "\(index). Loading…", action: nil, keyEquivalent: "")
  }
  private lazy var openAtLoginItem = NSMenuItem(
    title: "Open at Login",
    action: #selector(toggleOpenAtLogin),
    keyEquivalent: ""
  )

  func applicationDidFinishLaunching(_ notification: Notification) {
    configureStatusItem()
    refresh()

    let timer = Timer(
      timeInterval: refreshInterval,
      target: self,
      selector: #selector(refresh),
      userInfo: nil,
      repeats: true
    )
    refreshTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  func applicationWillTerminate(_ notification: Notification) {
    refreshTimer?.invalidate()
    processRefreshTask?.cancel()
  }

  private func configureStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.autosaveName = "dev.ondori.cpu-load-bar.status"
    statusItem = item

    if let button = item.button {
      button.imagePosition = .imageLeading
      showStatus(
        appearance: .normalCPU,
        text: "—",
        accessibilityLabel: "CPU load average",
        accessibilityValue: "Unavailable"
      )
    }

    let menu = NSMenu()
    let activityMonitorItem = NSMenuItem(
      title: "Open Activity Monitor",
      action: #selector(openActivityMonitor),
      keyEquivalent: "a"
    )
    activityMonitorItem.target = self
    menu.addItem(activityMonitorItem)
    menu.addItem(.separator())

    topProcessesHeading.isEnabled = false
    topProcessesHeading.isHidden = true
    menu.addItem(topProcessesHeading)
    for item in topProcessItems {
      item.target = self
      item.action = #selector(copyProcessName(_:))
      item.isEnabled = false
      item.isHidden = true
      menu.addItem(item)
    }
    menu.addItem(.separator())

    let heading = NSMenuItem(title: "Load average", action: nil, keyEquivalent: "")
    heading.isEnabled = false
    menu.addItem(heading)
    oneMinuteItem.isEnabled = false
    fiveMinuteItem.isEnabled = false
    fifteenMinuteItem.isEnabled = false
    memoryPressureItem.isEnabled = false
    menu.addItem(oneMinuteItem)
    menu.addItem(fiveMinuteItem)
    menu.addItem(fifteenMinuteItem)
    menu.addItem(memoryPressureItem)
    menu.addItem(.separator())

    let coreCount = ProcessInfo.processInfo.activeProcessorCount
    let coresItem = NSMenuItem(
      title: "Logical CPUs: \(coreCount)",
      action: nil,
      keyEquivalent: ""
    )
    coresItem.isEnabled = false
    menu.addItem(coresItem)

    let refreshItem = NSMenuItem(
      title: "Refresh now",
      action: #selector(refresh),
      keyEquivalent: "r"
    )
    refreshItem.target = self
    menu.addItem(refreshItem)
    menu.addItem(.separator())

    openAtLoginItem.target = self
    menu.addItem(openAtLoginItem)
    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "Quit CPU Load Bar",
      action: #selector(quit),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    item.menu = menu
    updateOpenAtLoginItem()
  }

  @objc private func refresh() {
    updateOpenAtLoginItem()

    guard let loadAverage = LoadAverage.current() else {
      showUnavailableState()
      return
    }

    let memoryPressure = MemoryPressureLevel.current()
    let oneMinute = format(loadAverage.oneMinute)
    let fiveMinutes = format(loadAverage.fiveMinutes)
    let fifteenMinutes = format(loadAverage.fifteenMinutes)

    oneMinuteItem.title = "1 min: \(oneMinute)"
    fiveMinuteItem.title = "5 min: \(fiveMinutes)"
    fifteenMinuteItem.title = "15 min: \(fifteenMinutes)"
    updateMemoryPressureItem(memoryPressure)

    let metric = selectMenuBarMetric(
      load: loadAverage.oneMinute,
      logicalCPUCount: ProcessInfo.processInfo.activeProcessorCount,
      memoryPressure: memoryPressure
    )
    show(metric: metric, formattedLoad: oneMinute)
    refreshTopProcesses(for: metric)
  }

  private func format(_ value: Double) -> String {
    String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
  }

  private func showUnavailableState() {
    showStatus(
      appearance: .normalCPU,
      text: "—",
      accessibilityLabel: "CPU load average",
      accessibilityValue: "Unavailable"
    )
    statusItem?.button?.toolTip = "CPU load average is unavailable"
    oneMinuteItem.title = "1 min: unavailable"
    fiveMinuteItem.title = "5 min: unavailable"
    fifteenMinuteItem.title = "15 min: unavailable"
    updateMemoryPressureItem(.unavailable)
    hideTopProcesses()
  }

  private func show(metric: MenuBarMetric, formattedLoad: String) {
    switch metric {
    case .cpu(_, let elevated):
      showStatus(
        appearance: elevated ? .elevatedCPU : .normalCPU,
        text: formattedLoad,
        accessibilityLabel: "CPU load average",
        accessibilityValue: formattedLoad
      )
      statusItem?.button?.toolTip = "CPU load average (1 min): \(formattedLoad)"

    case .memory(let pressure):
      showStatus(
        appearance: .elevatedMemory,
        text: "Critical",
        accessibilityLabel: "Memory pressure",
        accessibilityValue: pressure.menuText
      )
      statusItem?.button?.toolTip = "Memory pressure: \(pressure.menuText)"
    }
  }

  private func showStatus(
    appearance: StatusAppearance,
    text: String,
    accessibilityLabel: String,
    accessibilityValue: String
  ) {
    guard let button = statusItem?.button else { return }

    let darkAppearance = button.effectiveAppearance.bestMatch(
      from: [.aqua, .darkAqua]
    ) == .darkAqua
    let appearanceChanged = displayedAppearance != appearance
      || displayedDarkAppearance != darkAppearance
    let color: NSColor?
    switch appearance {
    case .normalCPU: color = nil
    case .elevatedCPU: color = warningRed
    case .elevatedMemory: color = memoryPurple
    }

    if appearanceChanged {
      let isMemory = appearance == .elevatedMemory
      let symbol = NSImage(
        systemSymbolName: isMemory ? "memorychip" : "cpu",
        accessibilityDescription: isMemory ? "Memory" : "CPU"
      )
      button.contentTintColor = nil

      if let color {
        let configuration = NSImage.SymbolConfiguration(paletteColors: [color])
        let image = symbol?.withSymbolConfiguration(configuration)
        image?.isTemplate = false
        button.image = image
      } else {
        symbol?.isTemplate = true
        button.image = symbol
      }
      displayedAppearance = appearance
      displayedDarkAppearance = darkAppearance
    }

    if appearanceChanged || displayedText != text {
      if let color {
        button.attributedTitle = NSAttributedString(
          string: " \(text)",
          attributes: [.foregroundColor: color]
        )
      } else {
        button.title = " \(text)"
      }
      displayedText = text
    }
    button.setAccessibilityLabel(accessibilityLabel)
    button.setAccessibilityValue(accessibilityValue)
  }

  private var warningRed: NSColor {
    adaptiveColor(
      light: NSColor(srgbRed: 0.70, green: 0.13, blue: 0.18, alpha: 1),
      dark: NSColor.systemRed.withAlphaComponent(0.9)
    )
  }

  private var memoryPurple: NSColor {
    adaptiveColor(
      light: NSColor(srgbRed: 0.40, green: 0.18, blue: 0.59, alpha: 1),
      dark: NSColor.systemPurple.withAlphaComponent(0.9)
    )
  }

  private func adaptiveColor(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    }
  }

  private func updateMemoryPressureItem(_ pressure: MemoryPressureLevel) {
    let title = "Memory pressure: \(pressure.menuText)"
    let color: NSColor?
    switch pressure {
    case .warning:
      color = adaptiveColor(
        light: NSColor(srgbRed: 0.46, green: 0.31, blue: 0.02, alpha: 1),
        dark: .systemYellow
      )
    case .critical: color = warningRed
    case .normal, .unavailable: color = nil
    }

    if let color {
      memoryPressureItem.attributedTitle = NSAttributedString(
        string: title,
        attributes: [.foregroundColor: color]
      )
    } else {
      memoryPressureItem.attributedTitle = nil
      memoryPressureItem.title = title
    }
  }

  private func refreshTopProcesses(for metric: MenuBarMetric) {
    let processMetric: ProcessMetricKind?
    switch metric {
    case .cpu(_, elevated: true): processMetric = .cpu
    case .memory: processMetric = .memory
    case .cpu(_, elevated: false): processMetric = nil
    }

    guard let processMetric else {
      hideTopProcesses()
      return
    }

    let metricChanged = currentProcessMetric != processMetric
    let refreshExpired = Date().timeIntervalSince(lastProcessRefresh) >= processRefreshInterval
    currentProcessMetric = processMetric
    showTopProcessesLoading(for: processMetric, resetItems: metricChanged)

    guard metricChanged || refreshExpired else { return }
    lastProcessRefresh = Date()
    processRefreshTask?.cancel()
    processRefreshTask = Task { [weak self] in
      let usages = await Task.detached(priority: .utility) {
        ProcessSampler.topProcesses(for: processMetric)
      }.value
      guard !Task.isCancelled else { return }
      self?.showTopProcesses(usages, for: processMetric)
    }
  }

  private func showTopProcessesLoading(
    for metric: ProcessMetricKind,
    resetItems: Bool
  ) {
    topProcessesHeading.title = metric == .cpu ? "Top CPU processes" : "Top memory processes"
    topProcessesHeading.isHidden = false
    if resetItems {
      for (index, item) in topProcessItems.enumerated() {
        item.title = index == 0 ? "Loading…" : ""
        item.representedObject = nil
        item.isEnabled = false
        item.isHidden = index != 0
      }
    }
  }

  private func showTopProcesses(
    _ usages: [ProcessUsage],
    for metric: ProcessMetricKind
  ) {
    guard currentProcessMetric == metric else { return }

    for (index, item) in topProcessItems.enumerated() {
      guard usages.indices.contains(index) else {
        item.representedObject = nil
        item.isEnabled = false
        item.isHidden = true
        continue
      }

      let usage = usages[index]
      let value: String
      switch metric {
      case .cpu:
        value = String(
          format: "%.1f%% CPU",
          locale: Locale(identifier: "en_US_POSIX"),
          usage.cpuPercentage
        )
      case .memory:
        value = ByteCountFormatter.string(
          fromByteCount: usage.residentMemoryKilobytes * 1_024,
          countStyle: .memory
        )
      }

      item.title = "\(index + 1). \(usage.name) — \(value)"
      item.representedObject = usage.name
      item.isEnabled = true
      item.isHidden = false
    }
  }

  private func hideTopProcesses() {
    currentProcessMetric = nil
    processRefreshTask?.cancel()
    topProcessesHeading.isHidden = true
    for item in topProcessItems {
      item.representedObject = nil
      item.isEnabled = false
      item.isHidden = true
    }
  }

  @objc private func copyProcessName(_ sender: NSMenuItem) {
    guard let processName = sender.representedObject as? String else { return }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(processName, forType: .string)
  }

  @objc private func openActivityMonitor() {
    guard
      let url = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: "com.apple.ActivityMonitor"
      )
    else {
      NSSound.beep()
      return
    }

    NSWorkspace.shared.open(url)
  }

  @objc private func toggleOpenAtLogin() {
    do {
      switch loginItemService.status {
      case .enabled:
        try loginItemService.unregister()
      case .requiresApproval:
        SMAppService.openSystemSettingsLoginItems()
      case .notRegistered, .notFound:
        try loginItemService.register()
      @unknown default:
        try loginItemService.register()
      }
    } catch {
      let alert = NSAlert()
      alert.messageText = "Couldn’t Update Open at Login"
      alert.informativeText = error.localizedDescription
      alert.alertStyle = .warning
      alert.runModal()
    }

    updateOpenAtLoginItem()
  }

  private func updateOpenAtLoginItem() {
    switch loginItemService.status {
    case .enabled:
      openAtLoginItem.state = .on
      openAtLoginItem.toolTip = nil
    case .requiresApproval:
      openAtLoginItem.state = .off
      openAtLoginItem.toolTip = "Approval required in System Settings"
    case .notRegistered:
      openAtLoginItem.state = .off
      openAtLoginItem.toolTip = nil
    case .notFound:
      openAtLoginItem.state = .off
      openAtLoginItem.toolTip = "Login item is unavailable"
    @unknown default:
      openAtLoginItem.state = .off
      openAtLoginItem.toolTip = nil
    }
  }

  @objc private func quit() {
    NSApplication.shared.terminate(nil)
  }
}
