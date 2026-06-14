#include "WallpaperBackend.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QImageReader>
#include <QDebug>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusArgument>
#include <QDBusConnectionInterface>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QCryptographicHash>
#include <QColor>
#include <thread>
#include <algorithm>

#include <security/pam_appl.h>
#include <security/pam_misc.h>

struct PamConversationData { QByteArray password; };

static int pamConversation(int num_msg, const struct pam_message **msg, struct pam_response **resp, void *appdata_ptr) {
    auto* data = static_cast<PamConversationData*>(appdata_ptr);
    auto* responses = static_cast<struct pam_response*>(calloc(num_msg, sizeof(struct pam_response)));
    if (!responses) return PAM_BUF_ERR;
    for (int i = 0; i < num_msg; ++i) {
        if (msg[i]->msg_style == PAM_PROMPT_ECHO_OFF) {
            responses[i].resp = strdup(data->password.constData());
            responses[i].resp_retcode = 0;
        } else {
            responses[i].resp = nullptr;
            responses[i].resp_retcode = 0;
        }
    }
    *resp = responses;
    return PAM_SUCCESS;
}

WallpaperBackend::WallpaperBackend(QObject *parent)
    : QObject(parent), m_isPickingWallpaper(false), m_isEditing(false), m_isEditingLockscreen(false)
    , m_isLocked(false), m_selectedWidgetIndex(-1), m_cpuPrevTotal(0), m_cpuPrevIdle(0), m_cpuUsage(0.0)
    , m_ramUsage(0.0), m_systemTemp(0.0), m_mediaTitle(""), m_mediaArtist(""), m_mediaArt(""), m_mediaPlaybackStatus("Stopped")
{
    // THE FIX: Use a 0-millisecond singleShot timer to safely delay execution until the event loop starts.
    // This allows main.cpp to finish registering this object on the DBus before the theme is broadcast.
    QTimer::singleShot(0, this, &WallpaperBackend::loadWallpapers);

    m_pollTimer = new QTimer(this);
    connect(m_pollTimer, &QTimer::timeout, this, [this]() { pollSystemStats(); pollMprisInfo(); });
    m_pollTimer->start(2000);
}

bool WallpaperBackend::authenticatePassword(const QString &password) {
    QString username = qEnvironmentVariable("USER");
    if (username.isEmpty()) username = "root";
    PamConversationData data { password.toUtf8() };
    struct pam_conv conv = { pamConversation, &data };
    pam_handle_t* pamh = nullptr;
    int retval = pam_start("login", username.toUtf8().constData(), &conv, &pamh);
    if (retval != PAM_SUCCESS) return false;
    retval = pam_authenticate(pamh, 0);
    bool success = (retval == PAM_SUCCESS);
    pam_end(pamh, retval);
    return success;
}

void WallpaperBackend::generateTheme(const QString &wallpaperPath) {
    qDebug() << "[SurfaceDesk] Generating theme with wallust for:" << wallpaperPath;
    QProcess proc;
    proc.start("wallust", QStringList() << "run" << "--backend" << "wal" << "--quiet" << wallpaperPath);
    proc.waitForFinished();
    qDebug() << "[SurfaceDesk] Wallust finished with code:" << proc.exitCode();

    // Re-evaluate palette and broadcast immediately
    updatePalette();

    // Update Kitty Terminal natively via its socket
    QString cachePath = QDir::homePath() + "/.cache/wallust/scriptable_colors.txt";
    QFile cacheFile(cachePath);
    QMap<QString, QString> theme;
    if (cacheFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&cacheFile);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.contains('=')) {
                QStringList parts = line.split('=');
                if (parts.size() == 2) theme[parts[0].trimmed()] = parts[1].trimmed().remove('\'').remove('"');
            }
        }
        cacheFile.close();
    }

    if (qEnvironmentVariableIsSet("HYPRLAND_INSTANCE_SIGNATURE")) {
        QString hyprPath = QDir::homePath() + "/.config/hypr/colors-hyprland-generated.conf";
        QString c4 = theme["color4"].mid(1), c6 = theme["color6"].mid(1), c0 = theme["color0"].mid(1);
        QString hyprConf = QString("$wallust_background = %1\n$wallust_foreground = %2\n$wallust_color4 = %3\ngeneral {\n    col.active_border = rgba(%4ff) rgba(%5ff) 45deg\n    col.inactive_border = rgba(%6aa)\n}\n")
                           .arg(theme["background"]).arg(theme["foreground"]).arg(theme["color4"]).arg(c4).arg(c6).arg(c0);
        QFile hyprFile(hyprPath);
        if (hyprFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&hyprFile); out << hyprConf; hyprFile.close();
            QProcess::startDetached("hyprctl", {"reload"});
            qDebug() << "[SurfaceDesk] Triggered hyprctl reload for borders.";
        }
    }

    QString kittyPath = QDir::homePath() + "/.config/kitty/theme-wallust-generated.conf";
    QFile kittyFile(kittyPath);
    if (kittyFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&kittyFile);
        out << "foreground " << QColor(theme["foreground"]).lighter(150).name() << "\n";
        out << "background " << theme["background"] << "\n";
        out << "cursor " << QColor(theme["cursor"]).lighter(150).name() << "\n";
        for (int i=0; i<16; i++) out << "color" << i << " " << QColor(theme[QString("color%1").arg(i)]).lighter(150).name() << "\n";
        kittyFile.close();
        QProcess::startDetached("pkill", {"-SIGUSR1", "kitty"});
    }
}

void WallpaperBackend::updatePalette() {
    qDebug() << "[SurfaceDesk] Updating internal color palette...";
    QString cachePath = QDir::homePath() + "/.cache/wallust/scriptable_colors.txt";
    QFile file(cachePath);
    QMap<QString, QString> cMap;
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.contains('=')) {
                QStringList p = line.split('=');
                if (p.size() == 2) cMap.insert(p[0].trimmed(), p[1].trimmed().remove('\'').remove('"'));
            }
        }
        file.close();
    } else {
        qWarning() << "[SurfaceDesk] Failed to open wallust cache!";
    }

    // 1. Array for legacy surfacedesk UI widgets
    const QStringList keys = { "foreground", "color0", "color1", "color2", "color3", "color4", "color5", "color6", "color7", "color8", "color9", "color10", "color11", "color12", "color13", "color14", "color15" };
    m_wallpaperPalette.clear();
    for (const QString &k : keys) m_wallpaperPalette.append(cMap.value(k, "#FFFFFF"));
    emit wallpaperPaletteChanged();

    // 2. Dictionary Map for Luminate Edges via D-Bus!
    QColor bg(cMap.value("background", "#000000"));
    QColor fg(cMap.value("foreground", "#ffffff"));
    QColor acc(cMap.value("color4", "#00ffcc"));
    QColor surf = bg.lighter(130);

    double lum = (0.299 * bg.red() + 0.587 * bg.green() + 0.114 * bg.blue());
    QColor smartAcc = (lum < 128.0) 
        ? QColor(std::clamp((int)(acc.red()*.6 + 255*.4),0,255), std::clamp((int)(acc.green()*.6 + 255*.4),0,255), std::clamp((int)(acc.blue()*.6 + 255*.4),0,255))
        : QColor(std::clamp((int)(acc.red()*.7),0,255), std::clamp((int)(acc.green()*.7),0,255), std::clamp((int)(acc.blue()*.7),0,255));

    QVariantMap newTheme;
    newTheme["bg"] = bg.name();
    newTheme["fg"] = fg.name();
    newTheme["accent"] = smartAcc.name();
    newTheme["surface"] = surf.name();

    m_themeMap = newTheme;
    emit themeMapChanged();
    
    qDebug() << "[SurfaceDesk] Broadcasting ThemeMap to DBus:" << newTheme;

    // Force the D-Bus properties signal so Edges updates instantly in memory
    QDBusMessage sig = QDBusMessage::createSignal("/com/meismeric/SurfaceDesk", "org.freedesktop.DBus.Properties", "PropertiesChanged");
    QVariantMap props; props["themeMap"] = m_themeMap;
    sig << "com.meismeric.SurfaceDesk" << props << QStringList();
    QDBusConnection::sessionBus().send(sig);
}

void WallpaperBackend::pollSystemStats() {
    QFile statFile("/proc/stat");
    if (statFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QStringList parts = QString(statFile.readLine()).split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
        if (parts.size() > 4) {
            uint64_t currentIdle = parts[4].toULongLong() + parts[5].toULongLong();
            uint64_t currentTotal = parts[1].toULongLong() + parts[2].toULongLong() + parts[3].toULongLong() + currentIdle + parts[6].toULongLong() + parts[7].toULongLong() + parts[8].toULongLong();
            uint64_t totalDiff = currentTotal - m_cpuPrevTotal, idleDiff = currentIdle - m_cpuPrevIdle;
            if (totalDiff > 0) m_cpuUsage = (double)(totalDiff - idleDiff) / totalDiff;
            m_cpuPrevTotal = currentTotal;
            m_cpuPrevIdle = currentIdle;
        }
        statFile.close();
    }
    QFile memFile("/proc/meminfo");
    if (memFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        double total = 0.0, avail = 0.0; QTextStream in(&memFile);
        while (!in.atEnd()) {
            QString line = in.readLine();
            if (line.startsWith("MemTotal:")) total = line.section(' ', -2, -2).toDouble();
            else if (line.startsWith("MemAvailable:")) avail = line.section(' ', -2, -2).toDouble();
            if (total > 0 && avail > 0) break;
        }
        m_ramUsage = (total > 0) ? (total - avail) / total : 0.0;
        memFile.close();
    }
    QDir hwmonDir("/sys/class/hwmon");
    m_systemTemp = 0.0;
    for (const QString &hw : hwmonDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        QFile tempFile(hwmonDir.absoluteFilePath(hw) + "/temp1_input");
        if (tempFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            m_systemTemp = tempFile.readAll().trimmed().toDouble() / 1000.0;
            tempFile.close(); break;
        }
    }
    emit cpuUsageChanged(); emit ramUsageChanged(); emit systemTempChanged();
}

void WallpaperBackend::pollMprisInfo() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    QStringList services = bus.interface()->registeredServiceNames().value();
    QString activePlayer = "";
    for (const QString &service : services) if (service.startsWith("org.mpris.MediaPlayer2.")) { activePlayer = service; break; }

    if (activePlayer.isEmpty()) {
        if (m_mediaTitle != "") { m_mediaTitle = ""; m_mediaArtist = ""; m_mediaArt = ""; m_mediaPlaybackStatus = "Stopped"; emit mediaChanged(); }
        return;
    }

    QDBusInterface playerInterface(activePlayer, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", bus);
    if (!playerInterface.isValid()) return;

    QDBusReply<QVariant> statusReply = playerInterface.call("Get", "org.mpris.MediaPlayer2.Player", "PlaybackStatus");
    QString status = statusReply.isValid() ? statusReply.value().toString() : "Stopped";

    QDBusReply<QVariant> metadataReply = playerInterface.call("Get", "org.mpris.MediaPlayer2.Player", "Metadata");
    if (metadataReply.isValid()) {
        QDBusArgument arg = metadataReply.value().value<QDBusArgument>();
        QMap<QString, QVariant> metadata; arg >> metadata;

        QString title = metadata.value("xesam:title").toString();
        QString artist = metadata.value("xesam:artist").canConvert<QStringList>() ? metadata.value("xesam:artist").toStringList().join(", ") : metadata.value("xesam:artist").toString();
        QString rawArtUrl = metadata.value("mpris:artUrl").toString();
        QString diskArtPath = "";

        if (!rawArtUrl.isEmpty()) {
            if (rawArtUrl.startsWith("file://")) diskArtPath = rawArtUrl;
            else if (rawArtUrl.startsWith("http://") || rawArtUrl.startsWith("https://")) {
                QString checksum = QString(QCryptographicHash::hash(rawArtUrl.toUtf8(), QCryptographicHash::Sha256).toHex());
                QString targetLocalPath = QDir::homePath() + "/.cache/luminate-shell/art/" + checksum;
                QDir().mkpath(QFileInfo(targetLocalPath).absolutePath());
                if (!QFile::exists(targetLocalPath)) QProcess::startDetached("curl", {"-s", "-L", "-o", targetLocalPath, rawArtUrl});
                diskArtPath = "file://" + targetLocalPath;
            }
        }

        if (m_mediaTitle != title || m_mediaArtist != artist || m_mediaPlaybackStatus != status || m_mediaArt != diskArtPath) {
            m_mediaTitle = title; m_mediaArtist = artist; m_mediaPlaybackStatus = status; m_mediaArt = diskArtPath;
            emit mediaChanged();
        }
    }
}

void WallpaperBackend::sendMprisCommand(const QString &command) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    for (const QString &service : bus.interface()->registeredServiceNames().value()) {
        if (service.startsWith("org.mpris.MediaPlayer2.")) {
            QDBusInterface player(service, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", bus);
            if (player.isValid()) { player.call(command); break; }
        }
    }
}

void WallpaperBackend::mediaPlayPause() { sendMprisCommand("PlayPause"); }
void WallpaperBackend::mediaNext() { sendMprisCommand("Next"); }
void WallpaperBackend::mediaPrev() { sendMprisCommand("Previous"); }

void WallpaperBackend::loadWallpapers() {
    qDebug() << "[SurfaceDesk] loadWallpapers() triggered.";
    QString path = "/home/meismeric/Pictures/Wallpapers";
    QDir dir(path);
    if (!dir.exists()) {
        qWarning() << "[SurfaceDesk] Wallpaper directory does not exist:" << path;
        return;
    }

    m_wallpaperList.clear();
    for (const QString &file : dir.entryList({"*.png", "*.jpg", "*.jpeg", "*.webp"}, QDir::Files)) m_wallpaperList.append(dir.absoluteFilePath(file));

    if (!m_wallpaperList.isEmpty()) {
        QSettings settings;
        QString lastWallpaper = settings.value("lastWallpaper").toString();
        m_currentWallpaper = (!lastWallpaper.isEmpty() && m_wallpaperList.contains(lastWallpaper)) ? lastWallpaper : m_wallpaperList.first();
        qDebug() << "[SurfaceDesk] Current wallpaper selected:" << m_currentWallpaper;
        
        generateTheme(m_currentWallpaper);
        updateResolution(m_currentWallpaper);
    } else {
        m_currentWallpaper = "";
    }

    emit wallpaperListChanged();
    emit currentWallpaperChanged();
}

void WallpaperBackend::updateResolution(const QString &path) {
    QImageReader reader(path);
    m_currentResolution = reader.canRead() ? QString("%1  %2").arg(reader.size().width()).arg(reader.size().height()) : "Unknown";
    emit currentResolutionChanged();
}

QString WallpaperBackend::currentWallpaper() const { return m_currentWallpaper; }
void WallpaperBackend::setWallpaper(const QString &path) {
    if (m_currentWallpaper != path) {
        m_currentWallpaper = path;
        QSettings settings; settings.setValue("lastWallpaper", m_currentWallpaper);
        emit currentWallpaperChanged();
        generateTheme(path);
        updateResolution(path);
    }
}

QStringList WallpaperBackend::wallpaperList() const { return m_wallpaperList; }
bool WallpaperBackend::isPickingWallpaper() const { return m_isPickingWallpaper; }
void WallpaperBackend::setIsPickingWallpaper(bool picking) {
    if (m_isPickingWallpaper != picking) {
        m_isPickingWallpaper = picking;
        updateWorkspaceState();
        if (m_isPickingWallpaper) { m_confirmedWallpaper = m_currentWallpaper; emit confirmedWallpaperChanged(); }
        emit isPickingWallpaperChanged();
    }
}

QString WallpaperBackend::confirmedWallpaper() const { return m_confirmedWallpaper; }
QStringList WallpaperBackend::wallpaperPalette() const { return m_wallpaperPalette; }
QString WallpaperBackend::currentResolution() const { return m_currentResolution; }
bool WallpaperBackend::isEditing() const { return m_isEditing; }
void WallpaperBackend::setIsEditing(bool editing) { if (m_isEditing != editing) { m_isEditing = editing; updateWorkspaceState(); emit isEditingChanged(); } }
bool WallpaperBackend::isEditingLockscreen() const { return m_isEditingLockscreen; }
void WallpaperBackend::setIsEditingLockscreen(bool editing) { if (m_isEditingLockscreen != editing) { m_isEditingLockscreen = editing; updateWorkspaceState(); emit isEditingLockscreenChanged(); } }
bool WallpaperBackend::isLocked() const { return m_isLocked; }
void WallpaperBackend::setLocked(bool locked) { if (m_isLocked != locked) { m_isLocked = locked; emit isLockedChanged(); } }

void WallpaperBackend::updateWorkspaceState() {
    if (qEnvironmentVariableIsSet("HYPRLAND_INSTANCE_SIGNATURE")) {
        if (m_isEditing || m_isEditingLockscreen || m_isPickingWallpaper) {
            if (m_previousWorkspace.isEmpty()) {
                QProcess proc; proc.start("hyprctl", {"activeworkspace", "-j"});
                if (proc.waitForFinished(800)) {
                    QJsonDocument doc = QJsonDocument::fromJson(proc.readAllStandardOutput());
                    if (doc.isObject()) {
                        m_previousWorkspace = doc.object().value("name").toString();
                        if (m_previousWorkspace.isEmpty()) m_previousWorkspace = QString::number(doc.object().value("id").toInt());
                    }
                }
                QProcess::startDetached("hyprctl", {"dispatch", "workspace", "empty"});
            }
        } else {
            if (!m_previousWorkspace.isEmpty()) {
                QProcess::startDetached("hyprctl", {"dispatch", "workspace", m_previousWorkspace});
                m_previousWorkspace.clear();
            }
        }
    }
}

void WallpaperBackend::ToggleWallpaperMode() { setIsPickingWallpaper(!isPickingWallpaper()); }
void WallpaperBackend::ToggleEditMode() { setIsEditing(!isEditing()); }
void WallpaperBackend::ToggleLockscreenEditMode() { setIsEditingLockscreen(!isEditingLockscreen()); }