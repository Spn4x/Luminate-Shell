// 1. Include GIO FIRST before any Qt headers can define the 'signals' macro
#include <gio/gio.h>

#include "LauncherBackend.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusMetaType>
#include <QDBusPendingCallWatcher>
#include <QProcess>
#include <QGuiApplication>
#include <QClipboard>
#include <QDebug>

LauncherBackend::LauncherBackend(const QString& widgetName, QObject *parent) : QObject(parent) {
    qDBusRegisterMetaType<SearchResult>();
    qDBusRegisterMetaType<QList<SearchResult>>();

    QString busName = "com.meismeric.luminate.widgets." + widgetName;
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerService(busName);
    bus.registerObject("/com/meismeric/luminate/widget", this, QDBusConnection::ExportAllSlots);
}

void LauncherBackend::clearState() {
    m_results.clear();
    emit resultsChanged();
}

void LauncherBackend::setMode(int mode) {
    if (m_currentMode != mode) {
        m_currentMode = mode;
        emit modeChanged();
    }
}

void LauncherBackend::query(const QString& text) {
    if (text.trimmed().isEmpty() && m_currentMode != 2) {
        m_results.clear();
        emit resultsChanged();
        return;
    }

    QString method = (m_currentMode == 2) ? "QueryClipboard" : "Query";
    QString payloadText = text;
    if (m_currentMode == 1) payloadText = "> " + text; 

    QDBusMessage msg = QDBusMessage::createMethodCall(
        "com.meismeric.luminate.Search", 
        "/com/meismeric/luminate/Search", 
        "com.meismeric.luminate.Search", 
        method
    );
    msg << payloadText;

    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(call, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *watcher) {
        QDBusPendingReply<QList<SearchResult>> reply = *watcher;
        if (!reply.isError()) {
            QVariantList newResults;
            QList<SearchResult> list = reply.value();
            for (const auto& item : list) {
                QVariantMap map;
                map["type"] = item.type;
                map["title"] = item.title;
                map["desc"] = item.desc;
                map["icon"] = item.icon;
                map["payload"] = item.payload;
                newResults.append(map);
            }
            m_results = newResults;
            emit resultsChanged();
        } else {
            qWarning() << "D-Bus Query Error:" << reply.error().message();
        }
        watcher->deleteLater();
    });
}

void LauncherBackend::launchApp(const QString& desktopId) {
    GList *all_apps = g_app_info_get_all();
    GAppInfo *target_app = nullptr;

    for (GList *l = all_apps; l != nullptr; l = l->next) {
        if (g_strcmp0(g_app_info_get_id(G_APP_INFO(l->data)), desktopId.toUtf8().constData()) == 0) {
            target_app = G_APP_INFO(l->data);
            break;
        }
    }

    if (target_app) {
        // THE FIX: Use GAppLaunchContext. This tells GLib to properly spawn 
        // the app detached and daemonized through the desktop environment.
        GAppLaunchContext *context = g_app_launch_context_new();
        GError *error = nullptr;
        g_app_info_launch(target_app, nullptr, context, &error);
        if (error) {
            qWarning() << "Launch failed:" << error->message;
            g_error_free(error);
        }
        g_object_unref(context);
    } else {
        // Fallback
        QProcess::startDetached("dex", {desktopId});
    }
    g_list_free_full(all_apps, g_object_unref);
}

void LauncherBackend::activateResult(int index) {
    if (index < 0 || index >= m_results.size()) return;

    QVariantMap res = m_results[index].toMap();
    uint type = res["type"].toUInt();
    QString payload = res["payload"].toString();

    if (type == 0) { 
        launchApp(payload);
    } else if (type == 1) { 
        QGuiApplication::clipboard()->setText(payload);
    } else if (type == 2) { 
        // THE FIX: Detached shell spawn so it survives Luminate's state switch.
        QProcess::startDetached("sh", QStringList() << "-c" << payload);
    } else if (type == 3) { 
        QDBusMessage msg = QDBusMessage::createMethodCall("com.meismeric.luminate.Search", "/com/meismeric/luminate/Search", "com.meismeric.luminate.Search", "SetClipboardItem");
        msg << payload;
        QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
    }
}

void LauncherBackend::deleteClipboardItem(int index) {
    if (index < 0 || index >= m_results.size() || m_currentMode != 2) return;
    QString payload = m_results[index].toMap()["payload"].toString();
    
    QDBusMessage msg = QDBusMessage::createMethodCall("com.meismeric.luminate.Search", "/com/meismeric/luminate/Search", "com.meismeric.luminate.Search", "DeleteClipboardItem");
    msg << payload;
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}