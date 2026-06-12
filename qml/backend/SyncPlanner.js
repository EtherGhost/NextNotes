.pragma library

function planSync(localChanges) {
    var queue = []
    var conflictNoteIds = []
    var skippedCount = 0

    for (var i = 0; i < localChanges.length; ++i) {
        var note = localChanges[i] || {}
        if (note.deleted === true) {
            queue.push(note)
            continue
        }

        if (note.contentLoaded !== true) {
            skippedCount += 1
            continue
        }

        if (note.conflict === true) {
            conflictNoteIds.push(Number(note.noteId))
            continue
        }

        if (note.isNew !== true && (!note.etag || String(note.etag).length === 0)) {
            conflictNoteIds.push(Number(note.noteId))
            continue
        }

        queue.push(note)
    }

    return {
        "queue": queue,
        "skippedCount": skippedCount,
        "conflictNoteIds": conflictNoteIds,
        "conflictCount": conflictNoteIds.length
    }
}
