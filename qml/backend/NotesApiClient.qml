import QtQuick 2.7
import "NotesApiCore.js" as NotesApiCore

Item {
    id: client

    signal notesLoaded(var notes, string responseEtag, string responseLastModified)
    signal noteLoaded(var note)
    signal noteUploaded(var note)
    signal noteCreated(int localNoteId, var note)
    signal noteDeleted(int noteId)
    signal uploadConflict(int noteId, var serverNote, string message)
    signal failed(string message)

    function fetchNotes(serverUrl, userName, secret) {
        var url = NotesApiCore.notesUrl(serverUrl)
        var request = new XMLHttpRequest()

        console.log("NextNotes NotesApi GET /notes requesting serverUrlConfigured=" + hasValue(serverUrl))

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return
            }

            if (request.status < 200 || request.status >= 300) {
                console.log("NextNotes NotesApi GET /notes error status=" + request.status)
                client.failed(i18n.tr("Notes API request failed with HTTP %1.").arg(request.status))
                return
            }

            parseNotesResponse(request.responseText, request.getResponseHeader("ETag") || "", request.getResponseHeader("Last-Modified") || "")
        }

        request.open("GET", url)
        request.setRequestHeader("Authorization", "Basic " + Qt.btoa(userName + ":" + secret))
        request.setRequestHeader("Accept", "application/json")
        request.send()
    }

    function fetchNote(serverUrl, userName, secret, noteId) {
        var url = NotesApiCore.noteUrl(serverUrl, noteId)
        var request = new XMLHttpRequest()

        console.log("NextNotes NotesApi GET /notes/{id} requesting noteId=" + noteId + " serverUrlConfigured=" + hasValue(serverUrl))

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return
            }

            if (request.status < 200 || request.status >= 300) {
                console.log("NextNotes NotesApi GET /notes/{id} error noteId=" + noteId + " status=" + request.status)
                client.failed(i18n.tr("Note API request failed with HTTP %1.").arg(request.status))
                return
            }

            parseNoteResponse(request.responseText, noteId)
        }

        request.open("GET", url)
        request.setRequestHeader("Authorization", "Basic " + Qt.btoa(userName + ":" + secret))
        request.setRequestHeader("Accept", "application/json")
        request.send()
    }

    function uploadNote(serverUrl, userName, secret, note) {
        var url = NotesApiCore.noteUrl(serverUrl, note.noteId)
        var request = new XMLHttpRequest()
        var etag = note.etag || ""

        console.log(
            "NextNotes NotesApi PUT /notes/{id} requesting"
            + " noteId=" + note.noteId
            + " serverUrlConfigured=" + hasValue(serverUrl)
            + " etagAvailable=" + hasValue(etag)
            + " hasContent=" + hasValue(note.content)
        )

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return
            }

            if (request.status === 412) {
                console.log("NextNotes NotesApi PUT /notes/{id} conflict noteId=" + note.noteId + " status=412")
                fetchConflictNote(serverUrl, userName, secret, note.noteId, parseConflictNote(request.responseText, note.noteId))
                return
            }

            if (request.status === 404 || request.status === 410) {
                console.log("NextNotes NotesApi PUT /notes/{id} missing on server noteId=" + note.noteId + " status=" + request.status + " recreating=true")
                createNote(serverUrl, userName, secret, note)
                return
            }

            if (request.status < 200 || request.status >= 300) {
                console.log("NextNotes NotesApi PUT /notes/{id} error noteId=" + note.noteId + " status=" + request.status)
                client.failed(i18n.tr("Note upload failed with HTTP %1.").arg(request.status))
                return
            }

            parseUploadResponse(request.responseText, note.noteId)
        }

        request.open("PUT", url)
        request.setRequestHeader("Authorization", "Basic " + Qt.btoa(userName + ":" + secret))
        request.setRequestHeader("Accept", "application/json")
        request.setRequestHeader("Content-Type", "application/json")
        if (etag.length > 0) {
            request.setRequestHeader("If-Match", NotesApiCore.formatEtagHeader(etag))
        }
        request.send(JSON.stringify(NotesApiCore.notePayload(note)))
    }

    function createNote(serverUrl, userName, secret, note) {
        var url = NotesApiCore.notesUrl(serverUrl)
        var request = new XMLHttpRequest()
        var localNoteId = note.noteId

        console.log(
            "NextNotes NotesApi POST /notes requesting"
            + " localNoteId=" + localNoteId
            + " serverUrlConfigured=" + hasValue(serverUrl)
            + " hasTitle=" + hasValue(note.title)
            + " hasContent=" + hasValue(note.content)
        )

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return
            }

            if (request.status < 200 || request.status >= 300) {
                console.log("NextNotes NotesApi POST /notes error localNoteId=" + localNoteId + " status=" + request.status)
                client.failed(i18n.tr("Create note failed with HTTP %1.").arg(request.status))
                return
            }

            parseCreateResponse(request.responseText, localNoteId)
        }

        request.open("POST", url)
        request.setRequestHeader("Authorization", "Basic " + Qt.btoa(userName + ":" + secret))
        request.setRequestHeader("Accept", "application/json")
        request.setRequestHeader("Content-Type", "application/json")
        request.send(JSON.stringify(NotesApiCore.notePayload(note)))
    }

    function deleteNote(serverUrl, userName, secret, noteId) {
        var url = NotesApiCore.noteUrl(serverUrl, noteId)
        var request = new XMLHttpRequest()

        console.log(
            "NextNotes NotesApi DELETE /notes/{id} requesting"
            + " noteId=" + noteId
            + " serverUrlConfigured=" + hasValue(serverUrl)
        )

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return
            }

            if (request.status === 404 || request.status === 410) {
                console.log("NextNotes NotesApi DELETE /notes/{id} already gone noteId=" + noteId + " status=" + request.status)
                client.noteDeleted(noteId)
                return
            }

            if (request.status < 200 || request.status >= 300) {
                console.log("NextNotes NotesApi DELETE /notes/{id} error noteId=" + noteId + " status=" + request.status)
                client.failed(i18n.tr("Delete note failed with HTTP %1.").arg(request.status))
                return
            }

            console.log("NextNotes NotesApi DELETE /notes/{id} success noteId=" + noteId + " status=" + request.status)
            client.noteDeleted(noteId)
        }

        request.open("DELETE", url)
        request.setRequestHeader("Authorization", "Basic " + Qt.btoa(userName + ":" + secret))
        request.setRequestHeader("Accept", "application/json")
        request.send()
    }

    function fetchConflictNote(serverUrl, userName, secret, noteId, fallbackNote) {
        var url = NotesApiCore.noteUrl(serverUrl, noteId)
        var request = new XMLHttpRequest()

        console.log("NextNotes NotesApi GET conflict server note requesting noteId=" + noteId + " fallbackAvailable=" + (fallbackNote ? "true" : "false"))

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return
            }

            if (request.status < 200 || request.status >= 300) {
                console.log("NextNotes NotesApi GET conflict server note error noteId=" + noteId + " status=" + request.status)
                client.uploadConflict(noteId, fallbackNote, i18n.tr("Server version changed. Local draft was not uploaded."))
                return
            }

            var serverNote = parseConflictNote(request.responseText, noteId)
            client.uploadConflict(noteId, serverNote || fallbackNote, i18n.tr("Server version changed. Local draft was not uploaded."))
        }

        request.open("GET", url)
        request.setRequestHeader("Authorization", "Basic " + Qt.btoa(userName + ":" + secret))
        request.setRequestHeader("Accept", "application/json")
        request.send()
    }

    function parseNotesResponse(responseText, responseEtag, responseLastModified) {
        var result = NotesApiCore.parseNotesJson(responseText, i18n.tr("Untitled note"))
        if (!result.ok) {
            console.log("NextNotes NotesApi parse error message=" + result.error)
            failed(i18n.tr("Could not parse Notes API response."))
            return
        }

        if (!result.notes) {
            console.log("NextNotes NotesApi parse error message=response-not-array")
            failed(i18n.tr("Notes API returned an unexpected response format."))
            return
        }

        console.log("NextNotes NotesApi GET /notes success count=" + result.notes.length)
        notesLoaded(result.notes, responseEtag || "", responseLastModified || "")
    }

    function parseNoteResponse(responseText, requestedNoteId) {
        var result = NotesApiCore.parseNoteJson(responseText, i18n.tr("Untitled note"))
        if (!result.ok) {
            console.log("NextNotes NotesApi parse detail error noteId=" + requestedNoteId + " message=" + result.error)
            failed(i18n.tr("Could not parse note response."))
            return
        }

        var note = result.note

        console.log(
            "NextNotes NotesApi GET /notes/{id} success"
            + " noteId=" + requestedNoteId
            + " hasTitle=" + hasValue(note.title)
            + " hasContent=" + hasValue(note.content)
            + " modifiedAvailable=" + (note.modified > 0 ? "true" : "false")
            + " readonly=" + note.readonly
        )

        noteLoaded(note)
    }

    function parseUploadResponse(responseText, requestedNoteId) {
        var note = parseNoteObject(responseText, requestedNoteId, "upload")
        if (!note) {
            return
        }

        console.log(
            "NextNotes NotesApi PUT /notes/{id} success"
            + " noteId=" + requestedNoteId
            + " hasTitle=" + hasValue(note.title)
            + " hasContent=" + hasValue(note.content)
            + " modifiedAvailable=" + (note.modified > 0 ? "true" : "false")
            + " readonly=" + note.readonly
        )
        noteUploaded(note)
    }

    function parseCreateResponse(responseText, localNoteId) {
        var note = parseNoteObject(responseText, localNoteId, "create")
        if (!note) {
            return
        }

        console.log(
            "NextNotes NotesApi POST /notes success"
            + " localNoteId=" + localNoteId
            + " serverNoteId=" + note.noteId
            + " hasTitle=" + hasValue(note.title)
            + " hasContent=" + hasValue(note.content)
            + " modifiedAvailable=" + (note.modified > 0 ? "true" : "false")
        )
        noteCreated(localNoteId, note)
    }

    function parseConflictNote(responseText, requestedNoteId) {
        if (!responseText || responseText.length === 0) {
            return null
        }

        var note = parseNoteObject(responseText, requestedNoteId, "conflict")
        if (note) {
            console.log(
                "NextNotes NotesApi PUT /notes/{id} conflict body"
                + " noteId=" + requestedNoteId
                + " hasTitle=" + hasValue(note.title)
                + " hasContent=" + hasValue(note.content)
                + " etagAvailable=" + hasValue(note.etag)
            )
        }
        return note
    }

    function parseNoteObject(responseText, requestedNoteId, context) {
        var result = NotesApiCore.parseNoteJson(responseText, i18n.tr("Untitled note"))
        if (!result.ok) {
            console.log("NextNotes NotesApi parse " + context + " error noteId=" + requestedNoteId + " message=" + result.error)
            failed(context === "upload" || context === "create" ? i18n.tr("Could not parse upload response.") : i18n.tr("Could not parse note response."))
            return null
        }

        return result.note
    }

    function normalizeServerUrl(value) {
        return NotesApiCore.normalizeServerUrl(value)
    }

    function hasValue(value) {
        return NotesApiCore.hasValue(value)
    }
}
