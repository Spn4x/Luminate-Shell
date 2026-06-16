#include "PolkitBackend.h"
#include <QDebug>

PolkitBackend::PolkitBackend(QObject *parent) : QObject(parent) {}

void PolkitBackend::runElevated(const QString &command, const QString &reason) {
    // THE FIX: Prevent spam-clicking from killing and restating sudo in an infinite loop!
    if (m_process && m_process->state() == QProcess::Running) {
        return; 
    }

    if (m_process) {
        m_process->kill();
        m_process->waitForFinished(200);
        delete m_process;
    }

    m_authMessage = reason;
    emit authMessageChanged();

    m_process = new QProcess(this);
    m_process->setProcessChannelMode(QProcess::SeparateChannels);

    connect(m_process, &QProcess::readyReadStandardError, this, [this]() {
        if (!m_process) return;
        QString err = m_process->readAllStandardError();
        
        if (err.contains("AUTHSUDO_PROMPT")) {
            emit authRequested(m_authMessage);
        } else if (err.contains("try again", Qt::CaseInsensitive) || err.contains("incorrect", Qt::CaseInsensitive)) {
            emit authFailed();
        }
    });

    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this](int exitCode, QProcess::ExitStatus exitStatus) {
        if (exitCode == 0 && exitStatus == QProcess::NormalExit) {
            emit authResolved(true);
        } else {
            emit authResolved(false);
        }
        m_process->deleteLater();
        m_process = nullptr;
    });

    m_process->start("sudo", {"-S", "-p", "AUTHSUDO_PROMPT", "sh", "-c", command});
}

void PolkitBackend::submitPassword(const QString &password) {
    if (m_process && m_process->state() == QProcess::Running) {
        m_process->write(password.toUtf8() + "\n");
    }
}

void PolkitBackend::cancelAuth() {
    if (m_process) {
        m_process->kill();
        m_process->waitForFinished(200);
        delete m_process;
        m_process = nullptr;
    }
    emit authResolved(false);
}