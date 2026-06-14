import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Ubuntu.OnlineAccounts 0.1
import Lomiri.OnlineAccounts.Client 0.1
import Qt.labs.settings 1.0
import "../backend/AuthCore.js" as AuthCore

Page {
    id: page

    property var notesController

    readonly property string appApplicationId: "nextnotes.cloudsite_nextnotes"
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
    property string pendingServerUrlAction: ""
    property bool authorizationRunning: false
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
        property string avatarUrl: ""
    }

    AccountServiceModel {
        id: accountServices
        includeDisabled: true

        onCountChanged: {
            page.updateVisibleCloudAccounts()
            Qt.callLater(page.restoreSelectedAccountFromSettings)
        }
    }

    AccountService {
        id: selectedService

        onAuthenticated: {
            page.authorizationRunning = false
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

            if (page.displayServerUrlIsMissing()) {
                page.authorizationStatus = i18n.tr("Authorization succeeded, but the Ubuntu Touch account did not expose a server address for NextNotes.")
            } else {
                page.authorizationStatus = i18n.tr("Authorization succeeded for %1. Credentials are available to the app, but were not displayed or stored.")
                    .arg(page.selectedProviderId)
            }
            accountSettings.accountId = page.selectedAccountId
            accountSettings.displayName = page.selectedDisplayName
            accountSettings.providerId = page.selectedProviderId
            accountSettings.serviceId = page.selectedServiceId
            accountSettings.serverUrl = page.normalizeServerUrl(page.serverUrl)
            accountSettings.avatarUrl = page.avatarUrl(accountSettings.serverUrl, userName)
            if (page.notesController && page.notesController.applyAccountSelection) {
                page.notesController.applyAccountSelection(
                    accountSettings.accountId,
                    accountSettings.displayName,
                    accountSettings.providerId,
                    accountSettings.serviceId,
                    accountSettings.serverUrl,
                    accountSettings.avatarUrl
                )
            }
        }

        onAuthenticationError: {
            page.authorizationRunning = false
            var message = error && error.message ? error.message : JSON.stringify(error)
            console.log(
                "NextNotes OnlineAccountsAuthorization error"
                + " accountId=" + page.selectedAccountId
                + " providerId=" + page.selectedProviderId
                + " serviceId=" + page.selectedServiceId
                + " serviceTypeId=" + page.selectedServiceTypeId
                + " message=" + message
            )
            if (message.indexOf("AppArmor policy prevents") >= 0 || message.indexOf("AccessDenied") >= 0) {
                page.authorizationStatus = i18n.tr("NextNotes is not allowed to use this account yet. Open Ubuntu Touch System Settings > Accounts, select the Nextcloud account, allow NextNotes, then return here and select the account again.")
                page.clearSelectedAccount()
            } else {
                page.authorizationStatus = i18n.tr("Authorization failed: %1. If the system did not show an Online Accounts prompt, open System Settings > Accounts and allow NextNotes for this account, then try again.")
                    .arg(message)
            }
        }
    }

    AccountService {
        id: visibleCountService
    }

    Setup {
        id: accountSetup
        applicationId: page.appApplicationId
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
                page.authorizationStatus = i18n.tr("System account authorization completed. Verifying access...")
                enableThenAuthenticateTimer.start()
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

    Timer {
        id: serverUrlCommitTimer
        interval: 80
        repeat: false
        onTriggered: {
            page.serverUrl = serverUrlField.text
            page.saveServerUrl()
            var action = page.pendingServerUrlAction
            page.pendingServerUrlAction = ""
            if (action === "authorize") {
                page.authorizeSelectedAccountAfterCommit()
            } else if (action === "authenticate") {
                page.authenticateSelectedAccountAfterCommit()
            }
        }
    }

    Component.onCompleted: Qt.callLater(function() {
        page.updateVisibleCloudAccounts()
        page.restoreSelectedAccountFromSettings()
    })

    Flickable {
        id: pageFlickable
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(2)
            topMargin: header.height + units.gu(2)
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
                text: i18n.tr("Server address")
                font.bold: true
                elide: Text.ElideRight
            }

            TextField {
                id: serverUrlField
                Layout.fillWidth: true
                placeholderText: i18n.tr("https://cloud.example.com")
                text: page.serverUrl.length > 0 ? page.serverUrl : accountSettings.serverUrl
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                onTextChanged: page.serverUrl = text
                onAccepted: page.commitServerUrlInput("")
            }

            Label {
                Layout.fillWidth: true
                text: i18n.tr("The account still comes from Ubuntu Touch Online Accounts. Edit this only if the system account did not expose the correct server address.")
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                opacity: 0.68
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
                    property bool isAppService: rowServiceId === page.nextcloudServiceId || rowServiceId === page.owncloudServiceId
                    property bool isGenericCloudService: rowServiceId.length === 0
                        || rowServiceId === rowProviderId
                        || rowServiceId === row.role("serviceName")
                            && rowServiceTypeId.length === 0
                    property bool isSelected: (page.selectedAccountId === row.role("accountId")
                            && page.selectedServiceId === rowServiceId)
                        || (page.selectedAccountId <= 0
                            && accountSettings.accountId === row.role("accountId")
                            && accountSettings.serviceId === rowServiceId)

                    height: visible ? units.gu(7) : 0
                    visible: isCloudAccount && (isAppService || isGenericCloudService)
                    color: row.isSelected ? Qt.rgba(0.17, 0.5, 0.72, 0.16) : "transparent"

                    enabled: !page.authorizationRunning

                    onClicked: {
                        if (page.authorizationRunning) {
                            return
                        }

                        page.selectAccount(
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

                    RowLayout {
                        id: content
                        x: units.gu(1)
                        y: 0
                        width: Math.max(0, row.width - units.gu(2))
                        height: row.height
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

                            Label {
                                Layout.fillWidth: true
                                text: row.isAppService
                                    ? (row.role("enabled") ? i18n.tr("Allowed for NextNotes") : i18n.tr("Allow NextNotes in Ubuntu Touch account settings first"))
                                    : i18n.tr("Nextcloud account discovered")
                                textSize: Label.Small
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                opacity: row.isAppService && row.role("enabled") ? 0.72 : 0.9
                            }
                        }
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                text: page.authorizationRunning ? i18n.tr("Verifying account...") : i18n.tr("Verify selected account")
                enabled: page.selectedAccountId > 0 && !page.authorizationRunning
                onClicked: page.authenticateSelectedAccount()
            }

            Label {
                Layout.fillWidth: true
                text: authorizationStatus
                wrapMode: Text.WordWrap
                maximumLineCount: 5
                opacity: 0.82
            }
        }
    }

    function selectAccount(handle, accountId, displayName, providerName, providerId, serviceName, serviceId, serviceTypeId, enabled) {
        var appService = findPreferredAppService(accountId, providerId)
        if (appService.handle) {
            handle = appService.handle
            serviceName = appService.serviceName
            serviceId = appService.serviceId
            serviceTypeId = appService.serviceTypeId
            enabled = appService.enabled
        }

        selectedService.objectHandle = handle
        selectedAccountId = accountId
        selectedDisplayName = displayName
        selectedProviderName = providerName
        selectedProviderId = providerId
        selectedServiceName = serviceName
        selectedServiceId = serviceId
        selectedServiceTypeId = serviceTypeId
        selectedEnabled = enabled

        var resolvedServerUrl = findServerUrlForAccount(accountId, displayName)
        serverUrl = normalizeServerUrl(resolvedServerUrl)
        serverUrlField.text = serverUrl

        console.log(
            "NextNotes OnlineAccountsSelection selected"
            + " accountId=" + selectedAccountId
            + " providerId=" + selectedProviderId
            + " serviceId=" + selectedServiceId
            + " serviceTypeId=" + selectedServiceTypeId
            + " enabled=" + selectedEnabled
            + " hostAvailable=" + hasValue(serverUrl)
            + " preferredAppService=" + (appService.handle ? true : false)
        )

        authorizationStatus = i18n.tr("Selected %1. Verifying authorization...")
            .arg(selectedDisplayName)
        page.commitServerUrlInput("authenticate")
    }

    function findPreferredAppService(accountId, providerId) {
        var expectedServiceId = providerId === "owncloud" ? owncloudServiceId : nextcloudServiceId
        for (var i = 0; i < accountServices.count; ++i) {
            if (accountServices.get(i, "accountId") !== accountId) {
                continue
            }

            var handle = accountServices.get(i, "accountServiceHandle")
            if (!handle) {
                continue
            }

            visibleCountService.objectHandle = handle
            var provider = visibleCountService.provider || {}
            var service = visibleCountService.service || {}
            var rowProviderId = provider.id || accountServices.get(i, "providerName")
            var rowServiceId = service.id || accountServices.get(i, "serviceName")
            if (rowProviderId === providerId && rowServiceId === expectedServiceId) {
                return {
                    "handle": handle,
                    "serviceName": accountServices.get(i, "serviceName"),
                    "serviceId": rowServiceId,
                    "serviceTypeId": service.serviceTypeId || service.type || "",
                    "enabled": accountServices.get(i, "enabled")
                }
            }
        }

        return {}
    }

    function restoreSelectedAccountFromSettings() {
        if (selectedAccountId > 0 || accountSettings.accountId <= 0 || accountSettings.providerId.length === 0) {
            return
        }

        var appService = findPreferredAppService(accountSettings.accountId, accountSettings.providerId)
        if (!appService.handle) {
            return
        }

        selectedService.objectHandle = appService.handle
        selectedAccountId = accountSettings.accountId
        selectedDisplayName = accountSettings.displayName
        selectedProviderId = accountSettings.providerId
        selectedProviderName = accountSettings.providerId
        selectedServiceName = appService.serviceName
        selectedServiceId = appService.serviceId
        selectedServiceTypeId = appService.serviceTypeId
        selectedEnabled = appService.enabled
        serverUrl = normalizeServerUrl(accountSettings.serverUrl)
        serverUrlField.text = serverUrl
        authorizationStatus = i18n.tr("Saved account selected. Verify again if needed.")
    }

    function findServerUrlForAccount(accountId, displayName) {
        var selectedUrl = serverUrlFromCurrentService()
        if (selectedUrl.length > 0) {
            return selectedUrl
        }

        for (var i = 0; i < accountServices.count; ++i) {
            if (accountServices.get(i, "accountId") !== accountId) {
                continue
            }

            var handle = accountServices.get(i, "accountServiceHandle")
            if (!handle) {
                continue
            }

            visibleCountService.objectHandle = handle
            var url = serverUrlFromService(visibleCountService)
            if (url.length > 0) {
                return url
            }
        }

        var inferredUrl = inferServerUrlFromDisplayName(displayName)
        if (inferredUrl.length > 0) {
            return inferredUrl
        }

        if (accountSettings.accountId === accountId) {
            return normalizeServerUrl(accountSettings.serverUrl)
        }

        return ""
    }

    function serverUrlFromCurrentService() {
        return serverUrlFromService(selectedService)
    }

    function serverUrlFromService(serviceObject) {
        var settings = serviceObject.settings || {}
        var account = serviceObject.account || {}
        var provider = serviceObject.provider || {}
        var values = [
            settings.host,
            settings.Host,
            settings.server,
            settings.serverUrl,
            settings.url,
            settings.Url,
            account.host,
            account.Host,
            account.server,
            account.serverUrl,
            account.url,
            provider.host,
            provider.server,
            provider.serverUrl,
            provider.url
        ]

        for (var i = 0; i < values.length; ++i) {
            var url = normalizeServerUrl(values[i])
            if (url.length > 0) {
                return url
            }
        }

        return ""
    }

    function inferServerUrlFromDisplayName(displayName) {
        var value = String(displayName || "").trim()
        var atIndex = value.lastIndexOf("@")
        if (atIndex < 0 || atIndex === value.length - 1) {
            return ""
        }

        var host = value.slice(atIndex + 1)
        host = host.replace(/[<>()\[\],;]/g, "").trim()
        return normalizeServerUrl(host)
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
            var cloudAppService = serviceId === nextcloudServiceId || serviceId === owncloudServiceId
            var genericCloudService = serviceId.length === 0
                || serviceId === providerId
                || serviceId === accountServices.get(i, "serviceName") && (service.serviceTypeId || service.type || "").length === 0
            if (cloud && (cloudAppService || genericCloudService)) {
                count += 1
            }
        }
        visibleCloudAccounts = count
    }

    function authorizeSelectedAccount() {
        page.commitServerUrlInput("authenticate")
    }

    function authorizeSelectedAccountAfterCommit() {
        if (selectedAccountId <= 0) {
            authorizationStatus = i18n.tr("Select an account first.")
            return
        }

        authenticateSelectedAccountAfterCommit()
    }

    function authenticateSelectedAccount() {
        page.commitServerUrlInput("authenticate")
    }

    function authenticateSelectedAccountAfterCommit() {
        if (selectedAccountId <= 0) {
            authorizationStatus = i18n.tr("Select an account first.")
            return
        }

        refreshSelectedServiceHandle()
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
            page.authorizationRunning = false
            console.log(
                "NextNotes OnlineAccountsAuthorization service-not-enabled"
                + " accountId=" + selectedAccountId
                + " providerId=" + selectedProviderId
                + " serviceId=" + selectedServiceId
            )
            authorizationStatus = i18n.tr("This account is not allowed for NextNotes yet. Open Ubuntu Touch System Settings > Accounts, select the Nextcloud account, allow NextNotes, then return here and select the account again.")
            clearSelectedAccount()
            return
        }
        page.authorizationRunning = true

        selectedService.authenticate({})
    }

    function clearSelectedAccount() {
        page.authorizationRunning = false
        selectedService.objectHandle = null
        selectedAccountId = 0
        selectedDisplayName = ""
        selectedProviderName = ""
        selectedProviderId = ""
        selectedServiceName = ""
        selectedServiceId = ""
        selectedServiceTypeId = ""
        selectedEnabled = false
    }

    function commitServerUrlInput(action) {
        pendingServerUrlAction = action || ""
        Qt.inputMethod.commit()
        serverUrlField.focus = false
        serverUrlCommitTimer.restart()
    }

    function refreshSelectedServiceHandle() {
        if (selectedAccountId <= 0 || selectedProviderId.length === 0) {
            return
        }

        var appService = findPreferredAppService(selectedAccountId, selectedProviderId)
        if (!appService.handle) {
            return
        }

        selectedService.objectHandle = appService.handle
        selectedServiceName = appService.serviceName
        selectedServiceId = appService.serviceId
        selectedServiceTypeId = appService.serviceTypeId
        selectedEnabled = appService.enabled
    }

    function saveServerUrl() {
        var url = normalizeServerUrl(serverUrl)
        serverUrl = url
        accountSettings.serverUrl = url
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
        return i18n.tr("The selected Ubuntu Touch account did not expose a server address.")
    }

    function displayServerUrlIsMissing() {
        if (selectedAccountId > 0) {
            return normalizeServerUrl(serverUrl).length === 0
        }
        return normalizeServerUrl(accountSettings.serverUrl).length === 0
    }

    function accountReady() {
        return (selectedAccountId > 0 || accountSettings.accountId > 0)
            && !displayServerUrlIsMissing()
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

    function avatarUrl(serverUrl, userName) {
        if (!serverUrl || !userName) {
            return ""
        }
        return String(serverUrl).replace(/\/+$/, "") + "/index.php/avatar/" + encodeURIComponent(userName) + "/64"
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
