# Changelog

## 0.1.0 — local review candidate

- Native AppKit menu with a selectable preferred input and a checkable holding item.
- Right-click toggle and separate enabled/disabled menu bar icons.
- Persistent selection, system event monitoring and bounded recovery attempts.
- Burst limiting with automatic recovery, and cancellation of stale callbacks and retries.
- Repeated audio notifications preserve pending retry delays instead of causing immediate duplicate writes.
- System-managed launch at login with approval/error handling.
- About window, bundled licenses, daily automatic stable-release checks and a persisted opt-out checkbox; manual checks remain available.
- Compact Error submenus with wrapped details keep long system messages out of the main menu.
- Localized menu and About window in Russian, English, Ukrainian, German, Spanish and Simplified Chinese, with an in-app language override.
- Core Audio monitoring keeps working when a macOS release does not expose the optional service-restart property.
- Native menu opens without popover animation; the About window opens centered.
- Launch-at-login failures remain visible after the status refresh.
- Universal ad-hoc-signed app and drag-to-Applications DMG.

This version has not been published or notarized. See `docs/TESTING.md` for validation scope.
