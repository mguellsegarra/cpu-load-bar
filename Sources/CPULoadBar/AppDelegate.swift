import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let refreshInterval: TimeInterval = 2
  private var statusItem: NSStatusItem?
  private var refreshTimer: Timer?

  private let oneMinuteItem = NSMenuItem(title: "1 min: —", action: nil, keyEquivalent: "")
  private let fiveMinuteItem = NSMenuItem(title: "5 min: —", action: nil, keyEquivalent: "")
  private let fifteenMinuteItem = NSMenuItem(title: "15 min: —", action: nil, keyEquivalent: "")
  private let memoryPressureItem = NSMenuItem(
    title: "Memory pressure: —",
    action: nil,
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
  }

  private func configureStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem = item

    if let button = item.button {
      button.imagePosition = .imageLeading
      showStatus(
        symbolName: "cpu",
        symbolDescription: "CPU",
        text: "—",
        color: .labelColor,
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

    let quitItem = NSMenuItem(
      title: "Quit CPU Load Bar",
      action: #selector(quit),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    item.menu = menu
  }

  @objc private func refresh() {
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
    memoryPressureItem.title = "Memory pressure: \(memoryPressure.menuText)"

    let metric = selectMenuBarMetric(
      load: loadAverage.oneMinute,
      logicalCPUCount: ProcessInfo.processInfo.activeProcessorCount,
      memoryPressure: memoryPressure
    )
    show(metric: metric, formattedLoad: oneMinute)
  }

  private func format(_ value: Double) -> String {
    String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
  }

  private func showUnavailableState() {
    showStatus(
      symbolName: "cpu",
      symbolDescription: "CPU",
      text: "—",
      color: .labelColor,
      accessibilityLabel: "CPU load average",
      accessibilityValue: "Unavailable"
    )
    statusItem?.button?.toolTip = "CPU load average is unavailable"
    oneMinuteItem.title = "1 min: unavailable"
    fiveMinuteItem.title = "5 min: unavailable"
    fifteenMinuteItem.title = "15 min: unavailable"
    memoryPressureItem.title = "Memory pressure: unavailable"
  }

  private func show(metric: MenuBarMetric, formattedLoad: String) {
    switch metric {
    case .cpu(_, let elevated):
      let color = elevated ? subtleRed : NSColor.labelColor
      showStatus(
        symbolName: "cpu",
        symbolDescription: "CPU",
        text: formattedLoad,
        color: color,
        accessibilityLabel: "CPU load average",
        accessibilityValue: formattedLoad
      )
      statusItem?.button?.toolTip = "CPU load average (1 min): \(formattedLoad)"

    case .memory(let pressure):
      let text = pressure == .critical ? "Critical" : "High"
      let color = pressure == .critical ? NSColor.systemPurple : subtlePurple
      showStatus(
        symbolName: "memorychip",
        symbolDescription: "Memory",
        text: text,
        color: color,
        accessibilityLabel: "Memory pressure",
        accessibilityValue: pressure.menuText
      )
      statusItem?.button?.toolTip = "Memory pressure: \(pressure.menuText)"
    }
  }

  private func showStatus(
    symbolName: String,
    symbolDescription: String,
    text: String,
    color: NSColor,
    accessibilityLabel: String,
    accessibilityValue: String
  ) {
    guard let button = statusItem?.button else { return }

    let image = NSImage(
      systemSymbolName: symbolName,
      accessibilityDescription: symbolDescription
    )
    image?.isTemplate = true
    button.image = image
    button.contentTintColor = color
    button.attributedTitle = NSAttributedString(
      string: " \(text)",
      attributes: [.foregroundColor: color]
    )
    button.setAccessibilityLabel(accessibilityLabel)
    button.setAccessibilityValue(accessibilityValue)
  }

  private var subtleRed: NSColor {
    NSColor.systemRed.blended(withFraction: 0.25, of: .labelColor) ?? .systemRed
  }

  private var subtlePurple: NSColor {
    NSColor.systemPurple.blended(withFraction: 0.25, of: .labelColor) ?? .systemPurple
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

  @objc private func quit() {
    NSApplication.shared.terminate(nil)
  }
}
