import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Luminate.Shell

Item {
    id: control
    property bool expanded: false
    property string mode: "settings" 
    
    property var luminateEdge: parent
    
    property real targetX: 0
    property real clampedX: Math.max(16, Math.min(targetX, parent.width - baseWidth - 16))
    
    x: clampedX

    property string activeBusName: ""
    property string activeMenuPath: ""
    property var menuTree: []
    property var openSubmenus: ({})
    
    property string audioMenuType: ""
    property var audioMenuItems: []

    property int baseWidth: mode === "settings" || mode === "audio" ? 260 : 250
    property int baseHeight: {
        if (mode === "settings") return settingsLayout.implicitHeight + 24;
        if (mode === "audio") return audioCol.implicitHeight + 24;
        if (mode === "tray") return systrayCol.implicitHeight + 16;
        return 0;
    }

    width: baseWidth
    height: expanded ? baseHeight : 0

    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

    Shortcut {
        sequence: "Escape"
        enabled: control.expanded
        onActivated: { control.expanded = false; }
    }

    onExpandedChanged: {
        if (!expanded) openSubmenus = {};
    }

    Rectangle {
        id: bgRect
        anchors.bottom: parent.bottom 
        width: parent.width
        height: control.height
        color: AppTheme.bg
        border.color: AppTheme.borderAlpha
        border.width: 2
        radius: AppTheme.expandedRadius
        bottomLeftRadius: 0
        bottomRightRadius: 0

        MouseArea { anchors.fill: parent; hoverEnabled: true }
    }

    Item {
        id: contentContainer
        anchors.bottom: parent.bottom
        width: parent.width
        height: control.baseHeight
        opacity: control.expanded ? 1.0 : 0.0
        visible: opacity > 0
        
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ColumnLayout {
            id: settingsLayout
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 24
            spacing: 12
            visible: control.mode === "settings"

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
                    width: 24; height: 24; radius: 6
                    color: luminateEdge.isPinned ? AppTheme.accent : AppTheme.moduleBg
                    
                    Text { 
                        anchors.centerIn: parent; text: ""
                        font.family: AppTheme.iconFont
                        color: luminateEdge.isPinned ? AppTheme.bg : AppTheme.fg 
                    }
                    
                    MouseArea { 
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: luminateEdge.isPinned = !luminateEdge.isPinned;
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
                    
                    Layout.fillWidth: true; height: 32; radius: 6
                    color: btnArea.containsMouse ? AppTheme.surfaceAlpha : AppTheme.moduleBg
                    
                    Row { 
                        anchors.centerIn: parent; spacing: 6
                        Text { text: btnRect.iconStr; font.family: AppTheme.iconFont; color: AppTheme.fg }
                        Text { text: btnRect.labelStr; font.family: AppTheme.mainFont; color: AppTheme.fg; font.pixelSize: 12 } 
                    }
                    
                    MouseArea { 
                        id: btnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { Topbar.runCommand(btnRect.cmdStr); control.expanded = false; } 
                    }
                }

                SettingsBtn { iconStr: ""; labelStr: "Launcher"; cmdStr: "luminate-shell --toggle edge -l" }
                SettingsBtn { iconStr: ""; labelStr: "Screenshot"; cmdStr: "luminate-shell --toggle edge -s" }
                SettingsBtn { iconStr: ""; labelStr: "Wallpaper"; cmdStr: "luminate-shell --toggle surfacedesk -w" }
                SettingsBtn { iconStr: ""; labelStr: "Edit Desk"; cmdStr: "luminate-shell --toggle surfacedesk -e" }
            }

            Text { 
                text: "Power Options"
                color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.6)
                font.pixelSize: 12; font.bold: true; Layout.topMargin: 4 
            }
            
            GridLayout {
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                
                SettingsBtn { iconStr: ""; labelStr: "Lock"; cmdStr: "luminate-shell --toggle surfacedesk -l" }
                SettingsBtn { iconStr: "󰍃"; labelStr: "Log Out"; cmdStr: "hyprctl dispatch exit" }
                SettingsBtn { iconStr: "󰒲"; labelStr: "Sleep"; cmdStr: "systemctl suspend" }
                SettingsBtn { iconStr: ""; labelStr: "Reboot"; cmdStr: "systemctl reboot" }
                SettingsBtn { iconStr: ""; labelStr: "Shut Down"; cmdStr: "systemctl poweroff" }
            }
        }

        Column {
            id: systrayCol
            anchors.top: parent.top; anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 16; spacing: 2
            visible: control.mode === "tray"

            Repeater {
                model: control.menuTree
                delegate: SystrayMenuNode {
                    nodeData: modelData
                    busName: control.activeBusName
                    menuPath: control.activeMenuPath
                }
            }
        }

        ColumnLayout {
            id: audioCol
            anchors.top: parent.top; anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 24; spacing: 4
            visible: control.mode === "audio"

            Text {
                text: control.audioMenuType === "sink" ? "Select Speaker" : (control.audioMenuType === "source" ? "Select Microphone" : "Select Media Player")
                color: AppTheme.fg; font.family: AppTheme.mainFont; font.bold: true; font.pixelSize: AppTheme.fontSize + 1
                Layout.bottomMargin: 6
            }

            Repeater {
                model: control.audioMenuItems
                delegate: Rectangle {
                    Layout.fillWidth: true; height: 32; radius: 6
                    color: itemMouse.containsMouse ? AppTheme.accentAlpha15 : "transparent"

                    Row {
                        anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 8; spacing: 8
                        Text { text: modelData.icon; font.family: AppTheme.iconFont; color: modelData.isActive ? AppTheme.accent : AppTheme.fg; font.pixelSize: AppTheme.fontSize }
                        Text { text: modelData.name; font.family: AppTheme.mainFont; color: modelData.isActive ? AppTheme.accent : AppTheme.fg; font.pixelSize: AppTheme.fontSize; font.bold: modelData.isActive }
                    }

                    MouseArea {
                        id: itemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (control.audioMenuType === "sink") AudioBackend.setSink(modelData.id);
                            else if (control.audioMenuType === "source") AudioBackend.setSource(modelData.id);
                            else if (control.audioMenuType === "player") AudioBackend.setPlayer(modelData.id);
                            control.expanded = false; 
                        }
                    }
                }
            }
        }
    }
}