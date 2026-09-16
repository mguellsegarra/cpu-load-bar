# CPU Load Bar

[![CI](https://github.com/mguellsegarra/cpu-load-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/mguellsegarra/cpu-load-bar/actions/workflows/ci.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://support.apple.com/macos)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A tiny, native macOS menu bar app that keeps the current CPU load average visible at a glance.

CPU Load Bar shows the one-minute load average beside a native CPU symbol. Open its menu for the 1, 5 and 15-minute values, the number of logical CPUs, a manual refresh action and Quit.

<p align="center">
  <img src="docs/screenshots/high-cpu.png" width="600" alt="CPU Load Bar showing a red CPU alert, the top three CPU processes, and urgent memory pressure in its macOS menu" />
  <br />
  <sub>CPU alert · top processes and memory pressure at a glance</sub>
</p>

## Features

- Native Swift and AppKit
- Custom app icon with an editable SVG source
- Universal binary for Apple Silicon and Intel Macs
- One-minute load visible in the menu bar
- 1, 5 and 15-minute values in the menu
- One-click access to Activity Monitor
- Native Open at Login toggle
- Top three CPU or memory-consuming processes while an alert is active
- Purple memory-chip indicator when memory pressure is urgent or critical and CPU load is normal
- Memory-pressure menu detail graded by level: yellow for warning, orange for urgent and red for critical
- Subtle red CPU icon and value when CPU load is elevated
- Two-second refresh interval
- VoiceOver label and current-value support
- No Dock icon, third-party dependencies, network requests, analytics or stored data

## Requirements

- macOS 13 Ventura or newer

## Install

Download `CPU-Load-Bar.dmg` from [GitHub Releases](https://github.com/mguellsegarra/cpu-load-bar/releases), open it and drag **CPU Load Bar.app** onto **Applications**.

The downloadable app is ad-hoc signed but not Apple-notarized. On first launch, macOS may require you to right-click the app and choose **Open**.

## Build from source

Xcode with the macOS SDK and Swift 6 are required.

```sh
git clone https://github.com/mguellsegarra/cpu-load-bar.git
cd cpu-load-bar
./scripts/build-app.sh
ditto "build/CPU Load Bar.app" "/Applications/CPU Load Bar.app"
open "/Applications/CPU Load Bar.app"
```

The script builds a universal release binary, creates the app bundle at `build/CPU Load Bar.app`, and applies an ad-hoc signature.
Quit any running copy before replacing it. On macOS 27, run the app from `/Applications` for reliable menu bar visibility, especially with Bartender; running the build copy directly may make the item appear missing.

The app icon is generated from `Resources/AppIcon.svg`. To regenerate `Resources/AppIcon.icns` after editing the SVG, install ImageMagick and run `./scripts/build-icon.sh`.
To build the drag-to-Applications disk image locally, install ImageMagick and run `./scripts/build-dmg.sh`. The DMG will be written to `build/CPU-Load-Bar.dmg`.

## Understanding load average

Load average is not a CPU percentage. It represents runnable or waiting work averaged over time. As a rough guide, a load near the number of logical CPUs means the machine has approximately one runnable task per logical CPU.

Click the menu item to compare the 1, 5 and 15-minute values and see the logical CPU count reported by macOS.

The menu bar indicator prioritizes the signal that needs attention:

1. CPU stays visible with a subtle red icon and value when the one-minute load reaches 80% of the logical CPU count.
2. A memory **Warning** is shown only inside the menu, in yellow. When CPU load is below its threshold but memory pressure becomes **Urgent** or **Critical**, the menu bar changes to a purple memory-chip indicator.
3. Otherwise, the normal CPU load remains visible using the standard menu bar color.

While an alert is active, the menu lists the three processes using the most CPU or resident memory directly below **Open Activity Monitor**. Click a process to copy its name to the clipboard. This list refreshes every ten seconds in the background and is hidden when system pressure returns to normal.

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
