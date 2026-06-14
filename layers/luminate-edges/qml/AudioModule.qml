import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Luminate.Shell 

Item {
    id: root
    
    // THE FIX: Use Backend (NotificationBackend) for bulletproof media tracking
    property bool hasMedia: Backend.mediaTitle !== "" && Backend.mediaTitle !== "Unknown"
    property bool isActive: AudioBackend.btConnected || hasMedia

    implicitWidth: isActive ? 200 : 0
    implicitHeight: AppTheme.moduleHeight
    opacity: isActive ? 1 : 0
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

    property string activeView: AudioBackend.btConnected && !hasMedia ? "bluetooth" : "media"
    property string activeArtUrl: ""
    property string lastMediaTitle: ""

    signal audioMenuRequested(string type, var targetItem, var menuItems)

    function openMenu(type, targetItem) {
        var items = [];
        if (type === "sink") {
            items = AudioBackend.getSinks();
        } else if (type === "source") {
            items = AudioBackend.getSources();
        } else if (type === "player") {
            items = AudioBackend.getPlayers();
        }
        
        audioMenuRequested(type, targetItem, items);
    }

    Component.onCompleted: {
        updateMediaInfo();
    }

    function updateMediaInfo() {
        // THE FIX: Direct path string provided by NotificationBackend
        var rawUrl = Backend.mediaArt;
        var currentTitle = Backend.mediaTitle;

        if (rawUrl !== "") {
            if (rawUrl !== activeArtUrl) {
                activeArtUrl = rawUrl;
            }
            lastMediaTitle = currentTitle;
        } else {
            if (currentTitle !== "" && currentTitle === lastMediaTitle && activeArtUrl !== "") {
                // Keep artwork for current title
            } else {
                activeArtUrl = "";
                lastMediaTitle = currentTitle;
            }
        }
    }

    onActiveArtUrlChanged: {
        if (activeArtUrl === "") { 
            img1.source = ""; 
            img2.source = ""; 
            return; 
        }
        
        if (albumArtContainer.useLayer1) { 
            img2.source = activeArtUrl; 
        } else { 
            img1.source = activeArtUrl; 
        }
    }

    Connections {
        target: Backend
        function onMediaChanged() { 
            updateMediaInfo(); 
        }
    }

    Rectangle {
        anchors.fill: parent
        color: AppTheme.moduleBg
        radius: AppTheme.moduleRadius
        clip: true 

        // 1. BLUETOOTH VIEW
        Item {
            anchors.fill: parent
            visible: activeView === "bluetooth"
            
            Rectangle { 
                height: parent.height
                width: parent.width * (AudioBackend.btBattery > 0 ? (AudioBackend.btBattery / 100) : 0)
                color: AppTheme.accentAlpha30 
            }
            
            Text { 
                anchors.centerIn: parent
                text: { 
                    if (!AudioBackend.btPowered) return "󰂲  Bluetooth Off"; 
                    if (!AudioBackend.btConnected) return "󰂯  Disconnected"; 
                    if (AudioBackend.btBattery >= 0) return "󰋋  " + AudioBackend.btBattery + "% " + AudioBackend.btName; 
                    return "󰋋  " + AudioBackend.btName; 
                } 
                color: AppTheme.fg
                font.family: AppTheme.mainFont
                font.bold: true
                font.pixelSize: AppTheme.fontSize 
            }
        }

        // 2. MEDIA VIEW
        Item {
            id: mediaViewContainer
            anchors.fill: parent
            visible: activeView === "media"

            HoverHandler { 
                id: hoverHandler 
            }
            
            property real hoverAlpha: hoverHandler.hovered ? 1.0 : 0.0
            
            Behavior on hoverAlpha { 
                NumberAnimation { duration: 150 } 
            }

            Item {
                id: albumArtContainer
                anchors.fill: parent
                opacity: mediaViewContainer.hoverAlpha 
                property bool useLayer1: true
                
                Rectangle { 
                    anchors.fill: parent
                    color: "#11111b"
                    radius: AppTheme.moduleRadius 
                }

                Item {
                    id: layer1
                    anchors.fill: parent
                    opacity: albumArtContainer.useLayer1 ? 1.0 : 0.0
                    
                    Behavior on opacity { 
                        NumberAnimation { 
                            duration: 300
                            easing.type: Easing.OutCubic 
                        } 
                    }
                    
                    Image { 
                        id: img1
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                        
                        onStatusChanged: { 
                            if (status === Image.Ready && !albumArtContainer.useLayer1) {
                                albumArtContainer.useLayer1 = true;
                            }
                        } 
                    }
                    
                    Rectangle { 
                        id: mask1
                        anchors.fill: parent
                        radius: AppTheme.moduleRadius
                        color: "black"
                        visible: false
                        layer.enabled: true 
                    }
                    
                    MultiEffect { 
                        anchors.fill: parent
                        source: img1
                        maskEnabled: true
                        maskSource: mask1
                        visible: img1.source != "" 
                    }
                }

                Item {
                    id: layer2
                    anchors.fill: parent
                    opacity: albumArtContainer.useLayer1 ? 0.0 : 1.0
                    
                    Behavior on opacity { 
                        NumberAnimation { 
                            duration: 300
                            easing.type: Easing.OutCubic 
                        } 
                    }
                    
                    Image { 
                        id: img2
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                        
                        onStatusChanged: { 
                            if (status === Image.Ready && albumArtContainer.useLayer1) {
                                albumArtContainer.useLayer1 = false;
                            }
                        } 
                    }
                    
                    Rectangle { 
                        id: mask2
                        anchors.fill: parent
                        radius: AppTheme.moduleRadius
                        color: "black"
                        visible: false
                        layer.enabled: true 
                    }
                    
                    MultiEffect { 
                        anchors.fill: parent
                        source: img2
                        maskEnabled: true
                        maskSource: mask2
                        visible: img2.source != "" 
                    }
                }

                Rectangle { 
                    anchors.fill: parent
                    color: "black"
                    opacity: 0.3
                    radius: AppTheme.moduleRadius 
                }
            }

            Row {
                id: waveformRow
                anchors.centerIn: parent
                spacing: 4
                opacity: 1.0 - mediaViewContainer.hoverAlpha 
                
                function updateAllBars() { 
                    for (var i = 0; i < rep.count; i++) { 
                        var item = rep.itemAt(i); 
                        if (item) item.updateTarget(); 
                    } 
                }
                
                Timer { 
                    id: waveTimer
                    interval: 500
                    running: Backend.mediaStatus === "Playing" && waveformRow.opacity > 0.01
                    repeat: true
                    onTriggered: waveformRow.updateAllBars() 
                }
                
                Connections { 
                    target: Backend
                    function onMediaChanged() { 
                        waveformRow.updateAllBars(); 
                        if (Backend.mediaStatus === "Playing") {
                            waveTimer.restart(); 
                        } else {
                            waveTimer.stop();
                        }
                    } 
                }

                Repeater {
                    id: rep
                    model: 24 
                    
                    delegate: Rectangle {
                        width: 4
                        color: AppTheme.accent
                        radius: 2
                        anchors.verticalCenter: parent.verticalCenter
                        height: 4 
                        
                        Behavior on height { 
                            NumberAnimation { 
                                duration: 400
                                easing.type: Easing.OutQuint 
                            } 
                        }
                        
                        function updateTarget() { 
                            if (Backend.mediaStatus !== "Playing") { 
                                height = 4; 
                                return; 
                            } 
                            let windowFunc = Math.sin((index / 23.0) * Math.PI); 
                            let randomAmplitude = 0.2 + Math.random() * 0.8; 
                            height = Math.max(4, 20 * windowFunc * randomAmplitude); 
                        }
                        
                        Component.onCompleted: {
                            updateTarget();
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 20
                horizontalAlignment: Text.AlignHCenter
                text: Backend.mediaTitle !== "" ? Backend.mediaArtist + " - " + Backend.mediaTitle : "No Media Playing"
                color: "white"
                font.family: AppTheme.mainFont
                font.pixelSize: AppTheme.fontSize
                font.bold: true
                elide: Text.ElideRight
                opacity: mediaViewContainer.hoverAlpha
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.6)
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0 && AudioBackend.btConnected) {
                    root.activeView = "bluetooth";
                } else if (wheel.angleDelta.y < 0 && hasMedia) {
                    root.activeView = "media";
                }
            }

            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    openMenu("sink", root);
                } else if (mouse.button === Qt.MiddleButton) {
                    openMenu("source", root);
                } else if (mouse.button === Qt.RightButton) {
                    openMenu("player", root);
                }
            }
        }
    }
}