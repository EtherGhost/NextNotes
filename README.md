# NextNotes

NextNotes is a native Ubuntu Touch client for the official Nextcloud Notes app.

It is intentionally simple: plain-text notes, local caching, offline editing, and safe synchronization through the Nextcloud Notes API.

NextNotes is not affiliated with, endorsed by, or sponsored by Nextcloud GmbH or the Nextcloud project. Nextcloud is a trademark of its respective owners.

## Current Status

Current release candidate: `0.1.6`.

Current experimental branch: `experiment/content-hub-share-import` uses local device/debug version `0.1.6.1` while testing Content Hub import/export behavior.

This release focuses on visual polish: the notes list, navigation drawer, top bar, and account page now follow the cleaner shared Nextcloud suite style. Account, sync, editing, and cache behavior are unchanged.

## Features

- Use an existing Nextcloud or ownCloud account from Ubuntu Touch Online Accounts.
- List, search, open, create, edit, favorite, categorize, and delete notes.
- Cache notes locally for offline access.
- Keep local note caches separated per selected Online Accounts account.
- Automatically sync local changes while the app is active.
- Preserve local drafts when server conflicts are detected.
- Review conflicts on a dedicated conflict page by choosing the local or server version.
- Keep the note editor stable while sync state changes by showing sync/conflict state in the top bar.
- Import shared text from other Ubuntu Touch apps through Content Hub as a new local note.
- Share selected note text or full note text to other Ubuntu Touch apps through Content Hub.
- Follow the system language or manually choose a supported language.
- View version, license, and project information from the About page.

## Not Included

NextNotes focuses on a small reliable V1. It does not implement:

- Rich text editing
- Markdown rendering
- Attachments
- Image handling
- Rich note sharing beyond plain text Content Hub import/export
- Collaboration
- End-to-end encryption
- Tags
- Advanced formatting
- In-app username/password login

## Authentication

NextNotes always uses Ubuntu Touch Online Accounts. Add your Nextcloud or ownCloud account in Ubuntu Touch System Settings > Accounts, then select that account inside NextNotes. If Ubuntu Touch has not yet allowed NextNotes to use the account, the account page opens a guided prompt to System Settings > Accounts, keeps the account selected, and verifies access automatically when you return.

Credentials are requested from Online Accounts at runtime and are not stored by NextNotes. After successful runtime authentication, credentials may be kept only in process memory for the current app session.

The account flow follows the shared Nextcloud suite pattern: account rows are selected directly, verification is serialized while running, stale in-memory credentials are cleared when switching accounts, and technical diagnostics are kept out of the normal UI.

Each Ubuntu Touch account must be allowed for NextNotes in System Settings > Accounts. If one account works and another account does not, open the OS account settings for the failing account, allow NextNotes, then return to the app so it can verify the selected account automatically.

The notes list includes a swipe-action direction setting in the hamburger menu. Ubuntu Touch style is the default; Android-compatible style can be selected for users who prefer the upstream Android direction.

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
- `qml/pages/ConflictResolutionPage.qml`: full-screen local/server conflict review and resolution.
- `po/`: gettext translation catalogs.
- `tests/`: local regression/contract tests.
- `tests_live/`: opt-in live Nextcloud Notes API tests.

## Permissions

The AppArmor profile uses:

- `networking`: connect to the configured Nextcloud server.
- `accounts`: access Ubuntu Touch Online Accounts after user authorization.
- `content_exchange`: receive shared/imported content through Ubuntu Touch Content Hub.
- `content_exchange_source`: register as a Content Hub source/share participant for text import/export.

NextNotes does not request unconfined mode.

## Content Hub Import And Share

NextNotes can receive shared text from other Ubuntu Touch apps. The incoming Content Hub item is read as local text content, saved as a new local note, opened in the editor, and then handled by the existing offline-first autosync flow.

NextNotes can also share selected note text, or the full note text when nothing is selected, to other Ubuntu Touch apps. Content Hub transfers use both the item text field and a temporary UTF-8 text file so receiving apps can use the path that best fits their implementation.

On Pixel 3a / Ubuntu Touch 24.04 Noble, Content Hub text import/export required explicit `text`, `links`, and `documents` categories plus both `content_exchange` and `content_exchange_source` AppArmor policy groups. Reinstalling with a changed Content Hub/AppArmor profile required a local version bump from `0.1.6` to `0.1.6.1`.

## Deployment

NextNotes is intended for OpenStore distribution as a click package.

Release notes are maintained in [CHANGELOG.md](CHANGELOG.md).

## License

NextNotes is licensed under the MIT License.

Copyright (c) 2026 Etherghost. See [LICENSE](LICENSE).
