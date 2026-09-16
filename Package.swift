// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "CPULoadBar",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "CPULoadBar", targets: ["CPULoadBar"])
  ],
  targets: [
    .executableTarget(
      name: "CPULoadBar",
      path: "Sources/CPULoadBar"
    ),
    .testTarget(
      name: "CPULoadBarTests",
      dependencies: ["CPULoadBar"]
    ),
  ]
)
