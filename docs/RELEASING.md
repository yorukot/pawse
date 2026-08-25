# Releasing Pawse

This document describes the maintainer release process. Ordinary contributors do not need Apple signing credentials.

## Before Release

1. Ensure `main` is clean and CI passes.
2. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` for both Debug and Release configurations.
3. Move relevant entries from `Unreleased` into a dated version section in `CHANGELOG.md`.
4. Run the complete local verification:

```bash
make clean
make test
make release
git diff --check
```

5. Manually test the menu-bar item, natural-break flow, Emergency Exit, sound settings, Analytics, and at least one full break. Test display synchronization when multiple displays are available.
6. Treat localization as a release gate:
   - Have native speakers review every entry in `Pawse/Resources/Localizable.xcstrings` for Spanish, Japanese, Traditional Chinese, and Simplified Chinese. The checked-in translations are AI-generated drafts until that review is complete.
   - Verify the General → Language restart flow in English, Spanish, Japanese, Traditional Chinese, Simplified Chinese, and Automatic mode, including a change during an active Focus and an active break.
   - Confirm that the Pawse brand name remains unchanged and that no translated text is clipped in the menu bar, settings window, reminder, full-screen break overlay, Analytics, or accessibility labels.

## Archive

Create an archive with a configured Apple Developer identity:

```bash
xcodebuild \
  -project Pawse.xcodeproj \
  -scheme Pawse \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath .build/Pawse.xcarchive \
  archive
```

Use Xcode Organizer or an explicit export-options plist to export the Developer ID application. Do not commit archives, exported applications, signing certificates, provisioning data, or notarization credentials.

## Signing and Notarization

Public binary releases should be signed with Developer ID, use Hardened Runtime, and be notarized through Apple’s supported notary tooling. Verify the exported app before distribution:

```bash
codesign --verify --deep --strict --verbose=2 Pawse.app
spctl --assess --type execute --verbose=2 Pawse.app
```

Ad-hoc “Sign to Run Locally” builds are suitable for local development only and should not be presented as notarized public binaries.

## Publish

1. Create a signed Git tag matching the changelog version.
2. Publish release notes derived from `CHANGELOG.md`.
3. Attach only the notarized distribution archive and its SHA-256 checksum.
4. Verify installation on a clean macOS account before announcing the release.

Never publish from a dirty worktree or push rewritten release history.
