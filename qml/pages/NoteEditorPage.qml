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
                color: "transparent"
                border.width: 2
                border.color: page.statusAccentColor()

                Item {
                    id: statusIcon
                    anchors.centerIn: parent
                    width: units.gu(2.8)
                    height: units.gu(2.8)

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: notesController.syncRunning
                    }

                    Connections {
                        target: notesController
                        onSyncRunningChanged: {
                            if (!notesController.syncRunning) {
                                statusIcon.rotation = 0
                            }
                        }
                    }

                    Canvas {
                        id: statusCanvas
                        anchors.fill: parent
                        property string paintColor: page.statusAccentColor()
                        visible: page.statusIconKind() !== "dirty" && page.statusIconKind() !== "conflict"
                        onVisibleChanged: requestPaint()
                        onPaintColorChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width
                            var h = height
                            var s = Math.min(w, h)
                            ctx.clearRect(0, 0, w, h)
                            ctx.strokeStyle = paintColor
                            ctx.fillStyle = paintColor
                            ctx.lineWidth = Math.max(2.4, s * 0.13)
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"

                            if (notesController.syncRunning) {
                                ctx.beginPath()
                                ctx.arc(w / 2, h / 2, s * 0.35, Math.PI * 0.15, Math.PI * 1.55, false)
                                ctx.stroke()
                                ctx.beginPath()
                                ctx.moveTo(w * 0.77, h * 0.30)
                                ctx.lineTo(w * 0.82, h * 0.52)
                                ctx.lineTo(w * 0.62, h * 0.45)
                                ctx.stroke()
                            } else if (page.statusIconKind() === "readonly") {
                                ctx.strokeRect(w * 0.27, h * 0.45, w * 0.46, h * 0.34)
                                ctx.beginPath()
                                ctx.arc(w / 2, h * 0.45, s * 0.19, Math.PI, 0, false)
                                ctx.stroke()
                            } else {
                                ctx.beginPath()
                                ctx.moveTo(w * 0.22, h * 0.54)
                                ctx.lineTo(w * 0.42, h * 0.72)
                                ctx.lineTo(w * 0.78, h * 0.28)
                                ctx.stroke()
                            }
                        }

                        Connections {
                            target: notesController
                            onSyncRunningChanged: statusCanvas.requestPaint()
                            onNoteReadOnlyChanged: statusCanvas.requestPaint()
                            onNoteDirtyChanged: statusCanvas.requestPaint()
                            onNoteIsNewChanged: statusCanvas.requestPaint()
                            onNoteConflictChanged: statusCanvas.requestPaint()
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: units.gu(1.7)
                        height: width
                        radius: width / 2
                        visible: page.statusIconKind() === "dirty"
                        color: page.statusAccentColor()
                    }

                    Item {
                        anchors.fill: parent
                        visible: page.statusIconKind() === "conflict"

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height * 0.12
                            width: Math.max(3, parent.width * 0.16)
                            height: parent.height * 0.52
                            radius: width / 2
                            color: page.statusAccentColor()
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height * 0.76
                            width: Math.max(4, parent.width * 0.20)
                            height: width
                            radius: width / 2
                            color: page.statusAccentColor()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.openStatusFromIcon()
                }
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
            if (!notesController.noteConflict && contentEditor.text !== notesController.noteContent) {
                page.applyingControllerContent = true
                contentEditor.text = notesController.noteContent
                page.applyingControllerContent = false
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
                text: i18n.tr("Resolve conflict")
                visible: notesController.noteConflict
                enabled: !notesController.noteLoading
                onClicked: {
                    PopupUtils.close(dialog)
                    page.openConflictResolution()
                }
            }

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

        TextArea {
            id: contentEditor
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: ""
            readOnly: notesController.noteReadOnly
            placeholderText: notesController.noteReadOnly
                ? i18n.tr("This note is read-only.")
                : i18n.tr("Note content")
            onTextChanged: {
                if (!page.applyingControllerContent && !readOnly && noteId !== 0) {
                    localSaveTimer.restart()
                }
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

    function statusIconKind() {
        if (notesController.syncRunning) {
            return "syncing"
        }
        if (notesController.noteConflict) {
            return "conflict"
        }
        if (notesController.noteDirty || notesController.noteIsNew) {
            return "dirty"
        }
        if (notesController.noteReadOnly) {
            return "readonly"
        }
        return "synced"
    }

    function statusAccentColor() {
        var kind = page.statusIconKind()
        if (kind === "syncing") {
            return "#2c7fb8"
        }
        if (kind === "conflict") {
            return "#c7162b"
        }
        if (kind === "dirty") {
            return "#c65d00"
        }
        if (kind === "readonly") {
            return "#6f6f6f"
        }
        return notesController.syncStateColor
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

    function saveDraftNow() {
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

    function openStatusFromIcon() {
        if (notesController.noteConflict) {
            page.openConflictResolution()
            return
        }

        PopupUtils.open(statusDetailsDialog)
    }

    function openConflictResolution() {
        page.flushPendingDraft()
        pageStack.push(Qt.resolvedUrl("ConflictResolutionPage.qml"), {
            "noteTitle": page.displayTitle(),
            "notesController": notesController
        })
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
