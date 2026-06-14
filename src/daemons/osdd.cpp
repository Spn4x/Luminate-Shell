#include <QCoreApplication>
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QDebug>

class OSDDaemon : public QObject {
    Q_OBJECT
public:
    OSDDaemon() {
        m_uiIface = new QDBusInterface("com.meismeric.luminate.UI", "/com/meismeric/luminate/UI", "com.meismeric.luminate.UI", QDBusConnection::sessionBus(), this);
        
        m_volProc = new QProcess(this);
        connect(m_volProc, &QProcess::readyReadStandardOutput, this, [this](){
            QString out = m_volProc->readAllStandardOutput();
            if (out.contains("change") && out.contains("on sink") && !out.contains("input")) handleVolume(false);
        });
        m_volProc->start("pactl", QStringList() << "subscribe");

        m_udevBacklight = new QProcess(this);
        connect(m_udevBacklight, &QProcess::readyReadStandardOutput, this, [this]() {
            if (QString(m_udevBacklight->readAllStandardOutput()).contains("backlight")) handleBrightness();
        });
        m_udevBacklight->start("udevadm", QStringList() << "monitor" << "--subsystem-match=backlight");

        m_udevBattery = new QProcess(this);
        connect(m_udevBattery, &QProcess::readyReadStandardOutput, this, [this]() {
            if (QString(m_udevBattery->readAllStandardOutput()).contains("power_supply")) handleBattery(true);
        });
        m_udevBattery->start("udevadm", QStringList() << "monitor" << "--subsystem-match=power_supply");

        handleVolume(true); handleBrightness(true); handleBattery(false);
    }

private:
    QDBusInterface *m_uiIface;
    QProcess *m_volProc, *m_udevBacklight, *m_udevBattery;
    double m_lastVol = -1.0, m_lastBri = -1.0, m_lastBat = -1.0;
    bool m_lastMuted = false; QString m_lastStatus = "";

    void handleVolume(bool isStartup) {
        QProcess p; p.start("wpctl", {"get-volume", "@DEFAULT_AUDIO_SINK@"}); p.waitForFinished();
        QString out = p.readAllStandardOutput();
        bool muted = out.contains("[MUTED]");
        double vol = 0.0;
        QStringList parts = out.split(QRegularExpression("\\s+"));
        if (parts.size() >= 2) vol = parts[1].toDouble();
        if (vol == 0.0) muted = true;

        if (!isStartup && (qAbs(m_lastVol - vol) > 0.001 || m_lastMuted != muted)) {
            QString icon = muted ? "audio-volume-muted-symbolic" : (vol < 0.33 ? "audio-volume-low-symbolic" : (vol < 0.66 ? "audio-volume-medium-symbolic" : (vol <= 1.0 ? "audio-volume-high-symbolic" : "audio-volume-overamplified-symbolic")));
            m_uiIface->asyncCall("ShowOSD", icon, vol);
        }
        m_lastVol = vol; m_lastMuted = muted;
    }

    void handleBrightness(bool isStartup = false) {
        QProcess getP; getP.start("brightnessctl", {"get"}); getP.waitForFinished();
        QProcess maxP; maxP.start("brightnessctl", {"max"}); maxP.waitForFinished();
        double c = QString(getP.readAllStandardOutput()).trimmed().toDouble();
        double m = QString(maxP.readAllStandardOutput()).trimmed().toDouble();
        if (m > 0) {
            double lvl = std::min(c / m, 1.0);
            if (!isStartup && qAbs(m_lastBri - lvl) > 0.001) m_uiIface->asyncCall("ShowOSD", "display-brightness-symbolic", lvl);
            m_lastBri = lvl;
        }
    }

    void handleBattery(bool allowNotify) {
        double cap = -1.0; QString status; QDir dir("/sys/class/power_supply");
        for (const QString &entry : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            if (entry.startsWith("BAT")) {
                QFile fCap(dir.absoluteFilePath(entry) + "/capacity");
                if (fCap.open(QIODevice::ReadOnly)) cap = fCap.readAll().trimmed().toDouble();
                QFile fStat(dir.absoluteFilePath(entry) + "/status");
                if (fStat.open(QIODevice::ReadOnly)) status = fStat.readAll().trimmed();
                break;
            }
        }
        if (cap >= 0 && !status.isEmpty()) {
            bool isDischarging = (status == "Discharging");
            bool pluggedChanged = (isDischarging != (m_lastStatus == "Discharging")) && !m_lastStatus.isEmpty();
            bool hit50 = (cap == 50.0 && m_lastBat != 50.0 && isDischarging);
            m_lastBat = cap; m_lastStatus = status;

            if (allowNotify && (pluggedChanged || hit50)) {
                bool isFull = (status == "Full" || status == "Not charging" || cap >= 99.0);
                QString iconBase = cap >= 90 ? "battery-full" : (cap >= 70 ? "battery-good" : (cap >= 30 ? "battery-half" : (cap >= 10 ? "battery-low" : "battery-empty")));
                QString finalIcon = (isFull && !isDischarging) ? "battery-full-charged-symbolic" : (iconBase + (isDischarging ? "-symbolic" : "-charging-symbolic"));
                QString title = hit50 ? "Battery at 50%" : (isDischarging ? QString("Charger Disconnected (%1%)").arg(cap) : (isFull ? QString("Battery Full (%1%)").arg(cap) : QString("Charger Plugged In (%1%)").arg(cap)));
                QProcess::startDetached("notify-send", {"-u", "normal", "-i", finalIcon, title});
            }
        }
    }
};

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    OSDDaemon daemon;
    qDebug() << "luminate-osdd: Running hardware event watcher.";
    return app.exec();
}
#include "osdd.moc"