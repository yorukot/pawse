# Privacy

Breather is designed to work entirely on the user’s Mac.

## Data Stored Locally

- Timer, cycle, sound, appearance, and launch preferences in UserDefaults
- Finalized session history in SwiftData
- A read-only security-scoped bookmark when the user explicitly selects a custom break image
- A read-only security-scoped bookmark when the user explicitly grants access to a wallpaper folder

Session records contain the session mode, origin, outcome, start and end times, planned duration, active duration, and optional scheduled-break time and cycle position.

## Natural-Break Activity

During Break Pending and Break Entering, Breather checks aggregate macOS idle duration and an aggregate input activity counter using public Core Graphics APIs. These values are used in memory to decide when to begin or cancel break entry.

Breather does not collect or persist:

- Keys, keyboard shortcuts, or typed text
- Pointer coordinates or individual mouse events
- Application names or bundle identifiers
- Window titles
- Websites or URLs
- Screen captures or screen contents
- File contents, except a user-selected break image or a wallpaper inside an explicitly authorized folder loaded locally for display
- Location, accounts, or device fingerprints

Natural-break detection does not require Accessibility or Input Monitoring permission.

## Network Activity

Breather contains no telemetry, advertising, crash-reporting, or remote-analytics SDK. It does not send session history or settings to a server. The application has no networking feature.

## User Control

Analytics can be cleared from Breather’s Privacy settings without resetting preferences or interrupting the current session. A custom break image or wallpaper-folder authorization can be removed at any time. Selecting Solid Color retains those authorizations for later use; resetting settings clears them. Uninstalling the app and deleting its sandbox container removes its local data.

## Contributor Requirements

Changes that add networking, new system permissions, new data fields, or broader file access require explicit review and corresponding updates to this document, the in-app Privacy copy, tests, and release notes.
