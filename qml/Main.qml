import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "backend"

MainView {
    id: root
    objectName: "mainView"
    applicationName: "nextnotes.cloudsite"
    automaticOrientation: true

    width: desktopLarge ? units.gu(45) : units.gu(45)
    height: desktopLarge ? units.gu(80) : units.gu(75)

    Component.onCompleted: {
        if (desktopDarkMode) {
            theme.name = "Ubuntu.Components.Themes.SuruDark"
        }
    }

    NotesController {
        id: appNotesController
    }

    Loader {
        id: shareImportLoader
        active: !desktopLarge
        source: Qt.resolvedUrl("backend/ShareImportHandler.qml")

        onLoaded: {
            item.notesController = appNotesController
            item.sharedTextImported.connect(root.openSharedTextNote)
            item.importFailed.connect(root.showShareImportError)
        }

        onStatusChanged: {
            if (status === Loader.Error && source.toString().indexOf("ShareImportHandler.qml") !== -1) {
                console.log("NextNotes ContentHub Lomiri.Content handler unavailable; trying Ubuntu.Content fallback")
                source = Qt.resolvedUrl("backend/ShareImportHandlerUbuntu.qml")
            }
        }
    }

    Connections {
        target: Qt.application

        onActiveChanged: {
            if (Qt.application.active) {
                appNotesController.handleApplicationActivated()
            } else {
                appNotesController.handleApplicationDeactivated()
            }
        }
    }

    PageStack {
        id: pageStack
        anchors.fill: parent

        Component.onCompleted: push(Qt.resolvedUrl("pages/NotesListPage.qml"), {
            "notesController": appNotesController
        })
    }

    function openSharedTextNote(noteId, title) {
        pageStack.push(Qt.resolvedUrl("pages/NoteEditorPage.qml"), {
            "noteId": noteId,
            "initialTitle": title && title.length > 0 ? title : i18n.tr("Shared"),
            "notesController": appNotesController
        })
    }

    function showShareImportError(message) {
        appNotesController.statusText = message
    }
}
