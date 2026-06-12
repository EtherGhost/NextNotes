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

        self.assertEqual(manifest["name"], "nextnotes.cloudsite")
        self.assertEqual(manifest["version"], "0.1.0")
        self.assertIn("nextnotes", manifest["hooks"])
        self.assertEqual(manifest["hooks"]["nextnotes"]["apparmor"], "nextnotes.apparmor")
        self.assertEqual(manifest["hooks"]["nextnotes"]["desktop"], "nextnotes.desktop")

    def test_apparmor_keeps_minimal_permissions_and_no_unconfined_mode(self):
        apparmor = json.loads(read_text("nextnotes.apparmor"))

        self.assertNotIn("template", apparmor)
        self.assertNotIn("unconfined", json.dumps(apparmor).lower())
        self.assertEqual(sorted(apparmor.get("policy_groups", [])), ["accounts", "networking"])

    def test_online_accounts_service_ids_use_current_package_identity(self):
        account_page = read_text("qml/pages/AccountSelectionPage.qml")
        accounts_hook = read_text("nextnotes.accounts")

        self.assertIn("nextnotes.cloudsite_nextnotes", account_page)
        self.assertIn("nextnotes.cloudsite_nextnotes_nextcloud", account_page)
        self.assertIn("nextnotes.cloudsite_nextnotes_owncloud", account_page)
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
        self.assertIn('QSettings appSettings(QStringLiteral("nextnotes.cloudsite"), QStringLiteral("nextnotes.cloudsite"))', main)
        self.assertIn('qputenv("LANGUAGE"', main)
        self.assertIn('qputenv("LANG"', main)
        self.assertIn('localeForLanguageCode', main)
        self.assertLess(main.index('qputenv("LANGUAGE"'), main.index("QGuiApplication app"))
        self.assertIn('appSettings.remove(QStringLiteral("manualAccount"))', main)
        self.assertIn('text: i18n.tr("Language")', notes_list)
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
            r"request\.status === 404 \|\| request\.status === 410.*client\.noteDeleted\(noteId\)",
        )

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

        self.assertNotIn("Settings", self.controller)
        self.assertNotIn("LocalStorage", self.controller)
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
        ]:
            self.assertIn(snippet, account_page + session)

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
        self.assertNotIn('"content-hub"', apparmor)

    def test_notes_api_core_owns_payload_parse_url_and_etag_rules(self):
        api = read_text("qml/backend/NotesApiClient.qml")
        core = read_text("qml/backend/NotesApiCore.js")

        for snippet in [
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
            "pullRefreshThreshold",
            "section.property",
            "toggleFavoriteFromList",
            "requestDelete",
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

    def test_note_editor_autosaves_flushes_and_exposes_required_note_actions(self):
        editor = read_text("qml/pages/NoteEditorPage.qml")

        for snippet in [
            "interval: 2000",
            "Component.onDestruction: page.flushPendingDraft()",
            "onVisibleChanged",
            "saveDraftNow",
            "Upload changes",
            "Create note",
            "Review a version",
            "Keep local version",
            "Use server version",
            "Server version",
            "Local version",
            "conflictPreviewChoice",
            "selectConflictVersion",
            "applyConflictEditorContent",
            "conflictLocalContent",
            "notesController.noteConflict && page.conflictPreviewChoice === \"server\"",
            "!notesController.noteConflict || page.conflictPreviewChoice === \"local\"",
            "page.conflictPreviewChoice === \"server\"",
            "border.color: theme.palette.normal.backgroundText",
            "syncStateText",
            "noteServerContent",
            "noteConflictEtag",
            "Edit title",
            "Category",
            "Delete",
            "editingTitle",
            "editingCategory",
            "onPendingNoteIdChanged",
        ]:
            self.assertIn(snippet, editor)

    def test_note_editor_title_dialog_preserves_retyped_title(self):
        editor = read_text("qml/pages/NoteEditorPage.qml")

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
            "Diagnostics",
            "No Nextcloud account found",
            "Ubuntu Touch System Settings > Accounts",
            "currentSetupSummary",
            "displayAccountName",
            "accountInitial",
            "showDiagnostics",
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
