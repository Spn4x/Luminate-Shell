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

    implicitWidth: mainRow.implicitWidth + 32

    Row {
        id: mainRow
        anchors.centerIn: parent
        spacing: 12

        Rectangle {
            width: showPortal ? 24 : 0
            height: 24
            radius: 12
            color: AppTheme.accent
            opacity: showPortal ? 1 : 0
            visible: opacity > 0
            anchors.verticalCenter: parent.verticalCenter
            
            Behavior on width { 
                NumberAnimation { 
                    duration: 250
                    easing.type: Easing.OutCubic 
                } 
            }
            
            Behavior on opacity { 
                NumberAnimation { duration: 200 } 
            }
            
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
                onClicked: {
                    statusBarRoot.portalClicked();
                }
            }
        }

        ClockModule { 
            anchors.verticalCenter: parent.verticalCenter 
        }
        
        SystrayModule { 
            anchors.verticalCenter: parent.verticalCenter
            activeMenuBusName: statusBarRoot.activeTrayBusName
            
            onCloseDropdownRequested: {
                statusBarRoot.closeDropdownRequested();
            }
            
            onTrayMenuRequested: (busName, menuPath, x, y) => {
                statusBarRoot.trayMenuRequested(busName, menuPath, x, y);
            }
        }
        
        SysinfoModule { 
            anchors.verticalCenter: parent.verticalCenter 
        }
        
        AudioModule { 
            anchors.verticalCenter: parent.verticalCenter
            
            onAudioMenuRequested: (type, targetItem, items) => {
                statusBarRoot.audioMenuRequested(type, targetItem, items);
            }
        }
        
        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: AppTheme.moduleBg
            border.color: isPinned ? AppTheme.accent : "transparent"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            
            Behavior on border.color { 
                ColorAnimation { duration: 200 } 
            }
            
            Text { 
                anchors.centerIn: parent
                text: ""
                font.family: AppTheme.iconFont
                color: AppTheme.fg
                font.pixelSize: 13 
            }
            
            MouseArea { 
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    statusBarRoot.settingsClicked(parent);
                }
            }
        }
    }
}