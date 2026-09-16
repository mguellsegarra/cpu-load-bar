# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Native Open at Login toggle backed by macOS Service Management.

## [1.0.0] - 2026-09-16

### Added

- Native macOS menu bar display for the one-minute CPU load average.
- Menu details for 1, 5 and 15-minute load averages and logical CPU count.
- Matching status colors: subtle red for elevated CPU load, purple for urgent or critical memory mode, and yellow/orange/red pressure levels inside the menu.
- Activity Monitor shortcut as the first menu action.
- Top three CPU or memory-consuming processes shown while the corresponding alert is active.
- Two-second automatic refresh and manual refresh action.
- VoiceOver metadata for the menu bar item.
- Universal Apple Silicon and Intel build script.

[Unreleased]: https://github.com/mguellsegarra/cpu-load-bar/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/mguellsegarra/cpu-load-bar/releases/tag/v1.0.0
