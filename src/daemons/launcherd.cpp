// Must include glib/gio BEFORE Qt headers to avoid `signals` macro conflicts
#include <gio/gio.h>

#include <QCoreApplication>
#include <QObject>
#include <QDBusConnection>
#include <QDBusAbstractAdaptor>
#include <QDBusArgument>
#include <QDBusMetaType>
#include <QRegularExpression>
#include <QJSEngine>
#include <QProcess>
#include <QDir>
#include <QFile>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QTimer>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>

struct SearchResult { uint type; QString title; QString desc; QString icon; QString payload; int score; };
Q_DECLARE_METATYPE(SearchResult)
Q_DECLARE_METATYPE(QList<SearchResult>)

inline QDBusArgument &operator<<(QDBusArgument &argument, const SearchResult &res) {
    argument.beginStructure(); argument << res.type << res.title << res.desc << res.icon << res.payload << res.score; argument.endStructure(); return argument;
}
inline const QDBusArgument &operator>>(const QDBusArgument &argument, SearchResult &res) {
    argument.beginStructure(); argument >> res.type >> res.title >> res.desc >> res.icon >> res.payload >> res.score; argument.endStructure(); return argument;
}

class LauncherDaemon; // Forward Declaration

class SearchAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.meismeric.luminate.Search")
public:
    explicit SearchAdaptor(LauncherDaemon *parent);

public slots:
    QList<SearchResult> Query(const QString &term);
    QList<SearchResult> QueryClipboard(const QString &term);
    void DeleteClipboardItem(const QString &payload);
    void SetClipboardItem(const QString &payload);
    void ClearClipboard();
};

class LauncherDaemon : public QObject {
    Q_OBJECT
public:
    LauncherDaemon() {
        m_adaptor = new SearchAdaptor(this);
        
        QDBusConnection::sessionBus().registerService("com.meismeric.luminate.Search");
        QDBusConnection::sessionBus().registerObject("/com/meismeric/luminate/Search", this);

        loadApps(); 
        updateUsage();
        
        QTimer *t = new QTimer(this); 
        connect(t, &QTimer::timeout, this, &LauncherDaemon::updateUsage); 
        t->start(60000);

        m_clipDir = QDir::homePath() + "/.cache/luminate-shell/clipboard";
        QDir(m_clipDir).removeRecursively(); 
        QDir().mkpath(m_clipDir);
        
        QProcess *txtWatcher = new QProcess(this);
        connect(txtWatcher, &QProcess::readyReadStandardOutput, this, [this, txtWatcher](){
            txtWatcher->readAllStandardOutput();
            QProcess p; p.start("wl-paste", {"-n", "-t", "text/plain"}); p.waitForFinished();
            QString text = QString::fromUtf8(p.readAllStandardOutput());
            if (!text.trimmed().isEmpty() && text != m_lastText) {
                m_lastText = text; QVariantMap item; item["is_img"]=false; item["content"]=text; item["ts"]=QDateTime::currentSecsSinceEpoch();
                m_clips.prepend(item); if(m_clips.size()>10) m_clips.removeLast();
            }
        });
        txtWatcher->start("wl-paste", {"-t", "text/plain", "--watch", "echo", "T"});

        QProcess *imgWatcher = new QProcess(this);
        connect(imgWatcher, &QProcess::readyReadStandardOutput, this, [this, imgWatcher](){
            imgWatcher->readAllStandardOutput();
            QProcess p; p.start("wl-paste", {"-t", "image/png"}); p.waitForFinished();
            QByteArray bytes = p.readAllStandardOutput();
            if (!bytes.isEmpty()) {
                QString hash = QString(QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex());
                if (hash != m_lastImgHash) {
                    m_lastImgHash = hash; QString path = m_clipDir + "/" + hash + ".png";
                    QFile f(path); if(f.open(QIODevice::WriteOnly)) f.write(bytes);
                    QVariantMap item; item["is_img"]=true; item["content"]=path; item["ts"]=QDateTime::currentSecsSinceEpoch();
                    m_clips.prepend(item); if(m_clips.size()>10) m_clips.removeLast();
                }
            }
        });
        imgWatcher->start("wl-paste", {"-t", "image/png", "--watch", "echo", "I"});
    }

// Public handlers for the DBus Adaptor to call
public:
    void handleQuery(const QString &term, QList<SearchResult> &out) {
        QString q = term.trimmed(); if (q.isEmpty()) return;
        if (q.startsWith("/") || q.startsWith("~")) {
            QString path = q; if (q.startsWith("~")) path.replace(0, 1, QDir::homePath());
            if (QFile::exists(path)) out.append({2, path, "Open File or Folder", QFileInfo(path).isDir() ? "folder-symbolic" : "document-open-symbolic", "xdg-open '" + path + "'", 200});
        }
        if (q.startsWith("> ")) {
            QString cmd = q.mid(2).trimmed();
            out.append({2, cmd, "Run Command", "utilities-terminal-symbolic", cmd, 110}); return;
        }

        if (q.contains(QRegularExpression("\\d")) && q.contains(QRegularExpression("[+\\-*/]"))) {
            QJSValue res = QJSEngine().evaluate(q);
            if (res.isNumber()) out.append({1, res.toString(), "Result", "accessories-calculator-symbolic", res.toString(), 150});
        }

        QList<QPair<int, SearchResult>> scored; QString qLower = q.toLower();
        for (const auto& app : m_apps) {
            int score = qMax(fuzzyMatch(qLower, app["name"].toString()), fuzzyMatch(qLower, app["id"].toString()));
            if (score >= 50) {
                int uMins = 0;
                for (auto it = m_usage.begin(); it != m_usage.end(); ++it) if (app["id"].toString().toLower().contains(it.key()) || app["name"].toString().toLower().contains(it.key())) uMins = qMax(uMins, it.value() / 60);
                score = (int)(score * (1.0 + qMin(uMins, 200) / 400.0));
                scored.append({score, {0, app["name"].toString(), app["desc"].toString(), app["icon"].toString(), app["id"].toString(), score}});
            }
        }
        std::sort(scored.begin(), scored.end(), [](const auto& a, const auto& b){ return a.first > b.first; });
        for (int i = 0; i < qMin(8, scored.size()); ++i) out.append(scored[i].second);
    }

    void handleQueryClipboard(const QString &term, QList<SearchResult> &out) {
        QString q = term.toLower();
        for (const auto& c : m_clips) {
            bool isImg = c["is_img"].toBool(); QString content = c["content"].toString();
            if (!q.isEmpty() && isImg) continue;
            if (!q.isEmpty() && !content.toLower().contains(q)) continue;
            
            SearchResult r; r.type = 3; r.score = q.isEmpty() ? 100 : 110;
            int diffMins = (QDateTime::currentSecsSinceEpoch() - c["ts"].toLongLong()) / 60;
            r.desc = diffMins < 1 ? "Just now" : (diffMins < 60 ? QString("%1m ago").arg(diffMins) : QString("%1h ago").arg(diffMins/60));

            if (isImg) { r.title = "Image"; r.icon = content; r.payload = "IMG:" + content; }
            else {
                QString t = content; t.replace("\n", " "); if(t.length()>60) { t.truncate(60); t += "..."; }
                r.title = t; r.icon = "edit-paste-symbolic"; r.payload = "TXT:" + content;
            }
            out.append(r);
        }
    }

    void handleDeleteClipboard(const QString &payload) {
        for (int i=0; i<m_clips.size(); ++i) {
            QString cmp = m_clips[i]["is_img"].toBool() ? "IMG:"+m_clips[i]["content"].toString() : "TXT:"+m_clips[i]["content"].toString();
            if (cmp == payload) {
                if (m_clips[i]["is_img"].toBool()) QFile::remove(m_clips[i]["content"].toString());
                m_clips.removeAt(i); break;
            }
        }
    }

    void handleSetClipboard(const QString &payload) {
        if (payload.startsWith("IMG:")) QProcess::startDetached("sh", {"-c", "wl-copy -t image/png < '" + payload.mid(4) + "'"});
        else if (payload.startsWith("TXT:")) { QProcess p; p.start("wl-copy"); p.write(payload.mid(4).toUtf8()); p.waitForFinished(); }
    }
    
    void handleClearClipboard() {
        m_clips.clear();
        QDir dir(m_clipDir);
        dir.removeRecursively();
        QDir().mkpath(m_clipDir);
    }

private:
    SearchAdaptor *m_adaptor; QList<QVariantMap> m_apps, m_clips; QMap<QString, int> m_usage;
    QString m_clipDir, m_lastText, m_lastImgHash;

    void loadApps() {
        m_apps.clear();
        GList *apps = g_app_info_get_all();
        for (GList *l = apps; l; l = l->next) {
            GAppInfo *info = G_APP_INFO(l->data);
            if (!g_app_info_should_show(info)) continue;
            QVariantMap map;
            map["name"] = QString::fromUtf8(g_app_info_get_name(info));
            const char* desc = g_app_info_get_description(info);
            map["desc"] = desc ? QString::fromUtf8(desc) : "Application";
            map["id"] = QString::fromUtf8(g_app_info_get_id(info));
            
            GIcon *gicon = g_app_info_get_icon(info);
            QString iconStr = "application-x-executable";
            if (gicon) {
                if (G_IS_THEMED_ICON(gicon)) {
                    const gchar* const* names = g_themed_icon_get_names(G_THEMED_ICON(gicon));
                    if (names && names[0]) iconStr = QString::fromUtf8(names[0]);
                } else {
                    gchar* s = g_icon_to_string(gicon); if (s) { iconStr = QString::fromUtf8(s); g_free(s); }
                }
            }
            map["icon"] = iconStr; m_apps.append(map);
        }
        g_list_free_full(apps, g_object_unref);
    }

    void updateUsage() {
        m_usage.clear();
        
        QSqlDatabase db;
        if (QSqlDatabase::contains("usage_conn")) {
            db = QSqlDatabase::database("usage_conn");
        } else {
            db = QSqlDatabase::addDatabase("QSQLITE", "usage_conn");
            db.setDatabaseName(QDir::homePath() + "/.local/share/luminate-insight.db");
        }
        
        if (db.open()) {
            QSqlQuery q("SELECT app_class, SUM(usage_seconds) FROM app_usage GROUP BY app_class", db);
            while (q.next()) m_usage[q.value(0).toString().toLower()] = q.value(1).toInt();
        }
    }

    int fuzzyMatch(const QString& qLower, const QString& target) {
        if (qLower.isEmpty()) return 100;
        int score = 0, qIdx = 0; QString t = target.toLower();
        for (int i = 0; i < t.length() && qIdx < qLower.length(); ++i) if (t[i] == qLower[qIdx]) { score += 10; qIdx++; }
        if (qIdx == qLower.length()) {
            if (t.startsWith(qLower)) score += 100; else if (t.contains(qLower)) score += 20;
            return score;
        }
        return 0;
    }
};

// Implement Adaptor calls to delegate to Daemon
SearchAdaptor::SearchAdaptor(LauncherDaemon *parent) : QDBusAbstractAdaptor(parent) {
    qDBusRegisterMetaType<SearchResult>(); 
    qDBusRegisterMetaType<QList<SearchResult>>();
}

QList<SearchResult> SearchAdaptor::Query(const QString &term) { 
    QList<SearchResult> out; 
    static_cast<LauncherDaemon*>(parent())->handleQuery(term, out); 
    return out; 
}

QList<SearchResult> SearchAdaptor::QueryClipboard(const QString &term) { 
    QList<SearchResult> out; 
    static_cast<LauncherDaemon*>(parent())->handleQueryClipboard(term, out); 
    return out; 
}

void SearchAdaptor::DeleteClipboardItem(const QString &payload) { 
    static_cast<LauncherDaemon*>(parent())->handleDeleteClipboard(payload); 
}

void SearchAdaptor::SetClipboardItem(const QString &payload) { 
    static_cast<LauncherDaemon*>(parent())->handleSetClipboard(payload); 
}

void SearchAdaptor::ClearClipboard() { 
    static_cast<LauncherDaemon*>(parent())->handleClearClipboard(); 
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    LauncherDaemon daemon;
    qDebug() << "luminate-launcherd: Search and Clipboard daemon running.";
    return app.exec();
}
#include "launcherd.moc"