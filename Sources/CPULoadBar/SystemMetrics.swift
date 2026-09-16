import Darwin

struct LoadAverage: Equatable {
  let oneMinute: Double
  let fiveMinutes: Double
  let fifteenMinutes: Double

  static func current() -> LoadAverage? {
    var values = [Double](repeating: 0, count: 3)
    guard getloadavg(&values, Int32(values.count)) == values.count else {
      return nil
    }

    return LoadAverage(
      oneMinute: values[0],
      fiveMinutes: values[1],
      fifteenMinutes: values[2]
    )
  }
}

struct CPUTimeSample: Equatable {
  let user: UInt32
  let system: UInt32
  let idle: UInt32
  let nice: UInt32

  static func current() -> CPUTimeSample? {
    var info = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
    )
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }

    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return nil }

    return CPUTimeSample(
      user: info.cpu_ticks.0,
      system: info.cpu_ticks.1,
      idle: info.cpu_ticks.2,
      nice: info.cpu_ticks.3
    )
  }

  func busyFraction(since previous: CPUTimeSample) -> Double? {
    let busy = Double(user &- previous.user)
      + Double(system &- previous.system)
      + Double(nice &- previous.nice)
    let total = busy + Double(idle &- previous.idle)
    return total > 0 ? busy / total : nil
  }
}

struct CPUBusySampler {
  private var previous: CPUTimeSample?
  private var smoothedBusyFraction: Double?

  mutating func sample() -> Double? {
    guard let current = CPUTimeSample.current() else {
      previous = nil
      smoothedBusyFraction = nil
      return nil
    }
    defer { previous = current }
    guard let previous, let busy = current.busyFraction(since: previous) else {
      return smoothedBusyFraction
    }

    // Smooth the two-second samples so the alert color does not flicker.
    let smoothed = smoothedBusyFraction.map { $0 * 0.75 + busy * 0.25 } ?? busy
    smoothedBusyFraction = smoothed
    return smoothed
  }
}

enum CPUAlertLevel: Equatable {
  case normal
  case elevated
  case high
  case extreme

  static func current(load: Double, logicalCPUCount: Int) -> CPUAlertLevel {
    guard load.isFinite else { return .normal }
    let normalizedLoad = load / Double(max(logicalCPUCount, 1))
    if normalizedLoad >= 5 { return .extreme }
    if normalizedLoad >= 3 { return .high }
    if normalizedLoad >= 1.5 { return .elevated }
    return .normal
  }
}

enum MemoryPressureLevel: Equatable {
  case normal
  case warning
  case critical
  case unavailable

  init(kernelLevel: Int32) {
    switch kernelLevel {
    // This sysctl returns NOTE_MEMORYSTATUS_PRESSURE_* flags, not the
    // kernel's internal 0...3 pressure levels.
    case 1: self = .normal
    case 2: self = .warning
    case 4: self = .critical
    default: self = .unavailable
    }
  }

  static func current() -> MemoryPressureLevel {
    var level: Int32 = 0
    var size = MemoryLayout<Int32>.size
    let result = sysctlbyname(
      "kern.memorystatus_vm_pressure_level",
      &level,
      &size,
      nil,
      0
    )

    return result == 0 ? MemoryPressureLevel(kernelLevel: level) : .unavailable
  }

  var isElevated: Bool {
    switch self {
    case .critical: true
    case .normal, .warning, .unavailable: false
    }
  }

  var menuText: String {
    switch self {
    case .normal: "normal"
    case .warning: "warning"
    case .critical: "critical"
    case .unavailable: "unavailable"
    }
  }
}

enum MenuBarMetric: Equatable {
  case cpu(load: Double, alert: CPUAlertLevel)
  case memory(MemoryPressureLevel)
}

func selectMenuBarMetric(
  load: Double,
  logicalCPUCount: Int,
  memoryPressure: MemoryPressureLevel
) -> MenuBarMetric {
  let alert = CPUAlertLevel.current(
    load: load,
    logicalCPUCount: logicalCPUCount
  )
  if alert != .normal {
    return .cpu(load: load, alert: alert)
  }
  if memoryPressure.isElevated {
    return .memory(memoryPressure)
  }
  return .cpu(load: load, alert: .normal)
}
