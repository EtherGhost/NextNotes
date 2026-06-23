#include "ContentHubBridge.h"

#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QDir>
#include <QFile>
#include <QSettings>
#include <QSize>
#include <QString>
#include <QHash>
#include <QUrl>
#include <QtGlobal>

#ifndef NEXTNOTES_VERSION
#define NEXTNOTES_VERSION "development"
#endif

namespace {
QString environmentValue(const char *name)
{
    return QString::fromLocal8Bit(qgetenv(name)).trimmed();
}

QString unquoteEnvValue(QString value)
{
    value = value.trimmed();
    if (value.size() >= 2) {
        const QChar first = value.front();
        const QChar last = value.back();
        if ((first == QLatin1Char('"') && last == QLatin1Char('"'))
                || (first == QLatin1Char('\'') && last == QLatin1Char('\''))) {
            value = value.mid(1, value.size() - 2);
        }
    }
    return value;
}

QHash<QString, QString> readEnvFile(const QString &path)
{
    QHash<QString, QString> values;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return values;
    }

    const QString content = QString::fromUtf8(file.readAll());
    for (const QString &rawLine : content.split(QLatin1Char('\n'))) {
        const QString line = rawLine.trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#'))) {
            continue;
        }

        const int separator = line.indexOf(QLatin1Char('='));
        if (separator <= 0) {
            continue;
        }

        const QString key = line.left(separator).trimmed();
        const QString value = unquoteEnvValue(line.mid(separator + 1));
        values.insert(key, value);
    }
    return values;
}

QHash<QString, QString> readDesktopTestEnvFile()
{
    QStringList candidates;
    candidates << QDir::current().filePath(QStringLiteral(".clickable/nextnotes-desktop-env.local"));
    candidates << QDir::current().filePath(QStringLiteral(".env.test.local"));

    QDir appDir(QCoreApplication::applicationDirPath());
    for (int i = 0; i < 6; ++i) {
        candidates << appDir.filePath(QStringLiteral(".clickable/nextnotes-desktop-env.local"));
        candidates << appDir.filePath(QStringLiteral(".env.test.local"));
        appDir.cdUp();
    }

    for (const QString &candidate : candidates) {
        const QHash<QString, QString> values = readEnvFile(candidate);
        if (!values.isEmpty()) {
            return values;
        }
    }

    return {};
}

QString configValue(const QHash<QString, QString> &fileValues, const char *name)
{
    const QString env = environmentValue(name);
    if (!env.isEmpty()) {
        return env;
    }
    return fileValues.value(QString::fromLatin1(name)).trimmed();
}

QString localeForLanguageCode(const QString &languageCode)
{
    static const QHash<QString, QString> localeMap = {
        {QStringLiteral("en"), QStringLiteral("C.UTF-8")},
        {QStringLiteral("sv"), QStringLiteral("sv_SE.UTF-8")},
        {QStringLiteral("de"), QStringLiteral("de_DE.UTF-8")},
        {QStringLiteral("fr"), QStringLiteral("fr_FR.UTF-8")},
        {QStringLiteral("nl"), QStringLiteral("nl_NL.UTF-8")},
        {QStringLiteral("da"), QStringLiteral("da_DK.UTF-8")},
        {QStringLiteral("nb"), QStringLiteral("nb_NO.UTF-8")},
        {QStringLiteral("es"), QStringLiteral("es_ES.UTF-8")},
        {QStringLiteral("fi"), QStringLiteral("fi_FI.UTF-8")},
    };

    return localeMap.value(languageCode, QString());
}
}

int main(int argc, char *argv[])
{
    const bool desktopLarge = qEnvironmentVariableIsSet("CLICKABLE_DESKTOP_MODE");

    QSettings appSettings(QStringLiteral("nextnotes.cloudsite"), QStringLiteral("nextnotes.cloudsite"));
    appSettings.remove(QStringLiteral("manualAccount"));
    appSettings.sync();

    const QString languageCode = appSettings.value(QStringLiteral("languageCode")).toString();
    if (!languageCode.isEmpty()) {
        const QString localeName = localeForLanguageCode(languageCode);
        if (!localeName.isEmpty()) {
            qputenv("LANGUAGE", languageCode.toUtf8());
            qputenv("LANG", localeName.toUtf8());
        }
    }

    if (desktopLarge) {
        qputenv("QT_AUTO_SCREEN_SCALE_FACTOR", "0");
        qputenv("QT_SCALE_FACTOR", "2");
        qputenv("QT_FONT_DPI", "192");
        qputenv("GRID_UNIT_PX", "24");
    }

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nextnotes.cloudsite"));

    const QHash<QString, QString> desktopEnv = desktopLarge ? readDesktopTestEnvFile() : QHash<QString, QString>();
    const bool desktopDarkMode = desktopLarge
        && (qEnvironmentVariableIsSet("NEXTNOTES_DESKTOP_DARK_MODE")
            || configValue(desktopEnv, "NEXTNOTES_DESKTOP_DARK_MODE") == QStringLiteral("1"));

    const QString desktopTestServer = configValue(desktopEnv, "NEXTNOTES_TEST_SERVER");
    const QString desktopTestUserName = configValue(desktopEnv, "NEXTNOTES_TEST_USERNAME");
    const QString desktopTestSecret = configValue(desktopEnv, "NEXTNOTES_TEST_APP_PASSWORD");
    const bool desktopTestAuthEnabled = desktopLarge
        && configValue(desktopEnv, "NEXTNOTES_DESKTOP_TEST_AUTH") == QStringLiteral("1")
        && !desktopTestServer.isEmpty()
        && !desktopTestUserName.isEmpty()
        && !desktopTestSecret.isEmpty();

    QQuickView view;
    ContentHubBridge contentHubBridge;
    view.rootContext()->setContextProperty(QStringLiteral("nextnotesAppVersion"), QStringLiteral(NEXTNOTES_VERSION));
    view.rootContext()->setContextProperty(QStringLiteral("desktopLarge"), desktopLarge);
    view.rootContext()->setContextProperty(QStringLiteral("desktopDarkMode"), desktopDarkMode);
    view.rootContext()->setContextProperty(QStringLiteral("desktopTestAuthEnabled"), desktopTestAuthEnabled);
    view.rootContext()->setContextProperty(QStringLiteral("desktopTestServerUrl"), desktopTestAuthEnabled ? desktopTestServer : QString());
    view.rootContext()->setContextProperty(QStringLiteral("desktopTestUserName"), desktopTestAuthEnabled ? desktopTestUserName : QString());
    view.rootContext()->setContextProperty(QStringLiteral("desktopTestSecret"), desktopTestAuthEnabled ? desktopTestSecret : QString());
    view.rootContext()->setContextProperty(QStringLiteral("contentHubBridge"), &contentHubBridge);
    view.setSource(QUrl(QStringLiteral("qrc:/Main.qml")));
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    if (desktopLarge) {
        view.resize(QSize(540, 960));
    }
    view.show();
    qInfo("NextNotes desktopLarge=%s desktopDarkMode=%s desktopTestAuth=%s",
        desktopLarge ? "true" : "false",
        desktopDarkMode ? "true" : "false",
        desktopTestAuthEnabled ? "true" : "false");

    return app.exec();
}
