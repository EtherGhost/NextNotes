import QtQuick 2.7
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Lomiri.Components 1.3

Page {
    id: page

    property string swipeActionLayout: appSettings.swipeActionLayout
    property var notesListPage

    header: PageHeader {
        id: header
        title: i18n.tr("Settings")
    }

    Settings {
        id: appSettings
        category: "app"
        property string swipeActionLayout: "ut"
    }

    Flickable {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        contentWidth: width
        contentHeight: contentColumn.height + units.gu(6)

        ColumnLayout {
            id: contentColumn
            width: parent.width - units.gu(4)
            x: units.gu(2)
            y: units.gu(2)
            spacing: units.gu(1.4)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: swipeSettingsColumn.implicitHeight + units.gu(2)
                radius: units.gu(0.6)
                color: "transparent"
                border.width: 1
                border.color: "#7a7a7a"

                ColumnLayout {
                    id: swipeSettingsColumn

                    anchors {
                        fill: parent
                        margins: units.gu(1)
                    }
                    spacing: units.gu(1)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(1)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: units.gu(0.25)

                            Label {
                                Layout.fillWidth: true
                                text: i18n.tr("Android-compatible swipe direction")
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                text: page.swipeActionLayout === "android"
                                    ? i18n.tr("Swipe right to favorite, left to delete.")
                                    : i18n.tr("Swipe right to delete, left to favorite.")
                                wrapMode: Text.WordWrap
                                opacity: 0.72
                            }
                        }

                        Switch {
                            id: swipeDirectionSwitch
                            checked: page.swipeActionLayout === "android"
                            onCheckedChanged: {
                                page.setSwipeActionLayout(checked ? "android" : "ut")
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("Ubuntu Touch style is the default. Enable Android-compatible direction if you prefer the upstream Android Notes swipe behavior.")
                        wrapMode: Text.WordWrap
                        opacity: 0.68
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        page.swipeActionLayout = appSettings.swipeActionLayout === "android" || page.swipeActionLayout === "android" ? "android" : "ut"
    }

    function setSwipeActionLayout(value) {
        var normalized = value === "android" ? "android" : "ut"
        page.swipeActionLayout = normalized
        appSettings.swipeActionLayout = normalized
        if (page.notesListPage && page.notesListPage.setSwipeActionLayout) {
            page.notesListPage.setSwipeActionLayout(normalized)
        }
    }
}
