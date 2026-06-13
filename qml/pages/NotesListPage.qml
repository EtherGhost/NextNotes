import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtGraphicalEffects 1.0
import Qt.labs.settings 1.0
import "../backend"

Page {
    id: page

    property bool initialLoadDone: false
    property int selectedNoteId: 0
    property bool menuOpen: false
    property var notesController
    property bool selectionMode: false
    property var selectedNoteIds: []
    property int selectionRevision: 0
    property int listDeleteNoteId: 0
    property string listDeleteNoteTitle: ""
    property bool listDeleteNoteDirty: false
    property bool listDeleteNoteIsNew: false
    property int bulkDeleteDirtyCount: 0
    property int bulkDeleteNewCount: 0
    readonly property real pullRefreshThreshold: units.gu(7)
    readonly property string accountInitial: accountSettings.displayName.length > 0
        ? accountSettings.displayName.charAt(0).toUpperCase()
        : "N"

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

            Button {
                Layout.preferredWidth: units.gu(5)
                Layout.preferredHeight: units.gu(5)
                text: page.selectionMode ? "\u2715" : "\u2630"
                onClicked: {
                    if (page.selectionMode) {
                        page.clearSelection()
                    } else {
                        page.menuOpen = true
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                visible: page.selectionMode
                text: i18n.tr("%1 selected").arg(page.selectedNoteIds.length)
                font.bold: true
                elide: Text.ElideRight
            }

            TextField {
                id: searchField
                Layout.fillWidth: true
                visible: !page.selectionMode
                placeholderText: notesController.selectedCategoryType === "all"
                    ? i18n.tr("Search notes")
                    : i18n.tr("Search %1").arg(notesController.selectedCategoryLabel)
                inputMethodHints: Qt.ImhNoPredictiveText
                onTextChanged: notesController.setSearchQuery(text)
            }

            Button {
                Layout.preferredWidth: units.gu(8)
                Layout.preferredHeight: units.gu(5)
                visible: page.selectionMode
                enabled: page.selectedNoteIds.length > 0
                text: i18n.tr("Delete")
                color: "#c7162b"
                onClicked: page.requestBulkDelete()
            }

            Rectangle {
                Layout.preferredWidth: units.gu(5)
                Layout.preferredHeight: units.gu(5)
                visible: !page.selectionMode
                radius: units.gu(2.5)
                color: "#2c7fb8"
                border.width: 1
                border.color: "#7a7a7a"

                Image {
                    id: accountAvatarSource
                    anchors.fill: parent
                    source: notesController.accountAvatarUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                Rectangle {
                    id: accountAvatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: accountAvatarSource
                    maskSource: accountAvatarMask
                    visible: accountAvatarSource.status === Image.Ready
                }

                Label {
                    anchors.centerIn: parent
                    text: page.accountInitial
                    color: "white"
                    font.bold: true
                    visible: accountAvatarSource.status !== Image.Ready
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: pageStack.push(Qt.resolvedUrl("AccountSelectionPage.qml"))
                }
            }
        }
    }

    Settings {
        id: accountSettings
        category: "account"
        property string displayName: ""
    }

    Component {
        id: statusDetailsDialog

        Dialog {
            id: dialog
            title: i18n.tr("Status")
            text: notesController.statusText

            Button {
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: listDeleteConfirmDialog

        Dialog {
            id: dialog
            title: i18n.tr("Delete note?")
            text: page.listDeleteNoteIsNew
                ? i18n.tr("This local draft has not been uploaded. Deleting it will remove it from this device.")
                : page.listDeleteNoteDirty
                ? i18n.tr("This note has unsynced local changes. Deleting it will discard those changes and delete the server note.")
                : i18n.tr("This will delete \"%1\" from Nextcloud.").arg(page.listDeleteNoteTitle.length > 0 ? page.listDeleteNoteTitle : i18n.tr("Untitled note"))

            Button {
                text: i18n.tr("Delete")
                color: "#c7162b"
                onClicked: {
                    PopupUtils.close(dialog)
                    notesController.deleteNote(page.listDeleteNoteId)
                    page.listDeleteNoteId = 0
                    page.listDeleteNoteTitle = ""
                }
            }

            Button {
                text: i18n.tr("Cancel")
                onClicked: {
                    PopupUtils.close(dialog)
                    page.listDeleteNoteId = 0
                    page.listDeleteNoteTitle = ""
                }
            }
        }
    }

    Component {
        id: bulkDeleteConfirmDialog

        Dialog {
            id: dialog
            title: i18n.tr("Delete selected notes?")
            text: page.bulkDeleteMessage()

            Button {
                text: i18n.tr("Delete")
                color: "#c7162b"
                onClicked: {
                    PopupUtils.close(dialog)
                    var count = notesController.deleteNotes(page.selectedNoteIds)
                    page.clearSelection()
                    if (count === 0) {
                        notesController.statusText = i18n.tr("No selected notes could be deleted.")
                    }
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
            margins: units.gu(1.5)
        }
        spacing: units.gu(1.25)

        Rectangle {
            Layout.fillWidth: true
            height: units.gu(4)
            color: "transparent"
            border.width: 0
            visible: notesController.statusText.length > 0

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
                    color: notesController.loading ? "#2c7fb8" : notesController.syncStateColor
                }

                Label {
                    id: statusLabel
                    Layout.fillWidth: true
                    text: notesController.statusText + " - " + notesController.syncStateText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    opacity: 0.75
                }

                Button {
                    Layout.preferredWidth: units.gu(8)
                    text: i18n.tr("Details")
                    visible: notesController.statusText.length > 48
                    onClicked: PopupUtils.open(statusDetailsDialog)
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: notesList
                anchors.fill: parent
                clip: true
                spacing: units.gu(1)
                model: notesController.model
                visible: notesController.model.count > 0
                boundsBehavior: Flickable.DragOverBounds
                property bool pullRefreshArmed: false

                onContentYChanged: {
                    if (contentY < -page.pullRefreshThreshold && !notesController.loading) {
                        pullRefreshArmed = true
                    }
                }

                onMovementEnded: {
                    if (pullRefreshArmed && !notesController.loading) {
                        notesController.loadNotes()
                    }
                    pullRefreshArmed = false
                }

                Rectangle {
                    anchors {
                        top: parent.top
                        horizontalCenter: parent.horizontalCenter
                        topMargin: units.gu(0.6)
                    }
                    width: refreshPullLabel.implicitWidth + units.gu(2)
                    height: units.gu(3.2)
                    radius: units.gu(1.6)
                    color: "#2c7fb8"
                    opacity: notesList.contentY < -units.gu(2) || notesController.loading ? 0.92 : 0
                    visible: opacity > 0
                    z: 4

                    Label {
                        id: refreshPullLabel
                        anchors.centerIn: parent
                        text: notesController.loading
                            ? i18n.tr("Refreshing...")
                            : notesList.contentY < -page.pullRefreshThreshold
                            ? i18n.tr("Release to refresh")
                            : i18n.tr("Pull to refresh")
                        color: "white"
                    }
                }

                section.property: "sectionLabel"
                section.criteria: ViewSection.FullString
                section.delegate: Rectangle {
                    width: notesList.width
                    height: sectionLabel.implicitHeight + units.gu(1.4)
                    color: theme.palette.normal.background

                    Label {
                        id: sectionLabel
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: units.gu(0.5)
                            rightMargin: units.gu(0.5)
                        }
                        text: section
                        font.bold: true
                        opacity: 0.78
                        elide: Text.ElideRight
                    }
                }

                delegate: Item {
                    id: row

                    width: notesList.width
                    height: units.gu(6.6)
                    property bool longPressHandled: false
                    readonly property real actionThreshold: units.gu(8)

                    function resetSwipe() {
                        swipeContent.x = 0
                    }

                    function requestDelete() {
                        page.listDeleteNoteId = model.noteId
                        page.listDeleteNoteTitle = model.title && model.title.length > 0 ? model.title : i18n.tr("Untitled note")
                        page.listDeleteNoteDirty = model.dirty === true
                        page.listDeleteNoteIsNew = model.isNew === true
                        PopupUtils.open(listDeleteConfirmDialog)
                    }

                    Rectangle {
                        anchors {
                            fill: parent
                            leftMargin: units.gu(0.25)
                            rightMargin: units.gu(0.25)
                        }
                        radius: units.gu(0.75)
                        color: swipeContent.x >= 0 ? "#f6c343" : "#c7162b"
                        opacity: Math.min(1, Math.abs(swipeContent.x) / row.actionThreshold)

                        Label {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                                leftMargin: units.gu(2)
                            }
                            visible: swipeContent.x > units.gu(1)
                            text: model.favorite === true ? i18n.tr("Unfavorite") : i18n.tr("Favorite")
                            color: "white"
                            font.bold: true
                        }

                        Label {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                rightMargin: units.gu(2)
                            }
                            visible: swipeContent.x < -units.gu(1)
                            text: i18n.tr("Delete")
                            color: "white"
                            font.bold: true
                        }
                    }

                    Item {
                        id: swipeContent
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: parent.width

                        Rectangle {
                            id: card
                            anchors {
                                fill: parent
                                leftMargin: units.gu(0.25)
                                rightMargin: units.gu(0.25)
                            }
                            radius: units.gu(0.75)
                            color: theme.palette.normal.background
                            border.width: page.isSelected(model.noteId) || page.selectedNoteId === model.noteId ? 2 : 1
                            border.color: page.isSelected(model.noteId)
                                ? "#c7162b"
                                : page.selectedNoteId === model.noteId
                                ? "#2c7fb8"
                                : "#7a7a7a"

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "#c7162b"
                                opacity: page.isSelected(model.noteId) ? 0.08 : 0
                            }
                        }

                        RowLayout {
                            id: cardLayout
                            anchors {
                                left: card.left
                                right: card.right
                                top: card.top
                                bottom: card.bottom
                                leftMargin: units.gu(0.75)
                                rightMargin: units.gu(0.75)
                                topMargin: units.gu(0.55)
                                bottomMargin: units.gu(0.55)
                            }
                            spacing: units.gu(0.75)

                            Rectangle {
                                Layout.preferredWidth: units.gu(4)
                                Layout.preferredHeight: units.gu(4)
                                Layout.alignment: Qt.AlignVCenter
                                radius: units.gu(2)
                                color: favoriteMouseArea.pressed ? "#dedede" : "transparent"

                                Label {
                                    anchors.centerIn: parent
                                    text: page.isSelected(model.noteId) ? "\u2713" : (model.favorite === true ? "\u2605" : "\u2606")
                                    color: page.isSelected(model.noteId)
                                        ? "#c7162b"
                                        : model.favorite === true
                                        ? "#f6c343"
                                        : "#6f6f6f"
                                    font.pixelSize: units.gu(2.4)
                                    opacity: model.readonly === true ? 0.45 : 1.0
                                }

                                MouseArea {
                                    id: favoriteMouseArea
                                    anchors.fill: parent
                                    enabled: page.selectionMode || model.readonly !== true
                                    onClicked: {
                                        if (page.selectionMode) {
                                            page.toggleSelected(model.noteId)
                                        } else {
                                            notesController.toggleFavoriteFromList(model.noteId)
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: units.gu(0.1)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: units.gu(2.4)
                                        spacing: units.gu(0.75)

                                        Label {
                                            Layout.fillWidth: true
                                            text: model.title && model.title.length > 0 ? model.title : i18n.tr("Untitled note")
                                            font.bold: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        Label {
                                            Layout.preferredWidth: Math.max(units.gu(4.5), implicitWidth)
                                            text: model.relativeModifiedText && model.relativeModifiedText.length > 0
                                                ? model.relativeModifiedText
                                                : i18n.tr("New")
                                            horizontalAlignment: Text.AlignRight
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            opacity: 0.72
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: units.gu(2.4)
                                        spacing: units.gu(0.75)

                                        Label {
                                            Layout.fillWidth: true
                                            text: model.preview && model.preview.length > 0 ? model.preview : ""
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            opacity: 0.76
                                        }

                                        Row {
                                            id: badgesRow
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: units.gu(0.4)

                                            Rectangle {
                                                visible: model.category && model.category.length > 0
                                                color: "#4d6f8f"
                                                height: categoryBadgeLabel.implicitHeight + units.gu(0.35)
                                                width: Math.min(categoryBadgeLabel.implicitWidth + units.gu(0.9), units.gu(9))
                                                radius: units.gu(0.3)

                                                Label {
                                                    id: categoryBadgeLabel
                                                    anchors {
                                                        left: parent.left
                                                        right: parent.right
                                                        verticalCenter: parent.verticalCenter
                                                        leftMargin: units.gu(0.45)
                                                        rightMargin: units.gu(0.45)
                                                    }
                                                    text: model.category
                                                    color: "white"
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                }
                                            }

                                            Rectangle {
                                                visible: model.conflict === true
                                                color: "#c7162b"
                                                height: conflictBadgeLabel.implicitHeight + units.gu(0.35)
                                                width: conflictBadgeLabel.implicitWidth + units.gu(0.9)
                                                radius: units.gu(0.3)

                                                Label {
                                                    id: conflictBadgeLabel
                                                    anchors.centerIn: parent
                                                    text: i18n.tr("Conflict")
                                                    color: "white"
                                                }
                                            }

                                            Rectangle {
                                                visible: model.isNew === true
                                                color: "#237b4b"
                                                height: newBadgeLabel.implicitHeight + units.gu(0.35)
                                                width: newBadgeLabel.implicitWidth + units.gu(0.9)
                                                radius: units.gu(0.3)

                                                Label {
                                                    id: newBadgeLabel
                                                    anchors.centerIn: parent
                                                    text: i18n.tr("New")
                                                    color: "white"
                                                }
                                            }

                                            Rectangle {
                                                visible: model.dirty === true && model.conflict !== true && model.isNew !== true
                                                color: "#c65d00"
                                                height: dirtyBadgeLabel.implicitHeight + units.gu(0.35)
                                                width: dirtyBadgeLabel.implicitWidth + units.gu(0.9)
                                                radius: units.gu(0.3)

                                                Label {
                                                    id: dirtyBadgeLabel
                                                    anchors.centerIn: parent
                                                    text: i18n.tr("Unsynced")
                                                    color: "white"
                                                }
                                            }

                                            Rectangle {
                                                visible: model.readonly === true
                                                color: "#6f6f6f"
                                                height: readonlyBadgeLabel.implicitHeight + units.gu(0.35)
                                                width: readonlyBadgeLabel.implicitWidth + units.gu(0.9)
                                                radius: units.gu(0.3)

                                                Label {
                                                    id: readonlyBadgeLabel
                                                    anchors.centerIn: parent
                                                    text: i18n.tr("Read-only")
                                                    color: "white"
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowMouseArea
                                    anchors.fill: parent
                                    drag.target: page.selectionMode ? null : swipeContent
                                    drag.axis: Drag.XAxis
                                    drag.minimumX: -row.actionThreshold * 1.25
                                    drag.maximumX: row.actionThreshold * 1.25
                                    preventStealing: Math.abs(swipeContent.x) > units.gu(1)

                                    onPressAndHold: {
                                        row.resetSwipe()
                                        row.longPressHandled = true
                                        page.startSelection(model.noteId)
                                    }

                                    onReleased: {
                                        if (row.longPressHandled) {
                                            row.longPressHandled = false
                                            row.resetSwipe()
                                            return
                                        }
                                        if (page.selectionMode) {
                                            row.resetSwipe()
                                            page.toggleSelected(model.noteId)
                                            return
                                        }
                                        if (swipeContent.x > row.actionThreshold) {
                                            row.resetSwipe()
                                            if (model.readonly !== true) {
                                                notesController.toggleFavoriteFromList(model.noteId)
                                            }
                                        } else if (swipeContent.x < -row.actionThreshold) {
                                            row.resetSwipe()
                                            row.requestDelete()
                                        } else {
                                            var wasTap = Math.abs(swipeContent.x) < units.gu(1)
                                            row.resetSwipe()
                                            if (wasTap) {
                                                page.openNote(model.noteId, model.title)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: units.gu(2)
                }
                spacing: units.gu(1)
                visible: notesController.model.count === 0 && !notesController.loading

                Label {
                    width: parent.width
                    text: notesController.searchActive
                        ? i18n.tr("No matching notes")
                        : notesController.categoryFilterActive
                        ? i18n.tr("No notes in %1").arg(notesController.selectedCategoryLabel)
                        : notesController.hasCachedNotes
                        ? i18n.tr("No notes to show")
                        : i18n.tr("No saved notes")
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                Label {
                    width: parent.width
                    text: notesController.searchActive
                        ? i18n.tr("Search matches note titles and content already cached on this device.")
                        : notesController.categoryFilterActive
                        ? i18n.tr("Use another category or create a new note here.")
                        : notesController.hasCachedNotes
                        ? i18n.tr("Pull down to refresh from Nextcloud.")
                        : i18n.tr("Connect to Nextcloud while online to load notes onto this device.")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    opacity: 0.75
                }
            }
        }
    }

    Rectangle {
        id: newNoteButton
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: units.gu(2)
            bottomMargin: units.gu(2)
        }
        width: units.gu(7)
        height: units.gu(7)
        radius: units.gu(3.5)
        color: "#2c7fb8"
        visible: !page.menuOpen
            && !page.selectionMode
        z: 10

        Label {
            anchors.centerIn: parent
            text: "+"
            color: "white"
            font.pixelSize: units.gu(3.8)
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            enabled: !notesController.loading
            onClicked: page.createNote()
        }
    }

    Item {
        id: menuOverlay
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        visible: page.menuOpen
        z: 20

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.32
        }

        MouseArea {
            anchors.fill: parent
            onClicked: page.menuOpen = false
        }

        Rectangle {
            id: menuPanel
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: Math.min(parent.width * 0.82, units.gu(38))
            color: theme.palette.normal.background
            border.width: 1
            border.color: "#7a7a7a"

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: units.gu(1.5)
                }
                spacing: units.gu(1)

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("NextNotes")
                        font.bold: true
                    }

                    Button {
                        text: i18n.tr("Close")
                        onClicked: page.menuOpen = false
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: notesController.loading ? i18n.tr("Refreshing...") : i18n.tr("Refresh")
                    enabled: !notesController.loading
                    onClicked: {
                        page.menuOpen = false
                        notesController.loadNotes()
                    }
                }

                Button {
                    Layout.fillWidth: true
                    visible: notesController.dirtyNotesCount > 0 || notesController.syncRunning || notesController.syncSummaryText.length > 0
                    text: notesController.syncRunning
                        ? i18n.tr("Syncing...")
                        : notesController.dirtyNotesCount > 0
                        ? i18n.tr("Sync now (%1)").arg(notesController.dirtyNotesCount)
                        : i18n.tr("Sync now")
                    enabled: notesController.dirtyNotesCount > 0 && !notesController.syncRunning && !notesController.loading
                    onClicked: {
                        page.menuOpen = false
                        notesController.syncNow()
                    }
                }

                ListView {
                    id: categoryMenuList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: units.gu(0.5)
                    model: notesController.categories

                    delegate: Rectangle {
                        id: categoryMenuItem

                        readonly property bool selected: model.type === notesController.selectedCategoryType
                            && model.value === notesController.selectedCategoryValue

                        width: categoryMenuList.width
                        height: units.gu(5.2)
                        radius: units.gu(0.5)
                        color: selected ? "#2c7fb8" : "transparent"
                        border.width: selected ? 0 : 1
                        border.color: "#7a7a7a"

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: units.gu(1)
                                rightMargin: units.gu(1)
                            }
                            spacing: units.gu(1)

                            Label {
                                Layout.fillWidth: true
                                text: model.label
                                color: categoryMenuItem.selected ? "white" : theme.palette.normal.backgroundText
                                font.bold: categoryMenuItem.selected
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                height: categoryMenuCount.implicitHeight + units.gu(0.4)
                                width: categoryMenuCount.implicitWidth + units.gu(1)
                                radius: units.gu(0.35)
                                color: categoryMenuItem.selected ? "white" : "#7a7a7a"

                                Label {
                                    id: categoryMenuCount
                                    anchors.centerIn: parent
                                    text: model.count
                                    color: categoryMenuItem.selected ? "#2c7fb8" : "white"
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                notesController.selectCategory(model.type, model.value, model.label)
                                page.menuOpen = false
                            }
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("Language")
                    onClicked: {
                        page.menuOpen = false
                        pageStack.push(Qt.resolvedUrl("LanguageSelectionPage.qml"))
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("Account")
                    onClicked: {
                        page.menuOpen = false
                        pageStack.push(Qt.resolvedUrl("AccountSelectionPage.qml"))
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("About")
                    onClicked: {
                        page.menuOpen = false
                        pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        initialLoadDone = true
        notesController.loadNotes()
    }

    onVisibleChanged: {
        if (visible && initialLoadDone) {
            notesController.loadCachedNotesOnly()
        }
    }

    function openNote(noteId, title) {
        page.selectedNoteId = noteId
        console.log("NextNotes NotesApi opening noteId=" + noteId + " hasTitle=true")
        pageStack.push(Qt.resolvedUrl("NoteEditorPage.qml"), {
            "noteId": noteId,
            "initialTitle": title,
            "notesController": notesController
        })
    }

    function createNote() {
        if (searchField.text.length > 0) {
            searchField.text = ""
            notesController.clearSearch()
        }
        var newNoteId = notesController.createLocalNote()
        page.selectedNoteId = newNoteId
        pageStack.push(Qt.resolvedUrl("NoteEditorPage.qml"), {
            "noteId": newNoteId,
            "initialTitle": i18n.tr("Untitled note"),
            "notesController": notesController
        })
    }

    function startSelection(noteId) {
        page.selectionMode = true
        page.selectedNoteIds = [noteId]
        page.selectionRevision += 1
    }

    function clearSelection() {
        page.selectionMode = false
        page.selectedNoteIds = []
        page.selectionRevision += 1
    }

    function isSelected(noteId) {
        var ignored = page.selectionRevision
        for (var i = 0; i < page.selectedNoteIds.length; ++i) {
            if (Number(page.selectedNoteIds[i]) === Number(noteId)) {
                return true
            }
        }
        return false
    }

    function toggleSelected(noteId) {
        var next = []
        var found = false
        for (var i = 0; i < page.selectedNoteIds.length; ++i) {
            if (Number(page.selectedNoteIds[i]) === Number(noteId)) {
                found = true
            } else {
                next.push(page.selectedNoteIds[i])
            }
        }
        if (!found) {
            next.push(noteId)
        }
        page.selectedNoteIds = next
        if (next.length === 0) {
            page.selectionMode = false
        }
        page.selectionRevision += 1
    }

    function requestBulkDelete() {
        page.bulkDeleteDirtyCount = 0
        page.bulkDeleteNewCount = 0
        for (var i = 0; i < page.selectedNoteIds.length; ++i) {
            for (var j = 0; j < notesController.model.count; ++j) {
                var note = notesController.model.get(j)
                if (Number(note.noteId) === Number(page.selectedNoteIds[i])) {
                    if (note.dirty === true) {
                        page.bulkDeleteDirtyCount += 1
                    }
                    if (note.isNew === true) {
                        page.bulkDeleteNewCount += 1
                    }
                    break
                }
            }
        }
        PopupUtils.open(bulkDeleteConfirmDialog)
    }

    function bulkDeleteMessage() {
        var count = page.selectedNoteIds.length
        var message = i18n.tr("This will delete %1 selected notes.").arg(count)
        if (page.bulkDeleteNewCount > 0) {
            message += "\n" + i18n.tr("%1 local-only drafts will be removed from this device.").arg(page.bulkDeleteNewCount)
        }
        if (page.bulkDeleteDirtyCount > 0) {
            message += "\n" + i18n.tr("%1 notes have unsynced local changes that will be discarded.").arg(page.bulkDeleteDirtyCount)
        }
        return message
    }

}
