#pragma once
#include <QObject>
#include <QString>
#include <QTimer>

class TopbarBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString clockTime READ clockTime NOTIFY clockChanged)
    Q_PROPERTY(QString clockDate READ clockDate NOTIFY clockChanged)
    Q_PROPERTY(double timeProgress READ timeProgress NOTIFY clockChanged)
    Q_PROPERTY(double monthProgress READ monthProgress NOTIFY clockChanged)

    Q_PROPERTY(double cpuPct READ cpuPct NOTIFY sysinfoChanged)
    Q_PROPERTY(double ramPct READ ramPct NOTIFY sysinfoChanged)
    Q_PROPERTY(double tempPct READ tempPct NOTIFY sysinfoChanged)
    Q_PROPERTY(double batPct READ batPct NOTIFY sysinfoChanged)
    Q_PROPERTY(int cpuVal READ cpuVal NOTIFY sysinfoChanged)
    Q_PROPERTY(int ramVal READ ramVal NOTIFY sysinfoChanged)
    Q_PROPERTY(int tempVal READ tempVal NOTIFY sysinfoChanged)
    Q_PROPERTY(int batVal READ batVal NOTIFY sysinfoChanged)

    Q_PROPERTY(bool isMenuOpen READ isMenuOpen WRITE setIsMenuOpen NOTIFY isMenuOpenChanged)

public:
    explicit TopbarBackend(QObject *parent = nullptr);
    ~TopbarBackend() {}

    QString clockTime() const { return m_time; }
    QString clockDate() const { return m_date; }
    double timeProgress() const { return m_timeProgress; }
    double monthProgress() const { return m_monthProgress; }

    double cpuPct() const { return m_cpuPct; }
    double ramPct() const { return m_ramPct; }
    double tempPct() const { return m_tempPct; }
    double batPct() const { return m_batPct; }
    int cpuVal() const { return m_cpuVal; }
    int ramVal() const { return m_ramVal; }
    int tempVal() const { return m_tempVal; }
    int batVal() const { return m_batVal; }

    bool isMenuOpen() const { return m_isMenuOpen; }
    void setIsMenuOpen(bool open);

    Q_INVOKABLE void runCommand(const QString &cmd);

signals:
    void clockChanged();
    void sysinfoChanged();
    void isMenuOpenChanged();

private slots:
    void updateClock();
    void updateSysinfo();

private:
    void findTempSensor();

    QString m_time, m_date;
    double m_timeProgress = 0.0;
    double m_monthProgress = 0.0;
    QTimer m_clockTimer;

    QTimer m_sysinfoTimer;
    ulong m_lastTotal = 0;
    ulong m_lastIdle = 0;
    double m_cpuPct = 0, m_ramPct = 0, m_tempPct = 0, m_batPct = 0;
    int m_cpuVal = 0, m_ramVal = 0, m_tempVal = 0, m_batVal = 0;
    QString m_tempFilePath;
    bool m_isMenuOpen = false;
};