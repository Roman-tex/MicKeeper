# Contributing

Thank you for your interest in MicKeeper. The app does one thing — keeps the selected microphone as the system input — and is meant to stay small, native and dependency-free. Please keep that in mind before proposing new features.

## Reporting bugs

Open an issue with the **Bug report** template and include:

- MicKeeper version (About window) and macOS version;
- Mac model;
- the selected microphone and the device that took over (AirPods, USB, webcam, virtual device);
- what you expected and what happened.

Device behaviour differs between drivers, so the exact hardware matters more than anything else.

## Proposing changes

Fixes, reliability improvements, accessibility and translations are welcome. For anything that changes behaviour or adds a setting, please open an issue first so we can agree on the approach. Features outside the app's single purpose (muting, volume control, output devices) are likely to be declined.

## Development

Requirements: macOS 15 or later and Xcode 27 or later.

```sh
swift test                 # policy and recovery tests
./scripts/build.sh Debug   # universal debug build
./scripts/package-dmg.sh   # release build and disk image
```

You can also open `MicKeeper.xcodeproj` and run the **MicKeeper** scheme. No developer account is needed.

Where code goes:

- **`Sources/MicKeeperCore`** holds the policy (`KeeperController`, event monitoring, update schedule). It does not use AppKit, and every Core Audio operation (device reads, writes, listener registration) goes through an injected boundary, as do settings and time. Behaviour changes here need tests in `Tests/MicKeeperCoreTests`.
- **`MicKeeper/`** is the AppKit/SwiftUI shell and the Core Audio adapter. Keep it thin: decisions belong in the core.

Guidelines:

- Swift 6 with complete strict concurrency; keep the build free of compiler warnings.
- No third-party runtime dependencies.
- Prefer system components (NSMenu, SF Symbols, ServiceManagement) over custom UI.
- Do not log device names or UIDs, and do not add network requests beyond the update check.

## Localization

The interface is translated into English, Russian, Ukrainian, German, Spanish and Simplified Chinese. When you add or change a string, update the key in every `MicKeeper/*.lproj/Localizable.strings` file. If you cannot translate a language, use the English text and mention it in the pull request.

## Pull requests

- Keep each pull request focused on one change.
- Write commit messages in the [Conventional Commits](https://www.conventionalcommits.org) style used in the history (`fix(app): …`, `feat(core): …`, `docs: …`), with a body that explains why.
- Make sure `swift test` and `./scripts/build.sh Debug` pass; CI runs both and builds the disk image.
- For user-visible changes, update `CHANGELOG.md` and, if needed, the README in both languages.

By contributing, you agree that your contribution is licensed under the [MIT License](LICENSE).
