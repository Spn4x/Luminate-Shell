#pragma once
#include <QObject>
#include <QVariantList>
#include <QString>
#include <QDate>

class CalendarBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString monthYear READ monthYear NOTIFY calendarChanged)
    Q_PROPERTY(QVariantList days READ days NOTIFY calendarChanged)

public:
    explicit CalendarBackend(QObject *parent = nullptr);

    QString monthYear() const { return m_monthYear; }
    QVariantList days() const { return m_days; }

    Q_INVOKABLE void nextMonth();
    Q_INVOKABLE void prevMonth();
    Q_INVOKABLE void resetToToday();

signals:
    void calendarChanged();

private:
    void updateCalendar();

    QDate m_displayDate;
    QString m_monthYear;
    QVariantList m_days;
};