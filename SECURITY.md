# Security policy

## Supported versions

Only the latest release receives fixes. Please update before reporting a problem.

## Reporting a vulnerability

Please do not open a public issue for security problems. Use **Security → Report a vulnerability** on the repository page to send a private report through GitHub. Include the MicKeeper and macOS versions, the steps to reproduce and the impact you observed.

You will receive a response as soon as possible, and a fix will be released before the details are published.

## Scope

MicKeeper reads audio device metadata, changes the system default input and makes one network request: the update check against the GitHub releases API. Relevant reports include, for example, ways to make the update check open a page outside this repository's releases, or to make the app change settings it should not touch.

Release builds are signed ad hoc and not notarized. Verify downloads with the published SHA-256 checksum and build attestation, as described in the README.
