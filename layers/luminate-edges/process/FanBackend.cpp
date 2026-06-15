#include "FanBackend.h"
#include <QFile>
#include <QProcess>
#include <QDebug>
#include <unistd.h>
#include <sensors/sensors.h>

FanBackend::FanBackend(QObject *parent) : QObject(parent) {
    sensors_init(NULL);

    // Pre-fill history arrays (60 seconds)
    for (int i = 0; i < 60; i++) {
        m_rpmHistory.append(0.0);
        m_tempHistory.append(0.0);
    }

    ensurePermissions();

    connect(&m_timer, &QTimer::timeout, this, &FanBackend::pollHardware);
    m_timer.start(1000);
    pollHardware();
}

FanBackend::~FanBackend() {
    sensors_cleanup();
}

void FanBackend::ensurePermissions() {
    if (access("/proc/acpi/ibm/fan", W_OK) != 0) {
        qDebug() << "[FanBackend] Requesting pkexec permissions to write to /proc/acpi/ibm/fan";
        QProcess::startDetached("pkexec", {"chmod", "666", "/proc/acpi/ibm/fan"});
    }
}

void FanBackend::pollHardware() {
    // 1. Fetch fan RPM and Level
    QFile fanFile("/proc/acpi/ibm/fan");
    if (fanFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString content = fanFile.readAll();
        fanFile.close();

        for (const QString& line : content.split('\n')) {
            if (line.startsWith("speed:")) {
                m_rpm = line.mid(6).trimmed().toInt();
            } else if (line.startsWith("level:")) {
                m_mode = line.mid(6).trimmed();
            }
        }
    }

    // 2. Fetch Best CPU Temp via libsensors
    double bestTemp = 0.0;
    const sensors_chip_name *cn;
    int c = 0;
    while ((cn = sensors_get_detected_chips(NULL, &c))) {
        const sensors_feature *feat;
        int f = 0;
        while ((feat = sensors_get_features(cn, &f))) {
            if (feat->type == SENSORS_FEATURE_TEMP) {
                const sensors_subfeature *sub = sensors_get_subfeature(cn, feat, SENSORS_SUBFEATURE_TEMP_INPUT);
                if (sub) {
                    double val;
                    if (sensors_get_value(cn, sub->number, &val) == 0) {
                        char *label = sensors_get_label(cn, feat);
                        QString lStr = QString(label).toLower();
                        // Prioritize core packages
                        if (lStr.contains("cpu") || lStr.contains("package id 0")) {
                            bestTemp = val;
                        } else if (bestTemp == 0.0 && lStr.contains("temp1")) {
                            bestTemp = val;
                        }
                        free(label);
                    }
                }
            }
        }
    }
    m_temperature = bestTemp;

    // 3. Update History
    m_rpmHistory.removeFirst();
    m_rpmHistory.append((double)m_rpm);
    
    m_tempHistory.removeFirst();
    m_tempHistory.append(m_temperature);

    emit statsChanged();
    emit historyChanged();
}

void FanBackend::setMode(const QString& mode) {
    QFile fanFile("/proc/acpi/ibm/fan");
    if (fanFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        fanFile.write(QString("level " + mode).toUtf8());
        fanFile.close();
    } else {
        ensurePermissions();
    }
    // Instantly reflect state
    pollHardware();
}