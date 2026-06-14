# Changelog

## Unreleased

- Aligned the account page with the shared Nextcloud suite flow: clickable account rows, guided Ubuntu Touch account-setting approval, automatic verification after account selection, and immediate controller refresh after changing account.
- Hardened account switching by serializing verification, clearing stale in-memory credentials, removing normal diagnostic UI, and adding regression-test coverage.
- Fixed account switching in the Notes controller by restoring the missing runtime credential callback state and forcing a fresh server refresh after account changes.
- Separated the SQLite note cache per selected Ubuntu Touch account so switching accounts does not reconcile one account's cached notes against another account.
- Improved account authorization errors when Ubuntu Touch SignOn/AppArmor denies access for a specific account.

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
