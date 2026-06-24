import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read_text(relative_path):
    return (ROOT / relative_path).read_text(encoding="utf-8")


def compact(text):
    return re.sub(r"\s+", " ", text)


class ProjectMetadataTests(unittest.TestCase):
    def test_manifest_identity_and_version_are_consistent(self):
        manifest = json.loads(read_text("manifest.json.in"))
        cmake = read_text("CMakeLists.txt")

        self.assertEqual(manifest["name"], "nextnotes.cloudsite")
        self.assertIn('set(NEXTNOTES_VERSION "0.1.6.1")', cmake)
        self.assertEqual(manifest["version"], "@NEXTNOTES_VERSION@")
        self.assertIn("nextnotes", manifest["hooks"])
        self.assertEqual(manifest["hooks"]["nextnotes"]["apparmor"], "nextnotes.apparmor")
        self.assertEqual(manifest["hooks"]["nextnotes"]["desktop"], "nextnotes.desktop")
        self.assertEqual(manifest["hooks"]["nextnotes"]["content-hub"], "nextnotes-contenthub.json")

    def test_apparmor_keeps_minimal_permissions_and_no_unconfined_mode(self):
        apparmor = json.loads(read_text("nextnotes.apparmor"))

        self.assertNotIn("template", apparmor)
        self.assertNotIn("unconfined", json.dumps(apparmor).lower())
        self.assertEqual(sorted(apparmor.get("policy_groups", [])), ["accounts", "content_exchange", "content_exchange_source", "networking"])
        self.assertNotIn("document_files", apparmor.get("policy_groups", []))
        self.assertNotIn("document_files_read", apparmor.get("policy_groups", []))

    def test_content_hub_import_is_declared_as_share_destination(self):
        content_hub = json.loads(read_text("nextnotes-contenthub.json"))
        main = read_text("qml/Main.qml")
        handler = read_text("qml/backend/ShareImportHandler.qml")
        fallback_handler = read_text("qml/backend/ShareImportHandlerUbuntu.qml")
        controller = read_text("qml/backend/NotesController.qml")
        cmake = read_text("CMakeLists.txt")

        self.assertEqual(content_hub, {
            "destination": ["text", "links", "documents"],
            "share": ["text", "links", "documents"],
            "source": ["text", "links", "documents"]
        })
        self.assertIn("install(FILES ${PROJECT_NAME}-contenthub.json", cmake)
        self.assertIn("ShareImportHandler.qml", main)
        self.assertIn("ShareImportHandlerUbuntu.qml", main)
        self.assertIn("ShareExportPage.qml", read_text("qml/qml.qrc"))
        self.assertIn("ShareExportPageUbuntu.qml", read_text("qml/qml.qrc"))
        self.assertIn("active: !desktopLarge", main)
        self.assertIn("Lomiri.Content handler unavailable", main)
        self.assertIn("sharedTextImported.connect(root.openSharedTextNote)", main)
        self.assertIn("function openSharedTextNote(noteId, title)", main)
        self.assertIn("import Lomiri.Content 1.3", handler)
        self.assertIn("import Ubuntu.Content 1.3", fallback_handler)
        self.assertIn("target: ContentHub", handler)
        self.assertIn("target: ContentHub", fallback_handler)
        self.assertIn("onImportRequested", handler)
        self.assertIn("onImportRequested", fallback_handler)
        self.assertIn("ContentHub.hasPending", handler)
        self.assertIn("ContentHub.restoreImports()", handler)
        self.assertIn("ContentHub.finishedImports", handler)
        self.assertIn("ContentTransfer.Collected", handler)
        self.assertIn("contentHubBridge.readTextFile", handler)
        self.assertIn("writeSharedTextFile", read_text("ContentHubBridge.cpp"))
        export_page = read_text("qml/backend/ShareExportPage.qml")
        self.assertIn("ContentHandler.Share", export_page)
        self.assertIn("item.text = shareText", export_page)
        self.assertIn("Share selected text", read_text("qml/pages/NoteEditorPage.qml"))
        self.assertIn("createLocalNoteFromSharedText", handler)
        self.assertIn("function createLocalNoteFromSharedText(title, content)", controller)
        self.assertIn("notesCache.saveLocalDraft(noteId, cleanTitle, cleanContent", controller)
        self.assertIn("scheduleAutoSync()", controller)
        self.assertIn('function sharedDateNoteTitle()', controller)
        self.assertIn('i18n.tr("Shared %1").arg(sharedDateTitle())', controller)
        self.assertIn('var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"', controller)
        self.assertIn("if (line.length <= 80)", controller)
        self.assertIn("function shareTitleForExport()", read_text("qml/pages/NoteEditorPage.qml"))
        self.assertIn("notesController.sharedDateNoteTitle()", read_text("qml/pages/NoteEditorPage.qml"))
        self.assertNotIn("console.log(content", handler)

    def test_online_accounts_service_ids_use_current_package_identity(self):
        account_page = read_text("qml/pages/AccountSelectionPage.qml")
        accounts_hook = read_text("nextnotes.accounts")

        self.assertIn("nextnotes.cloudsite_nextnotes", account_page)
        self.assertIn("nextnotes.cloudsite_nextnotes_nextcloud", account_page)
        self.assertIn("nextnotes.cloudsite_nextnotes_owncloud", account_page)
        self.assertIn("findPreferredAppService", account_page)
        self.assertIn("service-not-enabled", account_page)
        self.assertIn("openSystemAccountsDialog", account_page)
        self.assertIn('Qt.openUrlExternally("settings://system/online-accounts")', account_page)
        self.assertIn("function systemAccountsDialogText()", account_page)
        self.assertIn("function retryAfterSystemApproval()", account_page)
        self.assertIn("waitingForSystemApproval", account_page)
        self.assertIn("selectedHasServiceHandle", account_page)
        self.assertIn("if (!selectedEnabled && !selectedHasServiceHandle)", account_page)
        self.assertIn("if (selectedEnabled || selectedHasServiceHandle)", account_page)
        self.assertIn("page.waitingForSystemApproval = true", account_page)
        self.assertIn("PopupUtils.open(openSystemAccountsDialog)", account_page)
        self.assertIn("visible: page.selectedAccountId > 0 && page.waitingForSystemApproval", account_page)
        self.assertIn("verify it automatically", account_page)
        self.assertIn('i18n.tr("Open system accounts")', account_page)
        self.assertIn("clearSelectedAccount()", account_page)
        self.assertIn("notesController.applyAccountSelection(", account_page)
        self.assertIn("authorizationRunning", account_page)
        self.assertIn("if (page.authorizationRunning)", account_page)
        self.assertIn("page.selectAccount(", account_page)
        self.assertIn("function restoreSelectedAccountFromSettings()", account_page)
        self.assertIn("Open Ubuntu Touch System Settings > Accounts", account_page)
        self.assertNotIn("select it again", account_page)
        self.assertNotIn("selectedService.updateServiceEnabled(true)", account_page)
        self.assertNotIn('text: row.isSelected ? i18n.tr("Selected") : i18n.tr("Use")', account_page)
        self.assertNotIn("accountSetup.exec()", account_page)
        self.assertNotIn("Discovered services:", account_page)
        self.assertNotIn("Diagnostics", account_page)
        self.assertNotIn("nextnotes.tobbe", account_page + accounts_hook)

    def test_qml_resource_file_includes_all_runtime_qml_files(self):
        qrc = read_text("qml/qml.qrc")
        qml_files = [
            path.relative_to(ROOT / "qml").as_posix()
            for path in (ROOT / "qml").rglob("*.qml")
        ]

        for qml_file in qml_files:
            self.assertIn(f"<file>{qml_file}</file>", qrc)

        for js_file in ["backend/AuthCore.js", "backend/NotesApiCore.js", "backend/SyncPlanner.js"]:
            self.assertIn(f"<file>{js_file}</file>", qrc)

    def test_translation_structure_and_language_page_are_present(self):
        cmake = read_text("CMakeLists.txt")
        qrc = read_text("qml/qml.qrc")
        main = read_text("main.cpp")
        language_page = read_text("qml/pages/LanguageSelectionPage.qml")
        notes_list = read_text("qml/pages/NotesListPage.qml")

        self.assertIn("add_subdirectory(po)", cmake)
        self.assertIn("pages/LanguageSelectionPage.qml", qrc)
        self.assertIn("pages/AboutPage.qml", qrc)
        self.assertIn('QSettings appSettings(QStringLiteral("nextnotes.cloudsite"), QStringLiteral("nextnotes.cloudsite"))', main)
        self.assertIn('qputenv("LANGUAGE"', main)
        self.assertIn('qputenv("LANG"', main)
        self.assertIn('localeForLanguageCode', main)
        self.assertLess(main.index('qputenv("LANGUAGE"'), main.index("QGuiApplication app"))
        self.assertIn('appSettings.remove(QStringLiteral("manualAccount"))', main)
        self.assertIn("NEXTNOTES_DESKTOP_TEST_AUTH", main)
        self.assertIn("NEXTNOTES_DESKTOP_DARK_MODE", main)
        self.assertIn("NEXTNOTES_TEST_SERVER", main)
        self.assertIn("NEXTNOTES_TEST_USERNAME", main)
        self.assertIn("NEXTNOTES_TEST_APP_PASSWORD", main)
        self.assertIn("desktopTestAuthEnabled", main)
        self.assertIn("desktopDarkMode", main)
        self.assertIn("readDesktopTestEnvFile", main)
        self.assertIn(".clickable/nextnotes-desktop-env.local", main)
        clickable = read_text("clickable.yaml")
        self.assertIn("desktop-test", clickable)
        self.assertIn("scripts/desktop-test.sh", clickable)
        self.assertIn("desktop-dark: bash scripts/desktop-dark.sh", clickable)
        self.assertIn("desktop-test-dark: bash scripts/desktop-test.sh --dark", clickable)
        desktop_test_script = read_text("scripts/desktop-test.sh")
        desktop_dark_script = read_text("scripts/desktop-dark.sh")
        self.assertIn("env_vars:", desktop_test_script)
        self.assertIn("NEXTNOTES_DESKTOP_TEST_AUTH", desktop_test_script)
        self.assertIn("NEXTNOTES_DESKTOP_DARK_MODE", desktop_test_script)
        self.assertIn("NEXTNOTES_DESKTOP_DARK_MODE", desktop_dark_script)
        self.assertIn("mktemp .clickable/nextnotes-desktop-test", desktop_test_script)
        self.assertIn("nextnotes-desktop-env.local", desktop_test_script)
        main_qml = read_text("qml/Main.qml")
        self.assertIn("desktopDarkMode", main_qml)
        self.assertIn("SuruDark", main_qml)
        self.assertIn('text: i18n.tr("Language")', notes_list)
        self.assertIn('text: i18n.tr("About")', notes_list)
        self.assertIn('property string languageCode: ""', language_page)
        self.assertIn('i18n.tr("Follow system language")', language_page)
        self.assertIn('"code": "en"', language_page)
        self.assertIn('"code": "sv"', language_page)
        for ready_language in ['"code": "nb"', '"code": "da"', '"code": "fi"', '"code": "de"', '"code": "fr"', '"code": "es"', '"code": "nl"']:
            self.assertIn(ready_language, language_page)
        for unready_language in ['"code": "ru"', '"code": "it"', '"code": "pl"', '"code": "uk"']:
            self.assertNotIn(unready_language, language_page)

        for language in ["sv", "nb", "da", "fi", "de", "fr", "ru", "es", "it", "nl", "pl", "uk"]:
            po_file = ROOT / "po" / f"{language}.po"
            self.assertTrue(po_file.exists(), f"Missing {po_file}")
            self.assertIn(f'"Language: {language}\\n"', po_file.read_text(encoding="utf-8"))

        swedish_po = read_text("po/sv.po")
        for translated in ['msgstr "Språk"', 'msgstr "Konto"', 'msgstr "Alla notes"', 'msgstr "Uppdatera"']:
            self.assertIn(translated, swedish_po)

        for language in ["de", "fr", "nl", "da", "nb", "es", "fi"]:
            po_text = read_text(f"po/{language}.po")
            self.assertIn(f'"Language: {language}\\n"', po_text)
            self.assertIn('"Content-Type: text/plain; charset=UTF-8\\n"', po_text)
            self.assertGreater(po_text.count('msgstr "'), 100)

    def test_about_page_records_version_license_and_disclaimer(self):
        page = read_text("qml/pages/AboutPage.qml")
        changelog = read_text("CHANGELOG.md")

        for snippet in [
            "Version %1",
            "nextnotesAppVersion",
            "MIT License",
            "Etherghost",
            "not affiliated",
            "qrc:/assets/logo.svg",
        ]:
            self.assertIn(snippet, page)
        self.assertIn("## 0.1.4", changelog)
        self.assertIn("## 0.1.0", changelog)


class NotesApiClientContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.api = read_text("qml/backend/NotesApiClient.qml")
        cls.api_compact = compact(cls.api)

    def test_notes_api_endpoints_and_http_methods_are_present(self):
        api_core = read_text("qml/backend/NotesApiCore.js")
        expected = [
            'request.open("GET", url)',
            'request.open("PUT", url)',
            'request.open("POST", url)',
            'request.open("DELETE", url)',
        ]

        for snippet in expected:
            self.assertIn(snippet, self.api)

        self.assertIn('"/index.php/apps/notes/api/v1/notes"', api_core)
        self.assertIn("function noteUrl", api_core)

    def test_runtime_basic_auth_is_used_without_credential_storage(self):
        self.assertGreaterEqual(self.api.count('request.setRequestHeader("Authorization"'), 5)
        self.assertIn('Qt.btoa(userName + ":" + secret)', self.api)
        self.assertNotRegex(self.api, r"LocalStorage|Settings|Secret\s*[:=]\s*secret")

    def test_create_and_update_send_supported_note_fields(self):
        api_core = read_text("qml/backend/NotesApiCore.js")
        payload_fields = ['"title"', '"category"', '"favorite"', '"content"']

        for field in payload_fields:
            self.assertIn(field, api_core)

        self.assertIn("NotesApiCore.notePayload(note)", self.api)

    def test_upload_uses_if_match_and_conflict_status_handling(self):
        self.assertIn('request.setRequestHeader("If-Match"', self.api)
        self.assertIn("NotesApiCore.formatEtagHeader(etag)", self.api)
        self.assertIn("request.status === 412", self.api)
        self.assertIn("fetchConflictNote", self.api)
        self.assertIn("request.status === 404 || request.status === 410", self.api)
        self.assertIn("recreating=true", self.api)

    def test_delete_treats_already_gone_as_success(self):
        self.assertRegex(
            self.api_compact,
            r"request\.status === 404 \|\| request\.status === 410.*client\.noteDeleted\(noteId, generation\)",
        )

    def test_api_responses_carry_request_generation(self):
        self.assertIn("property int requestGeneration: 0", self.api)
        for signal in [
            "signal notesLoaded(var notes, string responseEtag, string responseLastModified, int generation)",
            "signal noteLoaded(var note, int generation)",
            "signal noteUploaded(var note, int generation)",
            "signal noteCreated(int localNoteId, var note, int generation)",
            "signal noteDeleted(int noteId, int generation)",
            "signal uploadConflict(int noteId, var serverNote, string message, int generation)",
            "signal failed(string message, int generation)",
        ]:
            self.assertIn(signal, self.api)
        self.assertIn("var generation = requestGeneration", self.api)

    def test_logs_do_not_include_secret_or_full_note_content(self):
        unsafe_patterns = [
            r"console\.log\([^)]*secret",
            r"console\.log\([^)]*content\s*[:+]",
            r"console\.log\([^)]*responseText",
        ]

        for pattern in unsafe_patterns:
            self.assertNotRegex(self.api, pattern)
        self.assertIn("hasContent", self.api)


class NotesCacheContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cache = read_text("qml/backend/NotesCache.qml")
        cls.cache_compact = compact(cls.cache)

    def test_cache_schema_tracks_sync_and_draft_state(self):
        for column in [
            "id INTEGER PRIMARY KEY",
            "title TEXT NOT NULL",
            "category TEXT",
            "etag TEXT",
            "modified INTEGER",
            "readonly INTEGER",
            "favorite INTEGER",
            "content TEXT",
            "content_loaded INTEGER",
            "server_content TEXT",
            "status TEXT",
            "local_modified INTEGER",
            "conflict INTEGER",
            "conflict_etag TEXT",
            "is_new INTEGER",
        ]:
            self.assertIn(column, self.cache)

    def test_android_inspired_local_status_model_is_canonical(self):
        self.assertIn('statusClean: ""', self.cache)
        self.assertIn('statusEdited: "LOCAL_EDITED"', self.cache)
        self.assertIn('statusDeleted: "LOCAL_DELETED"', self.cache)
        self.assertIn("localStatus === statusEdited", self.cache)
        self.assertIn("localStatus === statusDeleted", self.cache)

    def test_server_refresh_preserves_local_edits_and_reconciles_clean_deletes(self):
        self.assertIn("existingDirty && !existingNew", self.cache)
        self.assertIn("saveNote preserved local edit", self.cache)
        self.assertIn("status === statusClean", self.cache)
        self.assertIn("reconciled server-deleted", self.cache)
        self.assertIn("note.favoriteKnown === false", self.cache)
        self.assertIn("SELECT etag, modified, favorite, server_content", self.cache)

    def test_new_note_ids_are_local_negative_until_created_on_server(self):
        self.assertIn("SELECT MIN(id) AS min_id FROM notes", self.cache)
        self.assertIn("noteId = minId < 0 ? minId - 1 : -1", self.cache)
        self.assertIn("is_new", self.cache)
        self.assertIn("saveCreatedNote", self.cache)

    def test_uploaded_and_created_notes_preserve_content_when_api_response_is_incomplete(self):
        self.assertIn("saveUploadedNote", self.cache)
        self.assertIn("saveCreatedNote", self.cache)
        self.assertGreaterEqual(self.cache.count("serverContent.length === 0"), 2)
        self.assertIn("preserve", read_text("README.md").lower())

    def test_uploaded_and_created_notes_keep_latest_local_modified_time(self):
        self.assertIn("modified, status, conflict FROM notes WHERE id = ?", self.cache)
        self.assertIn("local_modified FROM notes WHERE id = ?", self.cache)
        self.assertGreaterEqual(self.cache.count("var effectiveModified = Math.max(Number(note.modified || 0)"), 3)
        self.assertIn("var effectiveModified = Math.max(Number(serverNote.modified || 0)", self.cache)


class NotesControllerContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.controller = read_text("qml/backend/NotesController.qml")
        cls.controller_compact = compact(cls.controller)

    def test_sync_now_pushes_local_changes_before_pull(self):
        sync_planner = read_text("qml/backend/SyncPlanner.js")
        self.assertIn("function syncNow", self.controller)
        self.assertIn('syncPhase = "auth"', self.controller)
        self.assertIn('syncPhase = "push"', self.controller)
        self.assertIn("SyncPlanner.planSync(dirtyNotes)", self.controller)
        self.assertIn("function planSync", sync_planner)
        self.assertIn("uploadNextDirtyNote", self.controller)
        self.assertIn("pullAfterPush", self.controller)
        self.assertLess(self.controller.index("function uploadNextDirtyNote"), self.controller.index("function pullAfterPush"))

    def test_sync_processes_one_note_at_a_time_and_continues_after_failures(self):
        self.assertIn("syncIndex += 1", self.controller)
        self.assertIn("syncCurrentNote = syncQueue[syncIndex]", self.controller)
        self.assertIn("uploadNextDirtyNote()", self.controller)
        self.assertIn("syncFailedCount += 1", self.controller)
        self.assertIn("syncConflictCount += 1", self.controller)

    def test_sync_supports_existing_new_and_deleted_notes(self):
        self.assertIn("syncCurrentNote.deleted", self.controller)
        self.assertIn("deleteNote(syncServerUrl", self.controller)
        self.assertIn("syncCurrentNote.isNew", self.controller)
        self.assertIn("createNote(syncServerUrl", self.controller)
        self.assertIn("uploadNote(syncServerUrl", self.controller)

    def test_automatic_sync_lifecycle_and_retry_are_present(self):
        self.assertIn("autoSyncTimer", self.controller)
        self.assertRegex(self.controller, r"id:\s*autoSyncTimer\s*\n\s*interval:\s*500")
        self.assertIn("autoSyncRetryTimer", self.controller)
        self.assertIn("lifecycleSyncTimer", self.controller)
        self.assertIn("connectionRecoveryTimer", self.controller)
        self.assertIn("handleApplicationActivated", self.controller)
        self.assertIn("handleApplicationDeactivated", self.controller)
        self.assertIn("handleConnectionRecoveryCheck", self.controller)
        self.assertIn("runDeferredAutomaticSyncIfNeeded", self.controller)
        self.assertIn("lastServerSyncCompletedAt", self.controller)
        self.assertIn("connection-recovery", self.controller)
        self.assertIn("connectionRecoveryTimer.restart()", self.controller)

    def test_account_switch_cancels_stale_async_work(self):
        for snippet in [
            "property int accountRequestGeneration",
            "accountRequestGeneration += 1",
            "function stopAccountActivity()",
            "function isCurrentAccountResponse",
            "function isCurrentApiGeneration",
            "ignored stale auth response",
            "ignored stale notes response",
            "notesApiClient.requestGeneration = accountRequestGeneration",
        ]:
            self.assertIn(snippet, self.controller)
        self.assertLess(self.controller.index("accountRequestGeneration += 1"), self.controller.index("accountSettings.accountId = accountId"))

    def test_sync_updates_current_open_note_state(self):
        self.assertIn("applySyncedOpenNote", self.controller)
        self.assertIn("controller.applySyncedOpenNote(note.noteId", self.controller)
        self.assertIn("controller.applySyncedOpenNote(noteId, message)", self.controller)
        self.assertIn("pendingNoteId = note.noteId", self.controller)

    def test_prefetch_loads_missing_details_without_overwriting_open_editor_state(self):
        self.assertIn("startDetailPrefetch", self.controller)
        self.assertIn("loadNotesMissingContent", self.controller)
        self.assertIn('noteFetchMode === "prefetch"', self.controller)
        self.assertIn("pendingNoteId > 0 || syncRunning", self.controller)

    def test_filtering_matches_category_title_and_cached_content(self):
        self.assertIn("setSearchQuery", self.controller)
        self.assertIn("noteMatchesQuery", self.controller)
        self.assertIn("noteMatchesCategory", self.controller)
        self.assertIn("searchContent", self.controller)
        self.assertIn('selectedCategoryType === "favorites"', self.controller)
        self.assertIn('selectedCategoryType === "uncategorized"', self.controller)

    def test_runtime_credentials_are_transient_controller_properties_only(self):
        for name in ["sessionSecret", "syncSecret"]:
            self.assertIn(name, self.controller)

        self.assertNotIn("LocalStorage", self.controller)
        self.assertNotIn("property string sessionSecret", self.controller.split('Settings {', 1)[1].split('}', 1)[0])
        self.assertNotIn("property string syncSecret", self.controller.split('Settings {', 1)[1].split('}', 1)[0])
        self.assertRegex(self.controller, r'syncSecret\s*=\s*""')
        self.assertIn("sessionSecret = secret", self.controller)


class RefactoredCoreContractTests(unittest.TestCase):
    def test_auth_core_and_online_accounts_only_auth_are_used_without_new_permissions(self):
        auth_core = read_text("qml/backend/AuthCore.js")
        account_page = read_text("qml/pages/AccountSelectionPage.qml")
        session = read_text("qml/backend/AccountSessionAdapter.qml")
        apparmor = read_text("nextnotes.apparmor")

        for snippet in [
            "function normalizeServerUrl",
            "function onlineAccountConfigured",
            "function firstValue",
        ]:
            self.assertIn(snippet, auth_core)

        for snippet in [
            "AccountServiceModel",
            "AccountService",
            "accountService.authenticate({})",
            'category: "account"',
            "findSelectedAccountService",
            "envTestAuthEnabled",
            "desktop-test-env",
        ]:
            self.assertIn(snippet, account_page + session)

        self.assertIn("envTestAuthEnabled", session)
        self.assertIn("desktopTestAuthEnabled", session)
        self.assertIn("auth using desktop test environment credentials", session)
        self.assertIn("var accountChanged = currentAccountId !== accountId", session)
        self.assertIn("signal authenticated(string userName, string secret, string serverUrl, int accountId, string serviceId)", session)
        self.assertIn("adapter.cachedAccountId, adapter.cachedServiceId", session)
        self.assertIn("property var pendingCallback: null", session)
        self.assertIn("function withCredentials(callback)", session)
        self.assertIn("cachedSecret = \"\"", session)
        self.assertIn("pendingCallback = null", session)
        self.assertIn("NextNotes NotesController account selection applied", read_text("qml/backend/NotesController.qml"))
        self.assertIn("Qt.callLater(refreshSelectedAccountFromServer)", read_text("qml/backend/NotesController.qml"))
        self.assertIn("function refreshSelectedAccountFromServer()", read_text("qml/backend/NotesController.qml"))
        self.assertIn('category: "account"', read_text("qml/backend/NotesController.qml"))
        self.assertIn("notesCache.setScope(accountKey())", read_text("qml/backend/NotesController.qml"))
        self.assertIn("function setScope(scopeKey)", read_text("qml/backend/NotesCache.qml"))
        self.assertIn('Sql.LocalStorage.openDatabaseSync(databaseName', read_text("qml/backend/NotesCache.qml"))
        self.assertIn('message.indexOf("AppArmor policy prevents")', account_page)
        self.assertNotIn("page.clearSelectedAccount()", account_page)

        forbidden = [
            "manualAccount",
            "manualAppPassword",
            "manualCredentialsComplete",
            "manual-app-password",
            "Manual app-password login",
            "Use manual login",
            "Nextcloud app password",
        ]
        for snippet in forbidden:
            self.assertNotIn(snippet, account_page + session + auth_core)

        self.assertNotIn("unconfined", apparmor.lower())
        self.assertNotIn("document_files", apparmor)

    def test_notes_api_core_owns_payload_parse_url_and_etag_rules(self):
        api = read_text("qml/backend/NotesApiClient.qml")
        core = read_text("qml/backend/NotesApiCore.js")

        for snippet in [
            "function notesBaseUrl",
            "function notesUrl",
            "function noteUrl",
            "function notePayload",
            "function formatEtagHeader",
            "function parseNotesJson",
            "function parseNoteJson",
            "function parseNoteObject",
        ]:
            self.assertIn(snippet, core)

        for snippet in [
            "NotesApiCore.notesUrl(serverUrl)",
            "NotesApiCore.noteUrl(serverUrl",
            "NotesApiCore.notePayload(note)",
            "NotesApiCore.parseNotesJson",
            "NotesApiCore.parseNoteJson",
        ]:
            self.assertIn(snippet, api)
        self.assertIn("return notesBaseUrl(serverUrl)", core)

    def test_sync_planner_classifies_dirty_notes_before_controller_uploads(self):
        controller = read_text("qml/backend/NotesController.qml")
        planner = read_text("qml/backend/SyncPlanner.js")

        for snippet in [
            "function planSync",
            "note.deleted === true",
            "note.contentLoaded !== true",
            "note.conflict === true",
            "note.isNew !== true",
            "conflictNoteIds",
            "skippedCount",
            "queue",
        ]:
            self.assertIn(snippet, planner)

        self.assertIn('import "SyncPlanner.js" as SyncPlanner', controller)
        self.assertIn("var plan = SyncPlanner.planSync(dirtyNotes)", controller)
        self.assertIn("notesCache.markConflict(conflictNoteId, null)", controller)


class UiFlowContractTests(unittest.TestCase):
    def test_notes_list_contains_android_inspired_controls_and_status_indicators(self):
        notes_list = read_text("qml/pages/NotesListPage.qml")

        for snippet in [
            'text: page.selectionMode ? "\\u2715" : "\\u2630"',
            "placeholderText: notesController.selectedCategoryType",
            "accountAvatarUrl",
            "OpacityMask",
            "conflictNotesCount",
            "firstConflictNoteId",
            "statusIconKind",
            "openStatusFromIcon",
            "ConflictResolutionPage.qml",
            "pullRefreshThreshold",
            "section.property",
            "toggleFavoriteFromList",
            "requestDelete",
            "property string activeSwipeActionLayout",
            "androidSwipeActions",
            "function actionForOffset(offset)",
            "function triggerSwipeAction(offset)",
            "function setSwipeActionLayout(value)",
            '"notesListPage": page',
            'page.activeSwipeActionLayout = appSettings.swipeActionLayout === "android" ? "android" : "ut"',
            "SettingsPage.qml",
            "selectionMode",
            "onPressAndHold",
            "deleteNotes(page.selectedNoteIds)",
            "syncStateText",
            "syncStateColor",
            "Sync now",
            "categoryMenuList",
            "pullRefreshArmed && !notesController.loading",
        ]:
            self.assertIn(snippet, notes_list)

        settings_page = read_text("qml/pages/SettingsPage.qml")
        for snippet in [
            'property string swipeActionLayout: "ut"',
            'i18n.tr("Settings")',
            'i18n.tr("Android-compatible swipe direction")',
            'i18n.tr("Swipe right to delete, left to favorite.")',
            'i18n.tr("Swipe right to favorite, left to delete.")',
            "Switch {",
            "function setSwipeActionLayout(value)",
            "property var notesListPage",
            "page.notesListPage.setSwipeActionLayout(normalized)",
        ]:
            self.assertIn(snippet, settings_page)

        self.assertNotIn('i18n.tr("List")', settings_page)
        self.assertNotIn("property var swipeActionLayoutChanged", settings_page)
        self.assertNotIn("property var applySwipeActionLayout", settings_page)

    def test_note_editor_autosaves_flushes_and_exposes_required_note_actions(self):
        editor = read_text("qml/pages/NoteEditorPage.qml")
        conflict_page = read_text("qml/pages/ConflictResolutionPage.qml")

        for snippet in [
            "interval: 2000",
            "Component.onDestruction: page.flushPendingDraft()",
            "onVisibleChanged",
            "saveDraftNow",
            "syncStateText",
            "statusIconKind",
            "statusAccentColor",
            "Canvas",
            "Resolve conflict",
            "openStatusFromIcon",
            "openConflictResolution",
            "ConflictResolutionPage.qml",
            "Edit title",
            "Category",
            "Delete",
            "editingTitle",
            "editingCategory",
            "onPendingNoteIdChanged",
        ]:
            self.assertIn(snippet, editor)

        for removed in [
            "Save locally",
            "Upload changes",
            "Create note",
            "conflictPreviewChoice",
            "selectConflictVersion",
            "applyConflictEditorContent",
            "conflictLocalContent",
            "The server changed this note while you had local edits. Review a version",
        ]:
            self.assertNotIn(removed, editor)

        for snippet in [
            "Server version",
            "Local version",
            "Use server version",
            "Keep local version",
            "discardLocalDraftAndUseServer",
            "keepLocalDraftAfterConflict",
            'page.selectedVersion === "server"',
            "noteServerContent",
            "noteConflictEtag",
            "readOnly: true",
        ]:
            self.assertIn(snippet, conflict_page)

        self.assertEqual(conflict_page.count("discardLocalDraftAndUseServer"), 1)
        self.assertEqual(conflict_page.count("keepLocalDraftAfterConflict"), 1)

        controller = read_text("qml/backend/NotesController.qml")
        self.assertIn("function keepLocalDraftAfterConflict()", controller)
        self.assertIn("function discardLocalDraftAndUseServer()", controller)
        keep_local_block = controller[
            controller.index("function keepLocalDraftAfterConflict()"):
            controller.index("function discardLocalDraftAndUseServer()")
        ]
        discard_block = controller[
            controller.index("function discardLocalDraftAndUseServer()"):
            controller.index("function loadNote(")
        ]
        self.assertIn("refreshNotesFromCache()", keep_local_block)
        self.assertIn("refreshNotesFromCache()", discard_block)

    def test_note_editor_title_dialog_preserves_retyped_title(self):
        editor = read_text("qml/pages/NoteEditorPage.qml")

        self.assertIn("id: headerTitleField", editor)
        self.assertIn("TextField {", editor)
        self.assertIn("page.commitHeaderTitle(text)", editor)
        self.assertIn("function commitHeaderTitle(value)", editor)
        self.assertIn("localSaveTimer.restart()", editor)
        self.assertIn("titleDialogField.selectAll()", editor)
        self.assertIn("Qt.inputMethod.commit()", editor)
        self.assertIn("titleCommitTimer.restart()", editor)
        self.assertIn("var newTitle = titleDialogField.text", editor)
        self.assertIn("page.editTitleText = newTitle", editor)
        self.assertIn("page.draftTitle = newTitle", editor)
        self.assertIn("draftTitleInitialized", editor)
        self.assertIn("if (page.editingTitle)", editor)
        self.assertIn("return page.editTitleText || \"\"", editor)
        self.assertLess(
            editor.index("var newTitle = titleDialogField.text"),
            editor.index("notesController.saveLocalDraft(page.draftTitle"),
        )
        self.assertLess(
            editor.index("page.editTitleText = page.currentDraftTitle()"),
            editor.index("page.editingTitle = true"),
        )

    def test_account_switch_loads_scoped_cache_before_server_refresh(self):
        controller = read_text("qml/backend/NotesController.qml")

        self.assertIn("function refreshSelectedAccountFromServer()", controller)
        self.assertIn("var cachedNotes = notesCache.loadNotes()", controller)
        self.assertIn("populateNotes(cachedNotes)", controller)
        self.assertIn("hasCachedNotes = totalNotesCount > 0", controller)
        self.assertIn('i18n.tr("Showing saved notes. Checking for updates...")', controller)
        self.assertIn("accountSwitchRefreshRunning = true", controller)
        self.assertIn("accountSwitchFavoriteRetryUsed = false", controller)
        self.assertIn("function shouldRetryAccountSwitchFavoriteRefresh(notes)", controller)
        self.assertIn("cachedFavoriteCount > 0 && incomingFavoriteCount === 0", controller)
        self.assertIn("accountSwitchFavoriteRetryTimer.restart()", controller)
        self.assertIn("function retryAccountSwitchFavoriteRefresh()", controller)
        self.assertLess(
            controller.index("populateNotes(cachedNotes)", controller.index("function refreshSelectedAccountFromServer()")),
            controller.index("accountSession.authenticate()", controller.index("function refreshSelectedAccountFromServer()")),
        )

    def test_note_editor_category_dialog_commits_preedit_and_allows_empty_category(self):
        editor = read_text("qml/pages/NoteEditorPage.qml")

        self.assertIn("property bool draftCategoryInitialized: false", editor)
        self.assertIn("categoryCommitTimer", editor)
        self.assertIn("var newCategory = categoryDialogField.text", editor)
        self.assertIn("categoryDialogField.focus = false", editor)
        self.assertIn("categoryDialogField.text = page.editCategoryText", editor)
        self.assertIn("if (page.editingCategory)", editor)
        self.assertIn("return page.editCategoryText || \"\"", editor)
        self.assertIn("if (page.draftCategoryInitialized)", editor)
        self.assertIn("page.draftCategoryInitialized = true", editor)

    def test_main_owns_one_shared_notes_controller_and_forwards_lifecycle(self):
        main = read_text("qml/Main.qml")
        pages = read_text("qml/pages/NotesListPage.qml") + read_text("qml/pages/NoteEditorPage.qml")

        self.assertEqual(main.count("NotesController {"), 1)
        self.assertIn("target: Qt.application", main)
        self.assertIn("handleApplicationActivated", main)
        self.assertIn("handleApplicationDeactivated", main)
        self.assertNotIn("NotesController {", pages)

    def test_account_page_shows_current_setup_summary(self):
        account_page = read_text("qml/pages/AccountSelectionPage.qml")

        for snippet in [
            "Available accounts",
            "No Nextcloud account found",
            "Ubuntu Touch System Settings > Accounts",
            "currentSetupSummary",
            "displayAccountName",
            "accountInitial",
            "visibleCloudAccounts",
            "updateVisibleCloudAccounts",
            "Flickable",
            "pageFlickable",
            "contentColumn",
            "accountId ",
            "accountSettings.displayName",
            "accountSettings.serverUrl",
            "accountSettings.serviceId",
        ]:
            self.assertIn(snippet, account_page)

        self.assertNotIn("showDiagnostics", account_page)
        self.assertNotIn("Diagnostics", account_page)


class DocumentationAndAcceptanceCoverageTests(unittest.TestCase):
    def test_public_docs_record_testing_auth_release_and_license(self):
        readme = read_text("README.md")

        self.assertIn("Ubuntu Touch Online Accounts", readme)
        self.assertIn("NextNotes is not affiliated with", readme)
        self.assertIn("clickable script test", readme)
        self.assertIn("MIT License", readme)
        self.assertIn("does not request unconfined mode", readme)
        self.assertNotIn("NEXTNOTES_TEST_USERNAME=", readme)


if __name__ == "__main__":
    unittest.main(verbosity=2)
