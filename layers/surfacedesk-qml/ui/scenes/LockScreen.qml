import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import ".."
import "../modules"
import "../scenes"

Item {
    id: lockscreenRoot
    anchors.fill: parent
    focus: true

    AppTheme { id: appTheme }

    property int escapeCount: 0

    // Core state tracking for Idle/Auth transitions
    property bool _internalAuthMode: false
    property bool isAuthMode: (wallpaperBackend && wallpaperBackend.isEditingLockscreen) || _internalAuthMode

    // =========================================================
    // PERFECT MATHEMATICAL SPATIAL ZONES
    // =========================================================
    property int zoneMarginX: Math.round(width * 0.15)
    property int zoneWidth: width - (zoneMarginX * 2)

    property int zoneTopY: Math.round(height * 0.15)
    property int zoneTotalHeight: Math.round(height * 0.70)

    property int zoneRedY: zoneTopY
    property int zoneRedHeight: Math.round(zoneTotalHeight * 0.55)

    property int zoneGreenY: zoneRedY + zoneRedHeight
    property int zoneGreenHeight: zoneTotalHeight - zoneRedHeight
    // =========================================================

    property alias activeWidgets: activeWidgets
    
    property int selectedWidgetIndex: wallpaperBackend ? wallpaperBackend.selectedWidgetIndex : -1
    property bool isDraggingWidget: false 

    property int cellSize: Math.round(80 * appTheme.scale)
    property int cols: Math.max(1, Math.floor(width / cellSize))
    property int rows: Math.max(1, Math.floor(height / cellSize))
    property int gridOffsetX: Math.round((width - (cols * cellSize)) / 2.0)
    property int gridOffsetY: Math.round((height - (rows * cellSize)) / 2.0)

    property int dragGridX: -1
    property int dragGridY: -1
    property int dragGridW: 0
    property int dragGridH: 0
    property bool showDragHighlight: false
    
    property int dragMouseX: 0
    property int dragMouseY: 0
    property string dragWidgetType: ""
    property int dragWidgetVariant: 0

    Component.onCompleted: { 
        lockscreenRoot.forceActiveFocus(); 
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            if (wallpaperBackend && wallpaperBackend.isEditingLockscreen) {
                if (wallpaperBackend.selectedWidgetIndex !== -1) {
                    wallpaperBackend.selectedWidgetIndex = -1;
                } else {
                    wallpaperBackend.isEditingLockscreen = false;
                }
                event.accepted = true;
                return;
            }

            lockscreenRoot.escapeCount++;
            if (lockscreenRoot.escapeCount >= 5) {
                if (wallpaperBackend) wallpaperBackend.isLocked = false;
            }
            event.accepted = true;
        } else {
            lockscreenRoot.escapeCount = 0;
        }
    }

    function triggerSave() { 
        saveDebounceTimer.restart(); 
    }

    function addNewWidget(type, variant, gx, gy, gw, gh) {
        activeWidgets.append({
            "type": type,
            "variant": variant,
            "grid_x": gx,
            "grid_y": gy,
            "grid_w": gw,
            "grid_h": gh,
            "text": type === "Label" ? "New Label" : (type === "Auth" ? "ENTER PASSWORD" : ""),
            "fontSize": type === "Label" ? 18 : 32,
            "fontFamily": "system-ui",
            "dateFontFamily": "system-ui:600",
            "useTheme": type === "Label" ? false : true,
            "isBold": type === "Label" ? true : false,
            "padding": 0,
            "transparent": type === "Auth" ? false : true,
            "is24h": true,
            "dateSize": 10,
            "offsetX": 0,
            "offsetY": 0,
            "timeOpacity": 1.0,
            "dateOpacity": 0.7,
            "echoChar": "•",
            "showFocusBorder": true,
            "authWidth": type === "Auth" ? 280 : 0,
            "authHeight": type === "Auth" ? 45 : 0,
            "showTemp": true,
            "timeColorIndex": 8,
            "dateColorIndex": 5,
            "dateSpacing": 4
        });
        lockscreenRoot.triggerSave();
    }

    Timer { 
        id: saveDebounceTimer
        interval: 400
        repeat: false
        onTriggered: saveLayoutData() 
    }

    function saveLayoutData() {
        if (typeof desktopStorage === "undefined") return;
        let arr = [];
        for (let i = 0; i < activeWidgets.count; ++i) {
            let item = activeWidgets.get(i);
            arr.push({
                "type": item.type,
                "variant": item.variant,
                "grid_x": item.grid_x, 
                "grid_y": item.grid_y, 
                "grid_w": item.grid_w, 
                "grid_h": item.grid_h,
                "text": item.text !== undefined ? item.text : "",
                "fontSize": item.fontSize !== undefined ? item.fontSize : 32,
                "fontFamily": item.fontFamily !== undefined ? item.fontFamily : "system-ui",
                "dateFontFamily": item.dateFontFamily !== undefined ? item.dateFontFamily : "system-ui:600",
                "useTheme": item.useTheme !== undefined ? item.useTheme : true,
                "isBold": item.isBold !== undefined ? item.isBold : false,
                "padding": item.padding !== undefined ? item.padding : 0,
                "transparent": item.transparent !== undefined ? item.transparent : true,
                "is24h": item.is24h !== undefined ? item.is24h : true,
                "dateSize": item.dateSize !== undefined ? item.dateSize : 10,
                "offsetX": item.offsetX !== undefined ? item.offsetX : 0,
                "offsetY": item.offsetY !== undefined ? item.offsetY : 0,
                "timeOpacity": item.timeOpacity !== undefined ? item.timeOpacity : 1.0,
                "dateOpacity": item.dateOpacity !== undefined ? item.dateOpacity : 0.7,
                "echoChar": item.echoChar !== undefined ? item.echoChar : "•",
                "showFocusBorder": item.showFocusBorder !== undefined ? item.showFocusBorder : true,
                "authWidth": item.authWidth !== undefined ? item.authWidth : 0,
                "authHeight": item.authHeight !== undefined ? item.authHeight : 0,
                "showTemp": item.showTemp !== undefined ? item.showTemp : true,
                "timeColorIndex": item.timeColorIndex !== undefined ? item.timeColorIndex : 8,
                "dateColorIndex": item.dateColorIndex !== undefined ? item.dateColorIndex : 5,
                "dateSpacing": item.dateSpacing !== undefined ? item.dateSpacing : 4,
                // Legacy SQLite bindings
                "blendAccent": true,
                "blendRatio": 0.0
            });
        }
        desktopStorage.saveLockscreenLayout(arr);
    }

    function loadLayoutData() {
        if (typeof desktopStorage === "undefined") { 
            loadDefaults(); 
            return; 
        }
        let saved = desktopStorage.loadLockscreenLayout();
        if (saved && saved.length > 0) {
            activeWidgets.clear();
            for (let i = 0; i < saved.length; ++i) {
                activeWidgets.append(saved[i]);
            }
        } else { 
            loadDefaults(); 
        }
    }

    function loadDefaults() {
        activeWidgets.clear();
        activeWidgets.append({ 
            "type": "Clock", "variant": 1, "grid_x": 4, "grid_y": 2, "grid_w": 8, "grid_h": 4, 
            "text": "", "fontSize": 86, "fontFamily": "system-ui:800", "dateFontFamily": "system-ui:600", 
            "useTheme": true, "isBold": true, "padding": 0, "transparent": true, "is24h": true, 
            "dateSize": 18, "offsetX": 0, "offsetY": 0, "timeOpacity": 1.0, "dateOpacity": 0.9, 
            "echoChar": "•", "showFocusBorder": true, 
            "authWidth": 0, "authHeight": 0, "showTemp": true, "timeColorIndex": 8, "dateColorIndex": 5, "dateSpacing": 4 
        });
        activeWidgets.append({ 
            "type": "Auth", "variant": 0, "grid_x": 6, "grid_y": 6, "grid_w": 4, "grid_h": 1, 
            "text": "ENTER PASSWORD", "fontSize": 14, "fontFamily": "system-ui", "dateFontFamily": "system-ui:600", 
            "useTheme": true, "isBold": false, "padding": 0, "transparent": true, "is24h": true, 
            "dateSize": 10, "offsetX": 0, "offsetY": 0, "timeOpacity": 1.0, "dateOpacity": 0.7, 
            "echoChar": "•", "showFocusBorder": true, 
            "authWidth": 280, "authHeight": 45, "showTemp": true, "timeColorIndex": 8, "dateColorIndex": 5, "dateSpacing": 4 
        });
    }

    ListModel {
        id: activeWidgets
        onDataChanged: (topLeft, bottomRight, roles) => { lockscreenRoot.triggerSave() }
        onRowsInserted: (parent, first, last) => { lockscreenRoot.triggerSave() }
        onRowsRemoved: (parent, first, last) => { lockscreenRoot.triggerSave() }
        Component.onCompleted: {
            loadLayoutData();
            if (wallpaperBackend) {
                wallpaperBackend.lockscreenWidgets = activeWidgets;
            }
        }
    }

    Rectangle { 
        anchors.fill: parent
        color: "#000000" 
    }

    Image { 
        id: bgImg
        anchors.fill: parent
        source: wallpaperBackend ? ("file://" + wallpaperBackend.currentWallpaper) : ""
        fillMode: Image.PreserveAspectCrop
        visible: false 
    }

    MultiEffect { 
        anchors.fill: parent
        source: bgImg
        blurEnabled: true
        blur: lockscreenRoot.isAuthMode ? 0.6 : 0.0
        brightness: lockscreenRoot.isAuthMode ? -0.15 : 0.0
        opacity: 1.0 
        
        Behavior on blur { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }
        Behavior on brightness { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !lockscreenRoot.isAuthMode && (wallpaperBackend && !wallpaperBackend.isEditingLockscreen)
        hoverEnabled: true
        onClicked: lockscreenRoot._internalAuthMode = true
        onWheel: lockscreenRoot._internalAuthMode = true
    }

    Item {
        anchors.fill: parent
        visible: wallpaperBackend.isEditingLockscreen

        // =========================================================
        // VISUAL EDIT-MODE ZONES (Bound to absolute screen edge)
        // =========================================================
        Item {
            anchors.fill: parent
            z: -1

            // 1. WHITE ZONE OUTLINE (Screen Edge)
            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.round(10 * appTheme.scale)
                color: "transparent"
                border.color: "white"
                border.width: Math.round(4 * appTheme.scale)
                opacity: 0.25
                
                Text {
                    text: "STATIC ZONE (Anywhere outside Red & Green)\nObjects placed out here remain completely static."
                    color: "white"
                    font.family: "Lexend"
                    font.pointSize: 11 * appTheme.scale
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(15 * appTheme.scale)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // 2. RED ZONE
            Rectangle {
                x: lockscreenRoot.zoneMarginX
                y: lockscreenRoot.zoneRedY
                width: lockscreenRoot.zoneWidth
                height: lockscreenRoot.zoneRedHeight
                color: Qt.rgba(243/255, 139/255, 168/255, 0.05)
                border.color: "#F38BA8"
                border.width: Math.round(4 * appTheme.scale)
                opacity: 0.6
                
                Text {
                    text: "IDLE CENTER ZONE (Clocks, Labels)\nSnaps objects to screen center in Idle mode."
                    color: "#F38BA8"
                    font.family: "Lexend"
                    font.pointSize: 11 * appTheme.scale
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(15 * appTheme.scale)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // 3. GREEN ZONE
            Rectangle {
                x: lockscreenRoot.zoneMarginX
                y: lockscreenRoot.zoneGreenY - Math.round(4 * appTheme.scale) // Merge overlap
                width: lockscreenRoot.zoneWidth
                height: lockscreenRoot.zoneGreenHeight + Math.round(4 * appTheme.scale)
                color: Qt.rgba(166/255, 227/255, 161/255, 0.05)
                border.color: "#A6E3A1"
                border.width: Math.round(4 * appTheme.scale)
                opacity: 0.6
                
                Text {
                    text: "AUTH ZONE (Password Prompts)\nSlides down completely out of sight in Idle mode."
                    color: "#A6E3A1"
                    font.family: "Lexend"
                    font.pointSize: 11 * appTheme.scale
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(15 * appTheme.scale)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        GridOverlay { 
            cellSize: lockscreenRoot.cellSize
            offsetX: lockscreenRoot.gridOffsetX
            offsetY: lockscreenRoot.gridOffsetY 
        }

        Rectangle { 
            id: dragHighlightRect
            visible: lockscreenRoot.showDragHighlight
            x: lockscreenRoot.dragGridX * lockscreenRoot.cellSize + lockscreenRoot.gridOffsetX
            y: lockscreenRoot.dragGridY * lockscreenRoot.cellSize + lockscreenRoot.gridOffsetY
            width: lockscreenRoot.dragGridW * lockscreenRoot.cellSize
            height: lockscreenRoot.dragGridH * lockscreenRoot.cellSize
            color: Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.15)
            border.color: appTheme.accent
            border.width: 2
            radius: appTheme.radius 
        }

        Loader {
            id: dragProxyLoader
            visible: lockscreenRoot.showDragHighlight
            width: lockscreenRoot.dragGridW * lockscreenRoot.cellSize
            height: lockscreenRoot.dragGridH * lockscreenRoot.cellSize
            x: lockscreenRoot.dragMouseX - width / 2
            y: lockscreenRoot.dragMouseY - height / 2
            opacity: 0.65
            scale: 0.95
            z: 10000
            
            sourceComponent: { 
                if (lockscreenRoot.dragWidgetType === "Clock") return clockPreview; 
                if (lockscreenRoot.dragWidgetType === "Label") return labelPreview; 
                if (lockscreenRoot.dragWidgetType === "System") return systemPreview; 
                if (lockscreenRoot.dragWidgetType === "Media") return mediaPreview; 
                if (lockscreenRoot.dragWidgetType === "Auth") return authPreview; 
                return null; 
            }
            
            Component { 
                id: clockPreview
                ClockScene { variant: lockscreenRoot.dragWidgetVariant; customFontSize: 24 } 
            }
            Component { 
                id: labelPreview
                TextScene { labelText: "New Label" } 
            }
            Component { 
                id: systemPreview
                SystemScene { variant: lockscreenRoot.dragWidgetVariant } 
            }
            Component { 
                id: mediaPreview
                MediaScene { variant: lockscreenRoot.dragWidgetVariant } 
            }
            Component { 
                id: authPreview
                AuthScene { 
                    variant: lockscreenRoot.dragWidgetVariant
                    authPlaceholderText: "ENTER PASSWORD"
                    authEchoChar: "•"
                    authShowBorder: true
                    isTransparent: false 
                } 
            }
        }

        DropArea {
            anchors.fill: parent
            keys: ["text/plain"]
            
            onEntered: (drag) => { updateDragPosition(drag); }
            onPositionChanged: (drag) => { updateDragPosition(drag); }
            onExited: { lockscreenRoot.showDragHighlight = false; }
            onDropped: (drop) => {
                lockscreenRoot.showDragHighlight = false;
                if (drop.hasText) {
                    let parts = drop.text.split(":");
                    if (parts.length >= 2) {
                        let type = parts[0]; 
                        let variant = parseInt(parts[1]);
                        let gw = 4; 
                        let gh = (type === "Label" || type === "Auth") ? 1 : 2;
                        
                        let gx = Math.round((drop.x - lockscreenRoot.gridOffsetX - (gw * lockscreenRoot.cellSize) / 2) / lockscreenRoot.cellSize);
                        let gy = Math.round((drop.y - lockscreenRoot.gridOffsetY - (gh * lockscreenRoot.cellSize) / 2) / lockscreenRoot.cellSize);
                        
                        gx = Math.max(0, Math.min(lockscreenRoot.cols - gw, gx)); 
                        gy = Math.max(0, Math.min(lockscreenRoot.rows - gh, gy));
                        
                        lockscreenRoot.addNewWidget(type, variant, gx, gy, gw, gh);

                        if (wallpaperBackend) {
                            wallpaperBackend.selectedWidgetIndex = lockscreenRoot.activeWidgets.count - 1;
                        }
                        drop.acceptProposedAction();
                    }
                }
            }
            
            function updateDragPosition(drag) {
                if (drag.hasText) {
                    let parts = drag.text.split(":");
                    if (parts.length >= 2) {
                        lockscreenRoot.dragMouseX = drag.x; 
                        lockscreenRoot.dragMouseY = drag.y; 
                        lockscreenRoot.dragWidgetType = parts[0]; 
                        lockscreenRoot.dragWidgetVariant = parseInt(parts[1]);
                        
                        let gw = 4; 
                        let gh = (lockscreenRoot.dragWidgetType === "Label" || lockscreenRoot.dragWidgetType === "Auth") ? 1 : 2;
                        
                        let gx = Math.round((drag.x - lockscreenRoot.gridOffsetX - (gw * lockscreenRoot.cellSize) / 2) / lockscreenRoot.cellSize);
                        let gy = Math.round((drag.y - lockscreenRoot.gridOffsetY - (gh * lockscreenRoot.cellSize) / 2) / lockscreenRoot.cellSize);
                        
                        lockscreenRoot.dragGridX = Math.max(0, Math.min(lockscreenRoot.cols - gw, gx)); 
                        lockscreenRoot.dragGridY = Math.max(0, Math.min(lockscreenRoot.rows - gh, gy));
                        lockscreenRoot.dragGridW = gw; 
                        lockscreenRoot.dragGridH = gh; 
                        
                        lockscreenRoot.showDragHighlight = true;
                    }
                }
            }
        }
    }

    Repeater {
        model: activeWidgets
        delegate: InteractiveWidget {
            id: widgetInstance
            widgetModel: activeWidgets

            // Pass the LockScreen root safely to the widget so it can read the spatial variables
            spatialZoneRef: lockscreenRoot

            gridX: model.grid_x
            gridY: model.grid_y
            gridW: model.grid_w
            gridH: model.grid_h
            cellSize: lockscreenRoot.cellSize
            indexInModel: index
            
            isActiveSelection: (lockscreenRoot.selectedWidgetIndex === index)
            
            offsetX: model.offsetX !== undefined ? model.offsetX : 0
            offsetY: model.offsetY !== undefined ? model.offsetY : 0
            gridOffsetX: lockscreenRoot.gridOffsetX
            gridOffsetY: lockscreenRoot.gridOffsetY
            
            isEditing: wallpaperBackend.isEditingLockscreen
            isDraggingWidget: lockscreenRoot.isDraggingWidget

            isAuthMode: lockscreenRoot.isAuthMode
            onRequestAuthMode: lockscreenRoot._internalAuthMode = true
            onRequestIdleMode: lockscreenRoot._internalAuthMode = false

            widgetType: model.type
            variant: model.variant !== undefined ? model.variant : 0
            fontSize: model.fontSize !== undefined ? model.fontSize : 32
            fontFamily: model.fontFamily !== undefined ? model.fontFamily : "system-ui"
            dateFontFamily: model.dateFontFamily !== undefined ? model.dateFontFamily : "system-ui:600"
            useTheme: model.useTheme !== undefined ? model.useTheme : true
            isBold: model.isBold !== undefined ? model.isBold : false
            padding: model.padding !== undefined ? model.padding : 0
            transparent: model.transparent !== undefined ? model.transparent : true
            is24h: model.is24h !== undefined ? model.is24h : true
            dateSize: model.dateSize !== undefined ? model.dateSize : 10
            timeOpacity: model.timeOpacity !== undefined ? model.timeOpacity : 1.0
            dateOpacity: model.dateOpacity !== undefined ? model.dateOpacity : 0.7
            text: model.text !== undefined ? model.text : ""
            echoChar: model.echoChar !== undefined ? model.echoChar : "•"
            showFocusBorder: model.showFocusBorder !== undefined ? model.showFocusBorder : true
            authWidth: model.authWidth !== undefined ? model.authWidth : 0
            authHeight: model.authHeight !== undefined ? model.authHeight : 0
            showTemp: model.showTemp !== undefined ? model.showTemp : true
            timeColorIndex: model.timeColorIndex !== undefined ? model.timeColorIndex : 8
            dateColorIndex: model.dateColorIndex !== undefined ? model.dateColorIndex : 5
            dateSpacing: model.dateSpacing !== undefined ? model.dateSpacing : 4

            Binding { 
                target: lockscreenRoot
                property: "isDraggingWidget"
                value: widgetInstance.isDragging 
            }
            
            onSettingsClicked: { 
                if (wallpaperBackend) {
                    wallpaperBackend.selectedWidgetIndex = (wallpaperBackend.selectedWidgetIndex === index) ? -1 : index; 
                }
            }
            
            onWidgetChanged: { lockscreenRoot.triggerSave(); }
            
            onDeleteRequested: { 
                let targetIdx = index;
                if (wallpaperBackend) {
                    if (wallpaperBackend.selectedWidgetIndex === targetIdx) {
                        wallpaperBackend.selectedWidgetIndex = -1;
                    } else if (wallpaperBackend.selectedWidgetIndex > targetIdx) {
                        wallpaperBackend.selectedWidgetIndex -= 1;
                    }
                }
                activeWidgets.remove(targetIdx); 
                lockscreenRoot.triggerSave(); 
            }
        }
    }

    WidgetDrawer {
        id: widgetDrawer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        z: 99999
        
        active: wallpaperBackend ? wallpaperBackend.isEditingLockscreen : false
        activeWidgets: lockscreenRoot.activeWidgets
        selectedIndex: lockscreenRoot.selectedWidgetIndex
        forceCollapse: lockscreenRoot.showDragHighlight
    }
}