# NextNotes

NextNotes is a native Ubuntu Touch client for the official Nextcloud Notes app.

It is intentionally simple: plain-text notes, local caching, offline editing, and safe synchronization through the Nextcloud Notes API.

NextNotes is not affiliated with, endorsed by, or sponsored by Nextcloud GmbH or the Nextcloud project. Nextcloud is a trademark of its respective owners.

## Features

- Use an existing Nextcloud or ownCloud account from Ubuntu Touch Online Accounts.
- List, search, open, create, edit, favorite, categorize, and delete notes.
- Cache notes locally for offline access.
- Automatically sync local changes while the app is active.
- Preserve local drafts when server conflicts are detected.
- Review conflicts by choosing the local or server version.
- Follow the system language or manually choose a supported language.
- View version, license, and project information from the About page.

## Not Included

NextNotes focuses on a small reliable V1. It does not implement:

- Rich text editing
- Markdown rendering
- Attachments
- Image handling
- Sharing
- Collaboration
- End-to-end encryption
- Tags
- Advanced formatting
- In-app username/password login

## Authentication

NextNotes always uses Ubuntu Touch Online Accounts. Add your Nextcloud or ownCloud account in Ubuntu Touch System Settings > Accounts, then select that account inside NextNotes. If Ubuntu Touch has not yet allowed NextNotes to use the account, the account page tells you to allow it in System Settings > Accounts and then select it again.

Credentials are requested from Online Accounts at runtime and are not stored by NextNotes. After successful runtime authentication, credentials may be kept only in process memory for the current app session.

The account flow follows the shared Nextcloud suite pattern: account rows are selected directly, verification is serialized while running, stale in-memory credentials are cleared when switching accounts, and technical diagnostics are kept out of the normal UI.

## Languages

Current language choices:

- Follow system language
- English
- Swedish
- German
- French
- Dutch
- Danish
- Norwegian Bokmal
- Spanish
- Finnish

Swedish has been reviewed for the current UI. German, French, Dutch, Danish, Norwegian Bokmal, Spanish, and Finnish currently use AI-assisted translations and need review by fluent speakers.

Translations are gettext `.po` files under `po/`. Improvements are welcome.

## Build

Install Clickable, then build from the repository root:

```bash
~/.local/bin/clickable build --arch amd64
~/.local/bin/clickable build --arch arm64
```

Successful builds produce click packages under:

```text
build/x86_64-linux-gnu/app/
build/aarch64-linux-gnu/app/
```

## Run

Desktop mode:

```bash
~/.local/bin/clickable desktop --arch amd64
```

Larger desktop debug window:

```bash
~/.local/bin/clickable script desktop-large
```

Dark desktop debug window:

```bash
~/.local/bin/clickable script desktop-dark
```

Desktop mode can also use the dedicated live-test account from `.env.test.local`
for faster debugging without Ubuntu Touch Online Accounts:

```bash
cp .env.test.local.example .env.test.local
# edit .env.test.local with a dedicated test account
~/.local/bin/clickable script desktop-test
~/.local/bin/clickable script desktop-test-dark
```

This path is only enabled for desktop debugging when `NEXTNOTES_DESKTOP_TEST_AUTH=1`
is set by the script. Ubuntu Touch builds continue to use Online Accounts only.

Install on a connected Ubuntu Touch device:

```bash
~/.local/bin/clickable install --arch arm64
```

Use the architecture that matches the target device.

## Test

Run the local regression suite:

```bash
~/.local/bin/clickable script test
```

Optional live Nextcloud API tests are available. They create, update, and delete notes on a configured test account:

```bash
cp .env.test.local.example .env.test.local
# edit .env.test.local with a dedicated test account
~/.local/bin/clickable script test-live
```

Never use a personal account for live tests. `.env.test.local` is ignored by git.

## Architecture

NextNotes is a Clickable QML/C++ Ubuntu Touch application.

Important runtime areas:

- `qml/pages/`: Ubuntu Touch UI pages.
- `qml/backend/AccountSessionAdapter.qml`: Online Accounts runtime authentication.
- `qml/backend/NotesApiClient.qml`: Nextcloud Notes API requests.
- `qml/backend/NotesCache.qml`: local SQLite cache through Qt LocalStorage.
- `qml/backend/NotesController.qml`: note loading, filtering, sync orchestration, local draft handling, and UI-facing state.
- `qml/backend/*.js`: small testable helper modules.
- `po/`: gettext translation catalogs.
- `tests/`: local regression/contract tests.
- `tests_live/`: opt-in live Nextcloud Notes API tests.

## Permissions

The AppArmor profile uses:

- `networking`: connect to the configured Nextcloud server.
- `accounts`: access Ubuntu Touch Online Accounts after user authorization.

NextNotes does not request unconfined mode.

## Deployment

NextNotes is intended for OpenStore distribution as a click package.

Before release:

- Build and review amd64 and arm64 packages.
- Test on Ubuntu Touch Stable.
- Prepare OpenStore screenshots and banner.
- Verify maintainer metadata.
- Verify the Online Accounts setup flow on a fresh install.

Release notes are maintained in [CHANGELOG.md](CHANGELOG.md).

## License

NextNotes is licensed under the MIT License.

Copyright (c) 2026 Etherghost. See [LICENSE](LICENSE).
