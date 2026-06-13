import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "backend"

MainView {
    id: root
    objectName: "mainView"
    applicationName: "nextnotes.cloudsite"
    automaticOrientation: true

    width: desktopLarge ? units.gu(90) : units.gu(45)
    height: desktopLarge ? units.gu(120) : units.gu(75)

    Component.onCompleted: {
        if (desktopDarkMode) {
            theme.name = "Ubuntu.Components.Themes.SuruDark"
        }
    }

    NotesController {
        id: appNotesController
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
}
