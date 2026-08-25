# Changelog

All notable changes to Pawse will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added a localized About page with live version and build information, author and project links, and matching sidebar and macOS App menu entry points.
- Added a standalone Donate action to the Pawse sidebar.

### Changed

- Routed donation links in Pawse, the product website, README, and GitHub Sponsors through `https://yorukot.me/donate`.

## [0.1.1] - 2026-08-25

### Changed

- Simplified the README around Pawse's product experience, download, privacy, and contribution paths.
- Pinned CI and release builds to Xcode 26.6 and the macOS 26.5 SDK so Pawse uses the current native appearance on macOS 26 while retaining native compatibility with macOS 14 and 15.
- Rebuilt the DMG as a branded drag-to-Applications Finder window with fixed icon placement and automatic artifact validation.
- Redesigned Analytics with a clearer Focus summary, completion ring, aligned Break metrics, a combined daily Focus/Break chart, and a cleaner recent-session table.

### Added

- Added a responsive product site using real Pawse screenshots, accessible navigation, social metadata, structured data, sitemap, and GitHub Pages deployment.
- Added a separate download page that presents optional Ko-fi support and the free download at equal visual priority.
- Added a custom mounted-volume icon and illustrated installer background to the DMG.

### Fixed

- Fixed Release builds using the older macOS 15 SDK, which caused Pawse to render with the previous system appearance on macOS 26.
- Fixed mounted Pawse disk images displaying the generic macOS disk icon.

## [0.1.0] - 2026-08-25

### Changed

- Renamed the application and open-source project from Breather to Pawse while preserving the existing application identifier for local settings and analytics compatibility.
- Reduced the native settings sidebar width and tightened its brand header spacing.
- Reworked the full-color identity around a calm, right-facing sleeping white shepherd across the app icon, sidebar, banner treatment, and Break Soon HUD while retaining the existing monochrome menu-bar icon.
- Set the default sound profile to Submarine for session start and break completion, no Break Ready sound, and 70% volume.
- Reorganized the README around Pawse's value, default rhythm, natural-break behavior, source installation, architecture, privacy, and contribution workflow.
- Replaced the separate README logo and landscape with one centered branded hero stored under stable documentation assets.

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

[Unreleased]: https://github.com/yorukot/pawse/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/yorukot/pawse/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/yorukot/pawse/releases/tag/v0.1.0
