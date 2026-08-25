# Architecture

Pawse is a native SwiftUI menu-bar application with AppKit integration where macOS window behavior requires it. It targets macOS 14 and uses Swift 6 strict concurrency.

## Design Goals

- One authoritative session state machine
- Absolute-deadline timers that do not drift
- Safe, idempotent cleanup around full-screen breaks
- Exactly one finalized analytics record per actual session
- Privacy-preserving aggregate idle detection
- Native macOS UI and accessibility behavior
- Injectable boundaries for deterministic tests

## Application Composition

`PawseApp` creates the menu-bar scene and unified Pawse window. `AppModel` owns the long-lived services and wires their callbacks once during launch. `AppDelegate` applies accessory-app behavior and invokes termination cleanup.

```text
PawseApp
└── AppModel
    ├── SettingsStore
    ├── SessionController
    ├── BreakEnvironmentCoordinator
    │   ├── BreakReminderCoordinator
    │   ├── OverlayCoordinator
    │   └── PresentationOptionsController
    ├── SoundService
    ├── AnalyticsStore
    └── LaunchAtLoginService
```

All UI-facing ownership is isolated to the main actor.

## Session State Machine

`SessionController` is the only owner of session transitions, deadlines, pause accounting, automatic cycle decisions, and analytics finalization.

```text
Idle
├── Focus → Running Focus ⇄ Paused Focus
├── Short Break → Active Break
└── Long Break → Active Break

Completed Focus
├── automatic breaks disabled → Idle with scheduled Break selected
├── natural-break waiting disabled → Active Break
└── natural-break waiting enabled
    → Break Pending
    → Break Entering
        ├── new input during grace → Break Pending
        └── grace completes → Active Break
```

Views send intent methods such as start, pause, stop, begin pending break, and confirm Emergency Exit. They never own system timers, AppKit panels, or persistence writes.

## Timing

The clock source is an absolute deadline. UI refreshes request a new remaining interval from the deadline; they do not subtract elapsed ticks. Pausing Focus captures the remaining interval, and resuming creates a new deadline. Settings changes only affect the next session.

`SessionClock` and the repeating scheduler are injected so tests can advance time without sleeping.

## Natural Break Detection

`SystemUserActivityMonitor` reads aggregate Core Graphics idle duration and an aggregate activity token. It does not install an event tap and never observes or stores individual input events.

Polling exists only in Break Pending and Break Entering. The token baseline is captured after an initiating HUD click so that click does not cancel its own entry attempt.

## Break Environment

`BreakEnvironmentCoordinator` provides the single cleanup boundary for reminders, full-screen overlays, presentation options, activity polling, sound, and pending-entry state.

`BreakReminderCoordinator` owns a nonactivating top-center `NSPanel`. `OverlayCoordinator` owns one full-screen `BreakPanel` per stable display identifier and resynchronizes them after display changes. `PresentationOptionsController` saves the exact previous application presentation options and restores them idempotently.

Emergency Exit uses the same cleanup path as normal completion and failure recovery.

## Persistence

`SettingsStore` is the single owner of UserDefaults-backed preferences. Active sessions intentionally do not survive force-quit or restart.

`AnalyticsStore` writes finalized `SessionRecord` values into SwiftData. Session IDs prevent duplicate finalization. Break Pending and canceled Break Entry attempts do not create Break records.

No networking or remote telemetry layer exists.

## Source Layout

```text
Pawse/
├── App/         App lifecycle, composition, and design tokens
├── Analytics/   SwiftData records, aggregation, chart, and table UI
├── Break/       Reminder, overlays, activity monitoring, and cleanup
├── MenuBar/     Menu-bar label and popover
├── Resources/   Local asset catalog
├── Session/     State models, timer abstractions, and controller
├── Settings/    Persisted settings and unified window UI
└── Sound/       Native system-sound selection and playback

PawseTests/   Deterministic unit and AppKit infrastructure tests
```

## Testing Strategy

Core behavior is tested using fake clocks, repeating schedulers, activity monitors, sounds, analytics recorders, and break environments. Persistence tests use isolated UserDefaults suites and in-memory SwiftData. A smaller AppKit test layer verifies panel creation and cleanup on a macOS test host.

Changes to a state transition should normally add or update a deterministic controller test before adding UI coverage.
