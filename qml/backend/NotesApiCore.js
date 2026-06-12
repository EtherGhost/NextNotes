.pragma library

function normalizeServerUrl(value) {
    if (!value) {
        return ""
    }

    var url = String(value).trim()
    if (url.length === 0) {
        return ""
    }
    while (url.length > 0 && url.charAt(url.length - 1) === "/") {
        url = url.slice(0, -1)
    }
    if (url.indexOf("http://") === 0 || url.indexOf("https://") === 0) {
        return url
    }
    return "https://" + url
}

function notesUrl(serverUrl) {
    return normalizeServerUrl(serverUrl) + "/index.php/apps/notes/api/v1/notes"
}

function noteUrl(serverUrl, noteId) {
    return notesUrl(serverUrl) + "/" + encodeURIComponent(noteId)
}

function notePayload(note) {
    return {
        "title": note && note.title ? String(note.title) : "",
        "category": note && note.category ? String(note.category) : "",
        "favorite": note && note.favorite === true,
        "content": note && note.content ? String(note.content) : ""
    }
}

function formatEtagHeader(etag) {
    var value = String(etag || "")
    if (value.indexOf("\"") === 0 || value.indexOf("W/\"") === 0) {
        return value
    }
    return "\"" + value + "\""
}

function parseNotesJson(responseText, fallbackTitle) {
    var parsed
    try {
        parsed = JSON.parse(responseText)
    } catch (error) {
        return { "ok": false, "error": "parse-error" }
    }

    if (!parsed || typeof parsed.length !== "number") {
        return { "ok": false, "error": "response-not-array" }
    }

    var notes = []
    for (var i = 0; i < parsed.length; ++i) {
        var note = parseNoteObject(parsed[i], fallbackTitle)
        if (note && note.noteId > 0) {
            notes.push({
                "noteId": note.noteId,
                "title": note.title,
                "category": note.category,
                "etag": note.etag,
                "modified": note.modified,
                "readonly": note.readonly,
                "favorite": note.favorite
            })
        }
    }

    return { "ok": true, "notes": notes }
}

function parseNoteJson(responseText, fallbackTitle) {
    var parsed
    try {
        parsed = JSON.parse(responseText)
    } catch (error) {
        return { "ok": false, "error": "parse-error" }
    }

    var note = parseNoteObject(parsed, fallbackTitle)
    if (!note || note.noteId === 0) {
        return { "ok": false, "error": "response-missing-id" }
    }

    return { "ok": true, "note": note }
}

function parseNoteObject(parsed, fallbackTitle) {
    if (!parsed || parsed.id === undefined || parsed.id === null) {
        return null
    }

    return {
        "noteId": Number(parsed.id),
        "title": parsed.title !== undefined && parsed.title !== null && String(parsed.title).length > 0
            ? String(parsed.title)
            : String(fallbackTitle || "Untitled note"),
        "category": parsed.category !== undefined && parsed.category !== null ? String(parsed.category) : "",
        "etag": parsed.etag !== undefined && parsed.etag !== null ? String(parsed.etag) : "",
        "content": parsed.content !== undefined && parsed.content !== null ? String(parsed.content) : "",
        "modified": parsed.modified !== undefined && parsed.modified !== null ? Number(parsed.modified) : 0,
        "readonly": parsed.readonly === true,
        "favorite": parsed.favorite === true
    }
}

function hasValue(value) {
    return value !== undefined && value !== null && String(value).length > 0 ? "true" : "false"
}
