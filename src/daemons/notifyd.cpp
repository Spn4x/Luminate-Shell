#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusAbstractAdaptor>
#include <QDBusInterface>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QSettings>
#include <QDir>
#include <QDebug>
#include <QRandomGenerator>

class NotifyAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")
public:
    explicit NotifyAdaptor(QObject *parent) : QDBusAbstractAdaptor(parent) {
        QDir().mkpath(QDir::homePath() + "/.local/share/luminate-shell");
        m_db = QSqlDatabase::addDatabase("QSQLITE");
        m_db.setDatabaseName(QDir::homePath() + "/.local/share/luminate-shell/luminate_notifications.db");
        if (m_db.open()) {
            QSqlQuery q(m_db);
            q.exec("CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY AUTOINCREMENT, app_name TEXT, summary TEXT, body TEXT, icon TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);");
        }

        QSettings s(QDir::homePath() + "/.config/luminate-shell/notify_settings.conf", QSettings::IniFormat);
        m_dnd = s.value("General/DND", false).toBool();
        
        m_ui = new QDBusInterface("com.meismeric.luminate.UI", "/com/meismeric/luminate/UI", "com.meismeric.luminate.UI", QDBusConnection::sessionBus(), this);
        m_center = new QDBusInterface("com.meismeric.luminate.Center", "/com/meismeric/luminate/Center", "com.meismeric.luminate.Center", QDBusConnection::sessionBus(), this);
    }

signals:
    void ActionInvoked(uint id, const QString &action_key);
    void NotificationClosed(uint id, uint reason);
    void DNDStateChanged(bool is_active);

public slots:
    uint Notify(const QString &app_name, uint replaces_id, const QString &app_icon, const QString &summary, const QString &body, const QStringList &actions, const QVariantMap &hints, int expire_timeout) {
        Q_UNUSED(hints); Q_UNUSED(expire_timeout);
        uint id = replaces_id > 0 ? replaces_id : QRandomGenerator::global()->generate();

        QSqlQuery q(m_db);
        q.prepare("INSERT INTO history (app_name, summary, body, icon) VALUES (?, ?, ?, ?)");
        q.addBindValue(app_name); q.addBindValue(summary); q.addBindValue(body); q.addBindValue(app_icon);
        q.exec();

        if (!m_centerVisible && !m_dnd) m_ui->asyncCall("ShowNotification", id, app_icon, summary, body, actions);
        m_center->asyncCall("AddNotification", app_icon, app_name, summary, body);
        
        return id;
    }

    void InvokeAction(uint id, const QString &action_key) { emit ActionInvoked(id, action_key); }
    void CloseNotification(uint id) { emit NotificationClosed(id, 3); }
    QStringList GetCapabilities() { return {"body", "actions"}; }
    
    // THE FIX: Provide exact FDO D-Bus specification types (4 independent strings instead of a variant array)
    QString GetServerInformation(QString &vendor, QString &version, QString &spec_version) {
        vendor = "meismeric";
        version = "1.0";
        spec_version = "1.2";
        return "luminate-notify";
    }
    
    void SetDND(bool active) { if(m_dnd != active) { m_dnd = active; saveDnd(); emit DNDStateChanged(m_dnd); } }
    void ToggleDND() { m_dnd = !m_dnd; saveDnd(); emit DNDStateChanged(m_dnd); }
    bool GetDNDState() { return m_dnd; }
    void SetCenterVisible(bool visible) { m_centerVisible = visible; }

private:
    QSqlDatabase m_db;
    QDBusInterface *m_ui, *m_center;
    bool m_dnd = false;
    bool m_centerVisible = false;

    void saveDnd() {
        QSettings s(QDir::homePath() + "/.config/luminate-shell/notify_settings.conf", QSettings::IniFormat);
        s.setValue("General/DND", m_dnd);
    }
};

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    NotifyAdaptor adaptor(&app);
    QDBusConnection::sessionBus().registerService("org.freedesktop.Notifications");
    QDBusConnection::sessionBus().registerObject("/org/freedesktop/Notifications", &app);
    qDebug() << "luminate-notifyd: FDO Notification server running.";
    return app.exec();
}
#include "notifyd.moc"