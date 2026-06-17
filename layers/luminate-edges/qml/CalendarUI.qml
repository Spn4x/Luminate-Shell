import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Luminate.Shell

Item {
    id: calendarRoot
    implicitHeight: mainLayout.implicitHeight

    // Instantly reset to the current month whenever the pulltab opens
    onVisibleChanged: {
        if (visible) {
            CalendarBackend.resetToToday();
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 16

        // 1. HEADER (Arrows & Month/Year Label)
        RowLayout {
            Layout.fillWidth: true

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: AppTheme.actionRadius
                color: prevMouse.pressed ? AppTheme.actionBgHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰅂" // Chevron left (NerdFont)
                    font.family: AppTheme.iconFont
                    font.pixelSize: 18
                    color: AppTheme.fg
                }
                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CalendarBackend.prevMonth()
                }
            }

            Text {
                Layout.fillWidth: true
                text: CalendarBackend.monthYear
                color: AppTheme.fg
                font.family: AppTheme.mainFont
                font.pixelSize: 14
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: AppTheme.actionRadius
                color: nextMouse.pressed ? AppTheme.actionBgHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰅁" // Chevron right (NerdFont)
                    font.family: AppTheme.iconFont
                    font.pixelSize: 18
                    color: AppTheme.fg
                }
                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CalendarBackend.nextMonth()
                }
            }
        }

        // 2. DAYS OF WEEK HEADER
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                Text {
                    Layout.fillWidth: true
                    text: modelData
                    color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.5)
                    font.family: AppTheme.mainFont
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // 3. CALENDAR GRID
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: CalendarBackend.days
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width // Enforce square cells dynamically
                    radius: AppTheme.actionRadius
                    
                    color: modelData.isToday ? AppTheme.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.dayText
                        font.family: AppTheme.mainFont
                        font.pixelSize: 12
                        font.bold: modelData.isToday || modelData.isCurrentMonth
                        color: {
                            if (modelData.isToday) return AppTheme.bg;
                            if (modelData.isCurrentMonth) return AppTheme.fg;
                            return Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.3);
                        }
                    }
                }
            }
        }
    }
}