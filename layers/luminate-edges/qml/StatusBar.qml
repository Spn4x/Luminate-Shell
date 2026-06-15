import QtQuick
import Luminate.Shell

Item {
    id: statusBarRoot
    
    property bool showPortal: false
    property bool isPinned: false
    property string activeTrayBusName: ""
    
    signal portalClicked()
    signal settingsClicked(var buttonItem)
    signal closeDropdownRequested()
    signal trayMenuRequested(string busName, string menuPath, int x, int y)
    signal audioMenuRequested(string type, var targetItem, var items)
    signal indicatorClicked(string type, var targetItem)

    // Ensures exactly 16px of padding around the master row content, eliminating dead space
    implicitWidth: Math.max(300, masterRow.implicitWidth + 32)

    component IndicatorIcon : Item {
        property alias text: iconText.text
        property alias color: iconText.color
        property bool isDot: false
        property bool active: false
        signal clicked()

        // THE FIX: We smoothly animate the width instead of instantly hiding it.
        // This ensures the Row gently slides elements over, making overlap mathematically impossible.
        width: active ? 24 : 0
        height: 24
        visible: width > 0
        clip: true

        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 10
            radius: 5
            color: parent.color
            visible: parent.isDot
        }

        Text {
            id: iconText
            anchors.centerIn: parent
            font.family: AppTheme.iconFont
            font.pixelSize: 14
            visible: !parent.isDot
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                parent.clicked();
            }
        }
    }

    Row {
        id: masterRow
        anchors.centerIn: parent
        spacing: 12
        
        // --- 1. PRIVACY DOT (Standalone) ---
        IndicatorIcon {
            id: privacyDot
            active: Backend.privacyApps.length > 0
            isDot: true
            color: Backend.privacyHasCam ? AppTheme.colorCam : AppTheme.colorMic
            anchors.verticalCenter: parent.verticalCenter
            
            onClicked: {
                statusBarRoot.indicatorClicked("privacy", privacyDot);
            }
        }

        // --- 2. STATUS DOTS CONTAINER (Systray Style) ---
        Rectangle {
            id: statusDotsContainer
            anchors.verticalCenter: parent.verticalCenter
            
            property bool hasMedia: Backend.hasMedia
            property bool hasNotif: Backend.displayMode === "notification" || Backend.pendingNotifications > 0
            property bool hasScreen: Backend.screenshotState !== ""
            
            property int activeCount: (hasMedia ? 1 : 0) + (hasNotif ? 1 : 0) + (hasScreen ? 1 : 0)
            
            visible: activeCount > 0
            height: AppTheme.moduleHeight
            
            // If exactly 1 dot is active, it becomes a perfect square (24x24). 
            // If multiple, it expands dynamically with exactly 8px padding on left and right (+16 total).
            width: activeCount <= 1 ? height : (statusDotsRow.width + 16)
            
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            
            color: AppTheme.moduleBg
            radius: AppTheme.moduleRadius

            Row {
                id: statusDotsRow
                anchors.centerIn: parent
                spacing: 8
                
                IndicatorIcon {
                    active: statusDotsContainer.hasMedia
                    text: "󰎆" 
                    color: AppTheme.fg
                    onClicked: statusBarRoot.indicatorClicked("media", statusDotsContainer)
                }

                IndicatorIcon {
                    active: statusDotsContainer.hasNotif
                    text: "󰂚" 
                    color: AppTheme.fg
                    onClicked: statusBarRoot.indicatorClicked("notification", statusDotsContainer)
                }

                IndicatorIcon {
                    active: statusDotsContainer.hasScreen
                    text: "󰄄" 
                    color: AppTheme.fg
                    onClicked: Backend.expandScreenshotToEdit()
                }
            }
        }

        // --- 3. PINNED LYRICS OVERRIDE ---
        Text {
            id: pinnedLyricsText
            visible: Backend.mediaPinned && Backend.mediaCurrentLyric !== ""
            text: Backend.mediaCurrentLyric
            color: AppTheme.fg
            font.bold: true
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- 4. MAIN MODULES ---
        Row {
            id: mainModulesRow
            visible: !(Backend.mediaPinned && Backend.mediaCurrentLyric !== "")
            spacing: 12
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: showPortal ? 24 : 0
                height: 24
                radius: 12
                color: AppTheme.accent
                opacity: showPortal ? 1 : 0
                visible: opacity > 0
                anchors.verticalCenter: parent.verticalCenter
                
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
                
                Text { 
                    anchors.centerIn: parent
                    text: "⤢"
                    font.bold: true
                    color: AppTheme.bg
                    font.pixelSize: 14 
                }
                
                MouseArea { 
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: statusBarRoot.portalClicked()
                }
            }

            ClockModule { 
                anchors.verticalCenter: parent.verticalCenter 
            }
            
            SystrayModule { 
                anchors.verticalCenter: parent.verticalCenter
                activeMenuBusName: statusBarRoot.activeTrayBusName
                
                onCloseDropdownRequested: statusBarRoot.closeDropdownRequested()
                onTrayMenuRequested: (busName, menuPath, x, y) => statusBarRoot.trayMenuRequested(busName, menuPath, x, y)
            }
            
            SysinfoModule { 
                anchors.verticalCenter: parent.verticalCenter 
            }
            
            AudioModule { 
                anchors.verticalCenter: parent.verticalCenter
                onAudioMenuRequested: (type, targetItem, items) => statusBarRoot.audioMenuRequested(type, targetItem, items)
            }
            
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: isPinned ? AppTheme.accent : AppTheme.moduleBg
                border.width: 0 
                anchors.verticalCenter: parent.verticalCenter
                
                Behavior on color { ColorAnimation { duration: 200 } }
                
                Text { 
                    anchors.centerIn: parent
                    text: ""
                    font.family: AppTheme.iconFont
                    color: isPinned ? AppTheme.bg : AppTheme.fg
                    font.pixelSize: 13 
                }
                
                MouseArea { 
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: statusBarRoot.settingsClicked(parent)
                }
            }
        }
    }
}