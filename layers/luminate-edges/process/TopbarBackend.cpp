#include "TopbarBackend.h"
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QDBusMessage>
#include <QDBusConnection>
#include <QDBusReply>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusVariant>
#include <QProcess>
#include <stdio.h>
#include <string.h>

TopbarBackend::TopbarBackend(QObject *parent) : QObject(parent) {
    connect(&m_clockTimer, &QTimer::timeout, this, &TopbarBackend::updateClock);
    m_clockTimer.start(1000);
    updateClock();

    findTempSensor();
    connect(&m_sysinfoTimer, &QTimer::timeout, this, &TopbarBackend::updateSysinfo);
    m_sysinfoTimer.start(2000);
    updateSysinfo();
}

void TopbarBackend::setIsMenuOpen(bool open) {
    if (m_isMenuOpen != open) {
        m_isMenuOpen = open;
        emit isMenuOpenChanged();
    }
}

void TopbarBackend::runCommand(const QString &cmd) {
    QProcess::startDetached("sh", {"-c", cmd});
}

void TopbarBackend::updateClock() {
    QDateTime now = QDateTime::currentDateTime();
    m_time = now.toString("hh:mm AP");
    m_date = now.toString("MMM dd");

    double current_minutes = (now.time().hour() * 60.0) + now.time().minute();
    m_timeProgress = current_minutes / 1440.0;
    m_monthProgress = (double)now.date().day() / (double)now.date().daysInMonth();
    emit clockChanged();
}

void TopbarBackend::findTempSensor() {
    QDir hwmonDir("/sys/class/hwmon");
    QStringList hwmons = hwmonDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &hw : hwmons) {
        QString path = "/sys/class/hwmon/" + hw + "/temp1_input";
        if (QFile::exists(path)) { m_tempFilePath = path; break; }
    }
}

void TopbarBackend::updateSysinfo() {
    FILE* cpuFp = fopen("/proc/stat", "r");
    if (cpuFp) {
        ulong user, nice, sys, idle, iowait, irq, softirq, steal;
        if (fscanf(cpuFp, "cpu %lu %lu %lu %lu %lu %lu %lu %lu", &user, &nice, &sys, &idle, &iowait, &irq, &softirq, &steal) == 8) {
            ulong currentIdle = idle + iowait;
            ulong currentTotal = user + nice + sys + currentIdle + irq + softirq + steal;
            if (m_lastTotal > 0 && currentTotal > m_lastTotal) {
                ulong totalDiff = currentTotal - m_lastTotal;
                ulong idleDiff = currentIdle - m_lastIdle;
                m_cpuPct = static_cast<double>(totalDiff - idleDiff) / static_cast<double>(totalDiff);
                m_cpuVal = qRound(m_cpuPct * 100.0);
            }
            m_lastTotal = currentTotal;
            m_lastIdle = currentIdle;
        }
        fclose(cpuFp);
    }

    FILE* ramFp = fopen("/proc/meminfo", "r");
    if (ramFp) {
        long memTotal = 0, memAvailable = 0;
        char line[256];
        while (fgets(line, sizeof(line), ramFp)) {
            char key[64]; long val = 0;
            if (sscanf(line, "%63s %ld", key, &val) >= 2) {
                if (strcmp(key, "MemTotal:") == 0) memTotal = val;
                else if (strcmp(key, "MemAvailable:") == 0) memAvailable = val;
            }
        }
        fclose(ramFp);
        if (memTotal > 0 && memAvailable > 0) {
            m_ramPct = static_cast<double>(memTotal - memAvailable) / static_cast<double>(memTotal);
            m_ramVal = qRound(m_ramPct * 100.0);
        }
    }

    if (!m_tempFilePath.isEmpty()) {
        QFile tempFile(m_tempFilePath);
        if (tempFile.open(QIODevice::ReadOnly)) {
            long tempMc = tempFile.readAll().trimmed().toLong();
            double tempC = (tempMc > 5000) ? (tempMc / 1000.0) : (tempMc > 150 ? tempMc / 10.0 : tempMc);
            m_tempVal = (int)tempC;
            m_tempPct = std::min(tempC / 100.0, 1.0);
            tempFile.close();
        }
    }
    
    emit sysinfoChanged();

    QDBusMessage msg = QDBusMessage::createMethodCall("org.freedesktop.UPower", "/org/freedesktop/UPower/devices/DisplayDevice", "org.freedesktop.DBus.Properties", "Get");
    msg << "org.freedesktop.UPower.Device" << "Percentage";
    QDBusPendingCall call = QDBusConnection::systemBus().asyncCall(msg);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QDBusVariant> reply = *w;
        if (reply.isValid()) {
            m_batPct = reply.value().variant().toDouble() / 100.0;
            m_batVal = qRound(m_batPct * 100.0);
            emit sysinfoChanged(); 
        }
        w->deleteLater();
    });
}