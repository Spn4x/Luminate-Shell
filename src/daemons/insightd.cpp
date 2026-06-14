#include <QCoreApplication>
#include <QObject>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QTimer>
#include <QDir>
#include <QFile>
#include <QDateTime>
#include <QDebug>

class InsightDaemon : public QObject {
    Q_OBJECT
public:
    InsightDaemon() {
        initDb();
        
        m_heartbeat = new QTimer(this);
        connect(m_heartbeat, &QTimer::timeout, this, &InsightDaemon::logSession);
        m_heartbeat->start(30000);

        m_niriProc = new QProcess(this);
        connect(m_niriProc, &QProcess::readyReadStandardOutput, this, &InsightDaemon::onNiriEvent);
        m_niriProc->start("niri", {"msg", "--json", "event-stream"});
    }
    ~InsightDaemon() { logSession(); }

private:
    QSqlDatabase m_db;
    QProcess *m_niriProc;
    QTimer *m_heartbeat;
    QString m_currentApp = "Unknown";
    qint64 m_focusStart = 0;

    void initDb() {
        QString dir = QDir::homePath() + "/.local/share";
        QDir().mkpath(dir);
        
        m_db = QSqlDatabase::addDatabase("QSQLITE");
        m_db.setDatabaseName(dir + "/luminate-insight.db");
        if (m_db.open()) {
            QSqlQuery q(m_db);
            q.exec("PRAGMA journal_mode=WAL;");
            q.exec("CREATE TABLE IF NOT EXISTS app_usage (id INTEGER PRIMARY KEY AUTOINCREMENT, app_class TEXT NOT NULL, date TEXT NOT NULL, usage_seconds INTEGER NOT NULL, UNIQUE(app_class, date));");
        }
    }

    void touchTrigger() {
        QFile file(QDir::homePath() + "/.local/share/luminate-insight.trigger");
        if (file.open(QIODevice::WriteOnly)) {
            file.write("update\n");
            file.close();
        }
    }

    void logSession() {
        if (m_focusStart > 0 && !m_currentApp.isEmpty()) {
            qint64 now = QDateTime::currentSecsSinceEpoch();
            qint64 diff = now - m_focusStart;
            if (diff > 60) diff = 30; // Cap ghost time
            
            if (diff > 0) {
                QString today = QDateTime::currentDateTime().toString("yyyy-MM-dd");
                QSqlQuery q(m_db);
                q.prepare("INSERT INTO app_usage (app_class, date, usage_seconds) VALUES (?, ?, ?) ON CONFLICT(app_class, date) DO UPDATE SET usage_seconds = usage_seconds + ?;");
                q.addBindValue(m_currentApp); q.addBindValue(today); q.addBindValue(diff); q.addBindValue(diff);
                if (q.exec()) touchTrigger();
            }
        }
        m_focusStart = QDateTime::currentSecsSinceEpoch();
    }

    QString getFocusedAppId() {
        QProcess p; p.start("niri", {"msg", "-j", "focused-window"}); p.waitForFinished();
        QJsonDocument doc = QJsonDocument::fromJson(p.readAllStandardOutput());
        if (doc.isObject()) return doc.object().value("app_id").toString("Unknown");
        return "Unknown";
    }

private slots:
    void onNiriEvent() {
        while (m_niriProc->canReadLine()) {
            QJsonDocument doc = QJsonDocument::fromJson(m_niriProc->readLine());
            if (doc.isObject() && doc.object().contains("WindowFocusChanged")) {
                QString newApp = getFocusedAppId();
                if (newApp != m_currentApp) {
                    logSession();
                    m_currentApp = newApp;
                    m_focusStart = QDateTime::currentSecsSinceEpoch();
                }
            }
        }
    }
};

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    InsightDaemon daemon;
    qDebug() << "luminate-insightd: Niri tracking active.";
    return app.exec();
}
#include "insightd.moc"