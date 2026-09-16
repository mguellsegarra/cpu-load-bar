import Foundation

enum ProcessMetricKind: Sendable {
  case cpu
  case memory
}

struct ProcessUsage: Equatable, Sendable {
  let processID: Int32
  let name: String
  let cpuPercentage: Double
  let residentMemoryKilobytes: Int64
}

enum ProcessSampler {
  static func topProcesses(for metric: ProcessMetricKind, limit: Int = 3) -> [ProcessUsage] {
    let process = Process()
    let outputPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = [
      "-A",
      metric == .cpu ? "-r" : "-m",
      "-c",
      "-o",
      "pid=,pcpu=,rss=,comm=",
    ]
    process.standardOutput = outputPipe
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
    } catch {
      return []
    }

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0,
      let output = String(data: outputData, encoding: .utf8)
    else {
      return []
    }

    return parse(
      output,
      excluding: [getpid(), process.processIdentifier],
      limit: limit
    )
  }

  static func parse(
    _ output: String,
    excluding excludedProcessIDs: Set<Int32> = [],
    limit: Int = 3
  ) -> [ProcessUsage] {
    output.split(whereSeparator: \Character.isNewline)
      .compactMap { line -> ProcessUsage? in
        let columns = line.split(
          maxSplits: 3,
          whereSeparator: \Character.isWhitespace
        )
        guard columns.count == 4,
          let processID = Int32(columns[0]),
          !excludedProcessIDs.contains(processID),
          let cpuPercentage = Double(columns[1]),
          let residentMemoryKilobytes = Int64(columns[2])
        else {
          return nil
        }

        return ProcessUsage(
          processID: processID,
          name: String(columns[3]),
          cpuPercentage: cpuPercentage,
          residentMemoryKilobytes: residentMemoryKilobytes
        )
      }
      .prefix(max(limit, 0))
      .map { $0 }
  }
}
