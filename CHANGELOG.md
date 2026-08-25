# Changelog

All notable changes to Pawse will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Renamed the application and open-source project from Breather to Pawse while preserving the existing application identifier for local settings and analytics compatibility.
- Reduced the native settings sidebar width and tightened its brand header spacing.
- Reworked the full-color identity into a simpler head-only 2D animated puppy across the app icon, sidebar, banner treatment, and Break Soon HUD while retaining the existing monochrome menu-bar icon.
- Set the default sound profile to Submarine for session start and break completion, no Break Ready sound, and 70% volume.
- Reorganized the README around Pawse's value, default rhythm, natural-break behavior, source installation, architecture, privacy, and contribution workflow.

### Added

- Open-source project governance, contribution documentation, and macOS CI.
- Native menu-bar Focus, Short Break, and Long Break workflow.
- Natural stopping-point detection with Break Pending and Break Entering states.
- Branded Break Soon HUD and multi-display break overlays.
- Local SwiftData analytics, native settings, sounds, and configurable backgrounds.
- Solid Color break backgrounds and explicit wallpaper-folder authorization.
- Unified sleeping-dog-head application identity, landscape banner, and native macOS design guidelines.

### Fixed

- Persist custom break images with read-only security-scoped bookmarks and migrate readable legacy bookmarks.
