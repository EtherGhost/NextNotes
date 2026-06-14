import QtQuick 2.7
import Ubuntu.OnlineAccounts 0.1
import Qt.labs.settings 1.0
import "AuthCore.js" as AuthCore

Item {
    id: adapter

    property bool pendingServiceHandle: false
    property int cachedAccountId: 0
    property string cachedServiceId: ""
    property string cachedServerUrl: ""
    property string cachedUserName: ""
    property string cachedSecret: ""
    property int currentAccountId: 0
    property string currentProviderId: ""
    property string currentServiceId: ""
    property string currentServerUrl: ""
    property bool envTestAuthEnabled: typeof desktopTestAuthEnabled !== "undefined" && desktopTestAuthEnabled
    property string envTestServerUrl: typeof desktopTestServerUrl !== "undefined" ? desktopTestServerUrl : ""
    property string envTestUserName: typeof desktopTestUserName !== "undefined" ? desktopTestUserName : ""
    property string envTestSecret: typeof desktopTestSecret !== "undefined" ? desktopTestSecret : ""

    signal authenticated(string userName, string secret, string serverUrl)
    signal failed(string message)

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

        onCountChanged: {
            if (adapter.pendingServiceHandle) {
                adapter.authenticate()
            }
        }
    }

    AccountService {
        id: accountService

        onAuthenticated: {
            var data = reply && reply.data ? reply.data : reply
            var userName = adapter.firstValue(data, ["UserName", "Username", "userName", "username"])
            var secret = adapter.firstValue(data, ["Secret", "Password", "password", "secret"])
            var token = adapter.firstValue(data, ["AccessToken", "Token", "token"])

            console.log(
                "NextNotes NotesApi auth success"
                + " accountId=" + adapter.effectiveAccountId()
                + " providerId=" + adapter.effectiveProviderId()
                + " serviceId=" + adapter.effectiveServiceId()
                + " dataKeys=" + adapter.objectKeys(data).join(",")
                + " hasUserName=" + adapter.hasValue(userName)
                + " hasPasswordOrSecret=" + adapter.hasValue(secret)
                + " hasToken=" + adapter.hasValue(token)
            )

            if (!userName || !secret) {
                adapter.failed(i18n.tr("Authentication succeeded, but username or password was not available."))
                return
            }

            adapter.cachedAccountId = adapter.effectiveAccountId()
            adapter.cachedServiceId = adapter.effectiveServiceId()
            adapter.cachedServerUrl = adapter.normalizeServerUrl(adapter.effectiveServerUrl())
            adapter.cachedUserName = userName
            adapter.cachedSecret = secret

            adapter.authenticated(userName, secret, adapter.cachedServerUrl)
        }

        onAuthenticationError: {
            var message = error && error.message ? error.message : JSON.stringify(error)
            console.log(
                "NextNotes NotesApi auth error"
                + " accountId=" + adapter.effectiveAccountId()
                + " providerId=" + adapter.effectiveProviderId()
                + " serviceId=" + adapter.effectiveServiceId()
                + " message=" + message
            )
            adapter.failed(i18n.tr("Authentication failed: %1").arg(message))
        }
    }

    function authenticate() {
        if (envTestAuthEnabled) {
            var testServerUrl = normalizeServerUrl(envTestServerUrl)
            if (testServerUrl.length === 0 || envTestUserName.length === 0 || envTestSecret.length === 0) {
                failed(i18n.tr("Desktop test credentials are incomplete."))
                return
            }

            cachedAccountId = -1
            cachedServiceId = "desktop-test-env"
            cachedServerUrl = testServerUrl
            cachedUserName = envTestUserName
            cachedSecret = envTestSecret
            console.log("NextNotes NotesApi auth using desktop test environment credentials serverUrlConfigured=" + hasValue(testServerUrl))
            authenticated(cachedUserName, cachedSecret, cachedServerUrl)
            return
        }

        if (effectiveAccountId() <= 0 || effectiveServiceId().length === 0) {
            failed(i18n.tr("No account selected. Open Account first and authorize a Nextcloud account."))
            return
        }

        var serverUrl = normalizeServerUrl(effectiveServerUrl())
        if (serverUrl.length === 0) {
            failed(i18n.tr("No server URL configured. Open Account and enter the server URL."))
            return
        }

        if (hasCachedCredentials(serverUrl)) {
            console.log(
                "NextNotes NotesApi auth reused in-memory credentials"
                + " accountId=" + effectiveAccountId()
                + " providerId=" + effectiveProviderId()
                + " serviceId=" + effectiveServiceId()
                + " serverUrlConfigured=" + hasValue(serverUrl)
            )
            authenticated(cachedUserName, cachedSecret, cachedServerUrl)
            return
        }

        var handle = findSelectedAccountService()
        if (!handle) {
            if (accountServices.count === 0) {
                pendingServiceHandle = true
                failed(i18n.tr("Waiting for Online Accounts..."))
            } else {
                failed(i18n.tr("Selected Online Accounts service was not found. Open Account and verify the account again."))
            }
            return
        }

        pendingServiceHandle = false
        accountService.objectHandle = handle
        console.log(
            "NextNotes NotesApi auth requesting"
            + " accountId=" + effectiveAccountId()
            + " providerId=" + effectiveProviderId()
            + " serviceId=" + effectiveServiceId()
            + " serverUrlConfigured=" + hasValue(serverUrl)
        )
        accountService.authenticate({})
    }

    function setAccount(accountId, providerId, serviceId, serverUrl) {
        var normalizedServerUrl = normalizeServerUrl(serverUrl)
        var accountChanged = currentAccountId !== accountId
            || currentProviderId !== (providerId || "")
            || currentServiceId !== (serviceId || "")
            || currentServerUrl !== normalizedServerUrl

        if (accountChanged) {
            pendingServiceHandle = false
            pendingCallback = null
            cachedAccountId = 0
            cachedServiceId = ""
            cachedServerUrl = ""
            cachedUserName = ""
            cachedSecret = ""
            accountService.objectHandle = null
        }

        currentAccountId = accountId
        currentProviderId = providerId || ""
        currentServiceId = serviceId || ""
        currentServerUrl = normalizedServerUrl
    }

    function hasCachedCredentials(serverUrl) {
        return cachedAccountId === effectiveAccountId()
            && cachedServiceId === effectiveServiceId()
            && cachedServerUrl === serverUrl
            && cachedUserName.length > 0
            && cachedSecret.length > 0
    }

    function findSelectedAccountService() {
        for (var i = 0; i < accountServices.count; ++i) {
            if (accountServices.get(i, "accountId") === effectiveAccountId()) {
                var handle = accountServices.get(i, "accountServiceHandle")
                accountService.objectHandle = handle
                var provider = accountService.provider || {}
                var service = accountService.service || {}
                var providerId = provider.id || accountServices.get(i, "providerName")
                var serviceId = service.id || accountServices.get(i, "serviceName")

                if (providerId === effectiveProviderId() && serviceId === effectiveServiceId()) {
                    return handle
                }
            }
        }
        return null
    }

    function effectiveAccountId() {
        return currentAccountId > 0 ? currentAccountId : accountSettings.accountId
    }

    function effectiveProviderId() {
        return currentProviderId.length > 0 ? currentProviderId : accountSettings.providerId
    }

    function effectiveServiceId() {
        return currentServiceId.length > 0 ? currentServiceId : accountSettings.serviceId
    }

    function effectiveServerUrl() {
        return currentServerUrl.length > 0 ? currentServerUrl : accountSettings.serverUrl
    }

    function normalizeServerUrl(value) {
        return AuthCore.normalizeServerUrl(value)
    }

    function firstValue(value, names) {
        return AuthCore.firstValue(value, names)
    }

    function objectKeys(value) {
        return AuthCore.objectKeys(value)
    }

    function hasValue(value) {
        return AuthCore.hasValue(value)
    }
}
