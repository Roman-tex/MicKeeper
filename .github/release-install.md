
## Install

1. Download `MicKeeper.dmg`, open it and drag MicKeeper into **Applications**.
2. Open MicKeeper from Applications.

MicKeeper is signed ad hoc and is not notarized by Apple, so macOS blocks the first launch. Open it in one of two ways:

- **System Settings** (recommended): after the blocked attempt, open **System Settings → Privacy & Security**, scroll to Security and click **Open Anyway** within about an hour, then confirm with your password.
- **Terminal**: remove the download quarantine from the installed copy only:

  ```sh
  xattr -dr com.apple.quarantine /Applications/MicKeeper.app
  ```

  `sudo` is not needed when you copied the app yourself. Avoid `xattr -c`, which clears every attribute rather than just the quarantine flag.

Do not run MicKeeper directly from the disk image or Downloads: macOS starts quarantined apps from a temporary read-only location, which breaks launch at login.

## Verify

```sh
shasum -a 256 -c MicKeeper.dmg.sha256
gh attestation verify MicKeeper.dmg --repo Roman-tex/MicKeeper
```

The attestation proves the disk image was built by this repository's GitHub Actions workflow from the tagged source.
