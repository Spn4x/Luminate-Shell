#pragma once
#include <QObject>
#include <QVariantList>
#include <QTimer>

class FanBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(int rpm READ rpm NOTIFY statsChanged)
    Q_PROPERTY(double temperature READ temperature NOTIFY statsChanged)
    Q_PROPERTY(QString mode READ mode NOTIFY statsChanged)
    Q_PROPERTY(QVariantList rpmHistory READ rpmHistory NOTIFY historyChanged)
    Q_PROPERTY(QVariantList tempHistory READ tempHistory NOTIFY historyChanged)

public:
    explicit FanBackend(QObject *parent = nullptr);
    ~FanBackend();

    int rpm() const { return m_rpm; }
    double temperature() const { return m_temperature; }
    QString mode() const { return m_mode; }
    QVariantList rpmHistory() const { return m_rpmHistory; }
    QVariantList tempHistory() const { return m_tempHistory; }

    Q_INVOKABLE void setMode(const QString& mode);

signals:
    void statsChanged();
    void historyChanged();

private slots:
    void pollHardware();

private:
    void ensurePermissions();

    int m_rpm = 0;
    double m_temperature = 0.0;
    QString m_mode = "unknown";
    
    QVariantList m_rpmHistory;
    QVariantList m_tempHistory;
    QTimer m_timer;
};