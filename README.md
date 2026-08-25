# Breather

Breather is a native macOS focus timer that waits for a natural stopping point before making you take a break.

It lives in the menu bar and starts a Focus session when it opens. The default cycle is two rounds of **25 minute Focus → 30 second Short Break**, followed by another 25 minute Focus and a **10 minute Long Break**. When a scheduled Focus session finishes, Breather shows a compact **Break soon** HUD and waits until the Mac has been idle for three seconds. A short grace period backs out of the break overlay if activity immediately resumes. Once committed, the break covers every connected display until its countdown completes or the user confirms Emergency Exit.

## Requirements

- macOS 14 or later
- Xcode 26 or another Xcode release capable of building Swift 6 code for macOS 14
- No third-party dependencies

## Features

- Native SwiftUI menu bar app that also remains available from the Dock
- Focus, Short Break, and Long Break modes with absolute-deadline timers
- Pause/resume for Focus with paused time excluded from analytics
- Confirmation-gated switching from an active Focus session
- Automatic two-Short-Break cycle with a configurable number of Short Breaks before each Long Break
- Automatic Focus at launch, with optional automatic breaks and next Focus sessions
- Mode icon with a surrounding menu-bar progress ring that drains from full to empty, with no countdown text
- Cycle-aware **Up Next** details for the next Break and the number of Focus sessions before the Long Break
- Privacy-preserving natural-break detection using aggregate Core Graphics idle state
- Non-activating, top-center **Break soon** HUD with a 15-second attention indicator that becomes a slow urgent pulse without forcing the break
- Grace-period retreat when keyboard or pointer activity resumes during break entry
- Full-screen native panels on every connected display, synchronized after display changes, with wallpaper or a user-selected image
- Public AppKit fade transitions that automatically become immediate when Reduce Motion is enabled
- In-overlay Emergency Exit confirmation on every display
- Exact restoration of the app’s previous macOS presentation options
- Native system sounds, runtime availability filtering, volume, and previews
- One native macOS sidebar window for Analytics, timers, cycle, break behavior, sounds, appearance, general settings, and privacy
- Local SwiftData session history in the same window, with a Swift Charts daily Focus chart, recent-session Table, toolbar date ranges, and clear-history controls
- Accessibility labels, monospaced countdowns, keyboard-accessible native controls, and no decorative continuous animation

## Natural stopping-point behavior

With **Automatically Start Breaks** and **Wait for Natural Break** enabled, a completed Focus follows this flow:

```text
Focus completes
→ Break Pending and “Break soon” HUD
→ HUD click or configured idle threshold
→ Break Entering grace period
→ activity resumes: return to Break Pending
→ no activity: commit the full-screen Break
```

Pending time is neither Focus time nor Break time. A canceled entry attempt creates no Break record and the next attempt starts with the full configured duration. Ordinary input does not dismiss a committed Break.

The HUD attention bar reaches full after 15 seconds and then uses a slow visual pulse to make the reminder easier to notice. This is intentionally not a forced timeout: continued keyboard or pointer activity can defer a scheduled break indefinitely. A click or the configured idle threshold can start Break Entry before the bar finishes.

Manual Short and Long Breaks start immediately because selecting one is already an explicit request to rest.

## Build

```bash
xcodebuild -list -project Breather.xcodeproj

xcodebuild \
  -project Breather.xcodeproj \
  -scheme Breather \
  -destination 'platform=macOS' \
  build
```

Open `Breather.xcodeproj` in Xcode to run the app interactively. The built app starts Focus automatically, stays available from the Dock, and provides its timer controls from the menu bar.

Use **Open Breather…** from the menu-bar popover, or press Command-comma, to open the unified Analytics and Settings window.

## Test

```bash
xcodebuild \
  -project Breather.xcodeproj \
  -scheme Breather \
  -destination 'platform=macOS' \
  test
```

The deterministic XCTest suite uses fake clocks, activity samples, sounds, overlays, schedulers, and an in-memory SwiftData configuration. It covers session timing, pause accounting, mode switching, cycle semantics, natural-break retries, Emergency Exit, centralized cleanup, sound transitions, analytics persistence, aggregation, and date ranges.

## Break backgrounds

Break overlays use the current wallpaper for each display by default. Appearance settings can instead store a read-only, security-scoped bookmark to an image selected with the native file picker. The image is loaded locally, fills each display, and receives a dark scrim so the break content remains legible. If a wallpaper or selected image becomes unreadable, Breather falls back to a near-black background and keeps Emergency Exit available.

## Privacy

Breather stores settings and session history locally on this Mac.

It does not collect telemetry, send analytics to a server, inspect application contents, record keyboard input, or make network requests.

Breather only checks aggregate system idle time and aggregate input counters to detect natural stopping points. It never retains individual input events, keys, keyboard shortcuts, pointer coordinates, application names, window titles, URLs, screen contents, files, location, account data, or device fingerprints. Natural-break detection does not require Accessibility or Input Monitoring permission.

## Analytics

Each completed or interrupted actual session produces one finalized local record. Focus records store active time with pauses excluded. Automatically scheduled breaks preserve both `scheduledAt` and actual `startedAt`, allowing Break Deferral to be calculated without storing activity events.

Analytics supports Today, Last 7 Days, Last 30 Days, and All Time using the current local calendar and time zone. Clearing Analytics deletes finalized history only; it does not change settings, the Focus cycle, or a session currently in progress.

## Known limitations

- macOS controls how third-party panels participate in Spaces and full-screen application Spaces. Breather uses only documented `NSPanel` levels and collection behaviors and cannot guarantee behavior beyond those public APIs.
- Available system sounds vary by macOS installation; unavailable sounds are omitted and missing playback fails safely.
- Wallpaper URLs and custom-image bookmarks can become unavailable after a wallpaper is removed or a file is moved; the break safely falls back to a dark background until a new image is chosen.
- Launch at Login may require approval in System Settings and is most reliable for a properly signed app installed in Applications.
- Breather is a self-discipline utility, not a security boundary. A user can still forcibly terminate it with macOS tools such as Activity Monitor.
