#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QDBusContext>
#include <QDBusAbstractAdaptor>
#include <QDBusArgument>
#include <QStringList>

class SystrayBackend : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)

public:
    explicit SystrayBackend(QObject *parent = nullptr);

    QVariantList items() const { return m_items; }

    Q_INVOKABLE void activateItem(const QString &busName, const QString &path, int x, int y);
    Q_INVOKABLE void contextMenu(const QString &busName, const QString &path, int x, int y);
    Q_INVOKABLE void secondaryActivate(const QString &busName, const QString &path, int x, int y);

    Q_INVOKABLE void requestMenu(const QString &busName, const QString &menuPath, int x, int y);
    Q_INVOKABLE void requestSubmenu(int id); // Populates dynamic submenus
    Q_INVOKABLE void triggerMenuEvent(const QString &busName, const QString &menuPath, int id, const QString &event);

    void handleRegisterItem(const QString &service);
    QStringList getRegisteredItems() const;

signals:
    void itemsChanged();
    void itemRegistered(const QString &service);
    void itemUnregistered(const QString &service);
    void menuReady(const QString &busName, const QString &menuPath, const QVariantMap &menuTree, int x, int y);

private slots:
    void onNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner);
    void onLayoutUpdated(uint revision, int parentId); 
    void onTraySignal(); 

private:
    void fetchIconAndAdd(const QString &busName, const QString &path);
    void finalizeIconAdd(const QString &busName, const QString &path, const QString &iconName, const QString &menuPath);
    QVariantMap parseDBusMenuNode(const QDBusArgument &arg);
    void fetchLayout();

    QVariantList m_items;
    
    QString m_activeBusName;
    QString m_activeMenuPath;
    int m_activeX = 0;
    int m_activeY = 0;
};

class StatusNotifierWatcherAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.StatusNotifierWatcher")
    Q_PROPERTY(QStringList RegisteredStatusNotifierItems READ RegisteredStatusNotifierItems)
    Q_PROPERTY(bool IsStatusNotifierHostRegistered READ IsStatusNotifierHostRegistered)
    Q_PROPERTY(int ProtocolVersion READ ProtocolVersion)

public:
    explicit StatusNotifierWatcherAdaptor(SystrayBackend *parent);

    QStringList RegisteredStatusNotifierItems() const;
    bool IsStatusNotifierHostRegistered() const { return true; }
    int ProtocolVersion() const { return 1; }

public slots:
    void RegisterStatusNotifierItem(const QString &service);
    void RegisterStatusNotifierHost(const QString &service);

signals:
    void StatusNotifierItemRegistered(const QString &service);
    void StatusNotifierItemUnregistered(const QString &service);

private:
    SystrayBackend *m_backend;
};