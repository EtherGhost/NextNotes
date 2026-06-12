import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "../backend"

Page {
    id: page

    property int noteId: 0
    property string initialTitle: ""
    property bool applyingControllerContent: false
    property bool favoriteSelected: false
    property bool noteMenuOpen: false
    property bool noteSearchVisible: false
    property string draftTitle: ""
    property bool draftTitleInitialized: false
    property string draftCategory: ""
    property bool draftCategoryInitialized: false
    property string editTitleText: ""
    property string editCategoryText: ""
    property bool editingTitle: false
    property bool editingCategory: false
    property string conflictPreviewChoice: "local"
    property string conflictLocalContent: ""
    property var notesController
    readonly property real oskOverlap: Qt.inputMethod.visible && Qt.inputMethod.keyboardRectangle.height > 0
        ? Math.max(0, page.height - Qt.inputMethod.keyboardRectangle.y)
        : 0

    header: PageHeader {
        id: header
        title: ""

        contents: RowLayout {
            anchors {
                fill: parent
                leftMargin: units.gu(1)
                rightMargin: units.gu(1)
            }
            spacing: units.gu(0.75)

            Label {
                Layout.fillWidth: true
                text: page.displayTitle()
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Rectangle {
                Layout.preferredWidth: units.gu(5)
                Layout.preferredHeight: units.gu(5)
                radius: units.gu(2.5)
                color: page.noteSearchVisible ? "#2c7fb8" : "transparent"
                border.width: 1
                border.color: page.noteSearchVisible ? "#2c7fb8" : "#7a7a7a"

                Label {
                    anchors.centerIn: parent
                    text: "\u2315"
                    color: page.noteSearchVisible ? "white" : theme.palette.normal.backgroundText
                    font.pixelSize: units.gu(2.4)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        page.noteSearchVisible = !page.noteSearchVisible
                        if (page.noteSearchVisible) {
                            noteSearchField.forceActiveFocus()
                        } else {
                            noteSearchField.text = ""
                            contentEditor.deselect()
                            contentEditor.forceActiveFocus()
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: units.gu(5)
                Layout.preferredHeight: units.gu(5)
                radius: units.gu(2.5)
                color: "transparent"
                border.width: 1
                border.color: "#7a7a7a"

                Label {
                    anchors.centerIn: parent
                    text: "\u22ee"
                    font.pixelSize: units.gu(2.7)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.noteMenuOpen = true
                }
            }
        }
    }

    Timer {
        id: localSaveTimer
        interval: 2000
        repeat: false
        onTriggered: page.saveDraftNow()
    }

    Connections {
        target: notesController

        onNoteContentChanged: {
            if (notesController.noteConflict) {
                page.conflictLocalContent = notesController.noteContent
                if (page.conflictPreviewChoice === "local") {
                    page.applyConflictEditorContent()
                }
                return
            }
            if (contentEditor.text !== notesController.noteContent) {
                page.applyingControllerContent = true
                contentEditor.text = notesController.noteContent
                page.applyingControllerContent = false
            }
        }

        onNoteTitleChanged: {
            if (page.editingTitle) {
                return
            }
            var title = notesController.noteTitle.length > 0 ? notesController.noteTitle : page.initialTitle
            if (page.draftTitle !== title) {
                page.applyingControllerContent = true
                page.draftTitle = title
                page.draftTitleInitialized = true
                page.applyingControllerContent = false
            }
        }

        onNoteCategoryChanged: {
            if (page.editingCategory) {
                return
            }
            if (page.draftCategory !== notesController.noteCategory) {
                page.applyingControllerContent = true
                page.draftCategory = notesController.noteCategory
                page.draftCategoryInitialized = true
                page.applyingControllerContent = false
            }
        }

        onNoteFavoriteChanged: {
            if (page.favoriteSelected !== notesController.noteFavorite) {
                page.applyingControllerContent = true
                page.favoriteSelected = notesController.noteFavorite
                page.applyingControllerContent = false
            }
        }

        onNoteConflictChanged: {
            if (notesController.noteConflict) {
                page.conflictPreviewChoice = "local"
                page.conflictLocalContent = notesController.noteContent
                page.applyConflictEditorContent()
            } else {
                page.conflictLocalContent = ""
            }
        }

        onNoteServerContentChanged: {
            if (notesController.noteConflict && page.conflictPreviewChoice === "server") {
                page.applyConflictEditorContent()
            }
        }

        onNoteDeletedChanged: {
            if (notesController.noteDeleted) {
                pageStack.pop()
            }
        }

        onPendingNoteIdChanged: {
            if (page.noteId < 0 && notesController.pendingNoteId > 0) {
                page.noteId = notesController.pendingNoteId
            }
        }
    }

    Component {
        id: editTitleDialog

        Dialog {
            id: dialog
            title: i18n.tr("Edit title")
            text: i18n.tr("Update the note title.")

            TextField {
                id: titleDialogField
                width: parent.width
                text: ""
                placeholderText: i18n.tr("Title")
                readOnly: notesController.noteReadOnly
                onTextChanged: page.editTitleText = text
                Component.onCompleted: {
                    text = page.editTitleText
                    Qt.callLater(function() {
                        titleDialogField.selectAll()
                        titleDialogField.forceActiveFocus()
                    })
                }
            }

            Timer {
                id: titleCommitTimer
                interval: 80
                repeat: false
                onTriggered: {
                    var newTitle = titleDialogField.text
                    page.editTitleText = newTitle
                    page.draftTitle = newTitle
                    page.draftTitleInitialized = true
                    page.editingTitle = false
                    localSaveTimer.stop()
                    notesController.saveLocalDraft(page.draftTitle, contentEditor.text, page.draftCategory, page.favoriteSelected)
                    PopupUtils.close(dialog)
                }
            }

            Button {
                text: i18n.tr("Save")
                enabled: !notesController.noteLoading && !notesController.noteReadOnly
                onClicked: {
                    Qt.inputMethod.commit()
                    titleDialogField.focus = false
                    titleCommitTimer.restart()
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: {
                    page.editingTitle = false
                    PopupUtils.close(dialog)
                }
            }
        }
    }

    Component {
        id: editCategoryDialog

        Dialog {
            id: dialog
            title: i18n.tr("Category")
            text: i18n.tr("Choose an existing category or enter a new one.")

            TextField {
                id: categoryDialogField
                width: parent.width
                text: ""
                placeholderText: i18n.tr("Category")
                readOnly: notesController.noteReadOnly
                onTextChanged: page.editCategoryText = text
                Component.onCompleted: {
                    text = page.editCategoryText
                    Qt.callLater(function() {
                        categoryDialogField.forceActiveFocus()
                    })
                }
            }

            Timer {
                id: categoryCommitTimer
                interval: 80
                repeat: false
                onTriggered: {
                    var newCategory = categoryDialogField.text
                    page.editCategoryText = newCategory
                    page.draftCategory = newCategory
                    page.draftCategoryInitialized = true
                    page.editingCategory = false
                    localSaveTimer.stop()
                    notesController.saveLocalDraft(page.draftTitle, contentEditor.text, page.draftCategory, page.favoriteSelected)
                    PopupUtils.close(dialog)
                }
            }

            ListView {
                id: categoryDialogList
                width: parent.width
                height: Math.min(units.gu(22), contentHeight)
                clip: true
                model: notesController.categories

                delegate: Button {
                    width: categoryDialogList.width
                    height: visible ? implicitHeight : 0
                    visible: model.type === "category" || model.type === "uncategorized"
                    text: model.type === "uncategorized"
                        ? i18n.tr("Uncategorized")
                        : model.label
                    onClicked: {
                        page.editCategoryText = model.type === "uncategorized" ? "" : model.value
                        categoryDialogField.text = page.editCategoryText
                    }
                }
            }

            Button {
                text: i18n.tr("Save")
                enabled: !notesController.noteLoading && !notesController.noteReadOnly
                onClicked: {
                    Qt.inputMethod.commit()
                    categoryDialogField.focus = false
                    categoryCommitTimer.restart()
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: {
                    page.editingCategory = false
                    PopupUtils.close(dialog)
                }
            }
        }
    }

    Component {
        id: statusDetailsDialog

        Dialog {
            id: dialog
            title: i18n.tr("Status")
            text: page.noteStatusDetails()

            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: deleteConfirmDialog

        Dialog {
            id: dialog
            title: i18n.tr("Delete note?")
            text: notesController.noteIsNew
                ? i18n.tr("This local draft has not been uploaded. Deleting it will remove it from this device.")
                : notesController.noteDirty
                ? i18n.tr("This note has unsynced local changes. Deleting it will discard those changes and delete the server note.")
                : i18n.tr("This will delete the note from Nextcloud.")

            Button {
                text: i18n.tr("Delete")
                color: "#c7162b"
                onClicked: {
                    PopupUtils.close(dialog)
                    localSaveTimer.stop()
                    notesController.deleteCurrentNote()
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    ColumnLayout {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(2)
            bottomMargin: units.gu(2) + page.oskOverlap
        }
        spacing: units.gu(1.5)

        RowLayout {
            Layout.fillWidth: true
            spacing: units.gu(1)
            visible: page.noteSearchVisible

            TextField {
                id: noteSearchField
                Layout.fillWidth: true
                placeholderText: i18n.tr("Search in note")
                inputMethodHints: Qt.ImhNoPredictiveText
                onAccepted: page.findNextInContent()
            }

            Button {
                text: i18n.tr("Find")
                enabled: noteSearchField.text.length > 0
                onClicked: page.findNextInContent()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: units.gu(4.5)
            color: "transparent"
            border.width: 0
            visible: notesController.noteStatusText.length > 0
                || notesController.noteDirty
                || notesController.noteConflict
                || notesController.noteReadOnly

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: units.gu(0.25)
                    rightMargin: units.gu(0.25)
                }
                spacing: units.gu(0.75)

                Rectangle {
                    Layout.preferredWidth: units.gu(1)
                    Layout.preferredHeight: units.gu(1)
                    radius: units.gu(0.5)
                    color: notesController.noteConflict
                        ? "#c7162b"
                        : notesController.noteDirty || notesController.noteIsNew
                        ? "#c65d00"
                        : notesController.noteReadOnly
                        ? "#6f6f6f"
                        : notesController.syncStateColor
                }

                Label {
                    Layout.fillWidth: true
                    text: page.noteStatusSummary()
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    opacity: 0.78
                }

                Button {
                    Layout.preferredWidth: units.gu(8)
                    text: i18n.tr("Details")
                    visible: page.noteStatusDetails().length > 48
                    onClicked: PopupUtils.open(statusDetailsDialog)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: notesController.noteConflict
            spacing: units.gu(0.75)

            Label {
                Layout.fillWidth: true
                text: i18n.tr("The server changed this note while you had local edits. Review a version, then choose which one to keep.")
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                opacity: 0.82
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: units.gu(1)

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("Server version")
                    color: page.conflictPreviewChoice === "server" ? "#c7162b" : theme.palette.normal.background
                    onClicked: page.selectConflictVersion("server")
                }

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("Local version")
                    color: page.conflictPreviewChoice === "local" ? "#c65d00" : theme.palette.normal.background
                    onClicked: page.selectConflictVersion("local")
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(11)
                radius: units.gu(0.75)
                color: "transparent"
                border.width: 1
                border.color: page.conflictPreviewChoice === "server" ? "#c7162b" : "#c65d00"

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: units.gu(1)
                    }
                    spacing: units.gu(0.4)

                    Label {
                        Layout.fillWidth: true
                        text: page.conflictPreviewChoice === "server"
                            ? i18n.tr("Server version")
                            : i18n.tr("Local version")
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Label {
                        Layout.fillWidth: true
                        text: page.conflictPreviewChoice === "server"
                            ? page.serverConflictPreviewMetadata()
                            : page.localConflictPreviewMetadata()
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        opacity: 0.72
                    }

                    Label {
                        id: conflictPreviewText
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: page.previewFor(page.conflictPreviewChoice === "server"
                            ? notesController.noteServerContent
                            : contentEditor.text)
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        opacity: 0.88
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                text: page.conflictPreviewChoice === "server"
                    ? i18n.tr("Use server version")
                    : i18n.tr("Keep local version")
                enabled: !notesController.noteLoading
                onClicked: {
                    if (page.conflictPreviewChoice === "server") {
                        notesController.discardLocalDraftAndUseServer()
                    } else {
                        notesController.keepLocalDraftAfterConflict()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: units.gu(1)
            visible: !notesController.noteReadOnly && (notesController.noteDirty || notesController.noteIsNew)

            Button {
                Layout.fillWidth: true
                text: i18n.tr("Save locally")
                enabled: !notesController.noteLoading
                    && (!notesController.noteConflict || page.conflictPreviewChoice === "local")
                onClicked: {
                    localSaveTimer.stop()
                    notesController.saveLocalDraft(page.draftTitle, contentEditor.text, page.draftCategory, page.favoriteSelected)
                }
            }

            Button {
                Layout.fillWidth: true
                visible: notesController.noteDirty
                text: notesController.noteIsNew ? i18n.tr("Create note") : i18n.tr("Upload changes")
                enabled: !notesController.noteLoading
                    && (!notesController.noteConflict || page.conflictPreviewChoice === "local")
                onClicked: {
                    localSaveTimer.stop()
                    notesController.saveLocalDraft(page.draftTitle, contentEditor.text, page.draftCategory, page.favoriteSelected)
                    notesController.uploadLocalDraft()
                }
            }
        }

        TextArea {
            id: contentEditor
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: ""
            readOnly: notesController.noteReadOnly
                || (notesController.noteConflict && page.conflictPreviewChoice === "server")
            placeholderText: notesController.noteReadOnly || (notesController.noteConflict && page.conflictPreviewChoice === "server")
                ? i18n.tr("This note is read-only.")
                : i18n.tr("Note content")
            onTextChanged: {
                if (!page.applyingControllerContent && notesController.noteConflict && page.conflictPreviewChoice === "local") {
                    page.conflictLocalContent = contentEditor.text
                }
                if (!page.applyingControllerContent && !readOnly && noteId !== 0) {
                    localSaveTimer.restart()
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: notesController.noteConflict && page.conflictPreviewChoice === "server"
                color: "transparent"
                border.width: 1
                border.color: theme.palette.normal.backgroundText
                opacity: 0.28
                radius: units.gu(0.25)
                z: 2
            }
        }
    }

    Item {
        id: menuOverlay
        anchors.fill: parent
        visible: page.noteMenuOpen
        z: 20

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.32
        }

        MouseArea {
            anchors.fill: parent
            onClicked: page.noteMenuOpen = false
        }

        Rectangle {
            id: menuPanel
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            width: Math.min(parent.width * 0.78, units.gu(34))
            color: theme.palette.normal.background
            border.width: 1
            border.color: "#7a7a7a"

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: units.gu(1.5)
                }
                spacing: units.gu(1)

                Label {
                    Layout.fillWidth: true
                    text: page.displayTitle()
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }

                Button {
                    Layout.fillWidth: true
                    text: page.favoriteSelected ? i18n.tr("Remove favorite") : i18n.tr("Add favorite")
                    enabled: !notesController.noteLoading && !notesController.noteReadOnly && noteId !== 0
                    onClicked: {
                        page.noteMenuOpen = false
                        page.favoriteSelected = !page.favoriteSelected
                        localSaveTimer.stop()
                        notesController.saveLocalDraft(page.draftTitle, contentEditor.text, page.draftCategory, page.favoriteSelected)
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("Edit title")
                    enabled: !notesController.noteLoading && !notesController.noteReadOnly && noteId !== 0
                    onClicked: {
                        page.noteMenuOpen = false
                        page.flushPendingDraft()
                        page.editTitleText = page.currentDraftTitle()
                        page.editingTitle = true
                        PopupUtils.open(editTitleDialog)
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("Category")
                    enabled: !notesController.noteLoading && !notesController.noteReadOnly && noteId !== 0
                    onClicked: {
                        page.noteMenuOpen = false
                        page.flushPendingDraft()
                        page.editingCategory = true
                        page.editCategoryText = page.currentDraftCategory()
                        PopupUtils.open(editCategoryDialog)
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("Cancel")
                    onClicked: page.noteMenuOpen = false
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("Delete")
                    enabled: !notesController.noteLoading && noteId !== 0
                    color: "#c7162b"
                    onClicked: {
                        page.noteMenuOpen = false
                        PopupUtils.open(deleteConfirmDialog)
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (noteId > 0) {
            notesController.loadNote(noteId, initialTitle)
        } else if (noteId < 0) {
            notesController.loadNote(noteId, initialTitle)
        } else {
            notesController.noteStatusText = i18n.tr("No note selected.")
        }
        Qt.callLater(page.syncDraftFromController)
    }

    Component.onDestruction: page.flushPendingDraft()

    onVisibleChanged: {
        if (!visible) {
            page.flushPendingDraft()
        }
    }

    function displayTitle() {
        var title = page.currentDraftTitle()
        return title.length > 0
            ? title
            : i18n.tr("Untitled note")
    }

    function currentDraftTitle() {
        if (page.editingTitle) {
            return page.editTitleText || ""
        }
        if (page.draftTitleInitialized) {
            return page.draftTitle
        }
        if (notesController.noteTitle && notesController.noteTitle.length > 0) {
            return notesController.noteTitle
        }
        return page.initialTitle || ""
    }

    function currentDraftCategory() {
        if (page.editingCategory) {
            return page.editCategoryText || ""
        }
        if (page.draftCategoryInitialized) {
            return page.draftCategory
        }
        return notesController.noteCategory || ""
    }

    function syncDraftFromController() {
        if (page.applyingControllerContent) {
            return
        }
        page.applyingControllerContent = true
        page.draftTitle = page.currentDraftTitle()
        page.draftTitleInitialized = true
        page.draftCategory = page.currentDraftCategory()
        page.draftCategoryInitialized = true
        page.favoriteSelected = notesController.noteFavorite
        if (contentEditor.text.length === 0 && notesController.noteContent.length > 0) {
            contentEditor.text = notesController.noteContent
        }
        page.applyingControllerContent = false
    }

    function selectConflictVersion(choice) {
        if (!notesController.noteConflict) {
            page.conflictPreviewChoice = choice
            return
        }
        if (page.conflictPreviewChoice === "local" && choice === "server") {
            page.conflictLocalContent = contentEditor.text
            localSaveTimer.stop()
        }
        page.conflictPreviewChoice = choice
        page.applyConflictEditorContent()
    }

    function applyConflictEditorContent() {
        if (!notesController.noteConflict) {
            return
        }
        var nextText = page.conflictPreviewChoice === "server"
            ? notesController.noteServerContent
            : (page.conflictLocalContent.length > 0 ? page.conflictLocalContent : notesController.noteContent)
        if (contentEditor.text !== nextText) {
            page.applyingControllerContent = true
            contentEditor.text = nextText
            page.applyingControllerContent = false
        }
    }

    function noteStateLabel() {
        if (notesController.noteConflict) {
            return i18n.tr("Conflict")
        }
        if (notesController.noteIsNew) {
            return i18n.tr("New note")
        }
        if (notesController.noteDirty) {
            return i18n.tr("Unsynced changes")
        }
        if (notesController.noteReadOnly) {
            return i18n.tr("Read-only")
        }
        return ""
    }

    function noteStatusSummary() {
        var state = noteStateLabel()
        var status = notesController.noteStatusText || ""
        if (state.length > 0 && status.length > 0) {
            return i18n.tr("%1 - %2").arg(state).arg(status)
        }
        if (state.length > 0) {
            return state
        }
        if (status.length > 0) {
            return status
        }
        return notesController.syncStateText
    }

    function noteStatusDetails() {
        var parts = []
        var state = noteStateLabel()
        if (state.length > 0) {
            parts.push(state)
        }
        if (notesController.noteStatusText.length > 0) {
            parts.push(notesController.noteStatusText)
        }
        if (notesController.noteModifiedText.length > 0) {
            parts.push(i18n.tr("Modified: %1").arg(notesController.noteModifiedText))
        }
        if (notesController.noteDirty && notesController.noteLocalModifiedText.length > 0) {
            parts.push(i18n.tr("Local draft saved: %1").arg(notesController.noteLocalModifiedText))
        }
        if (notesController.noteConflict && notesController.noteConflictEtag.length > 0) {
            parts.push(i18n.tr("Server conflict etag is available."))
        }
        if (notesController.syncStateText.length > 0) {
            parts.push(i18n.tr("Sync: %1").arg(notesController.syncStateText))
        }
        return parts.join("\n")
    }

    function previewFor(content) {
        var text = String(content || "").replace(/\s+/g, " ").trim()
        if (text.length === 0) {
            return i18n.tr("No content preview")
        }
        return text.length > 120 ? text.slice(0, 117) + "..." : text
    }

    function serverConflictPreviewMetadata() {
        var modified = notesController.noteModifiedText.length > 0
            ? notesController.noteModifiedText
            : i18n.tr("unknown")
        return notesController.noteConflictEtag.length > 0
            ? i18n.tr("Modified: %1 - ETag available").arg(modified)
            : i18n.tr("Modified: %1").arg(modified)
    }

    function localConflictPreviewMetadata() {
        var saved = notesController.noteLocalModifiedText.length > 0
            ? notesController.noteLocalModifiedText
            : i18n.tr("unknown")
        return notesController.noteDirty
            ? i18n.tr("Local draft saved: %1 - unsynced").arg(saved)
            : i18n.tr("Local draft saved: %1").arg(saved)
    }

    function saveDraftNow() {
        if (notesController.noteConflict && page.conflictPreviewChoice === "server") {
            return
        }
        if (!page.applyingControllerContent && !notesController.noteReadOnly && noteId !== 0) {
            notesController.saveLocalDraft(page.draftTitle, contentEditor.text, page.draftCategory, page.favoriteSelected)
        }
    }

    function flushPendingDraft() {
        if (localSaveTimer.running) {
            localSaveTimer.stop()
            saveDraftNow()
        }
    }

    function findNextInContent() {
        var query = noteSearchField.text
        if (!query || query.length === 0) {
            return
        }

        var text = contentEditor.text || ""
        var start = contentEditor.cursorPosition >= 0 ? contentEditor.cursorPosition + 1 : 0
        var index = text.toLowerCase().indexOf(query.toLowerCase(), start)
        if (index < 0) {
            index = text.toLowerCase().indexOf(query.toLowerCase(), 0)
        }
        if (index >= 0) {
            contentEditor.forceActiveFocus()
            contentEditor.select(index, index + query.length)
        }
    }
}
