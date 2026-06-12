import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Ubuntu.OnlineAccounts 0.1
import Lomiri.OnlineAccounts.Client 0.1
import Qt.labs.settings 1.0
import "../backend/AuthCore.js" as AuthCore

Page {
    id: page

    readonly property string nextNotesApplicationId: "nextnotes.cloudsite_nextnotes"
    readonly property string nextcloudServiceId: "nextnotes.cloudsite_nextnotes_nextcloud"
    readonly property string owncloudServiceId: "nextnotes.cloudsite_nextnotes_owncloud"

    property int selectedAccountId: 0
    property string selectedDisplayName: ""
    property string selectedProviderId: ""
    property string selectedProviderName: ""
    property string selectedServiceId: ""
    property string selectedServiceName: ""
    property string selectedServiceTypeId: ""
    property bool selectedEnabled: false
    property string serverUrl: accountSettings.serverUrl
    property bool showDiagnostics: false
    property int visibleCloudAccounts: 0
    property string authorizationStatus: i18n.tr("Select an account and authorize it for NextNotes.")
    readonly property real oskOverlap: Qt.inputMethod.visible && Qt.inputMethod.keyboardRectangle.height > 0
        ? Math.max(0, page.height - Qt.inputMethod.keyboardRectangle.y)
        : 0

    header: PageHeader {
        id: header
        title: i18n.tr("Accounts")
    }

    Settings {
        id: accountSettings
        category: "account"
        property int accountId: 0
        property string displayName: ""
        property string providerId: ""
        property string serviceId: ""
        property string serverUrl: ""
    }

    AccountServiceModel {
        id: accountServices
        includeDisabled: true

        onCountChanged: page.updateVisibleCloudAccounts()
    }

    AccountService {
        id: selectedService

        onAuthenticated: {
            var data = reply && reply.data ? reply.data : reply
            var userName = page.firstValue(data, ["UserName", "Username", "userName", "username"])
            var secret = page.firstValue(data, ["Secret", "Password", "password", "secret"])
            var token = page.firstValue(data, ["AccessToken", "Token", "token"])

            console.log(
                "NextNotes OnlineAccountsAuthorization success"
                + " accountId=" + page.selectedAccountId
                + " providerId=" + page.selectedProviderId
                + " serviceId=" + page.selectedServiceId
                + " serviceTypeId=" + page.selectedServiceTypeId
                + " dataKeys=" + page.objectKeys(data).join(",")
                + " hasUserName=" + page.hasValue(userName)
                + " hasPasswordOrSecret=" + page.hasValue(secret)
                + " hasToken=" + page.hasValue(token)
            )

            page.authorizationStatus = i18n.tr("Authorization succeeded for %1. Credentials are available to the app, but were not displayed or stored.")
                .arg(page.selectedProviderId)
            accountSettings.accountId = page.selectedAccountId
            accountSettings.displayName = page.selectedDisplayName
            accountSettings.providerId = page.selectedProviderId
            accountSettings.serviceId = page.selectedServiceId
            accountSettings.serverUrl = page.normalizeServerUrl(page.serverUrl)
        }

        onAuthenticationError: {
            var message = error && error.message ? error.message : JSON.stringify(error)
            console.log(
                "NextNotes OnlineAccountsAuthorization error"
                + " accountId=" + page.selectedAccountId
                + " providerId=" + page.selectedProviderId
                + " serviceId=" + page.selectedServiceId
                + " serviceTypeId=" + page.selectedServiceTypeId
                + " message=" + message
            )
            page.authorizationStatus = i18n.tr("Authorization failed: %1. If the system did not show an Online Accounts prompt, open System Settings > Accounts and allow NextNotes for this account, then try again.")
                .arg(message)
        }
    }

    AccountService {
        id: visibleCountService
    }

    Setup {
        id: accountSetup
        applicationId: page.nextNotesApplicationId
        providerId: page.selectedProviderId.length > 0 ? page.selectedProviderId : "nextcloud"

        onFinished: {
            var accountId = reply && "accountId" in reply ? reply.accountId : 0
            console.log(
                "NextNotes OnlineAccountsSetup finished"
                + " providerId=" + providerId
                + " accountId=" + accountId
                + " replyKeys=" + page.objectKeys(reply).join(",")
            )
            if (accountId > 0) {
                page.authorizationStatus = i18n.tr("System account authorization completed. Select the account again if needed, then verify authorization.")
            } else {
                page.authorizationStatus = i18n.tr("System account authorization was cancelled or did not return an account.")
            }
        }
    }

    Timer {
        id: enableThenAuthenticateTimer
        interval: 1000
        repeat: false
        onTriggered: page.authenticateSelectedAccount()
    }

    Component.onCompleted: Qt.callLater(page.updateVisibleCloudAccounts)

    Flickable {
        id: pageFlickable
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(2)
            bottomMargin: units.gu(2) + page.oskOverlap
        }
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.DragAndOvershootBounds

        ColumnLayout {
            id: contentColumn
            width: pageFlickable.width
            spacing: units.gu(1.25)

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Account")
                textSize: Label.Large
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(8)
                radius: units.gu(0.5)
                color: "transparent"
                border.width: 1
                border.color: "#7a7a7a"

                RowLayout {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: units.gu(1)
                    }
                    spacing: units.gu(1)

                    Rectangle {
                        Layout.preferredWidth: units.gu(5)
                        Layout.preferredHeight: units.gu(5)
                        radius: units.gu(2.5)
                        color: "#2c7fb8"

                        Label {
                            anchors.centerIn: parent
                            text: page.accountInitial()
                            color: "white"
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(0.25)

                        Label {
                            Layout.fillWidth: true
                            text: page.displayAccountName()
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Label {
                            Layout.fillWidth: true
                            text: page.displayServerUrl()
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            opacity: 0.75
                        }
                    }

                    Label {
                        text: page.accountReady() ? "\u2713" : "!"
                        color: page.accountReady() ? "#2f7d32" : "#c65d00"
                        font.pixelSize: units.gu(2.4)
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Available accounts")
                font.bold: true
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: noAccountsColumn.implicitHeight + units.gu(2)
                visible: page.visibleCloudAccounts === 0
                radius: units.gu(0.5)
                color: "transparent"
                border.width: 1
                border.color: "#c65d00"

                ColumnLayout {
                    id: noAccountsColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: units.gu(1)
                    }
                    spacing: units.gu(0.5)

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("No Nextcloud account found")
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("Add a Nextcloud or ownCloud account in Ubuntu Touch System Settings > Accounts. Then return here and select it.")
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        opacity: 0.82
                    }
                }
            }

            ListView {
                id: servicesList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Math.max(contentHeight, units.gu(7)), units.gu(24))
                clip: true
                model: accountServices

                delegate: ListItem {
                    id: row

                    function role(roleName) {
                        return accountServices.get(index, roleName)
                    }

                    AccountService {
                        id: rowService
                        objectHandle: row.role("accountServiceHandle")
                    }

                    property var rowProvider: rowService.provider || {}
                    property var rowServiceInfo: rowService.service || {}
                    property string rowProviderId: rowProvider.id || row.role("providerName")
                    property string rowServiceId: rowServiceInfo.id || row.role("serviceName")
                    property string rowServiceTypeId: rowServiceInfo.serviceTypeId || rowServiceInfo.type || ""
                    property bool isCloudAccount: rowProviderId === "nextcloud" || rowProviderId === "owncloud"
                    property bool isNextNotesService: rowServiceId === page.nextcloudServiceId || rowServiceId === page.owncloudServiceId
                    property bool isSelected: page.selectedAccountId === row.role("accountId")
                        && page.selectedServiceId === rowServiceId

                    height: visible ? units.gu(7) : 0
                    visible: isCloudAccount && (isNextNotesService || row.role("enabled"))

                    RowLayout {
                        id: content
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: units.gu(1)
                        }
                        spacing: units.gu(1)

                        Rectangle {
                            Layout.preferredWidth: units.gu(4.5)
                            Layout.preferredHeight: units.gu(4.5)
                            radius: units.gu(2.25)
                            color: row.isSelected ? "#2c7fb8" : "transparent"
                            border.width: 1
                            border.color: "#7a7a7a"

                            Label {
                                anchors.centerIn: parent
                                text: String(row.role("displayName") || "?").charAt(0).toUpperCase()
                                color: row.isSelected ? "white" : theme.palette.normal.backgroundText
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: units.gu(0.25)

                            Label {
                                Layout.fillWidth: true
                                text: row.role("displayName")
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Label {
                                Layout.fillWidth: true
                                text: rowProviderId
                                    + " - accountId " + row.role("accountId")
                                    + (rowServiceId.length > 0 ? " - " + rowServiceId : "")
                                textSize: Label.Small
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                opacity: 0.72
                            }
                        }

                        Button {
                            Layout.preferredWidth: units.gu(9)
                            text: row.isSelected ? i18n.tr("Selected") : i18n.tr("Use")
                            onClicked: page.selectAccount(
                                row.role("accountServiceHandle"),
                                row.role("accountId"),
                                row.role("displayName"),
                                row.role("providerName"),
                                rowProviderId,
                                row.role("serviceName"),
                                rowServiceId,
                                rowServiceTypeId,
                                row.role("enabled")
                            )
                        }
                    }
                }
            }

            TextField {
                id: serverUrlField
                Layout.fillWidth: true
                placeholderText: i18n.tr("Server URL")
                text: page.serverUrl
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                onTextChanged: page.serverUrl = text
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: units.gu(1)

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("Authorize")
                    enabled: page.selectedAccountId > 0
                    onClicked: page.authorizeSelectedAccount()
                }

                Button {
                    Layout.fillWidth: true
                    text: i18n.tr("Verify")
                    enabled: page.selectedAccountId > 0
                    onClicked: page.authenticateSelectedAccount()
                }
            }

            Label {
                Layout.fillWidth: true
                text: authorizationStatus
                elide: Text.ElideRight
                maximumLineCount: 2
                opacity: 0.82
            }

            Button {
                Layout.fillWidth: true
                text: page.showDiagnostics ? i18n.tr("Hide diagnostics") : i18n.tr("Diagnostics")
                onClicked: page.showDiagnostics = !page.showDiagnostics
            }

            Label {
                Layout.fillWidth: true
                visible: page.showDiagnostics
                text: i18n.tr("Discovered services: %1\nSelected accountId=%2 providerId=%3 serviceId=%4 serviceTypeId=%5 enabled=%6")
                    .arg(accountServices.count)
                    .arg(selectedAccountId > 0 ? selectedAccountId : "-")
                    .arg(selectedProviderId.length ? selectedProviderId : "-")
                    .arg(selectedServiceId.length ? selectedServiceId : "-")
                    .arg(selectedServiceTypeId.length ? selectedServiceTypeId : "-")
                    .arg(selectedAccountId > 0 ? selectedEnabled : "-")
                wrapMode: Text.WordWrap
                textSize: Label.Small
            }
        }
    }

    function selectAccount(handle, accountId, displayName, providerName, providerId, serviceName, serviceId, serviceTypeId, enabled) {
        selectedService.objectHandle = handle
        selectedAccountId = accountId
        selectedDisplayName = displayName
        selectedProviderName = providerName
        selectedProviderId = providerId
        selectedServiceName = serviceName
        selectedServiceId = serviceId
        selectedServiceTypeId = serviceTypeId
        selectedEnabled = enabled

        var settings = selectedService.settings || {}
        var host = settings.host || settings.Host || accountSettings.serverUrl
        serverUrl = normalizeServerUrl(host)

        console.log(
            "NextNotes OnlineAccountsSelection selected"
            + " accountId=" + selectedAccountId
            + " providerId=" + selectedProviderId
            + " serviceId=" + selectedServiceId
            + " serviceTypeId=" + selectedServiceTypeId
            + " enabled=" + selectedEnabled
            + " hostAvailable=" + hasValue(serverUrl)
        )

        authorizationStatus = i18n.tr("Selected %1. Authorize the account before using it.")
            .arg(selectedDisplayName)
    }

    function updateVisibleCloudAccounts() {
        var count = 0
        for (var i = 0; i < accountServices.count; ++i) {
            var handle = accountServices.get(i, "accountServiceHandle")
            if (!handle) {
                continue
            }

            visibleCountService.objectHandle = handle
            var provider = visibleCountService.provider || {}
            var service = visibleCountService.service || {}
            var providerId = provider.id || accountServices.get(i, "providerName")
            var serviceId = service.id || accountServices.get(i, "serviceName")
            var enabled = accountServices.get(i, "enabled")
            var cloud = providerId === "nextcloud" || providerId === "owncloud"
            var nextNotesService = serviceId === nextcloudServiceId || serviceId === owncloudServiceId
            if (cloud && (nextNotesService || enabled)) {
                count += 1
            }
        }
        visibleCloudAccounts = count
    }

    function authorizeSelectedAccount() {
        if (selectedAccountId <= 0) {
            authorizationStatus = i18n.tr("Select an account first.")
            return
        }

        saveServerUrl()
        console.log(
            "NextNotes OnlineAccountsSetup starting"
            + " accountId=" + selectedAccountId
            + " providerId=" + selectedProviderId
            + " applicationId=" + nextNotesApplicationId
            + " serviceId=" + selectedServiceId
        )
        authorizationStatus = i18n.tr("Opening the system Online Accounts authorization flow...")
        accountSetup.exec()
    }

    function authenticateSelectedAccount() {
        if (selectedAccountId <= 0) {
            authorizationStatus = i18n.tr("Select an account first.")
            return
        }

        saveServerUrl()
        authorizationStatus = i18n.tr("Verifying Online Accounts authorization...")
        console.log(
            "NextNotes OnlineAccountsAuthorization requesting"
            + " accountId=" + selectedAccountId
            + " providerId=" + selectedProviderId
            + " serviceId=" + selectedServiceId
            + " serviceTypeId=" + selectedServiceTypeId
            + " serviceEnabled=" + selectedEnabled
            + " hostAvailable=" + hasValue(normalizeServerUrl(serverUrl))
        )

        if (!selectedEnabled) {
            console.log("NextNotes OnlineAccountsAuthorization enabling serviceId=" + selectedServiceId)
            selectedService.updateServiceEnabled(true)
            selectedEnabled = true
            enableThenAuthenticateTimer.start()
            return
        }

        selectedService.authenticate({})
    }

    function saveServerUrl() {
        var url = normalizeServerUrl(serverUrl)
        serverUrl = url
        accountSettings.serverUrl = url
        if (selectedAccountId > 0) {
            selectedService.updateSettings({ "host": url })
        }
    }

    function currentSetupSummary() {
        if (accountSettings.accountId <= 0) {
            return i18n.tr("No account is saved yet. Select a Nextcloud account below, authorize it, and verify access.")
        }

        return i18n.tr("%1 on %2\nproviderId=%3 serviceId=%4")
            .arg(accountSettings.displayName.length > 0 ? accountSettings.displayName : i18n.tr("Saved account"))
            .arg(accountSettings.serverUrl.length > 0 ? accountSettings.serverUrl : i18n.tr("server URL missing"))
            .arg(accountSettings.providerId.length > 0 ? accountSettings.providerId : "-")
            .arg(accountSettings.serviceId.length > 0 ? accountSettings.serviceId : "-")
    }

    function displayAccountName() {
        if (selectedDisplayName.length > 0) {
            return selectedDisplayName
        }
        if (accountSettings.displayName.length > 0) {
            return accountSettings.displayName
        }
        return i18n.tr("No account selected")
    }

    function displayServerUrl() {
        var url = normalizeServerUrl(serverUrl)
        if (url.length > 0) {
            return url
        }
        if (accountSettings.serverUrl.length > 0) {
            return accountSettings.serverUrl
        }
        return i18n.tr("Server URL missing")
    }

    function accountReady() {
        return (selectedAccountId > 0 || accountSettings.accountId > 0)
            && displayServerUrl() !== i18n.tr("Server URL missing")
    }

    function accountInitial() {
        var name = displayAccountName()
        if (name.length === 0 || name === i18n.tr("No account selected")) {
            return "?"
        }
        return name.charAt(0).toUpperCase()
    }

    function normalizeServerUrl(value) {
        return AuthCore.normalizeServerUrl(value)
    }

    function objectKeys(value) {
        return AuthCore.objectKeys(value)
    }

    function firstValue(value, names) {
        return AuthCore.firstValue(value, names)
    }

    function hasValue(value) {
        return AuthCore.hasValue(value)
    }
}
