#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QFontDatabase>
#include <QJSValue>
#include <QVariantMap>

class WallpaperBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentWallpaper READ currentWallpaper WRITE setWallpaper NOTIFY currentWallpaperChanged)
    Q_PROPERTY(QStringList wallpaperList READ wallpaperList NOTIFY wallpaperListChanged)
    Q_PROPERTY(bool isPickingWallpaper READ isPickingWallpaper WRITE setIsPickingWallpaper NOTIFY isPickingWallpaperChanged)
    Q_PROPERTY(QString confirmedWallpaper READ confirmedWallpaper NOTIFY confirmedWallpaperChanged)
    Q_PROPERTY(QStringList wallpaperPalette READ wallpaperPalette NOTIFY wallpaperPaletteChanged)
    Q_PROPERTY(QString currentResolution READ currentResolution NOTIFY currentResolutionChanged)
    Q_PROPERTY(bool isEditing READ isEditing WRITE setIsEditing NOTIFY isEditingChanged)
    Q_PROPERTY(bool isEditingLockscreen READ isEditingLockscreen WRITE setIsEditingLockscreen NOTIFY isEditingLockscreenChanged)
    Q_PROPERTY(bool isLocked READ isLocked WRITE setLocked NOTIFY isLockedChanged)
    
    Q_PROPERTY(QVariantMap themeMap READ themeMap NOTIFY themeMapChanged)

    Q_PROPERTY(int selectedWidgetIndex READ selectedWidgetIndex WRITE setSelectedWidgetIndex NOTIFY selectedWidgetIndexChanged)
    Q_PROPERTY(QJSValue desktopWidgets READ desktopWidgets WRITE setDesktopWidgets NOTIFY desktopWidgetsChanged)
    Q_PROPERTY(QJSValue lockscreenWidgets READ lockscreenWidgets WRITE setLockscreenWidgets NOTIFY lockscreenWidgetsChanged)

    Q_PROPERTY(double cpuUsage READ cpuUsage NOTIFY cpuUsageChanged)
    Q_PROPERTY(double ramUsage READ ramUsage NOTIFY ramUsageChanged)
    Q_PROPERTY(double systemTemp READ systemTemp NOTIFY systemTempChanged)

    Q_PROPERTY(QString mediaTitle READ mediaTitle NOTIFY mediaChanged)
    Q_PROPERTY(QString mediaArtist READ mediaArtist NOTIFY mediaChanged)
    Q_PROPERTY(QString mediaArt READ mediaArt NOTIFY mediaChanged)
    Q_PROPERTY(QString mediaPlaybackStatus READ mediaPlaybackStatus NOTIFY mediaChanged)

public:
    explicit WallpaperBackend(QObject *parent = nullptr);

    QString currentWallpaper() const;
    QStringList wallpaperList() const;

    bool isPickingWallpaper() const;
    void setIsPickingWallpaper(bool picking);

    QString confirmedWallpaper() const;
    QStringList wallpaperPalette() const;
    QVariantMap themeMap() const { return m_themeMap; }
    QString currentResolution() const;

    bool isEditing() const;
    void setIsEditing(bool editing);

    bool isEditingLockscreen() const;
    void setIsEditingLockscreen(bool editing);

    bool isLocked() const;

    int selectedWidgetIndex() const { return m_selectedWidgetIndex; }
    void setSelectedWidgetIndex(int index) {
        if (m_selectedWidgetIndex != index) {
            m_selectedWidgetIndex = index;
            emit selectedWidgetIndexChanged();
        }
    }

    QJSValue desktopWidgets() const { return m_desktopWidgets; }
    void setDesktopWidgets(const QJSValue &widgets) { m_desktopWidgets = widgets; emit desktopWidgetsChanged(); }

    QJSValue lockscreenWidgets() const { return m_lockscreenWidgets; }
    void setLockscreenWidgets(const QJSValue &widgets) { m_lockscreenWidgets = widgets; emit lockscreenWidgetsChanged(); }

    double cpuUsage() const { return m_cpuUsage; }
    double ramUsage() const { return m_ramUsage; }
    double systemTemp() const { return m_systemTemp; }

    QString mediaTitle() const { return m_mediaTitle; }
    QString mediaArtist() const { return m_mediaArtist; }
    QString mediaArt() const { return m_mediaArt; }
    QString mediaPlaybackStatus() const { return m_mediaPlaybackStatus; }

    Q_INVOKABLE QStringList getFontStyles(const QString &family) const { return QFontDatabase::styles(family); }
    Q_INVOKABLE int getFontWeight(const QString &family, const QString &style) const { return QFontDatabase::weight(family, style); }
    Q_INVOKABLE bool authenticatePassword(const QString &password);

public slots:
    // THE FIX: Moved to slots so D-Bus can invoke it
    void setWallpaper(const QString &path);

    void ToggleWallpaperMode();
    void ToggleEditMode();
    void ToggleLockscreenEditMode();
    void setLocked(bool locked);

    void mediaPlayPause();
    void mediaNext();
    void mediaPrev();

    void commitWallpaper();
    void cancelWallpaper();

signals:
    void currentWallpaperChanged();
    void wallpaperListChanged();
    void isPickingWallpaperChanged();
    void confirmedWallpaperChanged();
    void wallpaperPaletteChanged();
    void themeMapChanged();
    void currentResolutionChanged();
    void isEditingChanged();
    void isEditingLockscreenChanged();
    void isLockedChanged();
    void selectedWidgetIndexChanged();
    void desktopWidgetsChanged();
    void lockscreenWidgetsChanged();

    void cpuUsageChanged();
    void ramUsageChanged();
    void systemTempChanged();
    void mediaChanged();

private:
    QString m_currentWallpaper;
    QString m_confirmedWallpaper;
    QString m_currentResolution;
    QStringList m_wallpaperList;
    QStringList m_wallpaperPalette;
    QVariantMap m_themeMap;
    
    bool m_isPickingWallpaper;
    bool m_isEditing;
    bool m_isEditingLockscreen;
    bool m_isLocked;
    int m_selectedWidgetIndex;
    
    QJSValue m_desktopWidgets;
    QJSValue m_lockscreenWidgets;

    QTimer *m_pollTimer;

    uint64_t m_cpuPrevTotal;
    uint64_t m_cpuPrevIdle;
    double m_cpuUsage;
    double m_ramUsage;
    double m_systemTemp;

    QString m_mediaTitle;
    QString m_mediaArtist;
    QString m_mediaArt;
    QString m_mediaPlaybackStatus;

    QString m_previousWorkspace;

    void loadWallpapers();
    void updatePalette();
    void updateResolution(const QString &path);
    
    void generateTheme(const QString &wallpaperPath);
    void pollSystemStats();
    void pollMprisInfo();
    void sendMprisCommand(const QString &command);

    void updateWorkspaceState();
};