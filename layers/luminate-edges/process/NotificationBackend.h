#pragma once

#include <QObject>
#include <QVariantList>
#include <QStringList>
#include <QString>
#include <QQueue>
#include <QDBusContext>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantMap>
#include <QList>
#include <QTimer>

struct NotificationData {
    uint id;
    QString icon;
    QString summary;
    QString body;
    QVariantList actions;
};

class NotificationBackend : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.meismeric.luminate.UI")

    Q_PROPERTY(QString displayMode READ displayMode NOTIFY displayModeChanged) 
    Q_PROPERTY(QVariantMap themeData READ themeData NOTIFY themeChanged)
    Q_PROPERTY(bool isExpanded READ isExpanded WRITE setIsExpanded NOTIFY isExpandedChanged)

    Q_PROPERTY(QString summary READ summary NOTIFY notificationChanged)
    Q_PROPERTY(QString body READ body NOTIFY notificationChanged)
    Q_PROPERTY(QString icon READ icon NOTIFY notificationChanged)
    Q_PROPERTY(QVariantList actions READ actions NOTIFY notificationChanged)
    Q_PROPERTY(bool hasActions READ hasActions NOTIFY notificationChanged)
    Q_PROPERTY(int pendingNotifications READ pendingNotifications NOTIFY queueChanged)

    Q_PROPERTY(QVariantList privacyApps READ privacyApps NOTIFY privacyChanged)
    Q_PROPERTY(QString privacySummary READ privacySummary NOTIFY privacyChanged)
    Q_PROPERTY(bool privacyHasMic READ privacyHasMic NOTIFY privacyChanged)
    Q_PROPERTY(bool privacyHasCam READ privacyHasCam NOTIFY privacyChanged)

    Q_PROPERTY(QString osdIcon READ osdIcon NOTIFY osdChanged)
    Q_PROPERTY(double osdLevel READ osdLevel NOTIFY osdChanged)

    Q_PROPERTY(QString mediaTitle READ mediaTitle NOTIFY mediaChanged)
    Q_PROPERTY(QString mediaArtist READ mediaArtist NOTIFY mediaChanged)
    Q_PROPERTY(QString mediaArt READ mediaArt NOTIFY mediaChanged)
    Q_PROPERTY(QString mediaStatus READ mediaStatus NOTIFY mediaChanged)
    Q_PROPERTY(int mediaPosition READ mediaPosition NOTIFY positionChanged)
    Q_PROPERTY(int mediaDuration READ mediaDuration NOTIFY durationChanged)
    
    Q_PROPERTY(QString mediaCurrentLyric READ mediaCurrentLyric NOTIFY lyricIndexChanged)
    Q_PROPERTY(bool mediaHasLyrics READ mediaHasLyrics NOTIFY lyricsTextChanged)
    Q_PROPERTY(bool hasMedia READ hasMedia NOTIFY mediaChanged)
    Q_PROPERTY(bool mediaPinned READ mediaPinned WRITE setMediaPinned NOTIFY mediaPinnedChanged)

    Q_PROPERTY(QString screenshotState READ screenshotState NOTIFY screenshotStateChanged)
    Q_PROPERTY(QVariantList ocrResults READ ocrResults NOTIFY ocrResultsChanged)
    Q_PROPERTY(QVariantList niriWindows READ niriWindows NOTIFY niriWindowsChanged)
    
    Q_PROPERTY(QString sysOsName READ sysOsName NOTIFY systemInfoChanged)
    Q_PROPERTY(QString sysUptime READ sysUptime NOTIFY systemInfoChanged)

public:
    explicit NotificationBackend(QObject *parent = nullptr);

    QString displayMode() const { return m_displayMode; }
    QVariantMap themeData() const { return m_themeData; }
    
    bool isExpanded() const { return m_isExpanded; }
    void setIsExpanded(bool expanded);

    QString summary() const { return m_current.summary; }
    QString body() const { return m_current.body; }
    QString icon() const { return m_current.icon; }
    QVariantList actions() const { return m_current.actions; }
    bool hasActions() const { return !m_current.actions.isEmpty(); }
    int pendingNotifications() const { return m_queue.size(); }

    QVariantList privacyApps() const { return m_privacyApps; }
    QString privacySummary() const { return m_privacySummary; }
    bool privacyHasMic() const { return m_privacyHasMic; }
    bool privacyHasCam() const { return m_privacyHasCam; }

    QString osdIcon() const { return m_osdIcon; }
    double osdLevel() const { return m_osdLevel; }

    QString mediaTitle() const { return m_mediaTitle; }
    QString mediaArtist() const { return m_mediaArtist; }
    QString mediaArt() const { return m_mediaArt; }
    QString mediaStatus() const { return m_mediaStatus; }
    int mediaPosition() const { return m_mediaPosition; }
    int mediaDuration() const { return m_mediaDuration; }
    
    QString mediaCurrentLyric() const;
    bool mediaHasLyrics() const { return !m_parsedLyrics.isEmpty(); }
    
    bool hasMedia() const { return !m_activePlayerName.isEmpty(); }
    bool mediaPinned() const { return m_mediaPinned; }

    QString screenshotState() const { return m_screenshotState; }
    QVariantList ocrResults() const { return m_ocrResults; }
    QVariantList niriWindows() const { return m_niriWindows; }

    QString sysOsName() const { return m_sysOsName; }
    QString sysUptime() const { return m_sysUptime; }

    Q_INVOKABLE void invokeAction(const QString& actionId);
    Q_INVOKABLE void readyForNext();
    
    Q_INVOKABLE void killPrivacyApp(uint pid, const QString& name);
    Q_INVOKABLE void ignorePrivacyApp(uint pid, const QString& name);
    Q_INVOKABLE void killAllPrivacyApps(); 

    Q_INVOKABLE void mediaPlayPause();
    Q_INVOKABLE void mediaNext();
    Q_INVOKABLE void mediaPrev();
    Q_INVOKABLE void setMediaPinned(bool pinned);

    Q_INVOKABLE void expandScreenshotToEdit();
    Q_INVOKABLE void cancelScreenshot();
    Q_INVOKABLE void runOcrAsync();
    Q_INVOKABLE void fetchNiriWindows();
    Q_INVOKABLE void captureNiriWindow(const QString& winId, bool annotate);
    Q_INVOKABLE void copyTextToClipboard(const QString& text);

    Q_INVOKABLE void closeLauncher();

public slots: 
    void ShowNotification(uint id, const QString &icon, const QString &summary, const QString &body, const QStringList &actions);
    void SetPrivacyStatus(const QString &payload);
    void ShowOSD(const QString &icon, double level); 
    void UpdateMediaInfo(const QString &playerName, const QString &title, const QString &artist, const QString &artUrl, const QString &status);
    void TriggerMediaPeek();
    void TriggerSystemPeek();
    void triggerScreenshotFlow();
    void triggerLauncherFlow();

signals:
    void displayModeChanged();
    void themeChanged();
    void isExpandedChanged();
    void notificationChanged();
    void queueChanged();
    void privacyChanged();
    void osdChanged();
    void mediaChanged();
    void positionChanged();
    void durationChanged();
    void lyricsTextChanged();
    void lyricIndexChanged();
    void mediaPinnedChanged();
    void systemInfoChanged();
    void requestShow(); 
    void requestHide(); 

    void screenshotStateChanged();
    void ocrResultsChanged();
    void niriWindowsChanged();
    void windowScreenshotReady(const QString& path);

private:
    void processNext();
    void updateDisplayMode();
    void setupMediaManager();
    void parseLyrics(const QString& lrc);
    void updateSystemInfo();

    QString m_displayMode = "idle";
    bool m_isExpanded = false;
    
    QQueue<NotificationData> m_queue;
    NotificationData m_current;
    
    bool m_isShowingNotif = false;
    bool m_isShowingOsd = false;
    bool m_isShowingLauncher = false;
    bool m_isShowingSystem = false;

    QVariantList m_privacyApps;
    QString m_privacySummary;
    bool m_privacyHasMic = false;
    bool m_privacyHasCam = false;
    QList<uint> m_ignoredPids;
    QStringList m_ignoredNames;

    QString m_osdIcon;
    double m_osdLevel = 0.0;

    QString m_mediaTitle;
    QString m_mediaArtist;
    QString m_mediaArt;
    QString m_originalArtUrl; 
    QString m_mediaStatus = "Stopped";
    QString m_activePlayerName;
    int m_mediaPosition = 0;
    int m_mediaDuration = 0;
    
    QTimer m_positionTimer;
    QString m_rawLyricsCache; 
    QStringList m_parsedLyrics;
    int m_currentLyricIndex = -1;
    bool m_mediaPinned = false;

    QString m_screenshotState = "";
    QString m_tempScreenshotPath;
    QVariantList m_ocrResults;
    QVariantList m_niriWindows;
    
    QString m_sysOsName;
    QString m_sysUptime;

    QVariantMap m_themeData;
    
private slots:
    void onSurfaceDeskPropsChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated);
    void onMediaManagerPropsChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated);
    void fetchPosition();
    void fetchDuration();
};