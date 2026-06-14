#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QDBusConnection>
#include <QTimer>

class AudioBackend : public QObject {
    Q_OBJECT
    
    // MPRIS Media Properties
    Q_PROPERTY(QString mediaTitle READ mediaTitle NOTIFY mediaChanged)
    Q_PROPERTY(QString mediaArtist READ mediaArtist NOTIFY mediaChanged)
    Q_PROPERTY(QString mediaArtUrl READ mediaArtUrl NOTIFY mediaChanged)
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY mediaChanged)
    
    // Bluez Bluetooth Properties
    Q_PROPERTY(QString btName READ btName NOTIFY btChanged)
    Q_PROPERTY(int btBattery READ btBattery NOTIFY btChanged)
    Q_PROPERTY(bool btConnected READ btConnected NOTIFY btChanged)
    Q_PROPERTY(bool btPowered READ btPowered NOTIFY btChanged)

public:
    explicit AudioBackend(QObject *parent = nullptr);

    QString mediaTitle() const { return m_title; }
    QString mediaArtist() const { return m_artist; }
    QString mediaArtUrl() const { return m_artUrl; }
    bool isPlaying() const { return m_isPlaying; }

    QString btName() const { return m_btName; }
    int btBattery() const { return m_btBattery; }
    bool btConnected() const { return m_btConnected; }
    bool btPowered() const { return m_btPowered; }

    Q_INVOKABLE QVariantList getSinks();
    Q_INVOKABLE QVariantList getSources();
    Q_INVOKABLE QVariantList getPlayers();

    Q_INVOKABLE void setSink(const QString &name);
    Q_INVOKABLE void setSource(const QString &name);
    Q_INVOKABLE void setPlayer(const QString &busName);

signals:
    void mediaChanged();
    void btChanged();

private slots:
    void refreshBluezState();
    void refreshActivePlayer();
    void refreshMprisState();
    void onDbusPropertiesChanged(const QString &interface, const QVariantMap &changedProps, const QStringList &invalidatedProps);
    void pollStates();

private:
    void setActivePlayer(const QString &busName);
    QString getDefaultSink();
    QString getDefaultSource();

    // State Variables
    QString m_title = "Unknown";
    QString m_artist = "Unknown";
    QString m_artUrl = "";
    bool m_isPlaying = false;

    QString m_btName = "Unknown";
    int m_btBattery = -1;
    bool m_btConnected = false;
    bool m_btPowered = true;

    QString m_activePlayerBus = "";
    QTimer *m_pollTimer;
};