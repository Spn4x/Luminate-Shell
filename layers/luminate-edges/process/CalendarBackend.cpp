#include "CalendarBackend.h"

CalendarBackend::CalendarBackend(QObject *parent) : QObject(parent) {
    resetToToday();
}

void CalendarBackend::nextMonth() {
    m_displayDate = m_displayDate.addMonths(1);
    updateCalendar();
}

void CalendarBackend::prevMonth() {
    m_displayDate = m_displayDate.addMonths(-1);
    updateCalendar();
}

void CalendarBackend::resetToToday() {
    m_displayDate = QDate::currentDate();
    updateCalendar();
}

void CalendarBackend::updateCalendar() {
    QVariantList newDays;
    
    // First day of the currently displayed month
    QDate firstDay(m_displayDate.year(), m_displayDate.month(), 1);
    
    // Calculate offset to make Sunday the first column (1=Mon, 7=Sun -> offset mapping)
    int startDayOfWeek = firstDay.dayOfWeek();
    int offset = startDayOfWeek % 7; 
    
    QDate iterDate = firstDay.addDays(-offset);
    QDate today = QDate::currentDate();
    
    // Generate exactly 42 cells (6 rows * 7 days) to ensure the grid height never jumps
    for (int i = 0; i < 42; ++i) {
        QVariantMap map;
        map["dayText"] = QString::number(iterDate.day());
        map["isCurrentMonth"] = (iterDate.month() == m_displayDate.month());
        map["isToday"] = (iterDate == today);
        newDays.append(map);
        iterDate = iterDate.addDays(1);
    }
    
    m_days = newDays;
    m_monthYear = m_displayDate.toString("MMMM yyyy");
    
    emit calendarChanged();
}