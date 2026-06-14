import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Luminate.Shell 

Item {
    id: root
    objectName: "luminateEdge"
    
    property bool isPinned: false
    property bool isPeeking: false
    
    // Safety lock: only open the menu if the user explicitly clicked the tray icon.
    property string requestedTrayBusName: ""

    component SystemIcon: Button {
        property string iconName: ""
        property color iconColor: "white"
        property int size: 24
        
        width: size
        height: size
        icon.name: iconName
        icon.color: iconColor
        icon.width: size
        icon.height: size
        background: Item {} 
        focusPolicy: Qt.NoFocus
        hoverEnabled: false
        down: false
    }

    property string activeState: {
        if (Backend.displayMode === "launcher" || Backend.displayMode === "screenshot_edit" || Backend.isExpanded) {
            return "expanded";
        }
        if (Backend.displayMode === "notification" || Backend.displayMode === "media" || Backend.displayMode === "osd" || Backend.displayMode === "privacy" || Backend.displayMode === "screenshot_info") {
            return "pill";
        }
        if (isPinned || isPeeking || pulltabMenu.expanded || Backend.displayMode === "system") {
            return "statusbar";
        }
        return "passive";
    }

    onActiveStateChanged: {
        if (activeState === "pill" || activeState === "expanded" || activeState === "statusbar") {
            root.startTimer();
        }
        if (activeState !== "statusbar") {
            pulltabMenu.expanded = false;
        }
    }

    property int baseHeight: activeState === "passive" ? (AppTheme.passiveHeight || 13) : (AppTheme.sideInfoHeight || 36)
    
    property int totalWidth: {
        if (activeState === "expanded") {
            if (Backend.displayMode === "launcher") return AppTheme.launcherWidth || 420;
            if (Backend.displayMode === "screenshot_edit") return AppTheme.screenshotEditWidth || 1100;
            return AppTheme.expandedMinWidth || 420;
        }
        if (activeState === "statusbar") {
            return statusBar.implicitWidth || 600;
        }
        if (activeState === "pill") {
            if (Backend.displayMode === "screenshot_info") return 220;
            if (Backend.displayMode === "osd") return 290;
            if (Backend.displayMode === "media") return Math.max(AppTheme.sideInfoMinWidth || 250, (mediaPillComponent ? mediaPillComponent.pinnedContentWidth : 0) + 64);
            
            let dotSpace = Backend.displayMode === "privacy" ? 20 : 0;
            return Math.max(AppTheme.sideInfoMinWidth || 250, solidTitleText.implicitWidth + dotSpace + 48);
        }
        return AppTheme.passiveWidth || 150;
    }

    property int totalHeight: {
        if (activeState === "expanded") {
            if (Backend.displayMode === "launcher") {
                return launcherModule ? launcherModule.expandedHeight : 120;
            }
            if (Backend.displayMode === "screenshot_edit") {
                return AppTheme.screenshotEditHeight || 620;
            }
            if (Backend.displayMode === "notification") {
                return edgeHelper.notifHeight + 32;
            }
            if (Backend.displayMode === "media") {
                return mediaComponent ? mediaComponent.expandedImplicitHeight + 32 : 120;
            }
            if (Backend.displayMode === "privacy") {
                return Backend.privacyApps.length === 1 ? edgeHelper.privacySingleHeight + 32 : edgeHelper.privacyMultiHeight + 32;
            }
            return AppTheme.expandedMinHeight || 120;
        }
        return baseHeight;
    }

    width: totalWidth
    height: totalHeight

    onIsPinnedChanged: { 
        if (isPinned) { 
            pinGlowAnim.restart(); 
            autoDismissTimer.stop(); 
        } else { 
            root.startTimer(); 
        } 
    }

    SequentialAnimation {
        id: pinGlowAnim
        
        ColorAnimation { 
            target: barBg
            property: "border.color"
            to: AppTheme.accent
            duration: 200 
        }
        
        PauseAnimation { 
            duration: 600 
        }
        
        ColorAnimation { 
            target: barBg
            property: "border.color"
            to: AppTheme.borderAlpha
            duration: 400 
        }
    }

    // =====================================
    // THE PULLTAB MENU + OPTICAL ILLUSION
    // =====================================
    PulltabMenu {
        id: pulltabMenu
        objectName: "pulltabMenu"
        z: -1
        anchors.bottom: barBg.top 
        
        onExpandedChanged: {
            if (!expanded) {
                root.requestedTrayBusName = "";
            }
        }
    }
    
    Rectangle {
        id: seamlessPatch
        z: 10
        anchors.bottom: barBg.top
        anchors.bottomMargin: -2 
        x: pulltabMenu.x + 2
        width: pulltabMenu.width - 4
        height: 4
        color: AppTheme.bg
        visible: pulltabMenu.expanded && activeState === "statusbar"
    }

    // =====================================
    // FULLSCREEN DISMISS CATCHER (FIXED)
    // =====================================
    MouseArea {
        id: dismissCatcher
        
        // Push the MouseArea to cover the entire window
        x: -root.x
        y: -root.y
        width: Window.window ? Window.window.width : Screen.width
        height: Window.window ? Window.window.height : Screen.height
        
        // Sit safely behind the pulltabMenu (z: -1) and barBg (z: 0)
        z: -10 
        
        enabled: pulltabMenu.expanded
        
        onClicked: {
            root.requestedTrayBusName = "";
            pulltabMenu.expanded = false;
        }
    }

    Connections {
        target: Systray
        
        function onMenuReady(busName, menuPath, menuTree, x, y) {
            if (root.requestedTrayBusName !== busName) {
                return; 
            }

            let localP = root.mapFromItem(null, x, 0); 
            pulltabMenu.targetX = localP.x - (pulltabMenu.baseWidth / 2);
            pulltabMenu.mode = "tray";
            pulltabMenu.activeBusName = busName;
            pulltabMenu.activeMenuPath = menuPath;
            pulltabMenu.menuTree = menuTree.children || [];
            pulltabMenu.expanded = true;
            
            root.isPeeking = true; 
            root.startTimer();
        }
    }

    // =====================================
    // MAIN MORPHING BACKGROUND SHAPE
    // =====================================
    Rectangle {
        id: barBg
        objectName: "barBg"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: totalWidth
        height: totalHeight
        
        property int currentRadius: activeState === "expanded" ? AppTheme.expandedRadius : (activeState === "passive" ? AppTheme.passiveRadius : AppTheme.sideInfoRadius)
        
        topLeftRadius: currentRadius
        topRightRadius: currentRadius
        bottomLeftRadius: 0
        bottomRightRadius: 0
        
        Behavior on width { 
            NumberAnimation { 
                duration: 350
                easing.type: Easing.OutCubic 
            } 
        }
        
        Behavior on height { 
            NumberAnimation { 
                duration: 350
                easing.type: Easing.OutCubic 
            } 
        }
        
        Behavior on currentRadius { 
            NumberAnimation { 
                duration: 350
                easing.type: Easing.OutCubic 
            } 
        }

        color: AppTheme.bg
        border.color: root.isPinned ? AppTheme.borderAlpha : (activeState === "passive" ? "transparent" : AppTheme.borderAlpha)
        border.width: activeState === "passive" ? 0 : 2 
        clip: true 

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.border.width
            color: parent.color 
            visible: parent.border.width > 0 && activeState !== "expanded"
            z: 10 
        }

        Item {
            id: baseArea
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: totalWidth
            height: baseHeight
            visible: activeState !== "expanded"

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        if (activeState === "pill") {
                            if (Backend.displayMode === "privacy" || Backend.displayMode === "screenshot_info") {
                                return;
                            }
                            if (Backend.displayMode === "media") {
                                Backend.setMediaPinned(false);
                            }
                            Backend.readyForNext();
                            return;
                        }
                        root.isPeeking = true; 
                        root.startTimer(); 
                        return;
                    }
                    if (mouse.button === Qt.LeftButton) {
                        if (activeState === "passive") {
                            if (Backend.hasMedia) {
                                Backend.TriggerMediaPeek();
                            } else {
                                root.isPeeking = true;
                                root.startTimer();
                            }
                            return;
                        }
                        if (activeState === "pill") {
                            if (Backend.displayMode === "osd") {
                                return;
                            }
                            if (Backend.displayMode === "screenshot_info") { 
                                Backend.expandScreenshotToEdit(); 
                                return; 
                            }
                            Backend.isExpanded = true; 
                            return;
                        }
                        if (activeState === "statusbar") {
                            root.startTimer(); 
                            return; 
                        }
                    }
                }
            }

            Item {
                id: passiveView
                anchors.fill: parent
                opacity: activeState === "passive" ? 1 : 0
                visible: opacity > 0
                
                Behavior on opacity { 
                    NumberAnimation { duration: 150 } 
                }
                
                Rectangle { 
                    anchors.centerIn: parent
                    width: 40
                    height: 4
                    radius: 2
                    color: Backend.displayMode !== "idle" ? AppTheme.accent : "#55ffffff"
                    
                    Behavior on color { 
                        ColorAnimation { duration: 200 } 
                    } 
                }
            }

            StatusBar {
                id: statusBar
                anchors.centerIn: parent
                height: parent.height
                opacity: activeState === "statusbar" ? 1 : 0
                visible: opacity > 0
                
                Behavior on opacity { 
                    NumberAnimation { duration: 150 } 
                }

                showPortal: false
                isPinned: root.isPinned
                
                // Trays
                activeTrayBusName: pulltabMenu.expanded && pulltabMenu.mode === "tray" ? pulltabMenu.activeBusName : ""
                
                onCloseDropdownRequested: {
                    root.requestedTrayBusName = "";
                    pulltabMenu.expanded = false;
                }
                
                onTrayMenuRequested: (busName, menuPath, x, y) => {
                    root.requestedTrayBusName = busName;
                    Systray.requestMenu(busName, menuPath, x, y);
                }

                // Audio
                onAudioMenuRequested: (type, targetItem, items) => {
                    if (pulltabMenu.expanded && pulltabMenu.mode === "audio" && pulltabMenu.audioMenuType === type) {
                        pulltabMenu.expanded = false; 
                    } else {
                        let p = targetItem.mapToItem(root, targetItem.width / 2, 0);
                        pulltabMenu.targetX = p.x - (pulltabMenu.baseWidth / 2);
                        pulltabMenu.mode = "audio";
                        pulltabMenu.audioMenuType = type;
                        pulltabMenu.audioMenuItems = items;
                        pulltabMenu.expanded = true;
                        
                        root.isPeeking = true;
                        root.startTimer();
                    }
                }

                // Settings
                onSettingsClicked: (btn) => { 
                    if (pulltabMenu.expanded && pulltabMenu.mode === "settings") {
                        pulltabMenu.expanded = false;
                    } else {
                        let p = btn.mapToItem(root, btn.width / 2, 0);
                        pulltabMenu.targetX = p.x - (pulltabMenu.baseWidth / 2);
                        pulltabMenu.mode = "settings";
                        pulltabMenu.expanded = true;
                        
                        root.isPeeking = true;
                        root.startTimer();
                    }
                }
            }

            Item {
                id: pillView
                anchors.fill: parent
                opacity: activeState === "pill" ? 1 : 0
                visible: opacity > 0
                
                Behavior on opacity { 
                    NumberAnimation { duration: 150 } 
                }

                Item {
                    anchors.fill: parent
                    visible: Backend.displayMode === "osd"
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 14
                        
                        SystemIcon { 
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: Backend.osdIcon
                            iconColor: AppTheme.fg
                            size: 26 
                        }
                        
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200
                            height: 10
                            radius: 5
                            color: Qt.rgba(1, 1, 1, 0.2)
                            
                            Rectangle { 
                                width: Math.min(Backend.osdLevel || 0, 1.0) * parent.width
                                height: parent.height
                                radius: 5
                                color: AppTheme.fg
                                
                                Behavior on width { 
                                    NumberAnimation { 
                                        duration: 150
                                        easing.type: Easing.OutCubic 
                                    } 
                                } 
                            }
                        }
                        
                        Text { 
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Backend.osdLevel > 1.0
                            text: "+" + Math.round(((Backend.osdLevel || 1.0) - 1.0) * 100) + "%"
                            color: AppTheme.fg
                            font.pixelSize: 13
                            font.bold: true 
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: Backend.displayMode === "notification" || Backend.displayMode === "privacy" || Backend.displayMode === "screenshot_info"
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Rectangle { 
                            visible: Backend.displayMode === "privacy"
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            radius: 5
                            color: Backend.privacyHasCam ? AppTheme.colorCam : AppTheme.colorMic 
                        }
                        
                        SystemIcon { 
                            visible: Backend.displayMode === "screenshot_info"
                            iconName: "camera-photo-symbolic"
                            size: 24
                            anchors.verticalCenter: parent.verticalCenter 
                        }
                        
                        Text { 
                            id: solidTitleText
                            anchors.verticalCenter: parent.verticalCenter
                            text: { 
                                if (Backend.displayMode === "screenshot_info") return "Screenshot Captured"; 
                                if (Backend.displayMode === "notification") return Backend.summary; 
                                if (Backend.displayMode === "privacy") return Backend.privacySummary; 
                                return ""; 
                            }
                            color: AppTheme.fg
                            font.pixelSize: AppTheme.summarySize
                            font.bold: true 
                        }
                    }
                }
                
                Player { 
                    id: mediaPillComponent
                    anchors.fill: parent
                    isExpanded: false
                    visible: Backend.displayMode === "media" 
                }
            }
        }

        // =====================================
        // VIEW 4: EXPANDED CARD
        // =====================================
        Item {
            id: expandedView
            anchors.fill: parent
            opacity: activeState === "expanded" ? 1 : 0
            visible: opacity > 0
            
            Behavior on opacity { 
                NumberAnimation { duration: 150 } 
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                
                onClicked: (mouse) => {
                    if (Backend.displayMode === "screenshot_edit" || Backend.displayMode === "launcher") {
                        return;
                    }
                    
                    Backend.isExpanded = false;
                    
                    if (mouse.button === Qt.LeftButton && Backend.displayMode === "notification" && !Backend.hasActions) {
                        Backend.invokeAction("default");
                    }
                    
                    Backend.readyForNext();
                }
            }

            EdgeHelper { 
                id: edgeHelper 
            }
            
            Player { 
                id: mediaComponent
                anchors.fill: parent
                isExpanded: true
                visible: Backend.displayMode === "media" 
            }
            
            ScreenshotEditor { 
                id: qscreenEditor
                anchors.fill: parent
                visible: Backend.displayMode === "screenshot_edit" 
            }
            
            LauncherUI { 
                id: launcherModule
                anchors.fill: parent
                anchors.margins: 5
                visible: Backend.displayMode === "launcher" 
            }
        }
    }

    function startTimer() {
        autoDismissTimer.stop();
        
        if (isPinned || activeState === "expanded" || Backend.displayMode === "screenshot_edit" || Backend.displayMode === "launcher") {
            return;
        }
        if (Backend.mediaPinned && Backend.displayMode === "media" && Backend.mediaStatus === "Playing") {
            return;
        }
        
        if (Backend.displayMode === "screenshot_info") {
            autoDismissTimer.interval = 10000;
        } else if (Backend.displayMode === "osd") {
            autoDismissTimer.interval = 1500;
        } else if (Backend.displayMode === "media") {
            autoDismissTimer.interval = 6000;
        } else if (isPeeking || pulltabMenu.expanded) {
            autoDismissTimer.interval = 6000;
        } else {
            autoDismissTimer.interval = 4000;
        }
        
        autoDismissTimer.restart();
    }

    Timer {
        id: autoDismissTimer
        onTriggered: {
            root.isPeeking = false;
            pulltabMenu.expanded = false;
            
            if (Backend.displayMode === "screenshot_info") {
                Backend.cancelScreenshot();
            } else if (Backend.displayMode !== "idle") {
                Backend.readyForNext();
            }
        }
    }

    Connections {
        target: Backend
        function onRequestShow() { 
            root.startTimer(); 
        }
        
        function onRequestHide() { 
            autoDismissTimer.stop(); 
            pulltabMenu.expanded = false; 
            root.isPeeking = false; 
        }
        
        function onOsdChanged() {
            if (Backend.displayMode === "osd") {
                root.startTimer(); 
            }
        }

        function onDisplayModeChanged() {
            if (Backend.displayMode === "launcher") { 
                autoDismissTimer.stop(); 
                launcherModule.openAndFocus(); 
                return; 
            }
            if (Backend.displayMode === "screenshot_edit" || (Backend.displayMode === "media" && Backend.mediaPinned)) { 
                autoDismissTimer.stop(); 
                return; 
            }
            root.startTimer();
        }
    }
}