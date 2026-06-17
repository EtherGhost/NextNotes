import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3

Page {
    id: page

    property string noteTitle: ""
    property string selectedVersion: "local"
    property var notesController

    header: PageHeader {
        title: i18n.tr("Conflict")
    }

    ColumnLayout {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(2)
        }
        spacing: units.gu(1.25)

        Label {
            Layout.fillWidth: true
            text: page.noteTitle.length > 0 ? page.noteTitle : i18n.tr("Untitled note")
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
        }

        Label {
            Layout.fillWidth: true
            text: i18n.tr("The server changed this note while you had local edits. Review one version, then choose which version to keep.")
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
                color: page.selectedVersion === "server" ? "#c7162b" : theme.palette.normal.background
                onClicked: page.selectedVersion = "server"
            }

            Button {
                Layout.fillWidth: true
                text: i18n.tr("Local version")
                color: page.selectedVersion === "local" ? "#c65d00" : theme.palette.normal.background
                onClicked: page.selectedVersion = "local"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: units.gu(0.5)
            color: "transparent"
            border.width: 1
            border.color: page.selectedVersion === "server" ? "#c7162b" : "#c65d00"

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: units.gu(1)
                }
                spacing: units.gu(0.75)

                Label {
                    Layout.fillWidth: true
                    text: page.selectedVersion === "server"
                        ? page.serverConflictMetadata()
                        : page.localConflictMetadata()
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    opacity: 0.72
                }

                TextArea {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readOnly: true
                    text: page.selectedVersion === "server"
                        ? notesController.noteServerContent
                        : notesController.noteContent
                }
            }
        }

        Button {
            Layout.fillWidth: true
            text: page.selectedVersion === "server"
                ? i18n.tr("Use server version")
                : i18n.tr("Keep local version")
            enabled: notesController.noteConflict && !notesController.noteLoading
            onClicked: {
                if (page.selectedVersion === "server") {
                    notesController.discardLocalDraftAndUseServer()
                } else {
                    notesController.keepLocalDraftAfterConflict()
                }
                pageStack.pop()
            }
        }
    }

    function serverConflictMetadata() {
        var modified = notesController.noteModifiedText.length > 0
            ? notesController.noteModifiedText
            : i18n.tr("unknown")
        return notesController.noteConflictEtag.length > 0
            ? i18n.tr("Server version - modified: %1 - ETag available").arg(modified)
            : i18n.tr("Server version - modified: %1").arg(modified)
    }

    function localConflictMetadata() {
        var saved = notesController.noteLocalModifiedText.length > 0
            ? notesController.noteLocalModifiedText
            : i18n.tr("unknown")
        return notesController.noteDirty
            ? i18n.tr("Local version - saved: %1 - unsynced").arg(saved)
            : i18n.tr("Local version - saved: %1").arg(saved)
    }
}
