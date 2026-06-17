import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Luminate.Shell

Item {
    id: pulltabRoot
    property bool expanded: false
    property string mode: "settings" 
    
    property var luminateEdge: parent
    
    property real targetX: 0
    
    // --- FLAWLESS ADAPTIVE CLAMPING MATH ---
    // Calculates physical monitor bounds so menus never bleed off the screen
    property real screenMarginX: luminateEdge.parent ? (luminateEdge.parent.width - luminateEdge.width) / 2 : 0
    property real absoluteMinX: 16 - screenMarginX
    property real absoluteMaxX: luminateEdge.width + screenMarginX - baseWidth - 16

    // If the menu fits inside the status bar, force it to snap inside the edges.
    // If it is massive (like the Calendar), allow it to overhang perfectly centered.
    property real idealMinX: baseWidth <= parent.width ? 16 : absoluteMinX
    property real idealMaxX: baseWidth <= parent.width ? (parent.width - baseWidth - 16) : absoluteMaxX

    property real clampedX: Math.max(idealMinX, Math.min(targetX, idealMaxX))
    x: clampedX

    property string activeBusName: ""
    property string activeMenuPath: ""
    property var menuTree: []
    property var openSubmenus: ({})
    
    property string audioMenuType: ""
    property var audioMenuItems: []

    property int baseWidth: {
        if (mode === "calendar") {
            return 540; // Increased to prevent internal clipping
        }
        if (mode === "media" || mode === "notification") {
            return 320;
        }
        if (mode === "privacy") {
            return 280;
        }
        if (mode === "settings" || mode === "audio") {
            return 260;
        }
        return 250;
    }

    property int baseHeight: {
        if (mode === "calendar") {
            return 380; 
        }
        if (mode === "settings") {
            return settingsLayout.implicitHeight + 24;
        }
        if (mode === "audio") {
            return audioCol.implicitHeight + 24;
        }
        if (mode === "tray") {
            return systrayCol.implicitHeight + 16;
        }
        if (mode === "notification") {
            return notifCol.implicitHeight + 24;
        }
        if (mode === "privacy") {
            return privCol.implicitHeight + 24;
        }
        if (mode === "media") {
            return mediaCol.implicitHeight + 24;
        }
        return 0;
    }

    width: baseWidth
    height: expanded ? baseHeight : 0
    
    // THIS CLIPS THE CONTENT, CREATING THE PHYSICAL SLIDE-OUT ILLUSION
    clip: true

    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

    Shortcut {
        sequence: "Escape"
        enabled: pulltabRoot.expanded
        onActivated: { pulltabRoot.expanded = false; }
    }

    onExpandedChanged: {
        if (!expanded) {
            openSubmenus = {};
        } else {
            pulltabRoot.forceActiveFocus();
        }
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent 
        color: AppTheme.bg
        border.color: AppTheme.borderAlpha
        border.width: 2
        radius: AppTheme.expandedRadius
        bottomLeftRadius: 0
        bottomRightRadius: 0

        MouseArea { 
            anchors.fill: parent
            hoverEnabled: true 
            preventStealing: true
            onPressed: (mouse) => { mouse.accepted = true; }
            onReleased: (mouse) => { mouse.accepted = true; }
            onClicked: (mouse) => { mouse.accepted = true; }
        }
    }

    // THE CONTENT CONTAINER IS ANCHORED TO THE TOP.
    // AS HEIGHT GROWS, IT REVEALS ITSELF WITHOUT FADING IN!
    Item {
        id: contentContainer
        anchors.top: parent.top
        width: parent.width
        height: pulltabRoot.baseHeight
        visible: pulltabRoot.height > 2

        ColumnLayout {
            id: settingsLayout
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 24
            spacing: 12
            visible: pulltabRoot.mode === "settings"

            RowLayout {
                Layout.fillWidth: true
                
                Text { 
                    text: "Settings"
                    color: AppTheme.fg
                    font.bold: true
                    font.pixelSize: 14
                    Layout.fillWidth: true 
                }
                
                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: luminateEdge.isPinned ? AppTheme.accent : AppTheme.moduleBg
                    
                    Text { 
                        anchors.centerIn: parent
                        text: ""
                        font.family: AppTheme.iconFont
                        color: luminateEdge.isPinned ? AppTheme.bg : AppTheme.fg 
                    }
                    
                    MouseArea { 
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { luminateEdge.isPinned = !luminateEdge.isPinned; }
                    }
                }
            }

            Text { 
                text: "Quick Actions"
                color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.6)
                font.pixelSize: 12
                font.bold: true 
            }
            
            GridLayout {
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                
                component SettingsBtn : Rectangle {
                    id: btnRect
                    property string iconStr
                    property string labelStr
                    property string cmdStr
                    
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: btnArea.containsMouse ? AppTheme.surfaceAlpha : AppTheme.moduleBg
                    
                    Row { 
                        anchors.centerIn: parent
                        spacing: 6
                        
                        Text { 
                            text: btnRect.iconStr
                            font.family: AppTheme.iconFont
                            color: AppTheme.fg 
                        }
                        
                        Text { 
                            text: btnRect.labelStr
                            font.family: AppTheme.mainFont
                            color: AppTheme.fg
                            font.pixelSize: 12 
                        } 
                    }
                    
                    MouseArea { 
                        id: btnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: { 
                            Topbar.runCommand(btnRect.cmdStr); 
                            pulltabRoot.expanded = false; 
                        } 
                    }
                }

                SettingsBtn { iconStr: ""; labelStr: "Launcher"; cmdStr: "luminate-shell -r" }
                SettingsBtn { iconStr: ""; labelStr: "Screenshot"; cmdStr: "luminate-shell -s" }
                SettingsBtn { iconStr: ""; labelStr: "Wallpaper"; cmdStr: "luminate-shell -w" }
                SettingsBtn { iconStr: "󰈐"; labelStr: "Thinkfan"; cmdStr: "luminate-shell -t" } 
            }

            Text { 
                text: "Power Options"
                color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.6)
                font.pixelSize: 12
                font.bold: true
                Layout.topMargin: 4 
            }
            
            GridLayout {
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                
                SettingsBtn { iconStr: ""; labelStr: "Lock"; cmdStr: "luminate-shell -l" }
                SettingsBtn { iconStr: "󰍃"; labelStr: "Log Out"; cmdStr: "hyprctl dispatch exit" }
                SettingsBtn { iconStr: "󰒲"; labelStr: "Sleep"; cmdStr: "systemctl suspend" }
                SettingsBtn { iconStr: ""; labelStr: "Reboot"; cmdStr: "systemctl reboot" }
                SettingsBtn { iconStr: ""; labelStr: "Shut Down"; cmdStr: "systemctl poweroff" }
            }
        }

        ColumnLayout {
            id: calendarCol
            anchors.fill: parent
            anchors.margins: 12
            visible: pulltabRoot.mode === "calendar"

            CalendarUI {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        Column {
            id: systrayCol
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 16
            spacing: 2
            visible: pulltabRoot.mode === "tray"

            Repeater {
                model: pulltabRoot.menuTree
                delegate: SystrayMenuNode { 
                    nodeData: modelData
                    busName: pulltabRoot.activeBusName
                    menuPath: pulltabRoot.activeMenuPath 
                }
            }
        }

        ColumnLayout {
            id: audioCol
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 24
            spacing: 4
            visible: pulltabRoot.mode === "audio"

            Text { 
                text: pulltabRoot.audioMenuType === "sink" ? "Select Speaker" : (pulltabRoot.audioMenuType === "source" ? "Select Microphone" : "Select Media Player")
                color: AppTheme.fg
                font.family: AppTheme.mainFont
                font.bold: true
                font.pixelSize: AppTheme.fontSize + 1
                Layout.bottomMargin: 6 
            }

            Repeater {
                model: pulltabRoot.audioMenuItems
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 6
                    color: itemMouse.containsMouse ? AppTheme.accentAlpha15 : "transparent"
                    
                    Row { 
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        spacing: 8
                        
                        Text { 
                            text: modelData.icon
                            font.family: AppTheme.iconFont
                            color: modelData.isActive ? AppTheme.accent : AppTheme.fg
                            font.pixelSize: AppTheme.fontSize 
                        }
                        
                        Text { 
                            text: modelData.name
                            font.family: AppTheme.mainFont
                            color: modelData.isActive ? AppTheme.accent : AppTheme.fg
                            font.pixelSize: AppTheme.fontSize
                            font.bold: modelData.isActive 
                        } 
                    }
                    
                    MouseArea { 
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: { 
                            if (pulltabRoot.audioMenuType === "sink") {
                                AudioBackend.setSink(modelData.id); 
                            } else if (pulltabRoot.audioMenuType === "source") {
                                AudioBackend.setSource(modelData.id); 
                            } else if (pulltabRoot.audioMenuType === "player") {
                                AudioBackend.setPlayer(modelData.id); 
                            }
                            pulltabRoot.expanded = false; 
                        } 
                    }
                }
            }
        }

        ColumnLayout {
            id: notifCol
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 24
            spacing: 8
            visible: pulltabRoot.mode === "notification"

            Text {
                text: Backend.summary !== "" ? Backend.summary : "No Notifications"
                color: AppTheme.fg
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
            
            Text {
                visible: Backend.body !== ""
                text: Backend.body
                color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.8)
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                maximumLineCount: 3
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: Backend.hasActions
                
                Repeater {
                    model: Backend.actions
                    
                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: 8
                        color: actionMa.pressed ? AppTheme.actionBgHover : AppTheme.actionBg
                        border.color: AppTheme.actionBorder
                        border.width: 1
                        
                        Text { 
                            anchors.centerIn: parent
                            text: modelData.label
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true 
                        }
                        
                        MouseArea { 
                            id: actionMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: { 
                                Backend.invokeAction(modelData.id); 
                                Backend.closeNotification(); 
                                pulltabRoot.expanded = false; 
                            } 
                        }
                    }
                }
            }
            
            Rectangle {
                visible: Backend.summary !== ""
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: dismissMa.pressed ? AppTheme.actionBgHover : AppTheme.actionBg
                border.color: AppTheme.actionBorder
                border.width: 1
                
                Text { 
                    anchors.centerIn: parent
                    text: "Dismiss"
                    color: AppTheme.colorKill
                    font.pixelSize: 12
                    font.bold: true 
                }
                
                MouseArea { 
                    id: dismissMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: { 
                        Backend.closeNotification(); 
                        pulltabRoot.expanded = false; 
                    } 
                }
            }
        }

        ColumnLayout {
            id: privCol
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 24
            spacing: 8
            visible: pulltabRoot.mode === "privacy"
            
            Text {
                text: Backend.privacySummary !== "" ? Backend.privacySummary : "Privacy Secure"
                color: AppTheme.fg
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: Backend.privacyApps
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: "transparent"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 8
                        
                        Text { 
                            text: modelData.name
                            color: AppTheme.fg
                            font.pixelSize: 13
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight 
                        }
                        
                        Text { 
                            visible: modelData.hasMic
                            text: "󰍬"
                            font.family: AppTheme.iconFont
                            color: AppTheme.colorMic
                            font.pixelSize: 14 
                        }
                        
                        Text { 
                            visible: modelData.hasCam
                            text: "󰄀"
                            font.family: AppTheme.iconFont
                            color: AppTheme.colorCam
                            font.pixelSize: 14 
                        }
                        
                        Text { 
                            text: "Ignore"
                            color: AppTheme.fg
                            font.pixelSize: 12
                            font.bold: true
                            
                            MouseArea { 
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { 
                                    Backend.ignorePrivacyApp(modelData.pid, modelData.name); 
                                    if (Backend.privacyApps.length <= 1) { pulltabRoot.expanded = false; }
                                } 
                            } 
                        }
                        
                        Text { 
                            text: "Kill"
                            color: AppTheme.colorKill
                            font.pixelSize: 12
                            font.bold: true
                            
                            MouseArea { 
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { 
                                    Backend.killPrivacyApp(modelData.pid, modelData.name); 
                                    if (Backend.privacyApps.length <= 1) { pulltabRoot.expanded = false; }
                                } 
                            } 
                        }
                    }
                }
            }
            
            Rectangle {
                visible: Backend.privacyApps.length > 1
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: killAllMa.pressed ? AppTheme.actionBgHover : AppTheme.actionBg
                border.color: AppTheme.actionBorder
                border.width: 1
                
                Text { 
                    anchors.centerIn: parent
                    text: "Kill All Apps"
                    color: AppTheme.colorKill
                    font.pixelSize: 12
                    font.bold: true 
                }
                
                MouseArea { 
                    id: killAllMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Backend.killAllPrivacyApps(); pulltabRoot.expanded = false; } 
                }
            }
        }

        ColumnLayout {
            id: mediaCol
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 24
            spacing: 12
            visible: pulltabRoot.mode === "media"

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 8
                    color: AppTheme.actionBg
                    clip: true
                    
                    Image { 
                        anchors.fill: parent
                        source: Backend.mediaArt
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready 
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Text { 
                        text: Backend.mediaTitle !== "" ? Backend.mediaTitle : "No Media"
                        color: AppTheme.fg
                        font.pixelSize: 14
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight 
                    }
                    
                    Text { 
                        text: Backend.mediaArtist
                        color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.7)
                        font.pixelSize: 12
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight 
                    }
                }
            }
            
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
                
                Text { 
                    text: "󰒮"
                    font.family: AppTheme.iconFont
                    color: AppTheme.fg
                    font.pixelSize: 22
                    MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: Backend.mediaPrev() } 
                }
                
                Text { 
                    text: Backend.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                    font.family: AppTheme.iconFont
                    color: AppTheme.fg
                    font.pixelSize: 30
                    MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: Backend.mediaPlayPause() } 
                }
                
                Text { 
                    text: "󰒭"
                    font.family: AppTheme.iconFont
                    color: AppTheme.fg
                    font.pixelSize: 22
                    MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: Backend.mediaNext() } 
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                Text {
                    text: {
                        var m = Math.floor(Backend.mediaPosition / 60);
                        var s = Backend.mediaPosition % 60;
                        return m + ":" + (s < 10 ? "0" : "") + s;
                    }
                    color: AppTheme.fg
                    font.pixelSize: 11
                    font.bold: true
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.2)
                    
                    Rectangle { 
                        width: Backend.mediaDuration > 0 ? parent.width * (Backend.mediaPosition / Backend.mediaDuration) : 0
                        height: parent.height
                        radius: 2
                        color: AppTheme.fg 
                    }
                }
                
                Text {
                    text: {
                        var m = Math.floor(Backend.mediaDuration / 60);
                        var s = Backend.mediaDuration % 60;
                        return m + ":" + (s < 10 ? "0" : "") + s;
                    }
                    color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.6)
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}