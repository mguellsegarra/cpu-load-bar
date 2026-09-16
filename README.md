# CPU Load Bar

[![CI](https://github.com/mguellsegarra/cpu-load-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/mguellsegarra/cpu-load-bar/actions/workflows/ci.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://support.apple.com/macos)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A tiny, native macOS menu bar app that keeps the current CPU load average visible at a glance.

CPU Load Bar shows the one-minute load average beside a native CPU symbol. Open its menu for the 1, 5 and 15-minute values, the number of logical CPUs, a manual refresh action and Quit.

## Features

- Native Swift and AppKit
- Universal binary for Apple Silicon and Intel Macs
- One-minute load visible in the menu bar
- 1, 5 and 15-minute values in the menu
- One-click access to Activity Monitor
- Purple memory-chip indicator when memory pressure is high and CPU load is normal
- Subtle red CPU icon and value when CPU load is elevated
- Two-second refresh interval
- VoiceOver label and current-value support
- No Dock icon, third-party dependencies, network requests, analytics or stored data

## Requirements

- macOS 13 Ventura or newer

## Install

Download `CPU-Load-Bar.zip` from the [latest release](https://github.com/mguellsegarra/cpu-load-bar/releases/latest), unzip it and move **CPU Load Bar.app** to Applications.

The downloadable app is ad-hoc signed but not Apple-notarized. On first launch, macOS may require you to right-click the app and choose **Open**.

## Build from source

Xcode with the macOS SDK and Swift 6 are required.

```sh
git clone https://github.com/mguellsegarra/cpu-load-bar.git
cd cpu-load-bar
./scripts/build-app.sh
open "build/CPU Load Bar.app"
```

The script builds a universal release binary, creates the app bundle at `build/CPU Load Bar.app`, and applies an ad-hoc signature.

## Understanding load average

Load average is not a CPU percentage. It represents runnable or waiting work averaged over time. As a rough guide, a load near the number of logical CPUs means the machine has approximately one runnable task per logical CPU.

Click the menu item to compare the 1, 5 and 15-minute values and see the logical CPU count reported by macOS.

The menu bar indicator prioritizes the signal that needs attention:

1. CPU stays visible with a subtle red icon and value when the one-minute load reaches 80% of the logical CPU count.
2. When CPU load is below that threshold but macOS reports elevated memory pressure, the indicator changes to a purple memory-chip icon with **High** or **Critical**.
3. Otherwise, the normal CPU load remains visible using the standard menu bar color.

## Resource use and privacy

CPU Load Bar calls the native `getloadavg(3)` API every two seconds. It does not make network requests, collect analytics or persist information. On the development machine, the idle process measured `0.0%` CPU and approximately `40 MB` resident memory; exact usage varies by macOS version and hardware.

## Development

```sh
swift build
./scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 "build/CPU Load Bar.app"
```

Contributions and bug reports are welcome through GitHub issues and pull requests.

## License

[MIT](LICENSE) © 2026 Marc Güell Segarra
