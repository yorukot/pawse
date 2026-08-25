# Contributing to Pawse

Thank you for helping improve Pawse. Contributions that preserve its native macOS behavior, privacy guarantees, and safe break cleanup are welcome.

## Before You Start

- Search existing issues before opening a new one.
- Use the bug or feature-request template and include the macOS version you tested.
- Discuss large behavior or architecture changes in an issue before investing in an implementation.
- Report vulnerabilities privately according to [SECURITY.md](SECURITY.md).

Participation in this project is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Development Requirements

- macOS 14 or later
- Xcode with Swift 6 and the macOS 14 SDK or later
- Git

Pawse has no third-party runtime dependencies. Clone the repository and open `Pawse.xcodeproj`, or use the commands below.

```bash
make build
make test
```

The equivalent direct commands are documented in [README.md](README.md). Build output is written under `.build/` and is ignored by Git.

## Making a Change

1. Fork the repository and create a focused branch from `main`.
2. Keep state transitions in `SessionController`; SwiftUI views should send intents rather than manage timers, analytics, or AppKit panels directly.
3. Follow [DESIGN_GUIDELINES.md](DESIGN_GUIDELINES.md) for UI and copy changes.
4. Add deterministic tests for behavioral changes. Prefer the existing fake clock, scheduler, activity, sound, analytics, and break-environment dependencies.
5. Run `make verify` and manually exercise relevant UI where possible.
6. Update documentation and `CHANGELOG.md` when user-visible behavior changes.

## Engineering Expectations

- Preserve absolute-deadline timer semantics; never decrement a counter as the source of truth.
- Keep break cleanup centralized and idempotent.
- Never require Accessibility or Input Monitoring permission for natural-break detection.
- Do not collect keys, pointer coordinates, application names, window titles, URLs, or screen contents.
- Do not add telemetry, analytics SDKs, network tracking, or private APIs.
- Avoid new dependencies when Apple frameworks provide a suitable implementation.
- Keep Swift 6 concurrency checks clean and avoid force unwraps where a recoverable path exists.

## Tests

Tests must remain isolated from the contributor’s real settings and analytics. Use an in-memory SwiftData configuration and suite-specific `UserDefaults` where persistence is involved.

Important areas include:

- Session timing, pause accounting, and mode switching
- Short/Long Break cycle behavior
- Natural-break idle and grace-period transitions
- Emergency Exit and cleanup idempotency
- Sound event deduplication
- Analytics finalization and aggregation
- Panel lifecycle and display synchronization

## Pull Requests

Keep pull requests small enough to review. Explain the user-facing outcome, implementation tradeoffs, validation performed, accessibility impact, and privacy impact. Screenshots are helpful for visual changes but must not contain private information.

Use clear commit messages. Conventional Commit prefixes such as `feat:`, `fix:`, `test:`, `docs:`, and `chore:` are preferred.

By submitting a contribution, you agree that it may be distributed under the project’s [MIT License](LICENSE).
