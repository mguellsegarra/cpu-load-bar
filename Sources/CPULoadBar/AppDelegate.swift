import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private enum StatusAppearance: Equatable {
    case cpu(CPUAlertLevel)
    case elevatedMemory
  }

  private let refreshInterval: TimeInterval = 2
  private let processRefreshInterval: TimeInterval = 10
  private var statusItem: NSStatusItem?
  private var displayedAppearance: StatusAppearance?
  private var displayedText: String?
  private var displayedDarkAppearance: Bool?
  private var refreshTimer: Timer?
  private var cpuBusySampler = CPUBusySampler()
  private var processRefreshTask: Task<Void, Never>?
  private var copyConfirmationPanel: NSPanel?
  private var copyConfirmationTimer: Timer?
  private var pendingCopiedProcessName: String?
  private var copyConfirmationScheduled = false
  private var isProcessMenuOpen = false
  private var currentProcessMetric: ProcessMetricKind?
  private var lastProcessRefresh = Date.distantPast
  private let loginItemService = SMAppService.mainApp

  private let oneMinuteItem = NSMenuItem(title: "1 min: —", action: nil, keyEquivalent: "")
  private let fiveMinuteItem = NSMenuItem(title: "5 min: —", action: nil, keyEquivalent: "")
  private let fifteenMinuteItem = NSMenuItem(title: "15 min: —", action: nil, keyEquivalent: "")
  private let cpuBusyItem = NSMenuItem(title: "CPU busy (recent): —", action: nil, keyEquivalent: "")
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
    copyConfirmationTimer?.invalidate()
  }

  private func configureStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.autosaveName = "dev.ondori.cpu-load-bar.status"
    statusItem = item

    if let button = item.button {
      button.imagePosition = .imageLeading
      showStatus(
        appearance: .cpu(.normal),
        text: "—",
        accessibilityLabel: "CPU load average",
        accessibilityValue: "Unavailable"
      )
    }

    let menu = NSMenu()
    menu.delegate = self
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
    cpuBusyItem.isEnabled = false
    memoryPressureItem.isEnabled = false
    menu.addItem(oneMinuteItem)
    menu.addItem(fiveMinuteItem)
    menu.addItem(fifteenMinuteItem)
    menu.addItem(cpuBusyItem)
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
    let busyFraction = cpuBusySampler.sample()
    let oneMinute = format(loadAverage.oneMinute)
    let fiveMinutes = format(loadAverage.fiveMinutes)
    let fifteenMinutes = format(loadAverage.fifteenMinutes)

    oneMinuteItem.title = "1 min: \(oneMinute)"
    fiveMinuteItem.title = "5 min: \(fiveMinutes)"
    fifteenMinuteItem.title = "15 min: \(fifteenMinutes)"
    cpuBusyItem.title = busyFraction.map {
      "CPU busy (recent): \(Int(($0 * 100).rounded()))%"
    } ?? "CPU busy (recent): —"
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
      appearance: .cpu(.normal),
      text: "—",
      accessibilityLabel: "CPU load average",
      accessibilityValue: "Unavailable"
    )
    statusItem?.button?.toolTip = "CPU load average is unavailable"
    oneMinuteItem.title = "1 min: unavailable"
    fiveMinuteItem.title = "5 min: unavailable"
    fifteenMinuteItem.title = "15 min: unavailable"
    cpuBusyItem.title = "CPU busy (recent): —"
    updateMemoryPressureItem(.unavailable)
    hideTopProcesses()
  }

  private func show(metric: MenuBarMetric, formattedLoad: String) {
    switch metric {
    case .cpu(_, let alert):
      showStatus(
        appearance: .cpu(alert),
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
    case .cpu(.normal): color = nil
    case .cpu(let level): color = cpuColor(for: level)
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
        button.image = image.map(alignStatusImage)
      } else {
        symbol?.isTemplate = true
        button.image = symbol.map(alignStatusImage)
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

  private func alignStatusImage(_ image: NSImage) -> NSImage {
    let aligned = NSImage(size: image.size, flipped: false) { _ in
      image.draw(
        in: NSRect(x: 0, y: 0.5, width: image.size.width, height: image.size.height),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
      )
      return true
    }
    aligned.isTemplate = image.isTemplate
    return aligned
  }

  private var warningRed: NSColor {
    adaptiveColor(
      light: NSColor(srgbRed: 0.70, green: 0.13, blue: 0.18, alpha: 1),
      dark: NSColor.systemRed.withAlphaComponent(0.9)
    )
  }

  private func cpuColor(for level: CPUAlertLevel) -> NSColor {
    let light: UInt32
    let dark: UInt32
    switch level {
    case .normal: return .labelColor
    case .elevated: (light, dark) = (0x9A4A37, 0xD9957F)
    case .high: (light, dark) = (0xAE2F2C, 0xEB7067)
    case .extreme: (light, dark) = (0x77112D, 0xFF4969)
    }
    return adaptiveColor(light: rgb(light), dark: rgb(dark))
  }

  private func rgb(_ value: UInt32) -> NSColor {
    NSColor(
      srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: 1
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
    guard !isProcessMenuOpen else { return }

    let processMetric: ProcessMetricKind?
    switch metric {
    case .cpu(_, let alert) where alert != .normal: processMetric = .cpu
    case .memory: processMetric = .memory
    case .cpu: processMetric = nil
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
    guard !isProcessMenuOpen, currentProcessMetric == metric else { return }

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
    guard !isProcessMenuOpen else { return }

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
    guard pasteboard.setString(processName, forType: .string) else {
      NSSound.beep()
      return
    }
    pendingCopiedProcessName = processName
    scheduleCopyConfirmation()
  }

  func menuWillOpen(_ menu: NSMenu) {
    isProcessMenuOpen = true
    dismissCopyConfirmation()
  }

  func menuDidClose(_ menu: NSMenu) {
    isProcessMenuOpen = false
    scheduleCopyConfirmation()
    lastProcessRefresh = .distantPast
    DispatchQueue.main.async { [weak self] in
      self?.refresh()
    }
  }

  private func scheduleCopyConfirmation() {
    guard pendingCopiedProcessName != nil, !copyConfirmationScheduled else { return }
    copyConfirmationScheduled = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      guard let self else { return }
      self.copyConfirmationScheduled = false
      guard !self.isProcessMenuOpen, let processName = self.pendingCopiedProcessName else {
        return
      }
      self.pendingCopiedProcessName = nil
      self.showCopyConfirmation(for: processName)
    }
  }

  private func showCopyConfirmation(for processName: String) {
    let pointer = NSEvent.mouseLocation
    guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) })
      ?? NSScreen.main else { return }

    copyConfirmationTimer?.invalidate()
    copyConfirmationPanel?.close()

    let size = NSSize(width: 280, height: 58)
    let contentView = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
    contentView.material = .popover
    contentView.blendingMode = .behindWindow
    contentView.state = .active
    contentView.wantsLayer = true
    contentView.layer?.cornerRadius = 12
    contentView.layer?.masksToBounds = true
    let checkmark = NSImageView(
      image: NSImage(
        systemSymbolName: "checkmark.circle.fill",
        accessibilityDescription: nil
      ) ?? NSImage()
    )
    checkmark.frame = NSRect(x: 14, y: 20, width: 18, height: 18)
    checkmark.contentTintColor = .systemGreen
    contentView.addSubview(checkmark)

    let title = NSTextField(labelWithString: "Copied to clipboard")
    title.font = .systemFont(ofSize: 13, weight: .semibold)
    title.frame = NSRect(x: 42, y: 30, width: 224, height: 18)
    contentView.addSubview(title)

    let detail = NSTextField(labelWithString: processName)
    detail.font = .systemFont(ofSize: 11)
    detail.textColor = .secondaryLabelColor
    detail.lineBreakMode = .byTruncatingMiddle
    detail.frame = NSRect(x: 42, y: 11, width: 224, height: 15)
    contentView.addSubview(detail)

    let panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.contentView = contentView
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .popUpMenu
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    let visible = screen.visibleFrame
    let centeredX = screen.frame.midX - size.width / 2
    let topY = visible.maxY - size.height - 12
    panel.setFrameOrigin(NSPoint(
      x: min(max(centeredX, visible.minX + 8), visible.maxX - size.width - 8),
      y: max(topY, visible.minY + 8)
    ))
    copyConfirmationPanel = panel
    panel.orderFrontRegardless()

    copyConfirmationTimer = Timer.scheduledTimer(
      timeInterval: 2,
      target: self,
      selector: #selector(dismissCopyConfirmation),
      userInfo: nil,
      repeats: false
    )
  }

  @objc private func dismissCopyConfirmation() {
    copyConfirmationTimer?.invalidate()
    copyConfirmationPanel?.close()
    copyConfirmationPanel = nil
    copyConfirmationTimer = nil
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
