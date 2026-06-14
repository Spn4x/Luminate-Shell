#include "AudioBackend.h"
#include "qdbusmetatype.h"
#include <QProcess>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusArgument>
#include <QDBusVariant>
#include <QDBusObjectPath>
#include <QUrl>
#include <QDebug>

typedef QMap<QString, QVariantMap> DBusInterfaceMap;
Q_DECLARE_METATYPE(DBusInterfaceMap)

typedef QMap<QDBusObjectPath, DBusInterfaceMap> DBusObjectMap;
Q_DECLARE_METATYPE(DBusObjectMap)

static QString getMprisString(const QVariant &var) {
    if (var.userType() == qMetaTypeId<QDBusVariant>()) {
        return getMprisString(var.value<QDBusVariant>().variant());
    }
    if (var.userType() == qMetaTypeId<QDBusObjectPath>()) {
        return var.value<QDBusObjectPath>().path();
    }
    if (var.canConvert<QUrl>()) {
        return var.toUrl().toString();
    }
    if (var.canConvert<QStringList>()) {
        QStringList list = var.toStringList();
        if (!list.isEmpty()) return list.first();
    }
    return var.toString();
}

AudioBackend::AudioBackend(QObject *parent) : QObject(parent) {
    qDBusRegisterMetaType<DBusInterfaceMap>();
    qDBusRegisterMetaType<DBusObjectMap>();

    // 1. Bluetooth BlueZ Setup
    QDBusConnection::systemBus().connect(
        "org.bluez", "", "org.freedesktop.DBus.Properties", "PropertiesChanged",
        this, SLOT(onDbusPropertiesChanged(QString, QVariantMap, QStringList)));
    
    QDBusConnection::systemBus().connect(
        "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "InterfacesAdded",
        this, SLOT(refreshBluezState()));
        
    QDBusConnection::systemBus().connect(
        "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "InterfacesRemoved",
        this, SLOT(refreshBluezState()));

    // 2. MPRIS MediaManager Setup
    QDBusConnection::sessionBus().connect(
        "com.meismeric.luminate.MediaManager", "/com/meismeric/luminate/MediaManager", 
        "org.freedesktop.DBus.Properties", "PropertiesChanged",
        this, SLOT(onDbusPropertiesChanged(QString, QVariantMap, QStringList)));

    // 3. Failsafe Polling (Fixes the Boot Race Condition)
    m_pollTimer = new QTimer(this);
    connect(m_pollTimer, &QTimer::timeout, this, &AudioBackend::pollStates);
    m_pollTimer->start(3000);

    pollStates();
}

void AudioBackend::pollStates() {
    refreshBluezState();
    refreshActivePlayer();
}

void AudioBackend::onDbusPropertiesChanged(const QString &interface, const QVariantMap &changedProps, const QStringList &invalidatedProps) {
    Q_UNUSED(changedProps);
    Q_UNUSED(invalidatedProps);
    
    if (interface.startsWith("org.bluez")) {
        refreshBluezState();
    } else if (interface == "com.meismeric.luminate.MediaManager") {
        refreshActivePlayer();
    } else if (interface == "org.mpris.MediaPlayer2.Player") {
        refreshMprisState();
    }
}

// --- BLUEZ ---
void AudioBackend::refreshBluezState() {
    QDBusMessage msg = QDBusMessage::createMethodCall("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects");
    QDBusReply<DBusObjectMap> reply = QDBusConnection::systemBus().call(msg);
    
    m_btConnected = false;
    m_btPowered = false;
    m_btBattery = -1;
    m_btName = "Unknown";

    if (reply.isValid()) {
        DBusObjectMap objects = reply.value();
        for (auto it = objects.constBegin(); it != objects.constEnd(); ++it) {
            if (it.value().contains("org.bluez.Adapter1")) {
                QVariantMap props = it.value().value("org.bluez.Adapter1");
                if (props.contains("Powered")) { m_btPowered = props.value("Powered").toBool(); break; }
            }
        }
        
        if (m_btPowered) {
            for (auto it = objects.constBegin(); it != objects.constEnd(); ++it) {
                if (it.value().contains("org.bluez.Device1")) {
                    QVariantMap devProps = it.value().value("org.bluez.Device1");
                    if (devProps.value("Connected").toBool()) {
                        m_btConnected = true;
                        if (devProps.contains("Alias")) m_btName = devProps.value("Alias").toString();
                        else if (devProps.contains("Name")) m_btName = devProps.value("Name").toString();
                        
                        if (devProps.contains("BatteryPercentage")) {
                            m_btBattery = devProps.value("BatteryPercentage").toInt();
                        } else if (it.value().contains("org.bluez.Battery1")) {
                            m_btBattery = it.value().value("org.bluez.Battery1").value("Percentage").toInt();
                        }
                        break; 
                    }
                }
            }
        }
    }
    emit btChanged();
}

// --- MPRIS ---
void AudioBackend::refreshActivePlayer() {
    QDBusMessage msg = QDBusMessage::createMethodCall("com.meismeric.luminate.MediaManager", "/com/meismeric/luminate/MediaManager", "org.freedesktop.DBus.Properties", "Get");
    msg << "com.meismeric.luminate.MediaManager" << "ActivePlayer";
    
    QDBusReply<QDBusVariant> reply = QDBusConnection::sessionBus().call(msg);
    if (reply.isValid()) setActivePlayer(reply.value().variant().toString());
    else setActivePlayer("");
}

void AudioBackend::setActivePlayer(const QString &busName) {
    if (m_activePlayerBus == busName) return;

    if (!m_activePlayerBus.isEmpty()) {
        QDBusConnection::sessionBus().disconnect(m_activePlayerBus, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged", this, SLOT(onDbusPropertiesChanged(QString, QVariantMap, QStringList)));
    }
    m_activePlayerBus = busName;
    if (!m_activePlayerBus.isEmpty()) {
        QDBusConnection::sessionBus().connect(m_activePlayerBus, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged", this, SLOT(onDbusPropertiesChanged(QString, QVariantMap, QStringList)));
    }
    refreshMprisState();
}

void AudioBackend::refreshMprisState() {
    if (m_activePlayerBus.isEmpty()) {
        m_isPlaying = false;
        m_title = "";
        m_artist = "";
        m_artUrl = "";
        emit mediaChanged();
        return;
    }

    QDBusMessage msg = QDBusMessage::createMethodCall(m_activePlayerBus, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "GetAll");
    msg << "org.mpris.MediaPlayer2.Player";
    QDBusReply<QVariantMap> reply = QDBusConnection::sessionBus().call(msg);

    if (reply.isValid()) {
        QVariantMap props = reply.value();
        m_isPlaying = (props.value("PlaybackStatus").toString() == "Playing");
        
        QVariantMap metadata;
        QVariant rawMeta = props.value("Metadata");
        if (rawMeta.userType() == qMetaTypeId<QDBusVariant>()) {
            rawMeta = rawMeta.value<QDBusVariant>().variant();
        }

        if (rawMeta.canConvert<QVariantMap>()) {
            metadata = rawMeta.toMap();
        } else if (rawMeta.canConvert<QDBusArgument>()) {
            QDBusArgument arg = rawMeta.value<QDBusArgument>();
            if (arg.currentType() == QDBusArgument::MapType) {
                arg >> metadata;
            }
        }

        m_title = getMprisString(metadata.value("xesam:title"));
        m_artUrl = getMprisString(metadata.value("mpris:artUrl"));
        
        QStringList artists;
        QVariant artistVar = metadata.value("xesam:artist");
        if (artistVar.canConvert<QStringList>()) {
            artists = artistVar.toStringList();
        } else {
            QString singleArtist = getMprisString(artistVar);
            if (!singleArtist.isEmpty()) {
                artists.append(singleArtist);
            }
        }
        m_artist = artists.isEmpty() ? "Unknown" : artists.first();

        emit mediaChanged();
    }
}

// --- PACTL ---
QString AudioBackend::getDefaultSink() { QProcess p; p.start("sh", {"-c", "pactl get-default-sink"}); p.waitForFinished(); return QString(p.readAllStandardOutput()).trimmed(); }
QString AudioBackend::getDefaultSource() { QProcess p; p.start("sh", {"-c", "pactl get-default-source"}); p.waitForFinished(); return QString(p.readAllStandardOutput()).trimmed(); }

QVariantList AudioBackend::getSinks() {
    QVariantList list;
    QString defaultSink = getDefaultSink();
    QProcess proc;
    proc.start("sh", {"-c", "pactl list sinks | grep -E 'Name:|Description:' | awk 'NR%2{printf $2 \"|\"} NR%2==0{$1=\"\"; print substr($0,2)}'"});
    proc.waitForFinished();
    QString output = proc.readAllStandardOutput();
    for (const QString &line : output.split("\n", Qt::SkipEmptyParts)) {
        QStringList parts = line.split("|");
        if (parts.size() >= 2) {
            QVariantMap item;
            item["id"] = parts[0].trimmed();
            item["name"] = parts[1].trimmed();
            QString lower = item["name"].toString().toLower();
            if (lower.contains("hdmi")) item["icon"] = "󰡁";
            else if (lower.contains("bluez") || lower.contains("headset") || lower.contains("buds")) item["icon"] = "󰋋";
            else item["icon"] = "󰕾";
            item["isActive"] = (item["id"].toString() == defaultSink);
            list.append(item);
        }
    }
    return list;
}

QVariantList AudioBackend::getSources() {
    QVariantList list;
    QString defaultSource = getDefaultSource();
    QProcess proc;
    proc.start("sh", {"-c", "pactl list sources | grep -E 'Name:|Description:' | awk 'NR%2{printf $2 \"|\"} NR%2==0{$1=\"\"; print substr($0,2)}'"});
    proc.waitForFinished();
    QString output = proc.readAllStandardOutput();
    for (const QString &line : output.split("\n", Qt::SkipEmptyParts)) {
        QStringList parts = line.split("|");
        if (parts.size() >= 2 && !parts[0].trimmed().endsWith(".monitor")) {
            QVariantMap item;
            item["id"] = parts[0].trimmed();
            item["name"] = parts[1].trimmed();
            QString lower = item["name"].toString().toLower();
            if (lower.contains("bluez") || lower.contains("headset")) item["icon"] = "󰋎";
            else item["icon"] = "󰍬";
            item["isActive"] = (item["id"].toString() == defaultSource);
            list.append(item);
        }
    }
    return list;
}

QVariantList AudioBackend::getPlayers() {
    QVariantList list;
    QDBusMessage msg = QDBusMessage::createMethodCall("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ListNames");
    QDBusReply<QStringList> reply = QDBusConnection::sessionBus().call(msg);
    if (reply.isValid()) {
        for (const QString& name : reply.value()) {
            if (name.startsWith("org.mpris.MediaPlayer2.") && !name.contains("playerctld")) {
                QString friendlyName = name.mid(23); 
                int dot = friendlyName.indexOf('.');
                if (dot != -1) friendlyName = friendlyName.left(dot);
                if (!friendlyName.isEmpty()) friendlyName[0] = friendlyName[0].toUpper();
                QVariantMap item;
                item["id"] = name;
                item["name"] = friendlyName;
                QString lower = friendlyName.toLower();
                if (lower.contains("spotify")) item["icon"] = "";
                else if (lower.contains("firefox") || lower.contains("chrome") || lower.contains("brave")) item["icon"] = "󰈹";
                else if (lower.contains("vlc")) item["icon"] = "󰕼";
                else item["icon"] = "󰎆";
                item["isActive"] = (name == m_activePlayerBus);
                list.append(item);
            }
        }
    }
    QVariantMap autoItem;
    autoItem["id"] = "";
    autoItem["name"] = "Auto-Select";
    autoItem["icon"] = "󰕾";
    autoItem["isActive"] = m_activePlayerBus.isEmpty();
    list.append(autoItem);
    return list;
}

void AudioBackend::setSink(const QString &name) { QProcess::startDetached("sh", {"-c", QString("pactl set-default-sink '%1'").arg(name)}); }
void AudioBackend::setSource(const QString &name) { QProcess::startDetached("sh", {"-c", QString("pactl set-default-source '%1'").arg(name)}); }
void AudioBackend::setPlayer(const QString &busName) {
    QDBusMessage msg = QDBusMessage::createMethodCall("com.meismeric.luminate.MediaManager", "/com/meismeric/luminate/MediaManager", "com.meismeric.luminate.MediaManager", "SelectPlayer");
    msg << busName;
    QDBusConnection::sessionBus().asyncCall(msg);
}