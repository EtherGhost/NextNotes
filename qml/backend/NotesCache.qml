import QtQuick 2.7
import QtQuick.LocalStorage 2.0 as Sql

Item {
    id: cache

    readonly property string statusClean: ""
    readonly property string statusEdited: "LOCAL_EDITED"
    readonly property string statusDeleted: "LOCAL_DELETED"

    property var database: null
    property string databaseName: "NextNotesSync"

    function setScope(scopeKey) {
        var scopedName = "NextNotesSync_" + safeScopeName(scopeKey)
        if (databaseName === scopedName) {
            return
        }

        database = null
        databaseName = scopedName
        console.log("NextNotes NotesCache scope changed")
    }

    function safeScopeName(scopeKey) {
        var value = String(scopeKey || "default")
        value = value.replace(/[^A-Za-z0-9_]/g, "_")
        if (value.length === 0) {
            return "default"
        }
        if (value.length > 96) {
            return value.slice(0, 96)
        }
        return value
    }

    function db() {
        if (database) {
            return database
        }

        database = Sql.LocalStorage.openDatabaseSync(databaseName, "1.0", "NextNotes sync cache", 8 * 1024 * 1024)
        database.transaction(function(tx) {
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS notes (" +
                "id INTEGER PRIMARY KEY, " +
                "title TEXT NOT NULL, " +
                "category TEXT DEFAULT '', " +
                "etag TEXT DEFAULT '', " +
                "modified INTEGER DEFAULT 0, " +
                "readonly INTEGER DEFAULT 0, " +
                "favorite INTEGER DEFAULT 0, " +
                "content TEXT DEFAULT '', " +
                "content_loaded INTEGER DEFAULT 0, " +
                "server_content TEXT DEFAULT '', " +
                "status TEXT DEFAULT '', " +
                "local_modified INTEGER DEFAULT 0, " +
                "conflict INTEGER DEFAULT 0, " +
                "conflict_etag TEXT DEFAULT '', " +
                "is_new INTEGER DEFAULT 0, " +
                "updated_at INTEGER NOT NULL)"
            )
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS sync_state (" +
                "id INTEGER PRIMARY KEY CHECK(id = 1), " +
                "etag TEXT DEFAULT '', " +
                "last_modified TEXT DEFAULT '', " +
                "last_sync INTEGER DEFAULT 0)"
            )
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_notes_modified ON notes(modified DESC)")
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_notes_status ON notes(status, local_modified)")
        })
        return database
    }

    function loadNotes() {
        var notes = []
        db().readTransaction(function(tx) {
            var result = tx.executeSql(
                "SELECT id, title, category, etag, modified, readonly, favorite, content, content_loaded, " +
                "server_content, status, local_modified, conflict, conflict_etag, is_new FROM notes " +
                "WHERE status != ? ORDER BY status DESC, favorite DESC, modified DESC, title COLLATE NOCASE ASC",
                [statusDeleted]
            )
            for (var i = 0; i < result.rows.length; ++i) {
                notes.push(rowToNote(result.rows.item(i), false))
            }
        })
        console.log("NextNotes NotesCache loadNotes count=" + notes.length)
        return notes
    }

    function loadNote(noteId) {
        var note = null
        db().readTransaction(function(tx) {
            var result = tx.executeSql(
                "SELECT id, title, category, etag, modified, readonly, favorite, content, content_loaded, " +
                "server_content, status, local_modified, conflict, conflict_etag, is_new FROM notes WHERE id = ?",
                [noteId]
            )
            if (result.rows.length > 0) {
                note = rowToNote(result.rows.item(0), true)
            }
        })
        console.log("NextNotes NotesCache loadNote noteId=" + noteId + " hit=" + (note ? "true" : "false") + " contentLoaded=" + (note && note.contentLoaded ? "true" : "false") + " status=" + (note ? note.localStatus : "missing") + " conflict=" + (note && note.conflict ? "true" : "false"))
        return note
    }

    function loadLocalChanges() {
        var notes = []
        db().readTransaction(function(tx) {
            var result = tx.executeSql(
                "SELECT id, title, category, etag, modified, readonly, favorite, content, content_loaded, " +
                "server_content, status, local_modified, conflict, conflict_etag, is_new FROM notes " +
                "WHERE status IN (?, ?) ORDER BY is_new DESC, local_modified ASC, modified ASC, title COLLATE NOCASE ASC",
                [statusEdited, statusDeleted]
            )
            for (var i = 0; i < result.rows.length; ++i) {
                notes.push(rowToNote(result.rows.item(i), true))
            }
        })
        console.log("NextNotes NotesCache loadLocalChanges count=" + notes.length)
        return notes
    }

    function loadDirtyNotes() {
        return loadLocalChanges()
    }

    function loadNotesMissingContent(maxCount) {
        var noteIds = []
        db().readTransaction(function(tx) {
            var result = tx.executeSql(
                "SELECT id FROM notes WHERE id > 0 AND content_loaded = 0 AND status != ? " +
                "ORDER BY modified DESC, title COLLATE NOCASE ASC LIMIT ?",
                [statusDeleted, maxCount || 100]
            )
            for (var i = 0; i < result.rows.length; ++i) {
                noteIds.push(Number(result.rows.item(i).id))
            }
        })
        console.log("NextNotes NotesCache loadNotesMissingContent count=" + noteIds.length)
        return noteIds
    }

    function rowToNote(row, includeContent) {
        var contentLoaded = Number(row.content_loaded || 0) === 1
        var localStatus = row.status || statusClean
        var note = {
            "noteId": Number(row.id),
            "title": row.title,
            "category": row.category || "",
            "etag": row.etag || "",
            "modified": Number(row.modified || 0),
            "readonly": Number(row.readonly || 0) === 1,
            "favorite": Number(row.favorite || 0) === 1,
            "localStatus": localStatus,
            "dirty": localStatus === statusEdited,
            "deleted": localStatus === statusDeleted,
            "localModified": Number(row.local_modified || 0),
            "conflict": Number(row.conflict || 0) === 1,
            "isNew": Number(row.is_new || 0) === 1,
            "preview": previewText(contentLoaded ? (row.content || "") : ""),
            "searchContent": contentLoaded ? (row.content || "") : ""
        }

        if (includeContent) {
            note.content = contentLoaded ? (row.content || "") : ""
            note.contentLoaded = contentLoaded
            note.serverContent = row.server_content || ""
            note.conflictEtag = row.conflict_etag || ""
        }

        return note
    }

    function previewText(content) {
        if (!content) {
            return ""
        }

        var lines = String(content).split(/\r?\n/)
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim()
            if (line.length > 0) {
                return line.length > 120 ? line.slice(0, 117) + "..." : line
            }
        }
        return ""
    }

    function replaceServerNotes(notes, responseEtag, responseLastModified) {
        var now = Math.floor(Date.now() / 1000)
        var serverIds = {}
        db().transaction(function(tx) {
            for (var i = 0; i < notes.length; ++i) {
                var note = notes[i]
                serverIds[String(note.noteId)] = true
                upsertServerMetadata(tx, note, now)
            }

            var result = tx.executeSql("SELECT id, status, is_new FROM notes")
            for (var j = 0; j < result.rows.length; ++j) {
                var row = result.rows.item(j)
                var id = Number(row.id)
                var status = row.status || statusClean
                var isNew = Number(row.is_new || 0) === 1
                if (id > 0 && !serverIds[String(id)] && status === statusClean && !isNew) {
                    tx.executeSql("DELETE FROM notes WHERE id = ?", [id])
                    console.log("NextNotes NotesCache reconciled server-deleted noteId=" + id)
                }
            }

            tx.executeSql(
                "INSERT OR REPLACE INTO sync_state (id, etag, last_modified, last_sync) VALUES (1, ?, ?, ?)",
                [responseEtag || "", responseLastModified || "", now]
            )
        })
        console.log("NextNotes NotesCache replaceServerNotes count=" + notes.length + " etagAvailable=" + (responseEtag ? "true" : "false"))
    }

    function saveNotes(notes) {
        replaceServerNotes(notes, "", "")
    }

    function countCachedFavorites() {
        var count = 0
        db().readTransaction(function(tx) {
            var result = tx.executeSql("SELECT COUNT(*) AS favorite_count FROM notes WHERE status != ? AND favorite = 1", [statusDeleted])
            if (result.rows.length > 0) {
                count = Number(result.rows.item(0).favorite_count || 0)
            }
        })
        return count
    }

    function upsertServerMetadata(tx, note, now) {
        var existingResult = tx.executeSql(
            "SELECT title, category, favorite, etag, modified, status, conflict FROM notes WHERE id = ?",
            [note.noteId]
        )
        var existing = existingResult.rows.length > 0 ? existingResult.rows.item(0) : null
        var existingStatus = existing ? (existing.status || statusClean) : statusClean
        var existingDirty = existingStatus === statusEdited
        var existingConflict = existing && Number(existing.conflict || 0) === 1
        var existingEtag = existing ? (existing.etag || "") : ""
        var serverEtag = note.etag || ""
        var etagChangedOnServer = existingDirty && existingEtag.length > 0 && serverEtag.length > 0 && existingEtag !== serverEtag
        var conflict = existingConflict || etagChangedOnServer
        var preservedTitle = existingDirty ? (existing.title || note.title) : note.title
        var preservedCategory = existingDirty ? (existing.category || "") : (note.category || "")
        var preservedFavorite = existingDirty || note.favoriteKnown === false
            ? Number(existing && existing.favorite || 0)
            : (note.favorite ? 1 : 0)
        var effectiveModified = Math.max(Number(note.modified || 0), existing ? Number(existing.modified || 0) : 0)

        tx.executeSql(
            "INSERT OR REPLACE INTO notes " +
            "(id, title, category, etag, modified, readonly, favorite, content, content_loaded, server_content, status, local_modified, conflict, conflict_etag, is_new, updated_at) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, " +
            "COALESCE((SELECT content FROM notes WHERE id = ?), ''), " +
            "COALESCE((SELECT content_loaded FROM notes WHERE id = ?), 0), " +
            "COALESCE((SELECT server_content FROM notes WHERE id = ?), ''), " +
            "COALESCE((SELECT status FROM notes WHERE id = ?), ''), " +
            "COALESCE((SELECT local_modified FROM notes WHERE id = ?), 0), " +
            "?, ?, 0, ?)",
            [
                note.noteId,
                preservedTitle,
                preservedCategory,
                existingDirty ? existingEtag : serverEtag,
                effectiveModified,
                note.readonly ? 1 : 0,
                preservedFavorite,
                note.noteId,
                note.noteId,
                note.noteId,
                note.noteId,
                note.noteId,
                conflict ? 1 : 0,
                conflict ? serverEtag : "",
                now
            ]
        )
    }

    function saveNote(note) {
        var now = Math.floor(Date.now() / 1000)
        db().transaction(function(tx) {
            var existingResult = tx.executeSql(
                "SELECT etag, modified, favorite, server_content, status, conflict, is_new FROM notes WHERE id = ?",
                [note.noteId]
            )
            var existing = existingResult.rows.length > 0 ? existingResult.rows.item(0) : null
            var existingStatus = existing ? (existing.status || statusClean) : statusClean
            var existingDirty = existingStatus === statusEdited
            var existingNew = existing && Number(existing.is_new || 0) === 1
            var serverContent = note.content || ""
            var serverEtag = note.etag || ""
            var effectiveModified = Math.max(Number(note.modified || 0), existing ? Number(existing.modified || 0) : 0)

            if (existingDirty && !existingNew) {
                var existingServerContent = existing.server_content || ""
                var existingEtag = existing.etag || ""
                var contentChangedOnServer = existingServerContent.length > 0 && existingServerContent !== serverContent
                var etagChangedOnServer = existingEtag.length > 0 && serverEtag.length > 0 && existingEtag !== serverEtag
                var conflict = Number(existing.conflict || 0) === 1 || contentChangedOnServer || etagChangedOnServer

                tx.executeSql(
                    "UPDATE notes SET modified = ?, readonly = ?, server_content = ?, conflict = ?, conflict_etag = ?, updated_at = ? WHERE id = ?",
                    [
                        effectiveModified,
                        note.readonly ? 1 : 0,
                        serverContent,
                        conflict ? 1 : 0,
                        conflict ? serverEtag : "",
                        now,
                        note.noteId
                    ]
                )
                console.log("NextNotes NotesCache saveNote preserved local edit noteId=" + note.noteId + " conflict=" + (conflict ? "true" : "false"))
                return
            }

            tx.executeSql(
                "INSERT OR REPLACE INTO notes " +
                "(id, title, category, etag, modified, readonly, favorite, content, content_loaded, server_content, status, local_modified, conflict, conflict_etag, is_new, updated_at) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, '', 0, 0, '', 0, ?)",
                [
                    note.noteId,
                    note.title,
                    note.category || "",
                    serverEtag,
                    effectiveModified,
                    note.readonly ? 1 : 0,
                    note.favoriteKnown === false && existing ? Number(existing.favorite || 0) : (note.favorite ? 1 : 0),
                    serverContent,
                    serverContent,
                    now
                ]
            )
        })
        console.log("NextNotes NotesCache saveNote noteId=" + note.noteId + " hasContent=" + (note.content && note.content.length > 0 ? "true" : "false"))
    }

    function createLocalNote(category, favorite) {
        var now = Math.floor(Date.now() / 1000)
        var noteId = -1
        var noteCategory = category ? String(category).trim() : ""
        db().transaction(function(tx) {
            var result = tx.executeSql("SELECT MIN(id) AS min_id FROM notes")
            var minId = result.rows.length > 0 ? Number(result.rows.item(0).min_id || 0) : 0
            noteId = minId < 0 ? minId - 1 : -1
            tx.executeSql(
                "INSERT INTO notes " +
                "(id, title, category, etag, modified, readonly, favorite, content, content_loaded, server_content, status, local_modified, conflict, conflict_etag, is_new, updated_at) " +
                "VALUES (?, ?, ?, '', 0, 0, ?, '', 1, '', ?, ?, 0, '', 1, ?)",
                [noteId, i18n.tr("Untitled note"), noteCategory, favorite ? 1 : 0, statusEdited, now, now]
            )
        })
        console.log("NextNotes NotesCache createLocalNote noteId=" + noteId)
        return noteId
    }

    function saveLocalDraft(noteId, title, content, category, favorite) {
        var now = Math.floor(Date.now() / 1000)
        var noteTitle = title && String(title).trim().length > 0 ? String(title).trim() : i18n.tr("Untitled note")
        var noteCategory = category ? String(category).trim() : ""
        db().transaction(function(tx) {
            tx.executeSql(
                "UPDATE notes SET title = ?, category = ?, favorite = ?, content = ?, content_loaded = 1, status = ?, local_modified = ?, updated_at = ? WHERE id = ?",
                [noteTitle, noteCategory, favorite ? 1 : 0, content || "", statusEdited, now, now, noteId]
            )
        })
        console.log("NextNotes NotesCache saveLocalDraft noteId=" + noteId)
    }

    function setFavoriteDraft(noteId, favorite) {
        var now = Math.floor(Date.now() / 1000)
        db().transaction(function(tx) {
            tx.executeSql(
                "UPDATE notes SET favorite = ?, status = ?, local_modified = ?, updated_at = ? WHERE id = ?",
                [favorite ? 1 : 0, statusEdited, now, now, noteId]
            )
        })
        console.log("NextNotes NotesCache setFavoriteDraft noteId=" + noteId + " favorite=" + (favorite ? "true" : "false"))
    }

    function markDeleted(noteId) {
        var now = Math.floor(Date.now() / 1000)
        db().transaction(function(tx) {
            tx.executeSql(
                "UPDATE notes SET status = ?, local_modified = ?, conflict = 0, conflict_etag = '', updated_at = ? WHERE id = ?",
                [statusDeleted, now, now, noteId]
            )
        })
        console.log("NextNotes NotesCache markDeleted noteId=" + noteId)
    }

    function saveUploadedNote(note) {
        var now = Math.floor(Date.now() / 1000)
        var serverContent = note.content || ""
        db().transaction(function(tx) {
            var existingResult = tx.executeSql("SELECT content, content_loaded, favorite, local_modified FROM notes WHERE id = ?", [note.noteId])
            var existing = existingResult.rows.length > 0 ? existingResult.rows.item(0) : null
            if (serverContent.length === 0 && existing && Number(existing.content_loaded || 0) === 1) {
                serverContent = existing.content || ""
            }
            var effectiveModified = Math.max(Number(note.modified || 0), existing ? Number(existing.local_modified || 0) : 0)

            tx.executeSql(
                "INSERT OR REPLACE INTO notes " +
                "(id, title, category, etag, modified, readonly, favorite, content, content_loaded, server_content, status, local_modified, conflict, conflict_etag, is_new, updated_at) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, '', 0, 0, '', 0, ?)",
                [
                    note.noteId,
                    note.title,
                    note.category || "",
                    note.etag || "",
                    effectiveModified,
                    note.readonly ? 1 : 0,
                    note.favoriteKnown === false && existing ? Number(existing.favorite || 0) : (note.favorite ? 1 : 0),
                    serverContent,
                    serverContent,
                    now
                ]
            )
        })
        console.log("NextNotes NotesCache saveUploadedNote noteId=" + note.noteId + " status=clean conflict=false hasContent=" + (serverContent.length > 0 ? "true" : "false"))
    }

    function saveCreatedNote(localNoteId, serverNote) {
        var now = Math.floor(Date.now() / 1000)
        var serverContent = serverNote.content || ""
        db().transaction(function(tx) {
            var localResult = tx.executeSql(
                "SELECT title, category, favorite, content, content_loaded, local_modified FROM notes WHERE id = ?",
                [localNoteId]
            )
            var local = localResult.rows.length > 0 ? localResult.rows.item(0) : null
            var localContentLoaded = local && Number(local.content_loaded || 0) === 1
            if (serverContent.length === 0 && localContentLoaded) {
                serverContent = local.content || ""
            }
            var serverTitle = serverNote.title || ""
            var localTitle = local ? (local.title || "") : ""
            if ((serverTitle.length === 0 || serverTitle === i18n.tr("Untitled note")) && localTitle.length > 0) {
                serverTitle = localTitle
            }
            var serverCategory = serverNote.category || ""
            if (serverCategory.length === 0 && local && local.category) {
                serverCategory = local.category
            }
            var serverFavorite = serverNote.favoriteKnown === false && local
                ? Number(local.favorite || 0) === 1
                : serverNote.favorite === true
            var effectiveModified = Math.max(Number(serverNote.modified || 0), local ? Number(local.local_modified || 0) : 0)

            tx.executeSql("DELETE FROM notes WHERE id = ?", [localNoteId])
            tx.executeSql(
                "INSERT OR REPLACE INTO notes " +
                "(id, title, category, etag, modified, readonly, favorite, content, content_loaded, server_content, status, local_modified, conflict, conflict_etag, is_new, updated_at) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, '', 0, 0, '', 0, ?)",
                [
                    serverNote.noteId,
                    serverTitle,
                    serverCategory,
                    serverNote.etag || "",
                    effectiveModified,
                    serverNote.readonly ? 1 : 0,
                    serverFavorite ? 1 : 0,
                    serverContent,
                    serverContent,
                    now
                ]
            )
        })
        console.log("NextNotes NotesCache saveCreatedNote localNoteId=" + localNoteId + " serverNoteId=" + serverNote.noteId + " hasContent=" + (serverContent.length > 0 ? "true" : "false"))
    }

    function deleteNote(noteId) {
        db().transaction(function(tx) {
            tx.executeSql("DELETE FROM notes WHERE id = ?", [noteId])
        })
        console.log("NextNotes NotesCache deleteNote noteId=" + noteId)
    }

    function markConflict(noteId, serverNote) {
        var now = Math.floor(Date.now() / 1000)
        var conflictEtag = serverNote && serverNote.etag ? serverNote.etag : ""
        db().transaction(function(tx) {
            if (serverNote) {
                tx.executeSql(
                    "UPDATE notes SET modified = ?, readonly = ?, server_content = ?, status = ?, conflict = 1, conflict_etag = ?, updated_at = ? WHERE id = ?",
                    [
                        serverNote.modified || 0,
                        serverNote.readonly ? 1 : 0,
                        serverNote.content || "",
                        statusEdited,
                        conflictEtag,
                        now,
                        noteId
                    ]
                )
            } else {
                tx.executeSql(
                    "UPDATE notes SET status = ?, conflict = 1, conflict_etag = ?, updated_at = ? WHERE id = ?",
                    [statusEdited, conflictEtag, now, noteId]
                )
            }
        })
        console.log("NextNotes NotesCache markConflict noteId=" + noteId + " serverNoteAvailable=" + (serverNote ? "true" : "false") + " conflictEtagAvailable=" + (conflictEtag.length > 0 ? "true" : "false"))
    }

    function keepLocalDraftForUpload(noteId) {
        var now = Math.floor(Date.now() / 1000)
        db().transaction(function(tx) {
            tx.executeSql(
                "UPDATE notes SET etag = CASE WHEN conflict_etag IS NOT NULL AND conflict_etag != '' THEN conflict_etag ELSE etag END, " +
                "conflict = 0, conflict_etag = '', updated_at = ? WHERE id = ?",
                [now, noteId]
            )
        })
        console.log("NextNotes NotesCache keepLocalDraftForUpload noteId=" + noteId)
    }

    function discardLocalDraft(noteId) {
        var now = Math.floor(Date.now() / 1000)
        db().transaction(function(tx) {
            tx.executeSql(
                "UPDATE notes SET content = COALESCE(server_content, content), content_loaded = 1, " +
                "etag = CASE WHEN conflict_etag IS NOT NULL AND conflict_etag != '' THEN conflict_etag ELSE etag END, " +
                "status = '', local_modified = 0, conflict = 0, conflict_etag = '', is_new = 0, updated_at = ? WHERE id = ?",
                [now, noteId]
            )
        })
        console.log("NextNotes NotesCache discardLocalDraft noteId=" + noteId)
    }
}
