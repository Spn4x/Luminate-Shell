import QtQuick
import QtQuick.Controls
import QtQuick.Window 
import Luminate.Shell 

Item {
    id: systrayRoot
    
    property bool hasItems: Systray.items.length > 0
    implicitWidth: hasItems ? trayRow.implicitWidth + 24 : 0
    implicitHeight: AppTheme.moduleHeight
    opacity: hasItems ? 1 : 0
    visible: opacity > 0

    Behavior on implicitWidth { 
        NumberAnimation { 
            duration: 250
            easing.type: Easing.OutCubic 
        } 
    }
    
    Behavior on opacity { 
        NumberAnimation { duration: 150 } 
    }

    property string activeMenuBusName: ""
    
    signal trayMenuRequested(string busName, string menuPath, int x, int y)
    signal closeDropdownRequested()

    property bool isProcessingClick: false
    
    Timer { 
        id: clickThrottle
        interval: 200
        onTriggered: {
            systrayRoot.isProcessingClick = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: AppTheme.moduleBg
        radius: AppTheme.moduleRadius
        clip: true 
        
        Row {
            id: trayRow
            anchors.centerIn: parent
            spacing: 12 
            
            Repeater {
                model: Systray.items
                delegate: Item {
                    id: delegateItem 
                    width: 26 
                    height: 26
                    
                    property bool isAbsolute: modelData.iconName.startsWith("/")

                    Image {
                        id: imgIcon
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: isAbsolute ? "file://" + modelData.iconName : ""
                        visible: isAbsolute && status === Image.Ready
                    }

                    Button {
                        id: themeIcon
                        anchors.fill: parent
                        visible: !isAbsolute && modelData.iconName !== ""
                        icon.name: modelData.iconName
                        icon.width: 16
                        icon.height: 16
                        icon.color: "transparent" 
                        background: null
                        padding: 0
                        focusPolicy: Qt.NoFocus
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰍡" 
                        font.family: AppTheme.iconFont
                        color: AppTheme.fg
                        font.pixelSize: 14
                        visible: !imgIcon.visible && !themeIcon.visible
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: (mouse) => {
                            if (systrayRoot.isProcessingClick) {
                                return;
                            }
                            
                            systrayRoot.isProcessingClick = true; 
                            clickThrottle.start();
                            
                            var gx = Math.round(delegateItem.mapToGlobal(mouse.x, mouse.y).x);
                            var gy = Math.round(delegateItem.mapToGlobal(mouse.x, mouse.y).y);
                            
                            if (mouse.button === Qt.LeftButton) {
                                systrayRoot.closeDropdownRequested(); 
                                Systray.activateItem(modelData.busName, modelData.path, gx, gy);
                            } else if (mouse.button === Qt.RightButton) {
                                if (modelData.menuPath && modelData.menuPath !== "") {
                                    if (systrayRoot.activeMenuBusName === modelData.busName) {
                                        systrayRoot.closeDropdownRequested(); 
                                    } else { 
                                        let centerP = delegateItem.mapToItem(null, delegateItem.width / 2, 0);
                                        systrayRoot.trayMenuRequested(modelData.busName, modelData.menuPath, centerP.x, centerP.y); 
                                    }
                                } else { 
                                    systrayRoot.closeDropdownRequested(); 
                                    Systray.contextMenu(modelData.busName, modelData.path, gx, gy); 
                                }
                            } else if (mouse.button === Qt.MiddleButton) { 
                                systrayRoot.closeDropdownRequested(); 
                                Systray.secondaryActivate(modelData.busName, modelData.path, gx, gy); 
                            }
                        }
                    }
                }
            }
        }
    }
}