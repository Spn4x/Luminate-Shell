#include <QCoreApplication>
#include <QObject>
#include <QTimer>
#include <QFile>
#include <QDir>
#include <QDBusConnection>
#include <QDBusAbstractAdaptor>
#include <QDBusMessage>
#include <QRegularExpression>
#include <QDebug>

class StatsAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.meismeric.luminate.Stats")
    Q_PROPERTY(double cpu_usage READ cpuUsage NOTIFY cpuUsageChanged)
    Q_PROPERTY(double ram_usage READ ramUsage NOTIFY ramUsageChanged)
    Q_PROPERTY(double temp_c READ tempC NOTIFY tempCChanged)
    Q_PROPERTY(double battery_percent READ batteryPercent NOTIFY batteryPercentChanged)

public:
    explicit StatsAdaptor(QObject *parent) : QDBusAbstractAdaptor(parent) {}
    double cpuUsage() const { return m_cpu; }
    double ramUsage() const { return m_ram; }
    double tempC() const { return m_temp; }
    double batteryPercent() const { return m_bat; }

    void updateStats(double c, double r, double t, double b) {
        bool changed = false;
        if (qAbs(m_cpu - c) > 0.001) { m_cpu = c; emit cpuUsageChanged(); changed = true; }
        if (qAbs(m_ram - r) > 0.001) { m_ram = r; emit ramUsageChanged(); changed = true; }
        if (qAbs(m_temp - t) > 0.1) { m_temp = t; emit tempCChanged(); changed = true; }
        if (qAbs(m_bat - b) > 0.1) { m_bat = b; emit batteryPercentChanged(); changed = true; }
        if (changed) {
            QDBusMessage signal = QDBusMessage::createSignal("/com/meismeric/luminate/Stats", "org.freedesktop.DBus.Properties", "PropertiesChanged");
            QVariantMap props;
            props.insert("cpu_usage", m_cpu); props.insert("ram_usage", m_ram);
            props.insert("temp_c", m_temp); props.insert("battery_percent", m_bat);
            signal << "com.meismeric.luminate.Stats" << props << QStringList();
            QDBusConnection::sessionBus().send(signal);
        }
    }

signals:
    void cpuUsageChanged(); void ramUsageChanged(); void tempCChanged(); void batteryPercentChanged();
private:
    double m_cpu = 0.0, m_ram = 0.0, m_temp = 0.0, m_bat = 100.0;
};

class WidgetDaemon : public QObject {
    Q_OBJECT
public:
    WidgetDaemon() {
        m_adaptor = new StatsAdaptor(this);
        QDBusConnection::sessionBus().registerService("com.meismeric.luminate.Stats");
        QDBusConnection::sessionBus().registerObject("/com/meismeric/luminate/Stats", this);
        QTimer *timer = new QTimer(this);
        connect(timer, &QTimer::timeout, this, &WidgetDaemon::pollSystem);
        timer->start(2000); pollSystem();
    }
private slots:
    void pollSystem() { m_adaptor->updateStats(getCpuUsage(), getRamUsage(), getTemp(), getBattery()); }
private:
    StatsAdaptor *m_adaptor;
    uint64_t m_prevTotal = 0, m_prevIdle = 0;

    double getCpuUsage() {
        QFile file("/proc/stat");
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return 0.0;
        QStringList parts = QString(file.readLine()).split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
        if (parts.size() > 4) {
            uint64_t currentIdle = parts[4].toULongLong() + parts[5].toULongLong();
            uint64_t currentTotal = parts[1].toULongLong() + parts[2].toULongLong() + parts[3].toULongLong() + currentIdle + parts[6].toULongLong() + parts[7].toULongLong() + parts[8].toULongLong();
            uint64_t totalDiff = currentTotal - m_prevTotal, idleDiff = currentIdle - m_prevIdle;
            m_prevTotal = currentTotal; m_prevIdle = currentIdle;
            if (totalDiff > 0) return (double)(totalDiff - idleDiff) / totalDiff;
        }
        return 0.0;
    }
    double getRamUsage() {
        QFile file("/proc/meminfo");
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return 0.0;
        double total = 0.0, avail = 0.0; QTextStream in(&file);
        while (!in.atEnd()) {
            QString line = in.readLine();
            if (line.startsWith("MemTotal:")) total = line.section(' ', -2, -2).toDouble();
            else if (line.startsWith("MemAvailable:")) avail = line.section(' ', -2, -2).toDouble();
            if (total > 0 && avail > 0) break;
        }
        return total > 0 ? (total - avail) / total : 0.0;
    }
    double getTemp() {
        QDir dir("/sys/class/hwmon");
        for (const QString &entry : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            QFile file(dir.absoluteFilePath(entry) + "/temp1_input");
            if (file.open(QIODevice::ReadOnly | QIODevice::Text)) return file.readAll().trimmed().toDouble() / 1000.0;
        }
        return 0.0;
    }
    double getBattery() {
        QDir dir("/sys/class/power_supply");
        for (const QString &entry : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            if (entry.startsWith("BAT")) {
                QFile file(dir.absoluteFilePath(entry) + "/capacity");
                if (file.open(QIODevice::ReadOnly | QIODevice::Text)) return file.readAll().trimmed().toDouble();
            }
        }
        return 100.0;
    }
};

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    WidgetDaemon daemon;
    qDebug() << "luminate-widgetd: Running System Stats DBus provider.";
    return app.exec();
}
#include "widgetd.moc"