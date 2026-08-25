<p align="center">
  <img src="website/assets/pawse-hero.webp" width="100%" alt="Pawse — Focus deeply. Rest naturally. A calm white shepherd above an illustrated mountain landscape.">
</p>

<div align="center">
  <p><strong>A macOS focus timer that waits for a natural stopping point before starting your break.</strong></p>

  <p>
    <a href="https://pawse.yorukot.me/download/"><strong>Download for macOS</strong></a>
    · <a href="https://pawse.yorukot.me/">Website</a>
    · <a href="CONTRIBUTING.md">Contribute</a>
  </p>

  <p>
    <img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple&logoColor=white">
    <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-34C759"></a>
  </p>
</div>

Pawse lives quietly in your menu bar and guides you through Focus, Short Break, and Long Break sessions. When Focus ends, it gives you a moment to finish what you are doing instead of immediately covering your screen.

## Why Pawse

- **Break naturally.** A small **Break soon** reminder waits for a click or a brief pause in keyboard and pointer activity.
- **Stay in rhythm.** Focus and breaks flow automatically, with a longer rest after a configurable number of cycles.
- **Rest without distraction.** A calm full-screen break appears across your displays, with Emergency Exit always available.
- **Make it yours.** Adjust durations, sounds, backgrounds, automatic transitions, and what appears in the menu bar.
- **Keep it private.** Settings and session history stay on your Mac. Pawse has no account, telemetry, or server analytics.

## How it works

1. Pawse starts a Focus session from the menu bar.
2. When Focus ends, **Break soon** appears without interrupting your current thought.
3. Click the reminder or pause input briefly to begin your break.
4. After the break, Pawse starts the next Focus and continues the cycle.

If activity resumes while the break is appearing, Pawse steps back and waits for a fresh natural stopping point.

## Download

[Get the current Pawse release for macOS](https://pawse.yorukot.me/download/). The download page shows compatibility, file size, checksum, current signing status, and the first-launch steps for early-access builds.

Pawse requires macOS 14 or later and includes native support for Apple silicon and Intel Macs.

## Build from source

Open `Pawse.xcodeproj` in Xcode and run the **Pawse** scheme, or use:

```bash
make build
```

Run the test suite with `make test`.

## Privacy

Pawse only checks aggregate system idle time while a scheduled break is waiting to begin. It does not record keys, pointer positions, application names, window titles, websites, or screen contents, and it makes no analytics network requests.

Read the full [Privacy documentation](docs/PRIVACY.md).

## Support the Project

Pawse is free, open source, and independent. Every download has the same features.

If Pawse helps you, you can support its ongoing development:

[Support Pawse](https://yorukot.me/donate)

## Contributing

Pawse is free and open source. Bug reports, translations, documentation, and focused code contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md).

Project details live in the [Architecture](docs/ARCHITECTURE.md), [Design Guidelines](DESIGN_GUIDELINES.md), [Changelog](CHANGELOG.md), and [Release Process](docs/RELEASING.md).

## License

Pawse is available under the [MIT License](LICENSE).
