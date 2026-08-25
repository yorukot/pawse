# Releasing Pawse

Pawse releases are built from immutable tags on `main`. The project version, changelog section, Git tag, DMG filename, and GitHub Release must all describe the same version.

## Version policy

Pawse follows [Semantic Versioning](https://semver.org/):

- `MARKETING_VERSION` is the public `MAJOR.MINOR.PATCH` version, such as `0.1.0`.
- `CURRENT_PROJECT_VERSION` is a positive, monotonically increasing build number.
- Git tags use the public version prefixed with `v`, such as `v0.1.0`.
- `0.x` releases are early-access pre-releases. `1.0.0` is the first stable release.
- Fixes increment PATCH, backward-compatible features increment MINOR, and breaking changes increment MAJOR after 1.0.

The values live in `Pawse.xcodeproj/project.pbxproj`. `make release-check VERSION=x.y.z` rejects mismatched Debug/Release values, malformed versions, or a missing dated changelog section.

## Release artifacts

Every GitHub Release contains:

- `Pawse-x.y.z.dmg` with a Universal (`arm64` and `x86_64`) macOS application.
- `Pawse-x.y.z.dmg.sha256` for integrity verification.
- Notes extracted from the matching `CHANGELOG.md` section.

The tag-triggered workflow currently publishes `0.x` builds with an ad-hoc signature and marks them as pre-releases. They are suitable for transparent early-access distribution but are not Apple-notarized; macOS may require Control-click → Open on first launch.

Stable public releases must be Developer ID signed and Apple-notarized. Do not describe an ad-hoc build as notarized.

## Prepare a release

1. Start from an up-to-date, clean `main` branch.
2. Set `MARKETING_VERSION` in both Pawse configurations.
3. Increment `CURRENT_PROJECT_VERSION` in both Pawse configurations.
4. Move user-facing entries from `Unreleased` into `## [x.y.z] - YYYY-MM-DD` in `CHANGELOG.md`.
5. Update the changelog comparison links.
6. Run:

```bash
make release-check VERSION=x.y.z
make clean
make test
make release
make package VERSION=x.y.z
git diff --check
```

7. Install the generated DMG and manually validate the menu-bar item, timer, natural-break entry and retry, Emergency Exit, sounds, Analytics, settings persistence, and a complete break. Test display synchronization when multiple displays are available.
8. Treat localization as a release gate. Native speakers should review Spanish, Japanese, Traditional Chinese, and Simplified Chinese strings, and the Language restart flow should be checked in every supported language.

The local package is written to `dist/`; build products and release artifacts are ignored by Git.

## Local signing and notarization

`make package` creates an ad-hoc signed DMG by default. A maintainer with an Apple Developer account can use the same packaging command with a Developer ID Application identity:

```bash
PAWSE_CODESIGN_IDENTITY='Developer ID Application: Example (TEAMID)' \
make package VERSION=x.y.z
```

To submit the final DMG to Apple, first store credentials in the login keychain using `notarytool`, then provide the profile name:

```bash
xcrun notarytool store-credentials pawse-notary \
  --apple-id maintainer@example.com \
  --team-id TEAMID \
  --password APP_SPECIFIC_PASSWORD

PAWSE_CODESIGN_IDENTITY='Developer ID Application: Example (TEAMID)' \
PAWSE_NOTARY_PROFILE='pawse-notary' \
make package VERSION=x.y.z
```

The script submits the DMG, waits for Apple, staples the ticket, and validates it. Never commit certificates, keychains, export options, app-specific passwords, or notarization credentials.

Before publishing a notarized build, verify it independently:

```bash
codesign --verify --deep --strict --verbose=2 /Volumes/Pawse*/Pawse.app
spctl --assess --type open --context context:primary-signature --verbose=2 dist/Pawse-x.y.z.dmg
shasum -a 256 -c dist/Pawse-x.y.z.dmg.sha256
```

## Tag and publish

Commit the prepared release separately:

```bash
git add CHANGELOG.md Pawse.xcodeproj/project.pbxproj docs/RELEASING.md
git commit -m "chore(release): prepare vX.Y.Z"
git tag -a vX.Y.Z -m "Pawse vX.Y.Z"
git push origin main
git push origin vX.Y.Z
```

Pushing the tag starts `.github/workflows/release.yml`. It repeats metadata validation and the complete test suite, builds the Universal DMG, produces its checksum, and creates the GitHub Release. Never manually replace an artifact under an existing tag; publish a new patch and build number instead.

After the workflow succeeds:

1. Download both assets from GitHub.
2. Verify the checksum.
3. Install on a clean macOS account.
4. Confirm the app reports the expected version and the menu-bar item remains visible.
5. Publish the announcement only after the downloaded artifact passes validation.

If a release is unsafe, mark the GitHub Release as withdrawn and document the reason. Do not move or reuse its tag.
