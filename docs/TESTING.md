# Validation

This file separates automated evidence from hardware checks. Support is targeted at macOS 15+; untested configurations are not claimed as verified.

## Automated coverage

`swift test` exercises 25 test functions (including parameterized version/URL cases):

- Preferred input enforcement and avoidance of duplicate writes.
- Disabled state, immutable disabled selection, and persistence on stop/relaunch.
- Device removal, rename and reconnection.
- Cancellation of delayed work, including already queued callbacks.
- Changed selection while retries are pending.
- Bounded retries, false-success write detection and conflict protection.
- Empty devices versus failed enumeration.
- Optional device-listener failure while system recovery stays active.
- Missing service-restart property while default-input and device-list monitoring remain active.
- Stale listener callbacks after shutdown and required registration failure.
- Numeric stable-version comparison, malformed tags, GitHub failures, absent releases, draft/prerelease exclusion and release URL validation.
- Localized resources are present in the app bundle for Russian, English, Ukrainian, German, Spanish and Simplified Chinese; unsupported system languages use the English fallback.

The tests simulate external audio operations; passing them does not prove the behavior of every driver or OS release.

## Build checks

- Xcode 26.6, Swift 6 mode; deployment target macOS 15.0.
- Debug build and launch on the development Mac.
- Universal Release build, strict signature verification and read-only DMG inspection are recorded in the local review result after packaging.
- GitHub Actions configuration is supplied but has not run remotely before the first authorized push.

## Manual acceptance checklist

Record the OS version, hardware and outcome when each check is performed.

| Check | Procedure | Evidence |
| --- | --- | --- |
| First launch | Open installed app; panel visible; holding and login off. | Pending final UI review. |
| Disabled selection | Chosen name remains, picker grey/noninteractive; normal system changes are untouched. | Policy automated; UI check pending. |
| Holding | Enable; change system default away; confirm return. | Policy automated; hardware check pending. |
| Right click | Right-click icon twice; check switch and both icons follow each action once. | UI check pending. |
| USB / Bluetooth | Select device, disconnect, reconnect. | Policy automated; hardware check pending. |
| Wake | Sleep and wake with selected device present and absent. | Hardware check pending. |
| Audio service reset | On a dedicated test machine, restart audio service; confirm recovery. | Pending; do not disrupt the user's audio session. |
| Login | From Applications enable login, log out/in; revoke in System Settings; confirm actual status. | Pending; requires a real login cycle. |
| About / update check | Open version/licenses; confirm the window is centered; run update check online and offline. | Parser automated; UI check pending. |
| Language override | In About, switch between System default and each bundled language; reopen the panel and About window. | UI check pending. |
| Accessibility | Keyboard navigation, VoiceOver, long/duplicate device names, light/dark mode. | Native semantic controls; full manual check pending. |
| macOS 15 | Repeat core hardware and first-install scenarios on a macOS 15 machine/VM with an input device. | Not tested locally. |
| Intel | Install x86_64 slice and repeat scenarios on Intel hardware. | Cross-build only; not hardware tested. |
| Downloaded DMG | Download through a browser on a clean machine, install, exercise Gatekeeper's first launch. | Local packaging is not equivalent to this check. |

## Reproducible commands

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
./scripts/package-dmg.sh
codesign --verify --deep --strict .build/xcode/Build/Products/Release/MicKeeper.app
lipo -archs .build/xcode/Build/Products/Release/MicKeeper.app/Contents/MacOS/MicKeeper
hdiutil verify dist/MicKeeper-0.1.0-universal.dmg
```

For an input-switch test, record the current system input first. Restore it through macOS after disabling holding. Do not terminate the audio service during calls or recordings. Opening the panel retries failed monitoring; the retry action also clears conflict protection.
