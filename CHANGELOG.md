# Changelog

All notable changes to MicKeeper are documented here. Versions follow [Semantic Versioning](https://semver.org).

## 0.1.0 — 2026-11-27

First public release.

- Keeps the selected microphone as the system default input and restores it when another device takes over.
- Native menu bar menu: input selection, holding toggle, launch at login, About window.
- Right-click the menu bar icon to turn holding on or off.
- Monochrome SF Symbols menu bar icon: filled while holding, outlined when off, with badges for a missing device and for errors. Magic Replace morphs between states and a single bounce marks a restore; both are skipped with Reduce Motion.
- App icon made in Icon Composer with light, dark and tinted appearances.
- Remembers the microphone by its Core Audio UID across launches, reconnections, sleep and audio service restarts.
- Bounded retries, verification of every switch and a burst limit of five switches per ten seconds with automatic recovery.
- Optional daily check for new stable releases on GitHub; installation stays manual.
- Interface in English, Russian, Ukrainian, German, Spanish and Simplified Chinese, with an in-app language override.
- Universal build for Apple Silicon and Intel, macOS 15 or later.
- Drag-to-install disk image with a first-launch hint, a SHA-256 checksum and, for public builds, a signed build provenance attestation.
