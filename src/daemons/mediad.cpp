#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusAbstractAdaptor>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusConnectionInterface> // <--- ADDED THIS HEADER
#include <QTimer>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrlQuery>
#include <QDebug>
#include <optional>

class MediaAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.meismeric.luminate.MediaManager")
    Q_PROPERTY(QString ActivePlayer READ activePlayer NOTIFY ActivePlayerChanged)
    Q_PROPERTY(QString CurrentLyrics READ currentLyrics NOTIFY CurrentLyricsChanged)
    Q_PROPERTY(int CurrentLyricIndex READ currentLyricIndex NOTIFY CurrentLyricIndexChanged)
    Q_PROPERTY(int SyncOffset READ syncOffset NOTIFY SyncOffsetChanged)
public:
    explicit MediaAdaptor(QObject *parent) : QDBusAbstractAdaptor(parent) {}
    QString activePlayer() const { return m_activePlayer; }
    QString currentLyrics() const { return m_lyrics; }
    int currentLyricIndex() const { return m_index; }
    int syncOffset() const { return m_offset; }

    void setProps(const QString& p, const QString& l, int idx, int offset) {
        if (m_activePlayer != p) { m_activePlayer = p; emit ActivePlayerChanged(); }
        if (m_lyrics != l) { m_lyrics = l; emit CurrentLyricsChanged(); }
        if (m_index != idx) { m_index = idx; emit CurrentLyricIndexChanged(); }
        if (m_offset != offset) { m_offset = offset; emit SyncOffsetChanged(); }
        QDBusMessage sig = QDBusMessage::createSignal("/com/meismeric/luminate/MediaManager", "org.freedesktop.DBus.Properties", "PropertiesChanged");
        QVariantMap map; map["ActivePlayer"]=p; map["CurrentLyrics"]=l; map["CurrentLyricIndex"]=idx; map["SyncOffset"]=offset;
        sig << "com.meismeric.luminate.MediaManager" << map << QStringList();
        QDBusConnection::sessionBus().send(sig);
    }
signals:
    void ActivePlayerChanged(); void CurrentLyricsChanged(); void CurrentLyricIndexChanged(); void SyncOffsetChanged();
private:
    QString m_activePlayer, m_lyrics; int m_index = -1, m_offset = -550;
};

class MediaDaemon : public QObject {
    Q_OBJECT
public:
    MediaDaemon() {
        m_adaptor = new MediaAdaptor(this);
        QDBusConnection::sessionBus().registerService("com.meismeric.luminate.MediaManager");
        QDBusConnection::sessionBus().registerObject("/com/meismeric/luminate/MediaManager", this, QDBusConnection::ExportAllSlots);
        m_ui = new QDBusInterface("com.meismeric.luminate.UI", "/com/meismeric/luminate/UI", "com.meismeric.luminate.UI", QDBusConnection::sessionBus(), this);
        m_net = new QNetworkAccessManager(this);
        QTimer *timer = new QTimer(this); connect(timer, &QTimer::timeout, this, &MediaDaemon::tick); timer->start(150);
    }
    Q_INVOKABLE void SelectPlayer(const QString &name) { m_manualPlayer = name; }
    Q_INVOKABLE void SetSyncOffset(int offset) { m_pendingOffset = offset; }
private slots:
    void tick() {
        QStringList players;
        QDBusReply<QStringList> reply = QDBusConnection::sessionBus().interface()->registeredServiceNames();
        if (reply.isValid()) for (const QString& n : reply.value()) if (n.startsWith("org.mpris.MediaPlayer2.") && !n.contains("playerctld")) players.append(n);

        QString bestPlayer = m_manualPlayer;
        if (!players.contains(bestPlayer)) bestPlayer.clear();
        if (bestPlayer.isEmpty()) {
            int bestScore = -1;
            for (const QString& p : players) {
                QDBusInterface iface(p, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", QDBusConnection::sessionBus());
                QString status = iface.call("Get", "org.mpris.MediaPlayer2.Player", "PlaybackStatus").arguments().value(0).value<QDBusVariant>().variant().toString();
                int score = (status == "Playing") ? 2 : (status == "Paused" ? 1 : 0);
                if (p == m_activePlayer) score = score * 10 + 1; else score *= 10;
                if (score > bestScore) { bestScore = score; bestPlayer = p; }
            }
        }
        m_activePlayer = bestPlayer;

        QString title, artist, artUrl, status = "Stopped"; uint64_t dur = 0;
        if (!bestPlayer.isEmpty()) {
            QDBusInterface iface(bestPlayer, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", QDBusConnection::sessionBus());
            status = iface.call("Get", "org.mpris.MediaPlayer2.Player", "PlaybackStatus").arguments().value(0).value<QDBusVariant>().variant().toString();
            QVariantMap meta = qdbus_cast<QVariantMap>(iface.call("Get", "org.mpris.MediaPlayer2.Player", "Metadata").arguments().value(0).value<QDBusVariant>().variant().value<QDBusArgument>());
            title = meta.value("xesam:title").toString();
            artist = meta.value("xesam:artist").canConvert<QStringList>() ? meta.value("xesam:artist").toStringList().first() : meta.value("xesam:artist").toString();
            artUrl = meta.value("mpris:artUrl").toString();
            dur = meta.value("mpris:length").toULongLong() / 1000000;

            QString sig = artist + " - " + title;
            if (sig != m_currentSig && !title.isEmpty()) {
                m_currentSig = sig; m_lyrics.clear(); m_timestamps.clear(); m_index = -1;
                fetchLyrics(title, artist, meta.value("xesam:album").toString(), dur);
            }

            if (!m_timestamps.isEmpty() && status == "Playing") {
                qint64 posUs = iface.call("Get", "org.mpris.MediaPlayer2.Player", "Position").arguments().value(0).value<QDBusVariant>().variant().toLongLong();
                qint64 posMs = std::max(0LL, (posUs / 1000) - m_offset);
                int newIdx = -1;
                for (int i = m_timestamps.size() - 1; i >= 0; --i) if (posMs >= m_timestamps[i]) { newIdx = i; break; }
                m_index = newIdx;
            }
        }

        m_ui->asyncCall("UpdateMediaInfo", bestPlayer, title, artist, artUrl, status);
        if (!title.isEmpty() && (title != m_lastUiTitle || (status == "Playing" && m_lastUiStatus != "Playing"))) m_ui->asyncCall("TriggerMediaPeek");
        m_lastUiTitle = title; m_lastUiStatus = status;

        if (m_pendingOffset.has_value()) { m_offset = m_pendingOffset.value(); m_pendingOffset.reset(); }
        m_adaptor->setProps(m_activePlayer, m_lyrics, m_index, m_offset);
    }

    void fetchLyrics(QString t, QString a, QString al, uint64_t dur) {
        QUrl url("https://lrclib.net/api/get"); QUrlQuery q;
        q.addQueryItem("track_name", t); q.addQueryItem("artist_name", a); q.addQueryItem("album_name", al); q.addQueryItem("duration", QString::number(dur));
        url.setQuery(q); QNetworkRequest req(url); req.setHeader(QNetworkRequest::UserAgentHeader, "LuminateMediaDaemon/1.0");
        QNetworkReply *reply = m_net->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            if (reply->error() == QNetworkReply::NoError) {
                m_lyrics = QJsonDocument::fromJson(reply->readAll()).object().value("syncedLyrics").toString();
                m_timestamps.clear(); QRegularExpression re("\\[(\\d{2}):(\\d{2})[.:](\\d{2,3})\\]");
                for (const QString& line : m_lyrics.split('\n')) {
                    QRegularExpressionMatch match = re.match(line);
                    if (match.hasMatch()) {
                        qint64 cs = match.captured(3).toLongLong(); if (match.captured(3).length() == 2) cs *= 10;
                        m_timestamps.append(match.captured(1).toLongLong() * 60000 + match.captured(2).toLongLong() * 1000 + cs);
                    }
                }
            }
            reply->deleteLater();
        });
    }

private:
    MediaAdaptor *m_adaptor; QDBusInterface *m_ui; QNetworkAccessManager *m_net;
    QString m_activePlayer, m_currentSig, m_lyrics, m_manualPlayer, m_lastUiTitle, m_lastUiStatus;
    int m_index = -1, m_offset = -550; std::optional<int> m_pendingOffset; QList<qint64> m_timestamps;
};

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    MediaDaemon daemon;
    qDebug() << "luminate-mediad: Running MPRIS and Lyrics coordinator.";
    return app.exec();
}
#include "mediad.moc"