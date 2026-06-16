#include "FanBackend.h"
#include "PolkitBackend.h"
#include <QFile>
#include <QDebug>
#include <unistd.h>
#include <sensors/sensors.h>

FanBackend::FanBackend(PolkitBackend *polkit, QObject *parent) : QObject(parent), m_polkit(polkit) {
    sensors_init(NULL);

    for (int i = 0; i < 60; i++) {
        m_rpmHistory.append(0.0);
        m_tempHistory.append(0.0);
    }

    if (m_polkit) {
        connect(m_polkit, &PolkitBackend::authResolved, this, [this](bool success) {
            if (success) {
                // Instantly apply the selected mode if it was cached behind a permissions wall
                if (!m_pendingMode.isEmpty()) {
                    setMode(m_pendingMode);
                    m_pendingMode.clear();
                }
                pollHardware(); 
            }
        });
    }

    connect(&m_timer, &QTimer::timeout, this, &FanBackend::pollHardware);
    m_timer.start(1000);
    pollHardware();
}

FanBackend::~FanBackend() {
    sensors_cleanup();
}

void FanBackend::requestPermissions() {
    ensurePermissions();
}

void FanBackend::ensurePermissions() {
    if (access("/proc/acpi/ibm/fan", W_OK) == 0) return; // We already have permissions
    
    if (m_polkit) {
        m_polkit->runElevated("chmod 666 /proc/acpi/ibm/fan", "ThinkFan requires access to the system hardware controllers.");
    }
}

void FanBackend::pollHardware() {
    QFile fanFile("/proc/acpi/ibm/fan");
    if (fanFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString content = fanFile.readAll();
        fanFile.close();
        for (const QString& line : content.split('\n')) {
            if (line.startsWith("speed:")) m_rpm = line.mid(6).trimmed().toInt();
            else if (line.startsWith("level:")) m_mode = line.mid(6).trimmed();
        }
    }

    double bestTemp = 0.0;
    const sensors_chip_name *cn; int c = 0;
    while ((cn = sensors_get_detected_chips(NULL, &c))) {
        const sensors_feature *feat; int f = 0;
        while ((feat = sensors_get_features(cn, &f))) {
            if (feat->type == SENSORS_FEATURE_TEMP) {
                const sensors_subfeature *sub = sensors_get_subfeature(cn, feat, SENSORS_SUBFEATURE_TEMP_INPUT);
                if (sub) {
                    double val;
                    if (sensors_get_value(cn, sub->number, &val) == 0) {
                        char *label = sensors_get_label(cn, feat);
                        QString lStr = QString(label).toLower();
                        if (lStr.contains("cpu") || lStr.contains("package id 0")) bestTemp = val;
                        else if (bestTemp == 0.0 && lStr.contains("temp1")) bestTemp = val;
                        free(label);
                    }
                }
            }
        }
    }
    m_temperature = bestTemp;

    m_rpmHistory.removeFirst(); m_rpmHistory.append((double)m_rpm);
    m_tempHistory.removeFirst(); m_tempHistory.append(m_temperature);

    emit statsChanged(); emit historyChanged();
}

void FanBackend::setMode(const QString& mode) {
    QFile fanFile("/proc/acpi/ibm/fan");
    if (fanFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        fanFile.write(QString("level " + mode).toUtf8());
        fanFile.close();
        m_pendingMode.clear();
    } else {
        m_pendingMode = mode; 
        ensurePermissions();
    }
    pollHardware();
}