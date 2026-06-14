#include "SystrayBackend.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusObjectPath>
#include <QDBusVariant>
#include <QVariantMap>
#include <QDebug>

StatusNotifierWatcherAdaptor::StatusNotifierWatcherAdaptor(SystrayBackend *parent)
    : QDBusAbstractAdaptor(parent), m_backend(parent) {
    connect(m_backend, &SystrayBackend::itemRegistered, this, &StatusNotifierWatcherAdaptor::StatusNotifierItemRegistered);
    connect(m_backend, &SystrayBackend::itemUnregistered, this, &StatusNotifierWatcherAdaptor::StatusNotifierItemUnregistered);
}

QStringList StatusNotifierWatcherAdaptor::RegisteredStatusNotifierItems() const { return m_backend->getRegisteredItems(); }
void StatusNotifierWatcherAdaptor::RegisterStatusNotifierItem(const QString &service) { m_backend->handleRegisterItem(service); }
void StatusNotifierWatcherAdaptor::RegisterStatusNotifierHost(const QString &service) { Q_UNUSED(service); }

SystrayBackend::SystrayBackend(QObject *parent) : QObject(parent) {
    new StatusNotifierWatcherAdaptor(this);

    QDBusConnection session = QDBusConnection::sessionBus();
    if (!session.registerService("org.kde.StatusNotifierWatcher")) {
        qWarning() << "[!] SYSTRAY ERROR: Could not claim org.kde.StatusNotifierWatcher.";
    } else {
        session.registerObject("/StatusNotifierWatcher", this);
    }

    session.connect("", "", "org.freedesktop.DBus", "NameOwnerChanged", this, SLOT(onNameOwnerChanged(QString,QString,QString)));
    
    session.connect("", "", "org.kde.StatusNotifierItem", "NewIcon", this, SLOT(onTraySignal()));
    session.connect("", "", "org.kde.StatusNotifierItem", "NewStatus", this, SLOT(onTraySignal()));
    session.connect("", "", "org.kde.StatusNotifierItem", "NewAttentionIcon", this, SLOT(onTraySignal()));
}

void SystrayBackend::onTraySignal() {
    QString busName = message().service();
    QString path = message().path();
    fetchIconAndAdd(busName, path); 
}

void SystrayBackend::handleRegisterItem(const QString &service) {
    QString busName = service;
    QString path = "/StatusNotifierItem";
    
    if (service.startsWith("/")) {
        busName = message().service();
        path = service;
    }
    fetchIconAndAdd(busName, path);
    emit itemRegistered(service);
}

QStringList SystrayBackend::getRegisteredItems() const {
    QStringList list;
    for (const QVariant &v : m_items) {
        list << v.toMap()["busName"].toString();
    }
    return list;
}

void SystrayBackend::fetchIconAndAdd(const QString &busName, const QString &path) {
    QDBusMessage msg = QDBusMessage::createMethodCall(busName, path, "org.freedesktop.DBus.Properties", "GetAll");
    msg << "org.kde.StatusNotifierItem";
    
    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(call, this);
    
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, busName, path](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QVariantMap> reply = *w;
        QString iconName = "application-x-executable";
        QString menuPath = "";

        if (reply.isValid()) {
            QVariantMap props = reply.value();
            QString status = props.contains("Status") ? props["Status"].toString() : "";
            
            if (status == "NeedsAttention" && props.contains("AttentionIconName")) {
                iconName = props["AttentionIconName"].toString();
            } else if (props.contains("IconName")) {
                iconName = props["IconName"].toString();
            } else if (props.contains("Id")) {
                iconName = props["Id"].toString();
            }

            if (props.contains("Menu")) {
                QVariant v = props["Menu"];
                if (v.userType() == qMetaTypeId<QDBusObjectPath>()) menuPath = v.value<QDBusObjectPath>().path();
                else menuPath = v.toString();
            }
        }
        finalizeIconAdd(busName, path, iconName, menuPath);
        w->deleteLater();
    });
}

void SystrayBackend::finalizeIconAdd(const QString &busName, const QString &path, const QString &iconName, const QString &menuPath) {
    for (int i = 0; i < m_items.size(); ++i) {
        QVariantMap item = m_items[i].toMap();
        if (item["busName"].toString() == busName) {
            item["iconName"] = iconName;
            if (!menuPath.isEmpty()) item["menuPath"] = menuPath;
            m_items[i] = item;
            emit itemsChanged();
            return;
        }
    }
    QVariantMap item;
    item["busName"] = busName;
    item["path"] = path;
    item["iconName"] = iconName;
    item["menuPath"] = menuPath;
    m_items.append(item);
    emit itemsChanged();
}

void SystrayBackend::onNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner) {
    Q_UNUSED(oldOwner);
    if (newOwner.isEmpty()) {
        for (int i = 0; i < m_items.size(); ++i) {
            if (m_items[i].toMap()["busName"].toString() == name) {
                m_items.removeAt(i);
                emit itemsChanged();
                emit itemUnregistered(name);
                break;
            }
        }
    }
}

void SystrayBackend::activateItem(const QString &busName, const QString &path, int x, int y) {
    QDBusMessage msg = QDBusMessage::createMethodCall(busName, path, "org.kde.StatusNotifierItem", "Activate");
    msg << x << y; QDBusConnection::sessionBus().asyncCall(msg);
}

void SystrayBackend::contextMenu(const QString &busName, const QString &path, int x, int y) {
    QDBusMessage msg = QDBusMessage::createMethodCall(busName, path, "org.kde.StatusNotifierItem", "ContextMenu");
    msg << x << y; QDBusConnection::sessionBus().asyncCall(msg);
}

void SystrayBackend::secondaryActivate(const QString &busName, const QString &path, int x, int y) {
    QDBusMessage msg = QDBusMessage::createMethodCall(busName, path, "org.kde.StatusNotifierItem", "SecondaryActivate");
    msg << x << y; QDBusConnection::sessionBus().asyncCall(msg);
}

void SystrayBackend::requestMenu(const QString &busName, const QString &menuPath, int x, int y) {
    m_activeBusName = busName; m_activeMenuPath = menuPath; m_activeX = x; m_activeY = y;
    QDBusConnection::sessionBus().disconnect(QString(), QString(), "com.canonical.dbusmenu", "LayoutUpdated", this, SLOT(onLayoutUpdated(uint, int)));
    QDBusConnection::sessionBus().connect(busName, menuPath, "com.canonical.dbusmenu", "LayoutUpdated", this, SLOT(onLayoutUpdated(uint, int)));
    QDBusMessage aboutMsg = QDBusMessage::createMethodCall(busName, menuPath, "com.canonical.dbusmenu", "AboutToShow");
    aboutMsg << 0;
    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(aboutMsg);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) { w->deleteLater(); fetchLayout(); });
}

void SystrayBackend::requestSubmenu(int id) {
    if (m_activeBusName.isEmpty() || m_activeMenuPath.isEmpty()) return;

    // FIX 2: We must send the "opened" Event payload, otherwise nm-applet refuses to populate the Wi-Fi array!
    QDBusMessage eventMsg = QDBusMessage::createMethodCall(m_activeBusName, m_activeMenuPath, "com.canonical.dbusmenu", "Event");
    eventMsg << id << "opened" << QVariant::fromValue(QDBusVariant(QVariant(QString("")))) << (uint)0;
    QDBusConnection::sessionBus().asyncCall(eventMsg);

    QDBusMessage aboutMsg = QDBusMessage::createMethodCall(m_activeBusName, m_activeMenuPath, "com.canonical.dbusmenu", "AboutToShow");
    aboutMsg << id;
    
    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(aboutMsg);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(call, this);
    
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        fetchLayout(); 
    });
}

void SystrayBackend::onLayoutUpdated(uint revision, int parentId) { Q_UNUSED(revision); Q_UNUSED(parentId); fetchLayout(); }

void SystrayBackend::fetchLayout() {
    if (m_activeBusName.isEmpty() || m_activeMenuPath.isEmpty()) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(m_activeBusName, m_activeMenuPath, "com.canonical.dbusmenu", "GetLayout");
    msg << 0 << -1 << QStringList();
    
    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(call, this);
    
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<> reply = *w; 
        
        if (!reply.isError()) {
            QDBusMessage replyMsg = reply.reply();
            if (replyMsg.arguments().size() >= 2) {
                QDBusArgument arg = replyMsg.arguments().at(1).value<QDBusArgument>();
                QVariantMap tree = parseDBusMenuNode(arg);
                emit menuReady(m_activeBusName, m_activeMenuPath, tree, m_activeX, m_activeY);
            }
        }
        w->deleteLater();
    });
}

void SystrayBackend::triggerMenuEvent(const QString &busName, const QString &menuPath, int id, const QString &event) {
    QDBusMessage msg = QDBusMessage::createMethodCall(busName, menuPath, "com.canonical.dbusmenu", "Event");
    msg << id << event << QVariant::fromValue(QDBusVariant(QVariant(QString("")))) << (uint)0;
    QDBusConnection::sessionBus().asyncCall(msg);
}

QVariantMap SystrayBackend::parseDBusMenuNode(const QDBusArgument &arg) {
    QVariantMap node; int id = 0; QVariantMap props; QVariantList children;
    if (arg.currentType() == QDBusArgument::StructureType) {
        arg.beginStructure(); arg >> id >> props; arg.beginArray();
        while (!arg.atEnd()) {
            QVariant childVar; arg >> childVar; QDBusArgument childArg; bool found = false;
            if (childVar.userType() == qMetaTypeId<QDBusArgument>()) { childArg = childVar.value<QDBusArgument>(); found = true; }
            else if (childVar.userType() == qMetaTypeId<QDBusVariant>()) {
                QVariant inner = childVar.value<QDBusVariant>().variant();
                if (inner.userType() == qMetaTypeId<QDBusArgument>()) { childArg = inner.value<QDBusArgument>(); found = true; }
            }
            if (found) children.append(parseDBusMenuNode(childArg));
        }
        arg.endArray(); arg.endStructure();
    }
    node["id"] = id; node["props"] = props; node["children"] = children; return node;
}