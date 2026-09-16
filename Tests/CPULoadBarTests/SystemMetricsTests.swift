import XCTest

@testable import CPULoadBar

final class SystemMetricsTests: XCTestCase {
  func testElevatedCPULoadTakesPriorityOverCriticalMemoryPressure() {
    let metric = selectMenuBarMetric(
      load: 8,
      logicalCPUCount: 10,
      memoryPressure: .critical
    )

    XCTAssertEqual(metric, .cpu(load: 8, elevated: true))
  }

  func testElevatedMemoryPressureReplacesNormalCPULoad() {
    let metric = selectMenuBarMetric(
      load: 2,
      logicalCPUCount: 10,
      memoryPressure: .warning
    )

    XCTAssertEqual(metric, .memory(.warning))
  }

  func testNormalMemoryPressureKeepsNormalCPULoad() {
    let metric = selectMenuBarMetric(
      load: 2,
      logicalCPUCount: 10,
      memoryPressure: .normal
    )

    XCTAssertEqual(metric, .cpu(load: 2, elevated: false))
  }

  func testMemoryPressureKernelLevelsAreMapped() {
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: 0), .normal)
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: 1), .warning)
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: 2), .urgent)
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: 3), .critical)
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: -1), .unavailable)
  }
}
