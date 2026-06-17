#include "NotificationBackend.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusPendingCallWatcher>
#include <QDBusVariant>
#include <QDBusArgument>
#include <QDBusMetaType>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDateTime>
#include <QTimeZone>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QCryptographicHash>
#include <QProcess>
#include <QUrl>
#include <QThread>
#include <csignal>
#include <cstdlib>

NotificationBackend::NotificationBackend(QObject *parent) : QObject(parent) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerService("com.meismeric.luminate.UI");
    bus.registerObject("/com/meismeric/luminate/UI", this, QDBusConnection::ExportAllSlots);

    setupMediaManager();
    updateSystemInfo();
    
    // --- SQLITE HISTORY SETUP ---
    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", "history_db");
    db.setDatabaseName(QDir::homePath() + "/.local/share/luminate-shell/luminate_notifications.db");
    if (db.open()) fetchNotificationHistory();

    // --- DND DBUS SETUP ---
    bus.connect("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "DNDStateChanged", this, SLOT(onDndStateChanged(bool)));
    QDBusMessage dndMsg = QDBusMessage::createMethodCall("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "GetDNDState");
    QDBusReply<bool> dndReply = bus.call(dndMsg);
    if (dndReply.isValid()) m_dndMode = dndReply.value();

    connect(&m_positionTimer, &QTimer::timeout, this, &NotificationBackend::fetchPosition);
    m_positionTimer.start(1000);

    bus.connect(
        "com.meismeric.SurfaceDesk", "/com/meismeric/SurfaceDesk",
        "org.freedesktop.DBus.Properties", "PropertiesChanged",
        this, SLOT(onSurfaceDeskPropsChanged(QString, QVariantMap, QStringList))
    );

    QDBusMessage msg = QDBusMessage::createMethodCall("com.meismeric.SurfaceDesk", "/com/meismeric/SurfaceDesk", "org.freedesktop.DBus.Properties", "GetAll");
    msg << "com.meismeric.SurfaceDesk";
    
    QDBusPendingCall call = bus.asyncCall(msg);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QVariantMap> reply = *w;
        if (reply.isValid()) {
            QVariantMap props = reply.value();
            if (props.contains("themeMap")) {
                QVariant val = props["themeMap"];
                if (val.userType() == qMetaTypeId<QDBusArgument>()) m_themeData = qdbus_cast<QVariantMap>(val.value<QDBusArgument>());
                else m_themeData = val.toMap();
                emit themeChanged();
            }
            if (props.contains("currentWallpaper")) {
                m_currentWallpaper = props["currentWallpaper"].toString();
                emit currentWallpaperChanged();
            }
            if (props.contains("confirmedWallpaper")) {
                m_confirmedWallpaper = props["confirmedWallpaper"].toString();
                emit confirmedWallpaperChanged();
            }
            if (props.contains("isPickingWallpaper")) {
                m_isPickingWallpaper = props["isPickingWallpaper"].toBool();
                emit isPickingWallpaperChanged();
                updateDisplayMode();
            }
            if (props.contains("wallpaperList")) {
                m_wallpaperList = props["wallpaperList"].toStringList();
                emit wallpaperListChanged();
            }
            if (props.contains("currentResolution")) {
                m_currentResolution = props["currentResolution"].toString();
                emit currentResolutionChanged();
            }
            if (props.contains("wallpaperPalette")) {
                m_wallpaperPalette = props["wallpaperPalette"].toStringList();
                emit wallpaperPaletteChanged();
            }
        }
        w->deleteLater();
    });
}

// --- NEW SMART GROUPED NOTIFICATION METHODS ---
void NotificationBackend::fetchNotificationHistory() {
    QVariantList history;
    QSqlDatabase db = QSqlDatabase::database("history_db");
    if (!db.isOpen()) return;
    
    QSqlQuery q(db);
    q.exec("SELECT id, app_name, summary, body, icon, timestamp FROM history ORDER BY timestamp DESC LIMIT 50");
    
    QList<QString> appOrder;
    QMap<QString, QVariantMap> appGroups;
    
    while (q.next()) {
        QString appName = q.value(1).toString();
        if (appName.isEmpty()) appName = "System";
        
        QVariantMap notif;
        notif["id"] = q.value(0).toInt();
        notif["summary"] = q.value(2).toString();
        notif["body"] = q.value(3).toString();
        
        QString iconStr = q.value(4).toString();
        notif["icon"] = iconStr;
        
        QString ts = q.value(5).toString();
        QDateTime dt = QDateTime::fromString(ts, "yyyy-MM-dd HH:mm:ss");
        dt.setTimeZone(QTimeZone::utc()); 
        notif["time"] = dt.toLocalTime().toString("hh:mm AP");
        
        if (!appGroups.contains(appName)) {
            appOrder.append(appName);
            QVariantMap group;
            group["appName"] = appName;
            group["icon"] = iconStr;
            group["latestTime"] = notif["time"];
            group["notifications"] = QVariantList();
            appGroups[appName] = group;
        }
        
        QVariantMap group = appGroups[appName];
        QVariantList list = group["notifications"].toList();
        list.append(notif);
        group["notifications"] = list;
        group["count"] = list.size();
        appGroups[appName] = group;
    }
    
    for (const QString& appName : appOrder) {
        history.append(appGroups[appName]);
    }
    
    m_notificationHistory = history;
    emit notificationHistoryChanged();
}

void NotificationBackend::clearNotificationHistory() {
    QSqlDatabase db = QSqlDatabase::database("history_db");
    if (db.isOpen()) {
        QSqlQuery q(db);
        q.exec("DELETE FROM history");
        fetchNotificationHistory();
    }
}

void NotificationBackend::onDndStateChanged(bool active) {
    if (m_dndMode != active) {
        m_dndMode = active;
        emit dndModeChanged();
    }
}

void NotificationBackend::toggleDndMode() {
    QDBusMessage msg = QDBusMessage::createMethodCall("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "ToggleDND");
    QDBusConnection::sessionBus().asyncCall(msg);
}

void NotificationBackend::onSurfaceDeskPropsChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated) {
    Q_UNUSED(interface);
    Q_UNUSED(invalidated);
    
    bool changedTheme = false;
    bool changedWallpaper = false;
    bool changedConfirmed = false;
    bool changedPicking = false;
    bool changedList = false;
    bool changedResolution = false;
    bool changedPalette = false;

    if (changed.contains("themeMap")) {
        QVariant val = changed["themeMap"];
        if (val.userType() == qMetaTypeId<QDBusArgument>()) m_themeData = qdbus_cast<QVariantMap>(val.value<QDBusArgument>());
        else m_themeData = val.toMap();
        changedTheme = true;
    }
    if (changed.contains("currentWallpaper")) {
        m_currentWallpaper = changed["currentWallpaper"].toString();
        changedWallpaper = true;
    }
    if (changed.contains("confirmedWallpaper")) {
        m_confirmedWallpaper = changed["confirmedWallpaper"].toString();
        changedConfirmed = true;
    }
    if (changed.contains("isPickingWallpaper")) {
        m_isPickingWallpaper = changed["isPickingWallpaper"].toBool();
        changedPicking = true;
    }
    if (changed.contains("wallpaperList")) {
        m_wallpaperList = changed["wallpaperList"].toStringList();
        changedList = true;
    }
    if (changed.contains("currentResolution")) {
        m_currentResolution = changed["currentResolution"].toString();
        changedResolution = true;
    }
    if (changed.contains("wallpaperPalette")) {
        m_wallpaperPalette = changed["wallpaperPalette"].toStringList();
        changedPalette = true;
    }

    if (changedTheme) emit themeChanged();
    if (changedWallpaper) emit currentWallpaperChanged();
    if (changedConfirmed) emit confirmedWallpaperChanged();
    if (changedPicking) {
        emit isPickingWallpaperChanged();
        updateDisplayMode(); 
    }
    if (changedList) emit wallpaperListChanged();
    if (changedResolution) emit currentResolutionChanged();
    if (changedPalette) emit wallpaperPaletteChanged(); 
}

void NotificationBackend::updateSystemInfo() {
    m_sysOsName = "Linux";
    QFile osRelease("/etc/os-release");
    if (osRelease.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&osRelease);
        while (!in.atEnd()) {
            QString line = in.readLine();
            if (line.startsWith("PRETTY_NAME=")) {
                m_sysOsName = line.mid(12).remove('"');
                break;
            }
        }
        osRelease.close();
    }

    m_sysUptime = "0 minutes";
    QFile uptimeFile("/proc/uptime");
    if (uptimeFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&uptimeFile);
        QString line = in.readLine();
        double uptimeSecs = line.split(" ").first().toDouble();
        
        int days = uptimeSecs / 86400;
        int hours = ((int)uptimeSecs % 86400) / 3600;
        int mins = ((int)uptimeSecs % 3600) / 60;
        
        QStringList parts;
        if (days > 0) parts << QString::number(days) + (days == 1 ? " day" : " days");
        if (hours > 0) parts << QString::number(hours) + (hours == 1 ? " hour" : " hours");
        if (mins > 0 || parts.isEmpty()) parts << QString::number(mins) + (mins == 1 ? " minute" : " minutes");
        
        m_sysUptime = parts.join(", ");
        uptimeFile.close();
    }
    emit systemInfoChanged();
}

void NotificationBackend::setIsExpanded(bool expanded) {
    if (m_isExpanded != expanded) {
        m_isExpanded = expanded;
        emit isExpandedChanged();
    }
}

void NotificationBackend::ShowNotification(uint id, const QString &icon, const QString &summary, const QString &body, const QStringList &actions) {
    NotificationData data;
    data.id = id;
    data.icon = icon;
    data.summary = summary;
    data.body = body;

    for (int i = 0; i < actions.size() - 1; i += 2) {
        QString actionId = actions[i];
        QString actionLabel = actions[i+1];
        if (actionId != "default") {
            data.actions.append(QVariantMap{{"id", actionId}, {"label", actionLabel}});
        }
    }

    m_queue.enqueue(data);
    fetchNotificationHistory(); 
    emit queueChanged();
    
    if (!m_isShowingNotif) processNext();
}

void NotificationBackend::SetPrivacyStatus(const QString &payload) {
    QJsonDocument doc = QJsonDocument::fromJson(payload.toUtf8());
    if (!doc.isArray()) return;
    
    QJsonArray arr = doc.array();

    for (int i = m_ignoredPids.size() - 1; i >= 0; --i) {
        uint igPid = m_ignoredPids[i];
        bool stillRunning = false;
        for (int j = 0; j < arr.size(); ++j) {
            if (arr[j].toObject()["pid"].toInt() == (int)igPid) { stillRunning = true; break; }
        }
        if (!stillRunning) m_ignoredPids.removeAt(i);
    }

    for (int i = m_ignoredNames.size() - 1; i >= 0; --i) {
        QString igName = m_ignoredNames[i];
        bool stillRunning = false;
        for (int j = 0; j < arr.size(); ++j) {
            QJsonObject obj = arr[j].toObject();
            if (obj["pid"].toInt() == 0 && obj["name"].toString() == igName) { stillRunning = true; break; }
        }
        if (!stillRunning) m_ignoredNames.removeAt(i);
    }
    
    QVariantList apps;
    bool globalHasMic = false, globalHasCam = false;

    for (int i = 0; i < arr.size(); ++i) {
        QJsonObject obj = arr[i].toObject();
        uint pid = obj["pid"].toInt();
        QString name = obj["name"].toString();
        int type = obj["type"].toInt();
        
        if (pid > 0 && m_ignoredPids.contains(pid)) continue;
        if (pid == 0 && m_ignoredNames.contains(name)) continue;

        if (type == 0) globalHasMic = true;
        if (type == 1) globalHasCam = true;

        bool found = false;
        for (int j = 0; j < apps.size(); ++j) {
            QVariantMap existing = apps[j].toMap();
            if ((pid > 0 && existing["pid"].toUInt() == pid) || (pid == 0 && existing["name"].toString() == name)) {
                if (type == 0) existing["hasMic"] = true;
                if (type == 1) existing["hasCam"] = true;
                apps[j] = existing;
                found = true;
                break;
            }
        }

        if (!found) {
            QVariantMap app;
            app["pid"] = pid;
            app["name"] = name;
            app["hasMic"] = (type == 0);
            app["hasCam"] = (type == 1);
            apps.append(app);
        }
    }

    m_privacyApps = apps;
    m_privacyHasMic = globalHasMic;
    m_privacyHasCam = globalHasCam;

    if (apps.isEmpty()) m_privacySummary = "";
    else if (apps.size() == 1) m_privacySummary = apps.first().toMap()["name"].toString() + " is active";
    else m_privacySummary = QString::number(apps.size()) + " Apps active";

    emit privacyChanged();
    updateDisplayMode();
}

void NotificationBackend::ShowOSD(const QString &icon, double level) { 
    if (m_isExpanded) return; 

    m_osdIcon = icon;
    m_osdLevel = level;
    m_isShowingOsd = true;
    
    emit osdChanged();
    updateDisplayMode();
}

void NotificationBackend::UpdateMediaInfo(const QString &playerName, const QString &title, const QString &artist, const QString &artUrl, const QString &status) {
    m_activePlayerName = playerName;
    bool changed = false;
    bool trackChanged = false;
    
    if (m_mediaTitle != title || m_mediaArtist != artist) { 
        m_mediaTitle = title; 
        m_mediaArtist = artist; 
        trackChanged = true;
        changed = true; 
        fetchDuration();
    }
    
    if (m_mediaStatus != status) { m_mediaStatus = status; changed = true; }
    
    if (m_originalArtUrl != artUrl) {
        if (artUrl.isEmpty() && !trackChanged && !m_mediaArt.isEmpty()) {
            // Keep art
        } else {
            m_originalArtUrl = artUrl;
            
            if (artUrl.isEmpty()) {
                m_mediaArt = "";
                changed = true;
            } else if (artUrl.startsWith("file://")) {
                QUrl url(artUrl);
                QString localPath = url.toLocalFile();
                m_mediaArt = QFile::exists(localPath) ? "file://" + localPath : "";
                changed = true;
            } else if (artUrl.startsWith("http://") || artUrl.startsWith("https://")) {
                QString checksum = QString(QCryptographicHash::hash(artUrl.toUtf8(), QCryptographicHash::Sha256).toHex());
                QString cacheDir = QDir::homePath() + "/.cache/luminate-shell/art";
                QDir().mkpath(cacheDir);
                QString cachePath = cacheDir + "/" + checksum;

                if (QFile::exists(cachePath)) {
                    m_mediaArt = "file://" + cachePath;
                    changed = true;
                } else {
                    m_mediaArt = ""; 
                    changed = true;
                    
                    QProcess *proc = new QProcess(this);
                    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, proc, cachePath](int exitCode, QProcess::ExitStatus exitStatus) {
                        if (exitStatus == QProcess::NormalExit && exitCode == 0 && QFile::exists(cachePath)) {
                            m_mediaArt = "file://" + cachePath;
                            emit mediaChanged();
                        }
                        proc->deleteLater();
                    });
                    proc->start("curl", QStringList() << "-s" << "-L" << "-o" << cachePath << artUrl);
                }
            } else {
                m_mediaArt = "";
                changed = true;
            }
        }
    }
    
    if (changed) {
        emit mediaChanged();
        updateDisplayMode(); 
    }
}

void NotificationBackend::fetchPosition() {
    if (m_activePlayerName.isEmpty() || m_mediaStatus != "Playing" || !m_isExpanded) return;
    
    QDBusMessage msg = QDBusMessage::createMethodCall(m_activePlayerName, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "Get");
    msg << "org.mpris.MediaPlayer2.Player" << "Position";
    
    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QDBusVariant> reply = *w;
        if (!reply.isError()) {
            qint64 posUs = reply.value().variant().toLongLong();
            m_mediaPosition = posUs / 1000000;
            emit positionChanged();
        }
        w->deleteLater();
    });
}

void NotificationBackend::fetchDuration() {
    if (m_activePlayerName.isEmpty()) return;
    
    QDBusMessage msg = QDBusMessage::createMethodCall(m_activePlayerName, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "Get");
    msg << "org.mpris.MediaPlayer2.Player" << "Metadata";
    
    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QDBusVariant> reply = *w;
        if (!reply.isError()) {
            QVariantMap meta = qdbus_cast<QVariantMap>(reply.value().variant().value<QDBusArgument>());
            if (meta.contains("mpris:length")) {
                m_mediaDuration = meta["mpris:length"].toLongLong() / 1000000;
                emit durationChanged();
            }
        }
        w->deleteLater();
    });
}

void NotificationBackend::TriggerMediaPeek() {
    if (m_isShowingNotif || m_isShowingOsd || !m_privacyApps.isEmpty() || !m_screenshotState.isEmpty() || m_isShowingLauncher || m_isPickingWallpaper || m_isShowingFan || m_isShowingPolkit) return; 
    
    m_displayMode = "media";
    emit displayModeChanged();
    emit requestShow(); 
}

void NotificationBackend::TriggerSystemPeek() {
    if (m_isShowingNotif || m_isShowingOsd || !m_privacyApps.isEmpty() || !m_screenshotState.isEmpty() || m_isShowingLauncher || m_isPickingWallpaper || hasMedia() || m_isShowingFan || m_isShowingPolkit) return;
    
    updateSystemInfo();
    m_isShowingSystem = true;
    updateDisplayMode();
}

void NotificationBackend::processNext() {
    if (!m_queue.isEmpty() && !m_isShowingNotif) {
        m_current = m_queue.dequeue();
        m_isShowingNotif = true;
        emit queueChanged();
        emit notificationChanged();
    } else if (m_queue.isEmpty() && !m_isShowingNotif) {
        m_current = NotificationData();
        emit notificationChanged();
    }
    updateDisplayMode();
}

void NotificationBackend::readyForNext() {
    if (m_displayMode == "screenshot_info" || m_displayMode == "screenshot_edit" || m_displayMode == "launcher" || m_displayMode == "wallpaper" || m_displayMode == "fan" || m_displayMode == "polkit") {
        return; 
    }
    
    if (m_displayMode == "osd") m_isShowingOsd = false;
    else if (m_displayMode == "notification") m_isShowingNotif = false;
    else if (m_displayMode == "system") m_isShowingSystem = false;
    else if (m_displayMode == "media") {
        if (!m_mediaPinned) {
            m_displayMode = "idle";
            emit displayModeChanged();
            emit requestHide();
        }
        return;
    }
    processNext();
}

void NotificationBackend::closeNotification() {
    m_isShowingNotif = false;
    processNext();
}

void NotificationBackend::invokeAction(const QString& actionId) {
    QDBusMessage msg = QDBusMessage::createMethodCall("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "InvokeAction");
    msg << m_current.id << actionId;
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}

void NotificationBackend::killPrivacyApp(uint pid, const QString& name) {
    if (pid > 0) kill(pid, SIGTERM);
    else if (!name.isEmpty()) {
        QString safeName = name.split(" ").first();
        QString cmd = QString("pkill -i '%1'").arg(safeName);
        system(cmd.toUtf8().constData());
    }
    ignorePrivacyApp(pid, name); 
}

void NotificationBackend::killAllPrivacyApps() {
    for (const QVariant& v : m_privacyApps) {
        QVariantMap map = v.toMap();
        uint pid = map["pid"].toUInt();
        QString name = map["name"].toString();
        if (pid > 0) kill(pid, SIGTERM);
        else if (!name.isEmpty()) {
            QString safeName = name.split(" ").first();
            QString cmd = QString("pkill -i '%1'").arg(safeName);
            system(cmd.toUtf8().constData());
        }
    }
    m_privacyApps.clear();
    m_privacySummary = "";
    m_privacyHasMic = false;
    m_privacyHasCam = false;
    emit privacyChanged();
    updateDisplayMode();
}

void NotificationBackend::ignorePrivacyApp(uint pid, const QString& name) {
    if (pid > 0) m_ignoredPids.append(pid);
    else if (!name.isEmpty()) m_ignoredNames.append(name);
    
    QVariantList filtered;
    bool globalHasMic = false, globalHasCam = false;
    for (const QVariant& v : m_privacyApps) {
        QVariantMap map = v.toMap();
        uint mPid = map["pid"].toUInt();
        QString mName = map["name"].toString();
        
        if (mPid > 0 && m_ignoredPids.contains(mPid)) continue;
        if (mPid == 0 && m_ignoredNames.contains(mName)) continue;
        
        if (map["hasMic"].toBool()) globalHasMic = true;
        if (map["hasCam"].toBool()) globalHasCam = true;
        filtered.append(map);
    }
    
    m_privacyApps = filtered;
    m_privacyHasMic = globalHasMic;
    m_privacyHasCam = globalHasCam;
    
    if (filtered.isEmpty()) m_privacySummary = "";
    else if (filtered.size() == 1) m_privacySummary = filtered.first().toMap()["name"].toString() + " is active";
    else m_privacySummary = QString::number(filtered.size()) + " Apps active";

    emit privacyChanged();
    updateDisplayMode();
}

void NotificationBackend::setupMediaManager() {
    QDBusConnection::sessionBus().connect(
        "com.meismeric.luminate.MediaManager", "/com/meismeric/luminate/MediaManager",
        "org.freedesktop.DBus.Properties", "PropertiesChanged",
        this, SLOT(onMediaManagerPropsChanged(QString, QVariantMap, QStringList))
    );

    QDBusMessage msg = QDBusMessage::createMethodCall("com.meismeric.luminate.MediaManager", "/com/meismeric/luminate/MediaManager", "org.freedesktop.DBus.Properties", "GetAll");
    msg << "com.meismeric.luminate.MediaManager";
    QDBusReply<QVariantMap> reply = QDBusConnection::sessionBus().call(msg);
    if (reply.isValid()) {
        QVariantMap props = reply.value();
        if (props.contains("CurrentLyrics")) parseLyrics(props["CurrentLyrics"].toString());
        if (props.contains("CurrentLyricIndex")) {
            m_currentLyricIndex = props["CurrentLyricIndex"].toInt();
            emit lyricIndexChanged();
        }
    }
}

void NotificationBackend::onMediaManagerPropsChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated) {
    Q_UNUSED(interface); Q_UNUSED(invalidated);
    if (changed.contains("CurrentLyrics")) parseLyrics(changed["CurrentLyrics"].toString());
    if (changed.contains("CurrentLyricIndex")) {
        m_currentLyricIndex = changed["CurrentLyricIndex"].toInt();
        emit lyricIndexChanged();
    }
}

void NotificationBackend::parseLyrics(const QString& lrc) {
    if (lrc == m_rawLyricsCache) return;
    m_rawLyricsCache = lrc;

    m_parsedLyrics.clear();
    QRegularExpression re("\\[\\d{2}:\\d{2}[.:]\\d{2,3}\\](.*)");
    QStringList lines = lrc.split('\n');
    for (const QString& line : lines) {
        QRegularExpressionMatch match = re.match(line);
        if (match.hasMatch()) {
            QString text = match.captured(1).trimmed();
            m_parsedLyrics.append(text);
        }
    }
    emit lyricsTextChanged();
}

QString NotificationBackend::mediaCurrentLyric() const {
    if (m_currentLyricIndex >= 0 && m_currentLyricIndex < m_parsedLyrics.size()) {
        return m_parsedLyrics[m_currentLyricIndex];
    }
    return "";
}

void NotificationBackend::mediaPlayPause() {
    if (m_activePlayerName.isEmpty()) return;
    QDBusMessage msg = QDBusMessage::createMethodCall(m_activePlayerName, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "PlayPause");
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}

void NotificationBackend::mediaNext() {
    if (m_activePlayerName.isEmpty()) return;
    QDBusMessage msg = QDBusMessage::createMethodCall(m_activePlayerName, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Next");
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}

void NotificationBackend::mediaPrev() {
    if (m_activePlayerName.isEmpty()) return;
    QDBusMessage msg = QDBusMessage::createMethodCall(m_activePlayerName, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Previous");
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}

void NotificationBackend::setMediaPinned(bool pinned) {
    if (m_mediaPinned != pinned) {
        m_mediaPinned = pinned;
        emit mediaPinnedChanged();
        updateDisplayMode();
    }
}

void NotificationBackend::fetchNiriWindows() {
    QProcess proc;
    proc.start("sh", {"-c", "niri msg -j windows"});
    proc.waitForFinished();
    
    QVariantList windows;
    QJsonDocument doc = QJsonDocument::fromJson(proc.readAllStandardOutput());
    for (const QJsonValue& val : doc.array()) {
        QJsonObject win = val.toObject();
        if (win.contains("workspace_id")) {
            QVariantMap wMap;
            wMap["id"] = QString::number(win["id"].toVariant().toULongLong());
            wMap["title"] = win["title"].toString();
            wMap["app_id"] = win["app_id"].toString();
            windows.append(wMap);
        }
    }
    m_niriWindows = windows;
    emit niriWindowsChanged();
}

void NotificationBackend::captureNiriWindow(const QString& winId, bool annotate) {
    cancelScreenshot(); 
    QProcess::execute("sh", {"-c", QString("niri msg action focus-window --id %1").arg(winId)});
    
    QTimer::singleShot(400, this, [this, annotate]() {
        QProcess::execute("niri", {"msg", "action", "screenshot-window"});
        
        if (annotate) {
            QTimer::singleShot(400, this, [this]() {
                m_tempScreenshotPath = QDir::tempPath() + "/qscreen_overlay.png";
                QProcess::execute("sh", {"-c", QString("wl-paste -t image/png > \"%1\"").arg(m_tempScreenshotPath)});
                emit windowScreenshotReady(m_tempScreenshotPath);
                expandScreenshotToEdit(); 
            });
        } else {
            QProcess::execute("notify-send", {"Screenshot Captured", "Window copied to clipboard."});
        }
    });
}

void NotificationBackend::runOcrAsync() {
    QProcess *proc = new QProcess(this);
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, proc]() {
        QString out = proc->readAllStandardOutput();
        QVariantList results;
        QStringList lines = out.split('\n');
        
        for (int i = 1; i < lines.size(); ++i) {
            QStringList fields = lines[i].split('\t');
            if (fields.size() >= 12 && fields[0].toInt() == 5) {
                if (fields[10].toInt() > 50 && !fields[11].trimmed().isEmpty()) {
                    QVariantMap box;
                    box["x"] = fields[6].toInt();
                    box["y"] = fields[7].toInt();
                    box["width"] = fields[8].toInt();
                    box["height"] = fields[9].toInt();
                    box["text"] = fields[11];
                    results.append(box);
                }
            }
        }
        m_ocrResults = results;
        emit ocrResultsChanged();
        proc->deleteLater();
    });
    proc->start("sh", {"-c", QString("tesseract \"%1\" stdout -l eng --psm 11 tsv").arg(m_tempScreenshotPath)});
}

void NotificationBackend::copyTextToClipboard(const QString& text) {
    QProcess proc;
    proc.start("wl-copy");
    proc.write(text.toUtf8());
    proc.closeWriteChannel();
    proc.waitForFinished();
    QProcess::execute("notify-send", {"Text Copied", "Selected text is on your clipboard."});
}

void NotificationBackend::closeLauncher() {
    m_isShowingLauncher = false;
    updateDisplayMode();
}

void NotificationBackend::closeFan() {
    m_isShowingFan = false;
    updateDisplayMode();
}

void NotificationBackend::selectWallpaper(const QString &path) {
    QDBusMessage msg = QDBusMessage::createMethodCall("com.meismeric.SurfaceDesk", "/com/meismeric/SurfaceDesk", "com.meismeric.SurfaceDesk", "setWallpaper");
    msg << path;
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}

void NotificationBackend::commitWallpaper() {
    QDBusMessage msg = QDBusMessage::createMethodCall("com.meismeric.SurfaceDesk", "/com/meismeric/SurfaceDesk", "com.meismeric.SurfaceDesk", "commitWallpaper");
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}

void NotificationBackend::cancelWallpaper() {
    QDBusMessage msg = QDBusMessage::createMethodCall("com.meismeric.SurfaceDesk", "/com/meismeric/SurfaceDesk", "com.meismeric.SurfaceDesk", "cancelWallpaper");
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}

void NotificationBackend::triggerLauncherFlow() {
    if (m_isShowingPolkit) emit forceCancelPolkit();
    m_isShowingFan = false;
    m_isPickingWallpaper = false;
    m_screenshotState = "";
    m_isShowingLauncher = true;
    updateDisplayMode(); 
}

void NotificationBackend::triggerFanFlow() {
    if (m_isShowingPolkit) emit forceCancelPolkit();
    m_isShowingLauncher = false;
    m_isPickingWallpaper = false;
    m_screenshotState = "";
    m_isShowingFan = true;
    updateDisplayMode();
}

void NotificationBackend::triggerScreenshotFlow() {
    if (m_isShowingPolkit) emit forceCancelPolkit();
    m_isShowingLauncher = false;
    m_isShowingFan = false;
    m_isPickingWallpaper = false;
    m_screenshotState = "hidden";
    updateDisplayMode();

    m_tempScreenshotPath = QDir::tempPath() + "/qscreen_overlay.png";
    QProcess::execute("grim", {m_tempScreenshotPath});

    m_screenshotState = "info";
    emit screenshotStateChanged();
    updateDisplayMode();
}

void NotificationBackend::expandScreenshotToEdit() {
    if (m_isShowingPolkit) emit forceCancelPolkit();
    m_screenshotState = "edit";
    emit screenshotStateChanged();
    updateDisplayMode();
}

void NotificationBackend::cancelScreenshot() {
    m_screenshotState = "";
    emit screenshotStateChanged();
    updateDisplayMode();
}

void NotificationBackend::toggleWallpaperMode() {
    if (m_isShowingPolkit) emit forceCancelPolkit();
    m_isShowingLauncher = false;
    m_isShowingFan = false;
    m_screenshotState = "";
    QDBusMessage msg = QDBusMessage::createMethodCall("com.meismeric.SurfaceDesk", "/com/meismeric/SurfaceDesk", "com.meismeric.SurfaceDesk", "ToggleWallpaperMode");
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}

void NotificationBackend::handlePolkitRequested(const QString &message) {
    Q_UNUSED(message);
    if (m_displayMode != "polkit") {
        m_prePolkitMode = m_displayMode;
        emit prePolkitModeChanged();
    }
    m_isShowingPolkit = true;
    updateDisplayMode();
}

void NotificationBackend::handlePolkitResolved(bool success) {
    Q_UNUSED(success);
    m_isShowingPolkit = false;
    updateDisplayMode();
}

void NotificationBackend::removeNotificationHistory(int id) {
    QSqlDatabase db = QSqlDatabase::database("history_db");
    if (db.isOpen()) {
        QSqlQuery q(db);
        q.prepare("DELETE FROM history WHERE id = ?");
        q.addBindValue(id);
        q.exec();
        fetchNotificationHistory(); // Instantly updates the UI
    }
}

void NotificationBackend::removeNotificationGroup(const QString& appName) {
    QSqlDatabase db = QSqlDatabase::database("history_db");
    if (db.isOpen()) {
        QSqlQuery q(db);
        if (appName == "System") {
            q.exec("DELETE FROM history WHERE app_name = '' OR app_name IS NULL OR app_name = 'System'");
        } else {
            q.prepare("DELETE FROM history WHERE app_name = ?");
            q.addBindValue(appName);
            q.exec();
        }
        fetchNotificationHistory(); // Instantly updates the UI
    }
}

void NotificationBackend::updateDisplayMode() {
    QString oldMode = m_displayMode;
    bool mediaValid = !m_activePlayerName.isEmpty() && m_mediaStatus != "Stopped";

    if (m_isShowingPolkit) {
        m_displayMode = "polkit";
    } else if (m_isShowingFan) {
        m_displayMode = "fan";
    } else if (m_isShowingLauncher) {
        m_displayMode = "launcher";
    } else if (m_screenshotState == "edit") {
        m_displayMode = "screenshot_edit";
    } else if (m_screenshotState == "info") {
        m_displayMode = "screenshot_info";
    } else if (m_isPickingWallpaper) { 
        m_displayMode = "wallpaper";
    } else if (m_isShowingOsd) {
        m_displayMode = "osd";
    } else if (m_isShowingNotif) {
        m_displayMode = "notification";
    } else if (!m_privacyApps.isEmpty()) {
        m_displayMode = "privacy";
    } else if (m_isShowingSystem) {
        m_displayMode = "system";
    } else if (m_mediaPinned && mediaValid) {
        m_displayMode = "media";
    } else if (oldMode == "media" && !m_mediaPinned && mediaValid) {
        m_displayMode = "media"; 
    } else {
        m_displayMode = "idle";
    }

    if (m_displayMode != oldMode) {
        emit displayModeChanged();
        if (m_displayMode == "idle" || m_screenshotState == "hidden") {
            emit requestHide();
        } else {
            emit requestShow(); 
        }
    } else if (m_displayMode != "idle" && m_screenshotState != "hidden") {
        emit requestShow(); 
    } else {
        emit requestHide();
    }
}