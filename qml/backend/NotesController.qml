import QtQuick 2.7
import "SyncPlanner.js" as SyncPlanner

Item {
    id: controller

    property alias model: notesModel
    property bool loading: false
    property string statusText: i18n.tr("Open your Nextcloud notes.")
    property string searchQuery: ""
    property string selectedCategoryType: "all"
    property string selectedCategoryValue: ""
    property string selectedCategoryLabel: i18n.tr("All notes")
    property int totalNotesCount: 0
    property bool searchActive: false
    property bool categoryFilterActive: selectedCategoryType !== "all"
    property int filteredNotesCount: notesModel.count
    property var allNotes: []
    property int dirtyNotesCount: 0
    property bool syncRunning: false
    property string syncProgressText: ""
    property string syncSummaryText: ""
    property string syncPhase: "idle"
    property bool syncAutomatic: false
    property alias syncRetryPending: autoSyncRetryTimer.running
    property alias connectionRecoveryPending: connectionRecoveryTimer.running
    property var syncQueue: []
    property int syncIndex: 0
    property int syncTotal: 0
    property int syncUploadedCount: 0
    property int syncFailedCount: 0
    property int syncConflictCount: 0
    property int syncSkippedCount: 0
    property var syncCurrentNote: null
    property string syncUserName: ""
    property string syncSecret: ""
    property string syncServerUrl: ""
    property string sessionUserName: ""
    property string sessionSecret: ""
    property string sessionServerUrl: ""
    property bool detailPrefetchRunning: false
    property var detailPrefetchQueue: []
    property int detailPrefetchIndex: 0
    property int detailPrefetchCurrentNoteId: 0
    property string noteFetchMode: "open"
    property int pendingNoteId: 0
    property bool noteLoading: false
    property string noteStatusText: ""
    property string noteTitle: ""
    property string noteCategory: ""
    property string noteContent: ""
    property string noteServerContent: ""
    property string noteModifiedText: ""
    property string noteConflictEtag: ""
    property bool noteReadOnly: true
    property bool noteDirty: false
    property bool noteConflict: false
    property bool noteIsNew: false
    property bool noteFavorite: false
    property string noteLocalModifiedText: ""
    property bool hasCachedNotes: false
    property bool hasCachedNote: false
    property bool pendingUpload: false
    property var pendingUploadNote: null
    property bool pendingDelete: false
    property int pendingDeleteNoteId: 0
    property bool noteDeleted: false
    property string accountAvatarUrl: ""
    property string activeAccountKey: ""
    property int currentAccountId: 0
    property string currentDisplayName: ""
    property string currentProviderId: ""
    property string currentServiceId: ""
    property string currentServerUrl: ""
    property string currentAvatarUrl: ""
    property double lastLifecycleSyncStartedAt: 0
    property double lastServerSyncCompletedAt: 0
    property string deferredAutomaticReason: ""
    property bool automaticServerCycleRunning: false
    readonly property string syncStateText: syncRunning
        ? syncProgressText
        : syncRetryPending || connectionRecoveryPending
        ? i18n.tr("Offline, will retry")
        : dirtyNotesCount > 0
        ? i18n.tr("%1 pending").arg(dirtyNotesCount)
        : lastServerSyncCompletedAt > 0
        ? i18n.tr("Synced %1").arg(relativeTimeFromMs(lastServerSyncCompletedAt))
        : i18n.tr("Not synced yet")
    readonly property string syncStateColor: syncRunning
        ? "#2c7fb8"
        : syncRetryPending || connectionRecoveryPending
        ? "#c65d00"
        : dirtyNotesCount > 0
        ? "#c65d00"
        : lastServerSyncCompletedAt > 0
        ? "#2f7d32"
        : "#7a7a7a"

    Timer {
        id: autoSyncTimer
        interval: 5000
        repeat: false
        onTriggered: controller.autoSyncNow()
    }

    Timer {
        id: autoSyncRetryTimer
        interval: 60000
        repeat: false
        onTriggered: controller.retryAutomaticSync()
    }

    Timer {
        id: lifecycleSyncTimer
        interval: 1200
        repeat: false
        onTriggered: controller.runLifecycleSync("foreground")
    }

    Timer {
        id: connectionRecoveryTimer
        interval: 45000
        repeat: false
        onTriggered: controller.handleConnectionRecoveryCheck()
    }

    ListModel {
        id: notesModel
    }

    ListModel {
        id: categoriesModel
    }

    property alias categories: categoriesModel

    NotesCache {
        id: notesCache
    }

    AccountSessionAdapter {
        id: accountSession

        onAuthenticated: {
            controller.accountAvatarUrl = controller.avatarUrl(serverUrl, userName)
            controller.currentAvatarUrl = controller.accountAvatarUrl
            controller.sessionUserName = userName
            controller.sessionSecret = secret
            controller.sessionServerUrl = serverUrl
            if (controller.syncRunning) {
                controller.syncUserName = userName
                controller.syncSecret = secret
                controller.syncServerUrl = serverUrl
                controller.syncPhase = "push"
                controller.uploadNextDirtyNote()
            } else if (controller.pendingDelete && controller.pendingDeleteNoteId > 0) {
                controller.noteStatusText = i18n.tr("Deleting note...")
                notesApiClient.deleteNote(serverUrl, userName, secret, controller.pendingDeleteNoteId)
            } else if (controller.pendingUpload && controller.pendingUploadNote) {
                if (controller.pendingUploadNote.isNew) {
                    controller.noteStatusText = i18n.tr("Creating note...")
                    notesApiClient.createNote(serverUrl, userName, secret, controller.pendingUploadNote)
                } else {
                    controller.noteStatusText = i18n.tr("Uploading changes...")
                    notesApiClient.uploadNote(serverUrl, userName, secret, controller.pendingUploadNote)
                }
            } else if (controller.pendingNoteId > 0) {
                controller.noteStatusText = i18n.tr("Loading note...")
                notesApiClient.fetchNote(serverUrl, userName, secret, controller.pendingNoteId)
            } else {
                controller.statusText = i18n.tr("Loading notes...")
                notesApiClient.fetchNotes(serverUrl, userName, secret)
            }
        }

        onFailed: controller.fail(message)
    }

    Timer {
        id: accountRefreshTimer
        interval: 150
        repeat: false
        onTriggered: controller.loadNotes()
    }

    NotesApiClient {
        id: notesApiClient

        onNotesLoaded: {
            notesCache.replaceServerNotes(notes, responseEtag, responseLastModified)
            controller.populateNotes(notesCache.loadNotes())
            controller.hasCachedNotes = controller.totalNotesCount > 0
            controller.lastServerSyncCompletedAt = Date.now()
            connectionRecoveryTimer.stop()
            if (controller.syncRunning && controller.syncPhase === "pull") {
                controller.finishSyncNow()
                controller.startDetailPrefetch()
            } else {
                controller.automaticServerCycleRunning = false
                autoSyncRetryTimer.stop()
                controller.loading = false
                controller.statusText = controller.totalNotesCount > 0
                    ? i18n.tr("%1 notes synced.").arg(controller.totalNotesCount)
                    : i18n.tr("No notes yet.")
                controller.startDetailPrefetch()
            }
        }

        onNoteLoaded: {
            if (controller.noteFetchMode === "prefetch" && note.noteId === controller.detailPrefetchCurrentNoteId) {
                notesCache.saveNote(note)
                controller.refreshNotesFromCache()
                controller.prefetchNextDetail()
                return
            }

            if (controller.pendingNoteId > 0 && note.noteId !== controller.pendingNoteId) {
                notesCache.saveNote(note)
                controller.refreshNotesFromCache()
                return
            }

            if (controller.pendingNoteId === 0 && !controller.noteLoading) {
                notesCache.saveNote(note)
                controller.refreshNotesFromCache()
                return
            }

            notesCache.saveNote(note)
            var cachedNote = notesCache.loadNote(note.noteId)
            controller.noteLoading = false
            controller.applyNote(cachedNote || note, cachedNote && cachedNote.dirty
                ? i18n.tr("Local changes saved on this device")
                : i18n.tr("Loaded from server"))
        }

        onNoteUploaded: {
            if (controller.syncRunning) {
                notesCache.saveUploadedNote(note)
                controller.syncUploadedCount += 1
                controller.applySyncedOpenNote(note.noteId, i18n.tr("Uploaded changes."))
                controller.refreshNotesFromCache()
                controller.uploadNextDirtyNote()
            } else {
                notesCache.saveUploadedNote(note)
                var uploadedNote = notesCache.loadNote(note.noteId)
                controller.pendingUpload = false
                controller.pendingUploadNote = null
                controller.noteLoading = false
                controller.applyNote(uploadedNote || note, i18n.tr("Uploaded changes."))
                controller.noteDirty = false
                controller.noteConflict = false
                controller.noteLocalModifiedText = ""
            }
        }

        onNoteCreated: {
            if (controller.syncRunning) {
                notesCache.saveCreatedNote(localNoteId, note)
                controller.syncUploadedCount += 1
                if (controller.pendingNoteId === localNoteId) {
                    controller.pendingNoteId = note.noteId
                    controller.applySyncedOpenNote(note.noteId, i18n.tr("Created note."))
                }
                controller.refreshNotesFromCache()
                controller.uploadNextDirtyNote()
            } else {
                notesCache.saveCreatedNote(localNoteId, note)
                var createdNote = notesCache.loadNote(note.noteId)
                controller.pendingNoteId = note.noteId
                controller.pendingUpload = false
                controller.pendingUploadNote = null
                controller.noteLoading = false
                controller.applyNote(createdNote || note, i18n.tr("Created note."))
                controller.noteDirty = false
                controller.noteConflict = false
                controller.noteIsNew = false
                controller.noteLocalModifiedText = ""
            }
        }

        onNoteDeleted: {
            if (controller.syncRunning) {
                notesCache.deleteNote(noteId)
                controller.syncUploadedCount += 1
                controller.refreshNotesFromCache()
                controller.uploadNextDirtyNote()
                return
            }

            notesCache.deleteNote(noteId)
            controller.pendingDelete = false
            controller.pendingDeleteNoteId = 0
            controller.noteLoading = false
            controller.noteDeleted = true
            controller.noteStatusText = i18n.tr("Deleted note.")
            controller.refreshNotesFromCache()
        }

        onUploadConflict: {
            if (controller.syncRunning) {
                notesCache.markConflict(noteId, serverNote)
                controller.syncConflictCount += 1
                controller.applySyncedOpenNote(noteId, message)
                controller.refreshNotesFromCache()
                controller.uploadNextDirtyNote()
            } else {
                notesCache.markConflict(noteId, serverNote)
                var conflictedNote = notesCache.loadNote(noteId)
                controller.pendingUpload = false
                controller.pendingUploadNote = null
                controller.noteLoading = false
                if (conflictedNote) {
                    controller.applyNote(conflictedNote, message)
                } else {
                    controller.noteStatusText = message
                    controller.noteConflict = true
                    controller.noteDirty = true
                }
            }
        }

        onFailed: controller.fail(message)
    }

    function loadNotes() {
        accountSession.setAccount(currentAccountId, currentProviderId, currentServiceId, currentServerUrl)
        cancelDetailPrefetch()
        pendingNoteId = 0
        pendingUpload = false
        pendingUploadNote = null
        pendingDelete = false
        pendingDeleteNoteId = 0
        hasCachedNote = false
        var cachedNotes = notesCache.loadNotes()
        populateNotes(cachedNotes)

        hasCachedNotes = totalNotesCount > 0
        if (notesCache.loadLocalChanges().length > 0) {
            statusText = hasCachedNotes
                ? i18n.tr("Showing saved notes. Syncing local changes...")
                : i18n.tr("Syncing local changes...")
            syncNow(true)
            return
        }

        loading = true
        statusText = hasCachedNotes
            ? i18n.tr("Showing saved notes. Checking for updates...")
            : i18n.tr("Connecting to Nextcloud...")
        accountSession.authenticate()
    }

    function applyAccountSelection(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl) {
        currentAccountId = accountId
        currentDisplayName = displayName || ""
        currentProviderId = providerId || ""
        currentServiceId = serviceId || ""
        currentServerUrl = serverUrl || ""
        currentAvatarUrl = avatarUrl || ""
        accountSession.setAccount(currentAccountId, currentProviderId, currentServiceId, currentServerUrl)
        clearAccountData()
        activeAccountKey = accountKey()
        accountRefreshTimer.restart()
    }

    function clearAccountData() {
        notesModel.clear()
        categoriesModel.clear()
        allNotes = []
        totalNotesCount = 0
        filteredNotesCount = 0
        hasCachedNotes = false
        accountAvatarUrl = currentAvatarUrl || ""
        statusText = currentAccountId > 0
            ? i18n.tr("Account changed. Refreshing...")
            : i18n.tr("Open your Nextcloud notes.")
    }

    function accountKey() {
        return String(currentAccountId)
            + "|" + String(currentProviderId || "")
            + "|" + String(currentServiceId || "")
            + "|" + String(currentServerUrl || "")
    }

    function loadCachedNotesOnly() {
        cancelDetailPrefetch()
        pendingNoteId = 0
        pendingUpload = false
        pendingUploadNote = null
        pendingDelete = false
        pendingDeleteNoteId = 0
        hasCachedNote = false
        var cachedNotes = notesCache.loadNotes()
        populateNotes(cachedNotes)
        hasCachedNotes = totalNotesCount > 0
        loading = false
        statusText = hasCachedNotes
            ? i18n.tr("Showing saved notes.")
            : i18n.tr("No saved notes on this device.")
    }

    function uploadLocalDraft() {
        if (pendingNoteId === 0 || noteReadOnly || !noteDirty) {
            return
        }

        var cachedNote = notesCache.loadNote(pendingNoteId)
        if (!cachedNote || !cachedNote.dirty || !cachedNote.contentLoaded) {
            noteStatusText = i18n.tr("No local draft is available to upload.")
            return
        }

        if (!cachedNote.isNew && (!cachedNote.etag || cachedNote.etag.length === 0)) {
            notesCache.markConflict(pendingNoteId, null)
            cachedNote = notesCache.loadNote(pendingNoteId)
            if (cachedNote) {
                applyNote(cachedNote, i18n.tr("Cannot upload safely because the server etag is missing."))
            }
            return
        }

        pendingUpload = true
        pendingUploadNote = cachedNote
        noteLoading = true
        noteStatusText = i18n.tr("Authenticating...")
        accountSession.authenticate()
    }

    function syncNow(automatic) {
        if (syncRunning || loading) {
            return
        }

        autoSyncTimer.stop()
        var dirtyNotes = notesCache.loadLocalChanges()
        syncQueue = []
        syncIndex = 0
        syncTotal = 0
        syncUploadedCount = 0
        syncFailedCount = 0
        syncConflictCount = 0
        syncSkippedCount = 0
        syncCurrentNote = null
        syncSummaryText = ""
        syncServerUrl = ""
        syncPhase = "auth"
        syncAutomatic = automatic === true

        var plan = SyncPlanner.planSync(dirtyNotes)
        syncQueue = plan.queue
        syncSkippedCount = plan.skippedCount
        syncConflictCount = plan.conflictCount
        for (var i = 0; i < plan.conflictNoteIds.length; ++i) {
            var conflictNoteId = Number(plan.conflictNoteIds[i])
            if (conflictNoteId !== 0) {
                notesCache.markConflict(conflictNoteId, null)
            }
        }

        syncTotal = syncQueue.length
        refreshNotesFromCache()

        if (syncTotal === 0) {
            syncRunning = true
            syncProgressText = i18n.tr("Checking for server changes...")
            statusText = syncProgressText
            accountSession.authenticate()
            return
        }

        syncRunning = true
        syncProgressText = i18n.tr("Authenticating...")
        statusText = syncProgressText
        accountSession.authenticate()
    }

    function deleteCurrentNote() {
        if (pendingNoteId === 0 || noteLoading) {
            return
        }

        deleteNote(pendingNoteId)
    }

    function deleteNote(noteId) {
        if (noteId === 0 || noteLoading || pendingDelete) {
            return
        }

        var cachedNote = notesCache.loadNote(noteId)
        if (!cachedNote) {
            noteStatusText = i18n.tr("No cached note is available to delete.")
            statusText = i18n.tr("No cached note is available to delete.")
            return
        }

        if (cachedNote.isNew) {
            notesCache.deleteNote(noteId)
            refreshNotesFromCache()
            if (pendingNoteId === noteId) {
                noteDeleted = true
                noteStatusText = i18n.tr("Deleted local draft.")
            }
            statusText = i18n.tr("Deleted local draft.")
            return
        }

        notesCache.markDeleted(noteId)
        refreshNotesFromCache()
        if (pendingNoteId === noteId) {
            noteDeleted = true
            noteStatusText = i18n.tr("Deleted locally. Syncing deletion...")
        }
        statusText = i18n.tr("Deleted locally. Syncing deletion...")
        scheduleAutoSync()
    }

    function deleteNotes(noteIds) {
        if (!noteIds || noteIds.length === 0 || pendingDelete) {
            return 0
        }

        var deletedCount = 0
        var serverDeleteCount = 0
        var localDeleteCount = 0
        for (var i = 0; i < noteIds.length; ++i) {
            var noteId = Number(noteIds[i])
            if (noteId === 0) {
                continue
            }

            var cachedNote = notesCache.loadNote(noteId)
            if (!cachedNote) {
                continue
            }

            if (cachedNote.isNew) {
                notesCache.deleteNote(noteId)
                localDeleteCount += 1
            } else {
                notesCache.markDeleted(noteId)
                serverDeleteCount += 1
            }
            deletedCount += 1

            if (pendingNoteId === noteId) {
                noteDeleted = true
                noteStatusText = cachedNote.isNew
                    ? i18n.tr("Deleted local draft.")
                    : i18n.tr("Deleted locally. Syncing deletion...")
            }
        }

        refreshNotesFromCache()
        if (serverDeleteCount > 0) {
            statusText = i18n.tr("Deleted %1 notes locally. Syncing deletions...").arg(deletedCount)
            scheduleAutoSync()
        } else if (localDeleteCount > 0) {
            statusText = deletedCount === 1
                ? i18n.tr("Deleted local draft.")
                : i18n.tr("Deleted %1 local drafts.").arg(deletedCount)
        }
        return deletedCount
    }

    function keepLocalDraftAfterConflict() {
        if (pendingNoteId <= 0 || !noteConflict) {
            return
        }

        notesCache.keepLocalDraftForUpload(pendingNoteId)
        var cachedNote = notesCache.loadNote(pendingNoteId)
        if (cachedNote) {
            applyNote(cachedNote, i18n.tr("Local draft kept. You can try uploading again."))
        }
    }

    function discardLocalDraftAndUseServer() {
        if (pendingNoteId <= 0 || !noteConflict) {
            return
        }

        notesCache.discardLocalDraft(pendingNoteId)
        var cachedNote = notesCache.loadNote(pendingNoteId)
        if (cachedNote) {
            applyNote(cachedNote, i18n.tr("Using server version."))
        }
    }

    function loadNote(noteId, initialTitle) {
        cancelDetailPrefetch()
        noteFetchMode = "open"
        pendingNoteId = noteId
        noteDeleted = false
        var cachedNote = notesCache.loadNote(noteId)
        hasCachedNote = cachedNote && cachedNote.contentLoaded
        if (cachedNote) {
            applyNote(cachedNote, hasCachedNote
                ? (cachedNote.dirty ? i18n.tr("Local changes saved on this device") : i18n.tr("Loaded cached note. Refreshing..."))
                : i18n.tr("Authenticating..."))
        } else {
            noteTitle = initialTitle || ""
            noteCategory = ""
            noteContent = ""
            noteServerContent = ""
            noteModifiedText = ""
            noteConflictEtag = ""
            noteLocalModifiedText = ""
            noteReadOnly = true
            noteDirty = false
            noteConflict = false
            noteIsNew = false
            noteFavorite = false
        }

        if (noteId < 0) {
            noteLoading = false
            return
        }

        noteLoading = true
        if (!cachedNote) {
            noteStatusText = i18n.tr("Authenticating...")
        }
        accountSession.authenticate()
    }

    function createLocalNote() {
        cancelDetailPrefetch()
        var category = selectedCategoryType === "category" ? selectedCategoryValue : ""
        var favorite = selectedCategoryType === "favorites"
        var noteId = notesCache.createLocalNote(category, favorite)
        populateNotes(notesCache.loadNotes())
        return noteId
    }

    function saveLocalDraft(title, content, category, favorite) {
        if (pendingNoteId === 0 || noteReadOnly) {
            return
        }

        notesCache.saveLocalDraft(pendingNoteId, title, content, category, favorite)
        var cachedNote = notesCache.loadNote(pendingNoteId)
        if (cachedNote) {
            applyNote(cachedNote, i18n.tr("Local changes saved on this device"))
        }
        refreshNotesFromCache()
        scheduleAutoSync()
    }

    function toggleFavoriteFromList(noteId) {
        var cachedNote = notesCache.loadNote(noteId)
        if (!cachedNote || cachedNote.readonly) {
            statusText = i18n.tr("This note is read-only.")
            return
        }

        notesCache.setFavoriteDraft(noteId, cachedNote.favorite !== true)
        refreshNotesFromCache()

        if (pendingNoteId === noteId) {
            var updatedNote = notesCache.loadNote(noteId)
            if (updatedNote) {
                applyNote(updatedNote, i18n.tr("Favorite changed locally."))
            }
        }

        statusText = i18n.tr("Favorite changed locally. Syncing soon.")
        scheduleAutoSync()
    }

    function populateNotes(notes) {
        var normalizedNotes = []
        for (var i = 0; i < notes.length; ++i) {
            normalizedNotes.push(normalizeNoteForList(notes[i]))
        }
        normalizedNotes.sort(function(a, b) {
            return b.sortModified - a.sortModified
        })
        allNotes = normalizedNotes
        totalNotesCount = allNotes.length
        dirtyNotesCount = notesCache.loadLocalChanges().length
        rebuildCategories()
        applyNoteFilter()
    }

    function refreshNotesFromCache() {
        populateNotes(notesCache.loadNotes())
        hasCachedNotes = totalNotesCount > 0
    }

    function scheduleAutoSync() {
        if (syncRunning || loading) {
            deferredAutomaticReason = "local-change"
            return
        }
        autoSyncTimer.restart()
    }

    function autoSyncNow() {
        if (syncRunning || loading) {
            deferredAutomaticReason = "auto-timer"
            return
        }
        if (notesCache.loadLocalChanges().length === 0) {
            return
        }
        syncNow(true)
    }

    function retryAutomaticSync() {
        if (syncRunning || loading || noteLoading) {
            deferredAutomaticReason = "retry"
            autoSyncRetryTimer.restart()
            return
        }

        console.log("NextNotes NotesApi automatic sync retry")
        runAutomaticServerCycle("retry")
    }

    function handleConnectionRecoveryCheck() {
        if (syncRunning || loading || noteLoading) {
            connectionRecoveryTimer.restart()
            return
        }

        console.log("NextNotes NotesApi connection recovery probe")
        runAutomaticServerCycle("connection-recovery")
    }

    function handleApplicationActivated() {
        console.log("NextNotes NotesApi lifecycle active=true")
        lifecycleSyncTimer.restart()
    }

    function handleApplicationDeactivated() {
        console.log("NextNotes NotesApi lifecycle active=false")
        autoSyncTimer.stop()
        if (notesCache.loadLocalChanges().length > 0) {
            autoSyncRetryTimer.restart()
            connectionRecoveryTimer.restart()
        }
    }

    function runLifecycleSync(reason) {
        var now = Date.now()
        if (now - lastLifecycleSyncStartedAt < 30000) {
            return
        }
        if (now - lastServerSyncCompletedAt < 30000) {
            return
        }
        if (syncRunning || loading || noteLoading) {
            deferredAutomaticReason = reason
            return
        }

        lastLifecycleSyncStartedAt = now
        runAutomaticServerCycle(reason)
    }

    function runDeferredAutomaticSyncIfNeeded() {
        if (deferredAutomaticReason.length === 0 || syncRunning || loading || noteLoading) {
            return
        }

        var reason = deferredAutomaticReason
        deferredAutomaticReason = ""
        if (Date.now() - lastServerSyncCompletedAt < 30000 && notesCache.loadLocalChanges().length === 0) {
            return
        }
        console.log("NextNotes NotesApi running deferred automatic sync reason=" + reason)
        runAutomaticServerCycle(reason)
    }

    function runAutomaticServerCycle(reason) {
        cancelDetailPrefetch()
        console.log(
            "NextNotes NotesApi automatic server cycle"
            + " reason=" + reason
            + " localChanges=" + notesCache.loadLocalChanges().length
        )
        automaticServerCycleRunning = true
        if (notesCache.loadLocalChanges().length > 0) {
            syncNow(true)
            return
        }

        loading = true
        statusText = hasCachedNotes
            ? i18n.tr("Showing saved notes. Checking for updates...")
            : i18n.tr("Connecting to Nextcloud...")
        accountSession.authenticate()
    }

    function countDirtyNotes(notes) {
        var count = 0
        for (var i = 0; i < notes.length; ++i) {
            if (notes[i].dirty === true) {
                count += 1
            }
        }
        return count
    }

    function uploadNextDirtyNote() {
        if (!syncRunning) {
            return
        }

        if (syncIndex >= syncQueue.length) {
            pullAfterPush()
            return
        }

        syncCurrentNote = syncQueue[syncIndex]
        syncIndex += 1
        syncProgressText = i18n.tr("Uploading %1 of %2...").arg(syncIndex).arg(syncTotal)
        statusText = syncProgressText

        console.log(
            "NextNotes NotesApi sync upload"
            + " item=" + syncIndex
            + " total=" + syncTotal
            + " noteId=" + syncCurrentNote.noteId
            + " isNew=" + (syncCurrentNote.isNew ? "true" : "false")
            + " deleted=" + (syncCurrentNote.deleted ? "true" : "false")
        )

        if (syncCurrentNote.deleted) {
            notesApiClient.deleteNote(syncServerUrl, syncUserName, syncSecret, syncCurrentNote.noteId)
        } else if (syncCurrentNote.isNew) {
            notesApiClient.createNote(syncServerUrl, syncUserName, syncSecret, syncCurrentNote)
        } else {
            notesApiClient.uploadNote(syncServerUrl, syncUserName, syncSecret, syncCurrentNote)
        }
    }

    function pullAfterPush() {
        if (!syncRunning) {
            return
        }

        syncPhase = "pull"
        syncProgressText = i18n.tr("Checking for server changes...")
        statusText = syncProgressText
        notesApiClient.fetchNotes(syncServerUrl, syncUserName, syncSecret)
    }

    function startDetailPrefetch() {
        if (detailPrefetchRunning || pendingNoteId > 0 || syncRunning) {
            return
        }
        if (sessionUserName.length === 0 || sessionSecret.length === 0 || sessionServerUrl.length === 0) {
            return
        }

        detailPrefetchQueue = notesCache.loadNotesMissingContent(100)
        detailPrefetchIndex = 0
        detailPrefetchCurrentNoteId = 0
        if (detailPrefetchQueue.length === 0) {
            return
        }

        detailPrefetchRunning = true
        noteFetchMode = "prefetch"
        statusText = i18n.tr("Caching note previews...")
        prefetchNextDetail()
    }

    function prefetchNextDetail() {
        if (!detailPrefetchRunning) {
            return
        }

        if (pendingNoteId > 0 || syncRunning) {
            cancelDetailPrefetch()
            return
        }

        if (detailPrefetchIndex >= detailPrefetchQueue.length) {
            detailPrefetchRunning = false
            detailPrefetchCurrentNoteId = 0
            noteFetchMode = "open"
            statusText = totalNotesCount > 0
                ? i18n.tr("%1 notes synced.").arg(totalNotesCount)
                : i18n.tr("No notes yet.")
            return
        }

        detailPrefetchCurrentNoteId = detailPrefetchQueue[detailPrefetchIndex]
        detailPrefetchIndex += 1
        console.log("NextNotes NotesApi prefetch detail noteId=" + detailPrefetchCurrentNoteId + " item=" + detailPrefetchIndex + " total=" + detailPrefetchQueue.length)
        notesApiClient.fetchNote(sessionServerUrl, sessionUserName, sessionSecret, detailPrefetchCurrentNoteId)
    }

    function cancelDetailPrefetch() {
        if (!detailPrefetchRunning) {
            return
        }
        detailPrefetchRunning = false
        detailPrefetchQueue = []
        detailPrefetchIndex = 0
        detailPrefetchCurrentNoteId = 0
        noteFetchMode = "open"
    }

    function finishSyncNow() {
        var wasAutomatic = syncAutomatic
        syncRunning = false
        syncCurrentNote = null
        syncUserName = ""
        syncSecret = ""
        syncServerUrl = ""
        syncQueue = []
        syncPhase = "idle"
        syncAutomatic = false
        automaticServerCycleRunning = false
        refreshNotesFromCache()

        syncSummaryText = i18n.tr("Sync complete: %1 uploaded, %2 failed, %3 conflicts, %4 skipped.")
            .arg(syncUploadedCount)
            .arg(syncFailedCount)
            .arg(syncConflictCount)
            .arg(syncSkippedCount)
        syncProgressText = syncSummaryText
        statusText = syncSummaryText
        if (syncFailedCount > 0 && wasAutomatic && notesCache.loadLocalChanges().length > 0) {
            autoSyncRetryTimer.restart()
            connectionRecoveryTimer.restart()
        } else {
            autoSyncRetryTimer.stop()
            connectionRecoveryTimer.stop()
        }
        Qt.callLater(controller.runDeferredAutomaticSyncIfNeeded)
    }

    function setSearchQuery(query) {
        var nextQuery = query || ""
        if (searchQuery === nextQuery) {
            return
        }
        searchQuery = nextQuery
        applyNoteFilter()
    }

    function clearSearch() {
        setSearchQuery("")
    }

    function selectCategory(type, value, label) {
        var nextType = type || "all"
        var nextValue = value || ""
        if (selectedCategoryType === nextType && selectedCategoryValue === nextValue) {
            return
        }
        selectedCategoryType = nextType
        selectedCategoryValue = nextValue
        selectedCategoryLabel = label || categoryLabel(nextType, nextValue)
        applyNoteFilter()
    }

    function rebuildCategories() {
        var counts = {}
        var names = []
        var favoritesCount = 0
        var uncategorizedCount = 0

        for (var i = 0; i < allNotes.length; ++i) {
            var note = allNotes[i]
            if (note.favorite === true) {
                favoritesCount += 1
            }

            var category = normalizedCategory(note.category)
            if (category.length === 0) {
                uncategorizedCount += 1
            } else {
                if (counts[category] === undefined) {
                    counts[category] = 0
                    names.push(category)
                }
                counts[category] += 1
            }
        }

        names.sort(function(a, b) {
            return a.toLowerCase() < b.toLowerCase() ? -1 : (a.toLowerCase() > b.toLowerCase() ? 1 : 0)
        })

        categoriesModel.clear()
        categoriesModel.append({
            "type": "all",
            "value": "",
            "label": i18n.tr("All notes"),
            "count": allNotes.length,
            "selected": selectedCategoryType === "all"
        })
        categoriesModel.append({
            "type": "favorites",
            "value": "",
            "label": i18n.tr("Favorites"),
            "count": favoritesCount,
            "selected": selectedCategoryType === "favorites"
        })
        categoriesModel.append({
            "type": "uncategorized",
            "value": "",
            "label": i18n.tr("Uncategorized"),
            "count": uncategorizedCount,
            "selected": selectedCategoryType === "uncategorized"
        })

        for (var j = 0; j < names.length; ++j) {
            categoriesModel.append({
                "type": "category",
                "value": names[j],
                "label": displayCategory(names[j]),
                "count": counts[names[j]],
                "selected": selectedCategoryType === "category" && selectedCategoryValue === names[j]
            })
        }

        if (!categoryStillExists()) {
            selectedCategoryType = "all"
            selectedCategoryValue = ""
            selectedCategoryLabel = i18n.tr("All notes")
            if (categoriesModel.count > 0) {
                categoriesModel.setProperty(0, "selected", true)
            }
        }
    }

    function applyNoteFilter() {
        var query = normalizedSearchQuery()
        searchActive = query.length > 0
        notesModel.clear()
        for (var i = 0; i < allNotes.length; ++i) {
            if (noteMatchesCategory(allNotes[i]) && (query.length === 0 || noteMatchesQuery(allNotes[i], query))) {
                notesModel.append(noteForListModel(allNotes[i]))
            }
        }
        filteredNotesCount = notesModel.count
    }

    function normalizeNoteForList(note) {
        return {
            "noteId": note.noteId,
            "title": note.title,
            "category": note.category || "",
            "etag": note.etag || "",
            "modified": note.modified,
            "readonly": note.readonly === true,
            "favorite": note.favorite === true,
            "dirty": note.dirty === true,
            "deleted": note.deleted === true,
            "localStatus": note.localStatus || "",
            "localModified": note.localModified || 0,
            "conflict": note.conflict === true,
            "isNew": note.isNew === true,
            "preview": note.preview || "",
            "modifiedText": formatModified(note.modified),
            "relativeModifiedText": formatRelativeModified(effectiveModified(note)),
            "sortModified": effectiveModified(note),
            "sectionLabel": sectionLabel(effectiveModified(note)),
            "searchContent": note.searchContent || ""
        }
    }

    function noteForListModel(note) {
        return {
            "noteId": note.noteId,
            "title": note.title,
            "category": note.category || "",
            "etag": note.etag || "",
            "modified": note.modified,
            "readonly": note.readonly === true,
            "favorite": note.favorite === true,
            "dirty": note.dirty === true,
            "deleted": note.deleted === true,
            "localStatus": note.localStatus || "",
            "localModified": note.localModified || 0,
            "conflict": note.conflict === true,
            "isNew": note.isNew === true,
            "preview": note.preview || "",
            "modifiedText": note.modifiedText || "",
            "relativeModifiedText": note.relativeModifiedText || "",
            "sectionLabel": note.sectionLabel || ""
        }
    }

    function normalizedSearchQuery() {
        return String(searchQuery || "").trim().toLowerCase()
    }

    function noteMatchesQuery(note, query) {
        var title = String(note.title || "").toLowerCase()
        var content = String(note.searchContent || "").toLowerCase()
        return title.indexOf(query) !== -1 || content.indexOf(query) !== -1
    }

    function noteMatchesCategory(note) {
        if (selectedCategoryType === "all") {
            return true
        }
        if (selectedCategoryType === "favorites") {
            return note.favorite === true
        }
        if (selectedCategoryType === "uncategorized") {
            return normalizedCategory(note.category).length === 0
        }
        if (selectedCategoryType === "category") {
            return normalizedCategory(note.category) === selectedCategoryValue
        }
        return true
    }

    function categoryStillExists() {
        if (selectedCategoryType === "all" || selectedCategoryType === "favorites" || selectedCategoryType === "uncategorized") {
            return true
        }

        for (var i = 0; i < categoriesModel.count; ++i) {
            var category = categoriesModel.get(i)
            if (category.type === selectedCategoryType && category.value === selectedCategoryValue && category.count > 0) {
                return true
            }
        }
        return false
    }

    function categoryLabel(type, value) {
        if (type === "favorites") {
            return i18n.tr("Favorites")
        }
        if (type === "uncategorized") {
            return i18n.tr("Uncategorized")
        }
        if (type === "category") {
            return displayCategory(value)
        }
        return i18n.tr("All notes")
    }

    function normalizedCategory(category) {
        return String(category || "").trim()
    }

    function displayCategory(category) {
        return String(category || "").replace(/\//g, " / ")
    }

    function applyNote(note, statusText) {
        noteTitle = note.title || ""
        noteCategory = note.category || ""
        noteContent = note.content || ""
        noteServerContent = note.serverContent || ""
        noteModifiedText = formatModified(note.modified)
        noteConflictEtag = note.conflictEtag || ""
        noteReadOnly = note.readonly === true
        noteDirty = note.dirty === true
        noteConflict = note.conflict === true
        noteIsNew = note.isNew === true
        noteFavorite = note.favorite === true
        noteLocalModifiedText = formatModified(note.localModified)
        noteStatusText = noteConflict
            ? i18n.tr("Potential conflict: local changes are not uploaded")
            : noteIsNew
            ? i18n.tr("New local draft. Upload to create it on the server.")
            : statusText
    }

    function applySyncedOpenNote(noteId, statusText) {
        if (pendingNoteId !== noteId) {
            return
        }

        var cachedNote = notesCache.loadNote(noteId)
        if (!cachedNote) {
            return
        }

        noteLoading = false
        pendingUpload = false
        pendingUploadNote = null
        applyNote(cachedNote, statusText)
    }

    function fail(message) {
        if (detailPrefetchRunning && noteFetchMode === "prefetch") {
            console.log("NextNotes NotesApi prefetch detail failed noteId=" + detailPrefetchCurrentNoteId)
            prefetchNextDetail()
            return
        }

        if (syncRunning) {
            var failedAutomaticSync = syncAutomatic
            if (syncUserName.length === 0 || syncSecret.length === 0 || syncServerUrl.length === 0) {
                syncFailedCount += Math.max(1, syncTotal - syncIndex)
                console.log("NextNotes NotesApi sync auth failed")
                finishSyncNow()
            } else if (syncPhase === "pull") {
                syncFailedCount += 1
                console.log("NextNotes NotesApi sync pull failed")
                finishSyncNow()
            } else {
                syncFailedCount += 1
                console.log("NextNotes NotesApi sync item failed noteId=" + (syncCurrentNote ? syncCurrentNote.noteId : 0))
                refreshNotesFromCache()
                uploadNextDirtyNote()
            }
            if (failedAutomaticSync && notesCache.loadLocalChanges().length > 0) {
                autoSyncRetryTimer.restart()
                connectionRecoveryTimer.restart()
            }
        } else if (pendingDelete) {
            pendingDelete = false
            pendingDeleteNoteId = 0
            noteLoading = false
            statusText = i18n.tr("Delete failed: %1").arg(message)
            if (pendingNoteId !== 0) {
                noteStatusText = statusText
            }
        } else if (pendingNoteId !== 0) {
            var wasUpload = pendingUpload
            var wasDelete = pendingDelete
            pendingUpload = false
            pendingUploadNote = null
            pendingDelete = false
            pendingDeleteNoteId = 0
            noteLoading = false
            noteStatusText = wasDelete
                ? i18n.tr("Delete failed: %1").arg(message)
                : wasUpload
                ? (noteIsNew ? i18n.tr("Create failed: %1").arg(message) : i18n.tr("Upload failed: %1").arg(message))
                : hasCachedNote
                ? i18n.tr("Showing cached note. Refresh failed: %1").arg(message)
                : message
        } else {
            loading = false
            statusText = hasCachedNotes
                ? i18n.tr("Showing saved notes. Could not refresh.")
                : i18n.tr("Could not load notes. Check the account and connection.")
            if (automaticServerCycleRunning || deferredAutomaticReason.length > 0) {
                autoSyncRetryTimer.restart()
                connectionRecoveryTimer.restart()
            }
            automaticServerCycleRunning = false
        }
    }

    function relativeTimeFromMs(timestampMs) {
        if (!timestampMs || timestampMs <= 0) {
            return i18n.tr("never")
        }

        var elapsedSeconds = Math.max(0, Math.floor((Date.now() - timestampMs) / 1000))
        if (elapsedSeconds < 60) {
            return i18n.tr("just now")
        }

        var elapsedMinutes = Math.floor(elapsedSeconds / 60)
        if (elapsedMinutes < 60) {
            return i18n.tr("%1m ago").arg(elapsedMinutes)
        }

        var elapsedHours = Math.floor(elapsedMinutes / 60)
        if (elapsedHours < 24) {
            return i18n.tr("%1h ago").arg(elapsedHours)
        }

        return i18n.tr("%1d ago").arg(Math.floor(elapsedHours / 24))
    }

    function formatModified(modified) {
        if (!modified || modified <= 0) {
            return ""
        }

        var date = new Date(modified * 1000)
        return date.toLocaleString(Qt.locale(), Locale.ShortFormat)
    }

    function formatRelativeModified(modified) {
        if (!modified || modified <= 0) {
            return i18n.tr("New")
        }

        var date = new Date(modified * 1000)
        var now = new Date()
        var diffSeconds = Math.max(0, Math.floor((now.getTime() - date.getTime()) / 1000))

        if (diffSeconds < 60) {
            return i18n.tr("now")
        }
        if (diffSeconds < 3600) {
            return i18n.tr("%1m").arg(Math.floor(diffSeconds / 60))
        }
        if (diffSeconds < 86400) {
            return i18n.tr("%1h").arg(Math.floor(diffSeconds / 3600))
        }
        if (date.getFullYear() === now.getFullYear()) {
            return date.toLocaleString(Qt.locale(), "d MMM")
        }
        return date.toLocaleString(Qt.locale(), "d MMM yyyy")
    }

    function effectiveModified(note) {
        var serverModified = note.modified || 0
        var localModified = note.localModified || 0
        if ((note.dirty === true || note.isNew === true) && localModified > serverModified) {
            return localModified
        }
        return serverModified
    }

    function sectionLabel(modified) {
        if (!modified || modified <= 0) {
            return i18n.tr("No date")
        }

        var noteDate = new Date(modified * 1000)
        var now = new Date()
        var todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        var noteStart = new Date(noteDate.getFullYear(), noteDate.getMonth(), noteDate.getDate())
        var diffDays = Math.floor((todayStart.getTime() - noteStart.getTime()) / 86400000)

        if (diffDays <= 0) {
            return i18n.tr("Today")
        }
        if (diffDays === 1) {
            return i18n.tr("Yesterday")
        }
        if (diffDays < 7) {
            return i18n.tr("Last week")
        }

        var label = noteDate.toLocaleString(Qt.locale(), "MMMM yyyy")
        return label.length > 0 ? label.charAt(0).toUpperCase() + label.slice(1) : ""
    }

    function avatarUrl(serverUrl, userName) {
        if (!serverUrl || !userName) {
            return ""
        }
        return String(serverUrl).replace(/\/+$/, "") + "/index.php/avatar/" + encodeURIComponent(userName) + "/64"
    }
}
