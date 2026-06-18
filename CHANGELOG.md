# Changelog

## 0.1.4 - 2026-06-18

- Improved the account setup prompt so a selected account stays selected and is verified automatically after the user returns from Ubuntu Touch account settings.
- Added a swipe-action direction setting with Ubuntu Touch style as the default and Android-compatible style as an option.
- Updated account page wording and Swedish translations for Ubuntu Touch Online Accounts guidance.
- Fixed stale authentication/API callbacks so delayed sync or refresh responses from a previous account are ignored after switching accounts.
- Fixed the note list after account switching so cached favorites are shown immediately before the server refresh completes.
- Made the note editor header title directly editable while keeping the existing Edit title menu action.

## 0.1.3 - 2026-06-17

- Fixed note list ordering after toggling a note as favorite so successful sync and server refresh no longer move the note back to an older modified position.
- Improved sync/conflict status presentation by replacing disruptive editor status text with top-bar status icons.
- Added a dedicated full-screen conflict review page that can be opened directly from the list or editor status icon.
- Removed obsolete manual save/upload controls from the editor now that automatic local save and sync are active.

## 0.1.2 - 2026-06-15

- Aligned the account page with the shared Nextcloud suite flow: clickable account rows, guided Ubuntu Touch account-setting approval, automatic verification after account selection, and immediate controller refresh after changing account.
- Hardened account switching by serializing verification, clearing stale in-memory credentials, removing normal diagnostic UI, and adding regression-test coverage.
- Fixed account switching in the Notes controller by restoring the missing runtime credential callback state and forcing a fresh server refresh after account changes.
- Separated the SQLite note cache per selected Ubuntu Touch account so switching accounts does not reconcile one account's cached notes against another account.
- Improved account authorization errors when Ubuntu Touch SignOn/AppArmor denies access for a specific account.
- Stabilized the note editor by moving sync/conflict status into a top-bar status icon, removing obsolete manual save/upload buttons, moving conflict resolution to a dedicated page, and shortening automatic sync after local autosave.

## 0.1.1 - 2026-06-13

- Fixed Online Accounts authorization so selecting an existing Ubuntu Touch account does not open the provider login page.

## 0.1.0 - 2026-06-13

- Initial OpenStore release.
- Supports Ubuntu Touch Online Accounts for Nextcloud/ownCloud authentication.
- Lists, searches, opens, creates, edits, favorites, categorizes, and deletes notes.
- Supports cached/offline access to previously loaded notes.
- Supports local draft editing with pending-change indicators.
- Supports safe upload of local changes with ETag conflict detection.
- Supports simple conflict review by choosing the local or server version.
- Supports manual and active-app synchronization.
- Includes category navigation, date-grouped note lists, pull-to-refresh, language selection, Swedish translation, and About page.
