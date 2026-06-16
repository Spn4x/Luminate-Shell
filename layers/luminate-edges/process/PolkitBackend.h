#pragma once
#include <QObject>
#include <QProcess>
#include <QString>

class PolkitBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString authMessage READ authMessage NOTIFY authMessageChanged)

public:
    explicit PolkitBackend(QObject *parent = nullptr);
    QString authMessage() const { return m_authMessage; }

    Q_INVOKABLE void runElevated(const QString &command, const QString &reason);
    Q_INVOKABLE void submitPassword(const QString &password);
    Q_INVOKABLE void cancelAuth();

signals:
    void authMessageChanged();
    void authRequested(const QString &message);
    void authFailed();
    void authResolved(bool success);

private:
    QString m_authMessage;
    QProcess *m_process = nullptr;
};