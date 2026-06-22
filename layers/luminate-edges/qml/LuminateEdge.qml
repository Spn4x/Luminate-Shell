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
    property bool isIdle: false 
    
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
        
        background: Item {
        } 
        
        focusPolicy: Qt.NoFocus
        hoverEnabled: false
        down: false
    }

    property string activeState: {
        if (Backend.displayMode === "polkit" || Backend.displayMode === "launcher" || Backend.displayMode === "screenshot_edit" || Backend.displayMode === "wallpaper" || Backend.displayMode === "fan") {
            return "expanded";
        }
        
        if (isPinned) {
            if (Backend.displayMode === "osd") {
                return "pill";
            }
            return "statusbar";
        }
        
        if (Backend.isExpanded) {
            return "expanded";
        }
        
        if (Backend.displayMode === "notification" || Backend.displayMode === "media" || Backend.displayMode === "osd" || Backend.displayMode === "privacy" || Backend.displayMode === "screenshot_info") {
            return "pill";
        }
        
        if (isPeeking || pulltabMenu.expanded || Backend.displayMode === "system") {
            return "statusbar";
        }
        
        return "passive";
    }

    onActiveStateChanged: {
        if (activeState !== "passive") {
            root.isIdle = false;
        }

        if (activeState === "pill" || activeState === "expanded" || activeState === "statusbar") {
            root.startTimer();
        }
        
        if (activeState !== "statusbar") {
            pulltabMenu.expanded = false;
        }
    }

    Timer {
        id: idleTimer
        interval: 3000 
        running: root.activeState === "passive" && !edgeHover.hovered
        
        onTriggered: {
            root.isIdle = true;
        }
    }

    property int baseHeight: {
        if (activeState === "passive") {
            let normalHeight = AppTheme.passiveHeight || 13;
            if (root.isIdle) {
                return Math.round(normalHeight * 0.5);
            } else {
                return normalHeight;
            }
        }
        return AppTheme.sideInfoHeight || 36;
    }
    
    property int totalWidth: {
        if (activeState === "expanded") {
            if (Backend.displayMode === "polkit") {
                return 400;
            }
            if (Backend.displayMode === "launcher") {
                return AppTheme.launcherWidth || 420;
            }
            if (Backend.displayMode === "screenshot_edit") {
                return AppTheme.screenshotEditWidth || 1100;
            }
            if (Backend.displayMode === "wallpaper") {
                return 700;
            }
            if (Backend.displayMode === "fan") {
                return 640; 
            }
            return AppTheme.expandedMinWidth || 420;
        }
        
        if (activeState === "statusbar") {
            let baseW = statusBar.implicitWidth;
            if (pulltabMenu.expanded) {
                if (pulltabMenu.mode === "calendar" || pulltabMenu.mode === "notification" || pulltabMenu.mode === "privacy" || pulltabMenu.mode === "media") {
                    if (pulltabMenu.baseWidth > baseW) {
                        return pulltabMenu.baseWidth;
                    }
                }
            }
            return baseW;
        }
        
        if (activeState === "pill") {
            if (Backend.displayMode === "screenshot_info") {
                return 220;
            }
            if (Backend.displayMode === "osd") {
                return 290;
            }
            if (Backend.displayMode === "media") {
                let contentW = 0;
                if (mediaPillComponent) {
                    contentW = mediaPillComponent.pinnedContentWidth;
                }
                return Math.min(800, Math.max(AppTheme.sideInfoMinWidth || 250, contentW + 64));
            }
            
            let dotSpace = 0;
            if (Backend.displayMode === "privacy") {
                dotSpace = 20;
            }
            return Math.max(AppTheme.sideInfoMinWidth || 250, solidTitleText.implicitWidth + dotSpace + 48);
        }
        
        return AppTheme.passiveWidth || 150;
    }

    property int totalHeight: {
        if (activeState === "expanded") {
            if (Backend.displayMode === "polkit") {
                return 180; 
            }
            if (Backend.displayMode === "launcher") {
                if (launcherModule) {
                    return launcherModule.expandedHeight;
                }
                return 120;
            }
            if (Backend.displayMode === "screenshot_edit") {
                return AppTheme.screenshotEditHeight || 620;
            }
            if (Backend.displayMode === "wallpaper") {
                return 170;
            }
            if (Backend.displayMode === "fan") {
                return 330; 
            }
            if (Backend.displayMode === "notification") {
                return edgeHelper.notifHeight + 32;
            }
            if (Backend.displayMode === "media") {
                if (mediaComponent) {
                    return mediaComponent.expandedImplicitHeight + 32;
                }
                return 120;
            }
            if (Backend.displayMode === "privacy") {
                if (Backend.privacyApps.length === 1) {
                    return edgeHelper.privacySingleHeight + 32;
                } else {
                    return edgeHelper.privacyMultiHeight + 32;
                }
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
            root.startTimer(); 
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

    function openMenu(mode, targetItem) {
        if (pulltabMenu.expanded) {
            if (pulltabMenu.mode === mode) {
                pulltabMenu.expanded = false;
                root.requestedTrayBusName = "";
                return;
            }
        }

        pulltabMenu.mode = mode;
        
        if (mode === "calendar" || mode === "notification" || mode === "privacy" || mode === "media") {
            // Target X is mathematically bypassed by anchors, but we reset it cleanly
            pulltabMenu.targetX = 0;
        } else if (targetItem !== null && targetItem !== undefined) {
            let p = targetItem.mapToItem(root, targetItem.width / 2, 0);
            pulltabMenu.targetX = p.x - (pulltabMenu.baseWidth / 2);
        }

        pulltabMenu.expanded = true;
        
        root.isPeeking = true;
        root.startTimer();
    }

    PulltabMenu {
        id: pulltabMenu
        objectName: "pulltabMenu"
        z: -1
        anchors.bottom: barBg.top 
        
        // Dynamically anchors wide menus to the exact center of the screen, bypassing targetX animations
        anchors.horizontalCenter: {
            if (mode === "calendar" || mode === "notification" || mode === "privacy" || mode === "media") {
                return root.horizontalCenter;
            }
            return undefined;
        }
        
        onExpandedChanged: {
            if (!expanded) {
                root.requestedTrayBusName = "";
                root.startTimer();
            }
        }
    }
    
    Rectangle {
        id: seamlessPatch
        z: 10
        anchors.bottom: barBg.top
        anchors.bottomMargin: -2 
        
        property real menuLeft: pulltabMenu.x
        property real menuRight: pulltabMenu.x + pulltabMenu.width
        
        property real overlapLeft: Math.max(0, menuLeft)
        property real overlapRight: Math.min(root.width, menuRight)
        
        x: overlapLeft + 2
        width: Math.max(0, overlapRight - overlapLeft - 4)
        height: 4
        color: AppTheme.bg
        
        visible: {
            if (pulltabMenu.height > 0 && activeState === "statusbar") {
                return true;
            }
            return false;
        }
    }

    MouseArea {
        id: dismissCatcher
        x: -root.x
        y: -root.y
        
        width: {
            if (Window.window) {
                return Window.window.width;
            }
            return Screen.width;
        }
        
        height: {
            if (Window.window) {
                return Window.window.height;
            }
            return Screen.height;
        }
        
        z: -10 
        
        enabled: {
            if (pulltabMenu.expanded) {
                return true;
            }
            if (Backend.displayMode === "fan") {
                return true;
            }
            if (Backend.displayMode === "polkit") {
                return true;
            }
            if (Backend.displayMode === "launcher") {
                return true;
            }
            if (Backend.displayMode === "wallpaper") {
                return true;
            }
            return false;
        }
        
        onClicked: {
            if (Backend.displayMode === "fan") {
                Backend.closeFan();
            } else if (Backend.displayMode === "polkit") {
                PolkitAgent.cancelAuth();
            } else if (Backend.displayMode === "launcher") {
                Backend.closeLauncher();
            } else if (Backend.displayMode === "wallpaper") {
                Backend.cancelWallpaper();
            } else {
                root.requestedTrayBusName = "";
                pulltabMenu.expanded = false;
            }
        }
    }

    Connections {
        target: Systray
        function onMenuReady(busName, menuPath, menuTree, x, y) {
            if (root.requestedTrayBusName !== busName) {
                return;
            } 

            pulltabMenu.mode = "tray"; 
            
            let localP = root.mapFromItem(null, x, 0); 
            pulltabMenu.targetX = localP.x - (pulltabMenu.baseWidth / 2);
            
            pulltabMenu.activeBusName = busName;
            pulltabMenu.activeMenuPath = menuPath;
            pulltabMenu.menuTree = menuTree.children || [];
            
            pulltabMenu.expanded = true;
            
            root.isPeeking = true; 
            root.startTimer();
        }
    }

    Rectangle {
        id: barBg
        objectName: "barBg"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        
        width: totalWidth
        height: totalHeight
        
        opacity: {
            if (root.isIdle && root.activeState === "passive") {
                return 0.3;
            }
            return 1.0;
        }
        
        Behavior on opacity { 
            NumberAnimation { 
                duration: 400
                easing.type: Easing.OutCubic 
            } 
        }

        HoverHandler {
            id: edgeHover
            onHoveredChanged: {
                if (hovered) {
                    root.isIdle = false; 
                }
            }
        }
        
        property int currentRadius: {
            if (activeState === "expanded") {
                return AppTheme.expandedRadius;
            }
            if (activeState === "passive") {
                return AppTheme.passiveRadius;
            }
            return AppTheme.sideInfoRadius;
        }
        
        property int topRadius: {
            if (pulltabMenu.height > 0 && activeState === "statusbar") {
                if (pulltabMenu.baseWidth >= statusBar.implicitWidth) {
                    return 0;
                }
            }
            return currentRadius;
        }
        
        Behavior on topRadius { 
            NumberAnimation { 
                duration: 250
                easing.type: Easing.OutCubic 
            } 
        }
        
        topLeftRadius: topRadius
        topRightRadius: topRadius
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
        
        border.color: {
            if (root.isPinned) {
                return AppTheme.borderAlpha;
            }
            if (activeState === "passive") {
                return "transparent";
            }
            return AppTheme.borderAlpha;
        }
        
        border.width: {
            if (activeState === "passive") {
                return 0;
            }
            return 2;
        }
        
        clip: true 

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.border.width
            color: parent.color 
            
            visible: {
                if (parent.border.width > 0) {
                    return true;
                }
                return false;
            }
            
            z: 10 
        }

        Item {
            id: baseArea
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: totalWidth
            height: baseHeight
            
            visible: {
                if (activeState !== "expanded") {
                    return true;
                }
                return false;
            }

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
                
                opacity: {
                    if (activeState === "passive") {
                        return 1.0;
                    }
                    return 0.0;
                }
                
                visible: {
                    if (opacity > 0) {
                        return true;
                    }
                    return false;
                }
                
                Behavior on opacity { 
                    NumberAnimation { 
                        duration: 150 
                    } 
                }
                
                Rectangle { 
                    anchors.centerIn: parent
                    width: 40
                    
                    height: {
                        if (root.isIdle && activeState === "passive") {
                            return 2;
                        }
                        return 4;
                    }
                    
                    radius: height / 2
                    
                    color: {
                        if (Backend.displayMode !== "idle") {
                            return AppTheme.accent;
                        }
                        return "#55ffffff";
                    }
                    
                    Behavior on height { 
                        NumberAnimation { 
                            duration: 350
                            easing.type: Easing.OutCubic 
                        } 
                    }
                    
                    Behavior on color { 
                        ColorAnimation { 
                            duration: 200 
                        } 
                    } 
                }
            }

            StatusBar {
                id: statusBar
                anchors.centerIn: parent
                height: parent.height
                
                opacity: {
                    if (activeState === "statusbar") {
                        return 1.0;
                    }
                    return 0.0;
                }
                
                visible: {
                    if (opacity > 0) {
                        return true;
                    }
                    return false;
                }
                
                Behavior on opacity { 
                    NumberAnimation { 
                        duration: 150 
                    } 
                }

                showPortal: false
                isPinned: root.isPinned
                
                activeTrayBusName: {
                    if (pulltabMenu.expanded && pulltabMenu.mode === "tray") {
                        return pulltabMenu.activeBusName;
                    }
                    return "";
                }
                
                onCloseDropdownRequested: {
                    root.requestedTrayBusName = "";
                    pulltabMenu.expanded = false;
                }
                
                onTrayMenuRequested: (busName, menuPath, x, y) => {
                    root.requestedTrayBusName = busName;
                    Systray.requestMenu(busName, menuPath, x, y);
                }

                onAudioMenuRequested: (type, targetItem, items) => {
                    pulltabMenu.audioMenuType = type;
                    pulltabMenu.audioMenuItems = items;
                    root.openMenu("audio", targetItem);
                }

                onSettingsClicked: (btn) => { 
                    root.openMenu("settings", btn);
                }
                
                onIndicatorClicked: (type, targetItem) => {
                    root.openMenu(type, targetItem);
                }

                onCalendarRequested: (targetItem) => {
                    root.openMenu("calendar", null);
                }
            }

            Item {
                id: pillView
                anchors.fill: parent
                
                opacity: {
                    if (activeState === "pill") {
                        return 1.0;
                    }
                    return 0.0;
                }
                
                visible: {
                    if (opacity > 0) {
                        return true;
                    }
                    return false;
                }
                
                Behavior on opacity { 
                    NumberAnimation { 
                        duration: 150 
                    } 
                }

                Item {
                    anchors.fill: parent
                    
                    visible: {
                        if (Backend.displayMode === "osd") {
                            return true;
                        }
                        return false;
                    }
                    
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
                                width: {
                                    let level = Backend.osdLevel || 0;
                                    return Math.min(level, 1.0) * parent.width;
                                }
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
                            
                            visible: {
                                if (Backend.osdLevel > 1.0) {
                                    return true;
                                }
                                return false;
                            }
                            
                            text: {
                                let level = Backend.osdLevel || 1.0;
                                return "+" + Math.round((level - 1.0) * 100) + "%";
                            }
                            
                            color: AppTheme.fg
                            font.pixelSize: 13
                            font.bold: true 
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    
                    visible: {
                        if (Backend.displayMode === "notification") {
                            return true;
                        }
                        if (Backend.displayMode === "privacy") {
                            return true;
                        }
                        if (Backend.displayMode === "screenshot_info") {
                            return true;
                        }
                        return false;
                    }
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Rectangle { 
                            visible: {
                                if (Backend.displayMode === "privacy") {
                                    return true;
                                }
                                return false;
                            }
                            
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            radius: 5
                            
                            color: {
                                if (Backend.privacyHasCam) {
                                    return AppTheme.colorCam;
                                }
                                return AppTheme.colorMic;
                            } 
                        }
                        
                        SystemIcon { 
                            visible: {
                                if (Backend.displayMode === "screenshot_info") {
                                    return true;
                                }
                                return false;
                            }
                            iconName: "camera-photo-symbolic"
                            size: 24
                            anchors.verticalCenter: parent.verticalCenter 
                        }
                        
                        Text { 
                            id: solidTitleText
                            anchors.verticalCenter: parent.verticalCenter
                            
                            text: { 
                                if (Backend.displayMode === "screenshot_info") {
                                    return "Screenshot Captured";
                                } 
                                if (Backend.displayMode === "notification") {
                                    return Backend.summary;
                                } 
                                if (Backend.displayMode === "privacy") {
                                    return Backend.privacySummary;
                                } 
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
                    
                    visible: {
                        if (Backend.displayMode === "media") {
                            return true;
                        }
                        return false;
                    } 
                }
            }
        }

        Item {
            id: expandedView
            anchors.fill: parent
            
            opacity: {
                if (activeState === "expanded") {
                    return 1.0;
                }
                return 0.0;
            }
            
            visible: {
                if (opacity > 0) {
                    return true;
                }
                return false;
            }
            
            Behavior on opacity { 
                NumberAnimation { 
                    duration: 150 
                } 
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                
                onClicked: (mouse) => {
                    if (Backend.displayMode === "polkit" || Backend.displayMode === "screenshot_edit" || Backend.displayMode === "launcher" || Backend.displayMode === "wallpaper" || Backend.displayMode === "fan") {
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
                
                visible: {
                    if (Backend.displayMode === "media") {
                        return true;
                    }
                    return false;
                } 
            }
            
            ScreenshotEditor { 
                id: qscreenEditor
                anchors.fill: parent
                
                visible: {
                    if (Backend.displayMode === "screenshot_edit") {
                        return true;
                    }
                    return false;
                } 
            }
            
            LauncherUI { 
                id: launcherModule
                anchors.fill: parent
                anchors.margins: 5
                
                visible: {
                    if (Backend.displayMode === "launcher") {
                        return true;
                    }
                    return false;
                } 
            }

            WallpaperChooser { 
                id: wallpaperChooser
                anchors.fill: parent
                
                visible: {
                    if (Backend.displayMode === "wallpaper") {
                        return true;
                    }
                    return false;
                } 
            }

            FanManager { 
                id: fanModule
                anchors.fill: parent
                
                visible: {
                    if (Backend.displayMode === "fan") {
                        return true;
                    }
                    return false;
                } 
            }

            PolkitAuth { 
                id: polkitModule
                anchors.fill: parent
                
                visible: {
                    if (Backend.displayMode === "polkit") {
                        return true;
                    }
                    return false;
                } 
            }
        }
    }

    function startTimer() {
        autoDismissTimer.stop();
        
        if (isPinned && Backend.displayMode !== "osd") {
            return;
        }

        if (activeState === "expanded" || Backend.displayMode === "polkit" || Backend.displayMode === "screenshot_edit" || Backend.displayMode === "launcher" || Backend.displayMode === "wallpaper" || Backend.displayMode === "fan") {
            return;
        }
        
        if (pulltabMenu.expanded) {
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
            if (Backend.displayMode === "polkit" || Backend.displayMode === "launcher" || Backend.displayMode === "wallpaper" || Backend.displayMode === "fan") { 
                autoDismissTimer.stop(); 
                if (Backend.displayMode === "launcher") {
                    launcherModule.openAndFocus(); 
                }
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