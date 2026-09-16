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
      memoryPressure: .critical
    )

    XCTAssertEqual(metric, .memory(.critical))
  }

  func testWarningMemoryPressureKeepsNormalCPULoad() {
    let metric = selectMenuBarMetric(
      load: 2,
      logicalCPUCount: 10,
      memoryPressure: .warning
    )

    XCTAssertEqual(metric, .cpu(load: 2, elevated: false))
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
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: 1), .normal)
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: 2), .warning)
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: 4), .critical)
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: 0), .unavailable)
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: 3), .unavailable)
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: 5), .unavailable)
    XCTAssertEqual(MemoryPressureLevel(kernelLevel: -1), .unavailable)
  }

  func testProcessSamplerParsesNamesWithSpacesAndExcludesProcesses() {
    let output = """
        101 42.5 2048 WindowServer
        202 20.0 1048576 Google Chrome Helper
        303 10.0 512 backupd
      """

    let usages = ProcessSampler.parse(output, excluding: [202], limit: 2)

    XCTAssertEqual(
      usages,
      [
        ProcessUsage(
          processID: 101,
          name: "WindowServer",
          cpuPercentage: 42.5,
          residentMemoryKilobytes: 2048
        ),
        ProcessUsage(
          processID: 303,
          name: "backupd",
          cpuPercentage: 10,
          residentMemoryKilobytes: 512
        ),
      ]
    )
  }
}
