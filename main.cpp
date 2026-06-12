#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QSettings>
#include <QSize>
#include <QString>
#include <QHash>
#include <QUrl>
#include <QtGlobal>

namespace {
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

    QQuickView view;
    view.rootContext()->setContextProperty(QStringLiteral("desktopLarge"), desktopLarge);
    view.setSource(QUrl(QStringLiteral("qrc:/Main.qml")));
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    if (desktopLarge) {
        view.resize(QSize(1080, 1600));
    }
    view.show();
    qInfo("NextNotes desktopLarge=%s", desktopLarge ? "true" : "false");

    return app.exec();
}
