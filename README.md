<p align="center">
  <img src="docs/assets/pawse-hero.png" width="100%" alt="Pawse — Focus deeply. Rest naturally. A sleeping white shepherd above an illustrated mountain landscape.">
</p>

<div align="center">
  <p>A native macOS focus timer that waits for a natural stopping point before starting your break.</p>

  <p>
    <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple&logoColor=white">
    <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
    <img alt="SwiftUI and AppKit" src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-0A84FF">
    <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-34C759"></a>
  </p>

  <p>
    <a href="#install-and-run">Install</a> ·
    <a href="#features">Features</a> ·
    <a href="#how-natural-breaks-work">Natural Breaks</a> ·
    <a href="#privacy">Privacy</a> ·
    <a href="CONTRIBUTING.md">Contributing</a>
  </p>
</div>

Pawse lives quietly in the menu bar and guides you through Focus, Short Break, and Long Break sessions. Unlike a conventional Pomodoro timer, it does not immediately cover your screen when Focus reaches zero. It shows a compact **Break soon** reminder, then waits for a click or a brief period without keyboard and pointer activity.

Pawse is free and open source. Settings and session history remain on your Mac, there is no account, and the app makes no analytics or telemetry network requests.

## Why Pawse

- **Breaks at a natural moment.** Finish the thought, sentence, or action already in progress before stepping away.
- **Native from top to bottom.** SwiftUI, AppKit, SwiftData, Swift Charts, SF Symbols, native controls, and macOS materials—no WebView or cross-platform shell.
- **Private by design.** Pawse checks only aggregate system idle time. It never records keys, pointer coordinates, app names, window titles, URLs, or screen contents.
- **Safe to leave.** Every display includes an Emergency Exit, and one idempotent cleanup path restores overlays, sounds, Dock, menu bar, and prior presentation options.
- **Open and dependency-light.** The full source, tests, design guidance, architecture, governance, and release process are included under the MIT License.

## Default rhythm

| Session | Default | What happens next |
| --- | ---: | --- |
| Focus | 25 minutes | Pawse offers a scheduled break at a natural stopping point. |
| Short Break | 30 seconds | Focus starts again automatically. |
| Long Break | 10 minutes | The cycle resets, then Focus starts again automatically. |

A Long Break is scheduled after **2 completed Short Break cycles** by default. Durations, cycle length, automatic transitions, idle delay, and grace period are configurable in the native settings window.

## How natural breaks work

```text
Focus completes
       ↓
Break Pending — “Break soon” appears while you finish naturally
       ↓ click, or 2 seconds idle by default
Break Entering — a short grace period begins
       ├─ input resumes → return to Break Pending
       └─ no input      → commit the full-screen Break
```

Pending time is neither Focus time nor Break time. If activity resumes during entry, Pawse removes the overlay and waits for a completely new idle interval. The next attempt starts with the full configured break duration. Once a Break is committed, ordinary input does not dismiss it; countdown completion or a confirmed Emergency Exit ends it.

The reminder’s 15-second attention indicator fills **before** the Break begins. After it fills, the HUD becomes warmer and more noticeable, but it never forces a Break while you remain active. Reduce Motion replaces animated attention treatments with a calm static state.

Manual Short and Long Breaks begin immediately because selecting one is already an explicit request to rest.

## Features

### Focus and cycle

- Absolute-deadline timers without counter drift
- Focus pause/resume with paused time excluded from analytics
- Confirmation before switching or interrupting an active Focus
- Configurable Short/Long Break cycle and automatic next Focus
- Cycle-aware estimates for the next Short Break and Long Break
- Skip Focus and Skip Next Break actions with deterministic analytics and cycle behavior

### Break experience

- Non-activating, top-center **Break soon** HUD with the sleeping-dog mascot
- Privacy-preserving natural-stop detection without Accessibility or Input Monitoring permission
- Grace-period retreat when keyboard or pointer activity immediately resumes
- Full-screen native panels across connected displays, synchronized as displays change
- Current wallpaper, a user-selected image, or a solid-color break background
- Fade transitions that automatically respect Reduce Motion
- Persistent, keyboard-accessible Emergency Exit confirmation on every display

### Native macOS experience

- Menu-bar-only operation with a sleeping-dog icon and progress ring—no countdown text in the menu bar
- One native sidebar window for Analytics and all settings
- Native sliders, pickers, toggles, tables, charts, materials, and accessibility behavior
- Filtered macOS system sounds with preview and volume controls
- Default sound profile: `Submarine` for session start and break completion, no Break Ready sound, 70% volume
- Launch at Login through the public `SMAppService` API
- English, Spanish, Japanese, Simplified Chinese, and Traditional Chinese interfaces

### Local analytics

- SwiftData history stored only on this Mac
- Focused time with pauses excluded
- Completed and interrupted Focus, Short Break, and Long Break totals
- Emergency Exit counts and automatic-break deferral timing
- Today, Last 7 Days, Last 30 Days, and All Time ranges
- Swift Charts Focus-by-day visualization and a native recent-session table
- Clear Analytics without resetting settings, cycle progress, or an active session

## Install and run

### Download Pawse 0.1.0

Download the early-access macOS disk image from the [v0.1.0 release](https://github.com/yorukot/pawse/releases/tag/v0.1.0), open it, and drag **Pawse** to **Applications**.

Pawse 0.1.0 is an ad-hoc signed open-source preview and is not Apple-notarized yet. macOS may require Control-clicking Pawse and choosing **Open** on first launch. Verify the download with the attached checksum:

```bash
shasum -a 256 -c Pawse-0.1.0.dmg.sha256
```

The release page includes both `Pawse-0.1.0.dmg` and `Pawse-0.1.0.dmg.sha256`. Pawse appears in the menu bar and intentionally has no normal Dock icon.

### Build from source

### Requirements

- macOS 14 or later
- Xcode with Swift 6 support and the macOS 14 SDK or later
- Git

Pawse has no third-party runtime or package dependencies.

### Xcode

1. Clone or download this repository.
2. Open `Pawse.xcodeproj`.
3. Select the **Pawse** scheme and **My Mac** destination.
4. Press **Run**.

Pawse appears in the menu bar and does not show a normal Dock icon. Use **Open Pawse…** from the menu-bar popover, or press Command-comma, to open the unified Analytics and Settings window.

### Command line

```bash
make build
open .build/DerivedData/Build/Products/Debug/Pawse.app
```

Equivalent direct command:

```bash
xcodebuild \
  -project Pawse.xcodeproj \
  -scheme Pawse \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  build
```

## Testing

Run the complete deterministic XCTest suite:

```bash
make test
```

Run tests and repository whitespace checks together:

```bash
make verify
```

The suite uses fake clocks, schedulers, activity samples, sounds, overlays, and an in-memory SwiftData configuration. It covers timing, pause accounting, mode switching, cycle semantics, natural-break retries, sound transitions, Emergency Exit, cleanup idempotency, analytics persistence, aggregation, localization, assets, and menu-bar rendering.

## Architecture

| Area | Responsibility |
| --- | --- |
| `SessionController` | Session state machine, deadlines, pause/resume, cycle transitions, sounds, and analytics finalization |
| `SettingsStore` | Centralized validated preferences backed by `UserDefaults` |
| `UserActivityMonitor` | Aggregate Core Graphics idle and input counters while a Break is pending or entering |
| `BreakReminderCoordinator` | Non-activating Break Soon panel lifecycle and display placement |
| `OverlayCoordinator` | One full-screen native panel per connected display |
| `BreakEnvironmentCoordinator` | Centralized and idempotent Break setup/cleanup |
| `SoundService` | Runtime-filtered `NSSound` playback and previews |
| `AnalyticsStore` / `AnalyticsAggregator` | Local SwiftData persistence and date-range metrics |

See [Architecture](docs/ARCHITECTURE.md) for the state model, dependency boundaries, cleanup contract, and persistence design. UI changes should also follow the project’s [Design Guidelines](DESIGN_GUIDELINES.md).

## Privacy

Pawse stores settings and session history locally on this Mac.

It does not collect telemetry, send analytics to a server, inspect application contents, record keyboard input, or make network requests.

Pawse checks aggregate system idle time and aggregate input counters only while a scheduled Break is pending or entering. It never retains individual input events, keys, keyboard shortcuts, pointer coordinates, application names, window titles, URLs, screen contents, files, location, account data, or device fingerprints.

Natural-break detection does not require Accessibility or Input Monitoring permission. Wallpaper and custom-image access is granted explicitly by the user through standard macOS file access and stored as security-scoped bookmarks.

Read the full [Privacy documentation](docs/PRIVACY.md).

## Contributing

Bug reports, focused feature proposals, documentation improvements, translations, and tested code contributions are welcome.

Before opening a pull request, read [CONTRIBUTING.md](CONTRIBUTING.md) and run `make verify`. Community participation follows the [Code of Conduct](CODE_OF_CONDUCT.md). Please report vulnerabilities privately according to the [Security Policy](SECURITY.md).

### Project documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Design Guidelines](DESIGN_GUIDELINES.md)
- [Privacy](docs/PRIVACY.md)
- [Contributing](CONTRIBUTING.md)
- [Governance](GOVERNANCE.md)
- [Security Policy](SECURITY.md)
- [Support](SUPPORT.md)
- [Release Process](docs/RELEASING.md)
- [Changelog](CHANGELOG.md)

## License

Pawse source code and project-owned visual assets are available under the [MIT License](LICENSE), unless a file explicitly states otherwise.

## Known limitations

- macOS controls how third-party panels participate in Spaces and full-screen application Spaces. Pawse uses only documented panel levels and collection behaviors.
- Available system sounds vary by macOS installation; unavailable options are omitted and missing playback fails safely.
- Wallpaper and custom-image bookmarks can become unavailable after a file or folder is moved. Pawse safely falls back to a dark background.
- Video-only dynamic wallpapers are not rendered by the Break overlay; use a still image or Solid Color when needed.
- Launch at Login may require approval in System Settings and is most reliable for a signed app installed in Applications.
- Pawse is a self-discipline utility, not a security boundary. It can still be forcibly terminated with macOS tools such as Activity Monitor.
