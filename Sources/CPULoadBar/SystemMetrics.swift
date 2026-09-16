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
  case cpu(load: Double, elevated: Bool)
  case memory(MemoryPressureLevel)
}

func selectMenuBarMetric(
  load: Double,
  logicalCPUCount: Int,
  memoryPressure: MemoryPressureLevel
) -> MenuBarMetric {
  let elevatedThreshold = Double(max(logicalCPUCount, 1)) * 0.8
  if load >= elevatedThreshold {
    return .cpu(load: load, elevated: true)
  }
  if memoryPressure.isElevated {
    return .memory(memoryPressure)
  }
  return .cpu(load: load, elevated: false)
}
