import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Luminate.Shell

Item {
    id: calendarRoot

    onVisibleChanged: {
        if (visible) {
            CalendarBackend.resetToToday();
            Backend.fetchNotificationHistory();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 16 

        // =====================================
        // LEFT SIDE: NOTIFICATION CENTER
        // =====================================
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 260
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    text: "Notifications"
                    color: AppTheme.fg
                    font.family: AppTheme.mainFont
                    font.pixelSize: 15
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 28; height: 28; radius: AppTheme.actionRadius
                    color: dndMouse.containsMouse ? AppTheme.actionBgHover : (Backend.dndMode ? AppTheme.accentAlpha30 : AppTheme.actionBg)
                    border.color: Backend.dndMode ? AppTheme.accent : AppTheme.actionBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Backend.dndMode ? "󰂛" : "󰂚" 
                        font.family: AppTheme.iconFont
                        color: Backend.dndMode ? AppTheme.accent : AppTheme.fg
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: dndMouse
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Backend.toggleDndMode()
                    }
                }

                Rectangle {
                    width: 28; height: 28; radius: AppTheme.actionRadius
                    color: clearMouse.containsMouse ? AppTheme.actionBgHover : AppTheme.actionBg
                    border.color: AppTheme.actionBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰃢" 
                        font.family: AppTheme.iconFont
                        color: AppTheme.colorKill
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Backend.clearNotificationHistory()
                    }
                }
            }

            // Scrollable List
            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 12
                model: Backend.notificationHistory
                
                // THE FIX: Preserves expanded states across SQLite database refreshes!
                property var expandedGroups: ({})
                function toggleGroup(appName) {
                    let newMap = Object.assign({}, expandedGroups);
                    newMap[appName] = !newMap[appName];
                    expandedGroups = newMap;
                }

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Column {
                    id: groupDelegate
                    width: notifList.width - 8
                    spacing: 6
                    
                    property bool isExpanded: notifList.expandedGroups[modelData.appName] === true
                    
                    // Group dismiss animation state
                    property bool isGroupDismissing: false
                    opacity: isGroupDismissing ? 0 : 1
                    scale: isGroupDismissing ? 0.9 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    // GROUP HEADER
                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "transparent"
                        radius: AppTheme.moduleRadius
                        
                        HoverHandler { id: groupHover }

                        Rectangle {
                            anchors.fill: parent
                            color: AppTheme.surfaceAlpha
                            opacity: groupHover.hovered ? 1 : 0
                            radius: AppTheme.moduleRadius
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: headerClickArea
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.count > 1) {
                                    notifList.toggleGroup(modelData.appName);
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            
                            Image {
                                source: modelData.icon.startsWith("/") ? "file://" + modelData.icon : ""
                                sourceSize: Qt.size(14, 14)
                                Layout.preferredWidth: 14; Layout.preferredHeight: 14
                                visible: modelData.icon.startsWith("/")
                            }
                            Text {
                                text: "󰂚"
                                font.family: AppTheme.iconFont
                                color: AppTheme.accent
                                font.pixelSize: 12
                                visible: !modelData.icon.startsWith("/")
                            }

                            Text {
                                text: modelData.appName !== "" ? modelData.appName : "System"
                                color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.7)
                                font.pixelSize: 11; font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                visible: modelData.count > 1
                                width: badgeText.implicitWidth + 12
                                height: 18
                                radius: 9
                                color: AppTheme.accentAlpha30
                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: "+" + (modelData.count - 1)
                                    color: AppTheme.accent
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }

                            // Crossfade Time and 'X' button to prevent UI jumping
                            Item {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 20
                                Layout.alignment: Qt.AlignRight

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.latestTime
                                    color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.4)
                                    font.pixelSize: 10; font.bold: true
                                    opacity: groupHover.hovered ? 0 : 1
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20; height: 20; radius: 10
                                    color: clearGroupMouse.containsMouse ? AppTheme.colorKill : "transparent"
                                    opacity: groupHover.hovered ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        font.family: AppTheme.iconFont
                                        color: clearGroupMouse.containsMouse ? AppTheme.bg : AppTheme.colorKill
                                        font.pixelSize: 12
                                    }
                                    
                                    Timer {
                                        id: clearGroupTimer
                                        interval: 250
                                        onTriggered: Backend.removeNotificationGroup(modelData.appName)
                                    }
                                    
                                    MouseArea {
                                        id: clearGroupMouse
                                        anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            groupDelegate.isGroupDismissing = true;
                                            clearGroupTimer.start();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // NOTIFICATION CARDS CONTAINER
                    Column {
                        width: parent.width
                        spacing: 6
                        clip: true

                        Repeater {
                            model: modelData.notifications
                            delegate: Rectangle {
                                id: cardRect
                                width: parent.width
                                
                                property bool isDismissing: false
                                
                                height: isDismissing ? 0 : (cardCol.implicitHeight + 20)
                                color: AppTheme.actionBg
                                radius: AppTheme.moduleRadius
                                border.color: AppTheme.actionBorder
                                border.width: 1

                                visible: (groupDelegate.isExpanded || index === 0) || isDismissing
                                opacity: isDismissing ? 0 : (visible ? 1 : 0)
                                
                                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 200 } }

                                HoverHandler { id: cardHover }

                                ColumnLayout {
                                    id: cardCol
                                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                                    anchors.margins: 10
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: modelData.summary
                                            color: AppTheme.fg
                                            font.family: AppTheme.mainFont
                                            font.pixelSize: 12; font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        // THE FIX: Individual Clear Button only visible when group is expanded!
                                        Item {
                                            Layout.preferredWidth: 18
                                            Layout.preferredHeight: 18
                                            Layout.alignment: Qt.AlignRight
                                            visible: groupDelegate.isExpanded 

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 9
                                                color: clearItemMouse.containsMouse ? AppTheme.colorKill : "transparent"
                                                opacity: cardHover.hovered ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅖"
                                                    font.family: AppTheme.iconFont
                                                    color: clearItemMouse.containsMouse ? AppTheme.bg : AppTheme.colorKill
                                                    font.pixelSize: 12
                                                }
                                                
                                                Timer {
                                                    id: clearItemTimer
                                                    interval: 250
                                                    onTriggered: Backend.removeNotificationHistory(modelData.id)
                                                }
                                                
                                                MouseArea {
                                                    id: clearItemMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        cardRect.isDismissing = true;
                                                        clearItemTimer.start();
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: modelData.body
                                        color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.8)
                                        font.family: AppTheme.mainFont
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        maximumLineCount: groupDelegate.isExpanded ? 20 : 2
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "You're all caught up!"
                    color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.4)
                    font.family: AppTheme.mainFont
                    font.pixelSize: 13; font.bold: true
                    visible: notifList.count === 0
                }
            }
        }

        // =====================================
        // RIGHT SIDE: CALENDAR
        // =====================================
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 230 
            spacing: 12

            // Topbar Clock
            Text {
                Layout.fillWidth: true
                text: Topbar.clockTime
                color: AppTheme.fg
                font.family: AppTheme.mainFont
                font.pixelSize: 34
                font.bold: true
                horizontalAlignment: Text.AlignLeft
                Layout.topMargin: 4
            }

            // Big Date Header
            Text {
                Layout.fillWidth: true
                text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
                color: AppTheme.accent
                font.family: AppTheme.mainFont
                font.pixelSize: 13
                font.bold: true
                horizontalAlignment: Text.AlignLeft
                Layout.topMargin: -8 
            }
            
            // THE FIX: Calendar Animation Wrapper
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                property int animDirection: 1 // 1 = Next, -1 = Prev
                
                SequentialAnimation {
                    id: monthChangeAnim
                    ParallelAnimation {
                        NumberAnimation { target: calInner; property: "opacity"; to: 0; duration: 150 }
                        NumberAnimation { target: calInner; property: "x"; to: parent.animDirection * 40; duration: 150; easing.type: Easing.InCubic }
                    }
                    ScriptAction {
                        script: {
                            if (parent.animDirection === 1) CalendarBackend.nextMonth();
                            else CalendarBackend.prevMonth();
                            calInner.x = -parent.animDirection * 40;
                        }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: calInner; property: "opacity"; to: 1; duration: 150 }
                        NumberAnimation { target: calInner; property: "x"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                    }
                }

                WheelHandler {
                    onWheel: (event) => {
                        if (monthChangeAnim.running) return;
                        if (event.angleDelta.y > 0) {
                            parent.animDirection = -1;
                            monthChangeAnim.restart();
                        } else if (event.angleDelta.y < 0) {
                            parent.animDirection = 1;
                            monthChangeAnim.restart();
                        }
                    }
                }

                ColumnLayout {
                    id: calInner
                    anchors.fill: parent
                    spacing: 12

                    // 1. HEADER (Arrows & Month/Year Label)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4

                        Rectangle {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: AppTheme.actionRadius
                            color: prevMouse.pressed ? AppTheme.actionBgHover : "transparent"
                            Text { anchors.centerIn: parent; text: "‹"; font.family: AppTheme.mainFont; font.pixelSize: 16; font.bold: true; color: AppTheme.fg; anchors.verticalCenterOffset: -1 } 
                            MouseArea { 
                                id: prevMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; 
                                onClicked: {
                                    if (monthChangeAnim.running) return;
                                    parent.parent.parent.animDirection = -1;
                                    monthChangeAnim.restart();
                                } 
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: CalendarBackend.monthYear
                            color: AppTheme.fg
                            font.family: AppTheme.mainFont
                            font.pixelSize: 14; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Rectangle {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: AppTheme.actionRadius
                            color: nextMouse.pressed ? AppTheme.actionBgHover : "transparent"
                            Text { anchors.centerIn: parent; text: "›"; font.family: AppTheme.mainFont; font.pixelSize: 16; font.bold: true; color: AppTheme.fg; anchors.verticalCenterOffset: -1 } 
                            MouseArea { 
                                id: nextMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; 
                                onClicked: {
                                    if (monthChangeAnim.running) return;
                                    parent.parent.parent.animDirection = 1;
                                    monthChangeAnim.restart();
                                } 
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
                                Layout.fillWidth: true; text: modelData
                                color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.5)
                                font.family: AppTheme.mainFont; font.pixelSize: 11; font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // 3. CALENDAR GRID
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true 
                        columns: 7
                        columnSpacing: 4
                        rowSpacing: 4

                        Repeater {
                            model: CalendarBackend.days
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true 
                                radius: AppTheme.actionRadius
                                color: modelData.isToday ? AppTheme.accent : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.dayText
                                    font.family: AppTheme.mainFont; font.pixelSize: 12
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
        }
    }
}