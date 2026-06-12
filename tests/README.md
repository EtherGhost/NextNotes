# NextNotes Test Suite

This suite is intentionally dependency-free and runs with Python's standard `unittest` module.

## Test Layers

- Unit/contract tests validate small local rules in the QML backend source: cache schema, status model, API request handling, sync ordering, filtering, and credential handling.
- Node-backed behavior tests execute extracted QML JavaScript core modules directly: `AuthCore.js`, `NotesApiCore.js`, and `SyncPlanner.js`.
- Integration contract tests validate that the current QML backend components still fit together as expected: push-local-then-pull-server sync, detail prefetch, tombstone delete, conflict handling, and runtime-only credentials.
- UI/acceptance contract tests validate that the main user-facing flows still expose the expected controls and actions.

These tests do not replace device testing for Ubuntu Touch platform behavior such as Online Accounts prompts, AppArmor runtime behavior, OSK positioning, or real network/connectivity changes. They reduce the amount of repeated manual regression testing needed before a phone smoke test.

## Run

From the project root:

```bash
python3 -m unittest discover -s tests -v
```

Through Clickable:

```bash
~/.local/bin/clickable script test
```

The JavaScript core tests verify URL normalization, Online Accounts readiness, Notes API URL/payload/ETag/parse behavior, and sync queue planning without launching the full Ubuntu Touch app.

Live Nextcloud integration tests are opt-in because they create, update, and delete notes on a real test account:

```bash
cp .env.test.local.example .env.test.local
# edit .env.test.local with a dedicated test user and app password
~/.local/bin/clickable script test-live
```

The live suite only runs when `.env.test.local` or the environment provides:

- `NEXTNOTES_RUN_LIVE_TESTS=1`
- `NEXTNOTES_TEST_SERVER`
- `NEXTNOTES_TEST_USERNAME`
- `NEXTNOTES_TEST_APP_PASSWORD`

Use a dedicated Nextcloud user and an app password. Do not use a personal account or main password.

## Manual Acceptance Still Needed

- Online Accounts authorization and SignOn behavior on the phone.
- Real Nextcloud API behavior against the user's account.
- Offline and network-recovery behavior on Ubuntu Touch.
- Visual layout, gestures, OSK behavior, and dark mode on the Pixel 3a.
