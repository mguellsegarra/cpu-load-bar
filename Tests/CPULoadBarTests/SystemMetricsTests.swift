import XCTest

@testable import CPULoadBar

final class SystemMetricsTests: XCTestCase {
  func testElevatedCPULoadTakesPriorityOverCriticalMemoryPressure() {
    let metric = selectMenuBarMetric(
      load: 18,
      logicalCPUCount: 10,
      memoryPressure: .critical
    )

    XCTAssertEqual(metric, .cpu(load: 18, alert: .elevated))
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

    XCTAssertEqual(metric, .cpu(load: 2, alert: .normal))
  }

  func testNormalMemoryPressureKeepsNormalCPULoad() {
    let metric = selectMenuBarMetric(
      load: 2,
      logicalCPUCount: 10,
      memoryPressure: .normal
    )

    XCTAssertEqual(metric, .cpu(load: 2, alert: .normal))
  }

  func testLoadBelowThresholdDoesNotTriggerAlert() {
    let metric = selectMenuBarMetric(
      load: 12.5,
      logicalCPUCount: 10,
      memoryPressure: .normal
    )

    XCTAssertEqual(metric, .cpu(load: 12.5, alert: .normal))
  }

  func testCriticalMemoryStillShowsWhenCPULoadIsBelowThreshold() {
    let metric = selectMenuBarMetric(
      load: 12,
      logicalCPUCount: 10,
      memoryPressure: .critical
    )

    XCTAssertEqual(metric, .memory(.critical))
  }

  func testExtremeLoadIsVisible() {
    let metric = selectMenuBarMetric(
      load: 158,
      logicalCPUCount: 10,
      memoryPressure: .normal
    )

    XCTAssertEqual(metric, .cpu(load: 158, alert: .extreme))
  }

  func testHighLoadIsVisible() {
    XCTAssertEqual(
      CPUAlertLevel.current(load: 40, logicalCPUCount: 10),
      .high
    )
  }

  func testAlertLevelsScaleWithAvailableCPUs() {
    for cpuCount in [8, 10, 16] {
      let count = Double(cpuCount)
      XCTAssertEqual(
        CPUAlertLevel.current(load: count * 1.3, logicalCPUCount: cpuCount),
        .normal
      )
      XCTAssertEqual(
        CPUAlertLevel.current(load: count * 1.8, logicalCPUCount: cpuCount),
        .elevated
      )
      XCTAssertEqual(
        CPUAlertLevel.current(load: count * 3.1, logicalCPUCount: cpuCount),
        .high
      )
      XCTAssertEqual(
        CPUAlertLevel.current(load: count * 5.1, logicalCPUCount: cpuCount),
        .extreme
      )
    }
  }

  func testExactAlertThresholds() {
    XCTAssertEqual(
      CPUAlertLevel.current(load: 15, logicalCPUCount: 10),
      .elevated
    )
    XCTAssertEqual(
      CPUAlertLevel.current(load: 30, logicalCPUCount: 10),
      .high
    )
    XCTAssertEqual(
      CPUAlertLevel.current(load: 50, logicalCPUCount: 10),
      .extreme
    )
  }

  func testNonfiniteCPULoadDoesNotTriggerFalseAlert() {
    XCTAssertEqual(
      CPUAlertLevel.current(load: .nan, logicalCPUCount: 10),
      .normal
    )
  }

  func testCPUTimeSampleUsesChangesNotLifetimeTotals() {
    let previous = CPUTimeSample(user: 100, system: 50, idle: 200, nice: 0)
    let current = CPUTimeSample(user: 140, system: 60, idle: 250, nice: 0)

    XCTAssertEqual(current.busyFraction(since: previous)!, 0.5, accuracy: 0.0001)
    XCTAssertNil(previous.busyFraction(since: previous))
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
