import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "modules"
import "scenes"

Item {
    id: mainRoot
    anchors.fill: parent

    AppTheme { id: appTheme }

    property alias activeWidgets: activeWidgets
    
    // Binding to backend state. NEVER ASSIGN DIRECTLY TO THIS, assign to wallpaperBackend.selectedWidgetIndex
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
        mainRoot.triggerSave();
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
                "blendRatio": 0.2
            });
        }
        desktopStorage.saveLayout(arr);
    }

    function loadLayoutData() {
        if (typeof desktopStorage === "undefined") {
            loadDefaults(); 
            return;
        }
        let saved = desktopStorage.loadLayout();
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
            "type": "Clock", "variant": 1, "grid_x": 2, "grid_y": 2, "grid_w": 4, "grid_h": 2, 
            "text": "", "fontSize": 32, "fontFamily": "system-ui", "dateFontFamily": "system-ui:600", 
            "useTheme": true, "isBold": false, "padding": 0, "transparent": true, "is24h": true, 
            "dateSize": 10, "offsetX": 0, "offsetY": 0, "timeOpacity": 1.0, "dateOpacity": 0.7, 
            "echoChar": "•", "showFocusBorder": true, 
            "authWidth": 0, "authHeight": 0, "showTemp": true, "timeColorIndex": 8, "dateColorIndex": 5, "dateSpacing": 4
        });
        activeWidgets.append({ 
            "type": "Label", "variant": 0, "grid_x": 8, "grid_y": 4, "grid_w": 4, "grid_h": 1, 
            "text": "Stay Focused", "fontSize": 18, "fontFamily": "system-ui", "dateFontFamily": "system-ui:600", 
            "useTheme": false, "isBold": true, "padding": 0, "transparent": true, "is24h": true, 
            "dateSize": 10, "offsetX": 0, "offsetY": 0, "echoChar": "•", "showFocusBorder": true, 
            "authWidth": 0, "authHeight": 0, "showTemp": true, "timeColorIndex": 8, "dateColorIndex": 5, "dateSpacing": 4
        });
        activeWidgets.append({ 
            "type": "System", "variant": 0, "grid_x": 2, "grid_y": 5, "grid_w": 4, "grid_h": 2, 
            "text": "", "fontSize": 18, "fontFamily": "system-ui", "dateFontFamily": "system-ui:600", 
            "useTheme": true, "isBold": false, "padding": 0, "transparent": true, "is24h": true, 
            "dateSize": 10, "offsetX": 0, "offsetY": 0, "timeOpacity": 1.0, "dateOpacity": 0.7, 
            "echoChar": "•", "showFocusBorder": true, 
            "authWidth": 0, "authHeight": 0, "showTemp": true, "timeColorIndex": 8, "dateColorIndex": 5, "dateSpacing": 4
        });
        activeWidgets.append({ 
            "type": "Media", "variant": 0, "grid_x": 7, "grid_y": 6, "grid_w": 4, "grid_h": 2, 
            "text": "", "fontSize": 18, "fontFamily": "system-ui", "dateFontFamily": "system-ui:600", 
            "useTheme": true, "isBold": false, "padding": 0, "transparent": true, "is24h": true, 
            "dateSize": 10, "offsetX": 0, "offsetY": 0, "timeOpacity": 1.0, "dateOpacity": 0.7, 
            "echoChar": "•", "showFocusBorder": true, 
            "authWidth": 0, "authHeight": 0, "showTemp": true, "timeColorIndex": 8, "dateColorIndex": 5, "dateSpacing": 4
        });
    }

    ListModel {
        id: activeWidgets
        objectName: "activeWidgets"
        onDataChanged: (topLeft, bottomRight, roles) => { mainRoot.triggerSave() }
        onRowsInserted: (parent, first, last) => { mainRoot.triggerSave() }
        onRowsRemoved: (parent, first, last) => { mainRoot.triggerSave() }
        Component.onCompleted: {
            loadLayoutData();
            if (wallpaperBackend) {
                wallpaperBackend.desktopWidgets = activeWidgets;
            }
        }
    }

    Item {
        id: desktopContainer
        anchors.fill: parent
        scale: 1.0

        Image {
            id: bgImage
            anchors.fill: parent
            source: wallpaperBackend ? ("file://" + wallpaperBackend.currentWallpaper) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

MultiEffect {
            id: blurEffect
            anchors.fill: parent
            source: bgImage
            blurEnabled: false // THE FIX: Disabled blur entirely
            blur: 0.0
            brightness: 0.0
            Behavior on blur { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
            Behavior on brightness { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
        }
        Rectangle {
            id: dragHighlightRect
            visible: mainRoot.showDragHighlight && (wallpaperBackend && wallpaperBackend.isEditing)
            x: mainRoot.dragGridX * mainRoot.cellSize + mainRoot.gridOffsetX
            y: mainRoot.dragGridY * mainRoot.cellSize + mainRoot.gridOffsetY
            width: mainRoot.dragGridW * mainRoot.cellSize
            height: mainRoot.dragGridH * mainRoot.cellSize
            color: Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.15)
            border.color: appTheme.accent
            border.width: 2
            radius: appTheme.radius
            
            Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
            Behavior on y { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
        }

        Loader {
            id: dragProxyLoader
            visible: mainRoot.showDragHighlight && (wallpaperBackend && wallpaperBackend.isEditing)
            width: mainRoot.dragGridW * mainRoot.cellSize
            height: mainRoot.dragGridH * mainRoot.cellSize
            
            x: mainRoot.dragMouseX - width / 2
            y: mainRoot.dragMouseY - height / 2
            
            opacity: 0.65
            scale: 0.95
            z: 10000 
            
            sourceComponent: {
                if (mainRoot.dragWidgetType === "Clock") return clockPreview;
                if (mainRoot.dragWidgetType === "Label") return labelPreview;
                if (mainRoot.dragWidgetType === "System") return systemPreview;
                if (mainRoot.dragWidgetType === "Media") return mediaPreview;
                if (mainRoot.dragWidgetType === "Auth") return authPreview;
                return null;
            }
            
            Component { id: clockPreview; ClockScene { variant: mainRoot.dragWidgetVariant; customFontSize: 24 } }
            Component { id: labelPreview; TextScene { labelText: "New Label" } }
            Component { id: systemPreview; SystemScene { variant: mainRoot.dragWidgetVariant } }
            Component { id: mediaPreview; MediaScene { variant: mainRoot.dragWidgetVariant } }
            Component { 
                id: authPreview; 
                AuthScene { 
                    variant: mainRoot.dragWidgetVariant 
                    authPlaceholderText: "ENTER PASSWORD"
                    authEchoChar: "•"
                    authShowBorder: true
                    isTransparent: false
                } 
            }
        }

        DropArea {
            id: desktopDropArea
            anchors.fill: parent
            keys: ["text/plain"]
            enabled: wallpaperBackend ? wallpaperBackend.isEditing : false

            onEntered: (drag) => { desktopDropArea.updateDragPosition(drag); }
            onPositionChanged: (drag) => { desktopDropArea.updateDragPosition(drag); }
            onExited: { mainRoot.showDragHighlight = false; }

            onDropped: (drop) => {
                mainRoot.showDragHighlight = false;
                if (drop.hasText) {
                    let text = drop.text;
                    let parts = text.split(":");
                    if (parts.length >= 2) {
                        let type = parts[0];
                        let variant = parseInt(parts[1]);
                        
                        let gw = 4;
                        let gh = (type === "Label" || type === "Auth") ? 1 : 2;

                        let gx = Math.round((drop.x - mainRoot.gridOffsetX - (gw * mainRoot.cellSize) / 2) / mainRoot.cellSize);
                        let gy = Math.round((drop.y - mainRoot.gridOffsetY - (gh * mainRoot.cellSize) / 2) / mainRoot.cellSize);
                        
                        gx = Math.max(0, Math.min(mainRoot.cols - gw, gx));
                        gy = Math.max(0, Math.min(mainRoot.rows - gh, gy));
                        
                        mainRoot.addNewWidget(type, variant, gx, gy, gw, gh);
                        
                        if (wallpaperBackend) {
                            wallpaperBackend.selectedWidgetIndex = mainRoot.activeWidgets.count - 1;
                        }
                        drop.acceptProposedAction();
                    }
                }
            }

            function updateDragPosition(drag) {
                if (drag.hasText) {
                    let text = drag.text;
                    let parts = text.split(":");
                    if (parts.length >= 2) {
                        let type = parts[0];
                        let variant = parseInt(parts[1]);
                        let gw = 4;
                        let gh = (type === "Label" || type === "Auth") ? 1 : 2;

                        mainRoot.dragMouseX = drag.x;
                        mainRoot.dragMouseY = drag.y;
                        mainRoot.dragWidgetType = type;
                        mainRoot.dragWidgetVariant = variant;

                        let gx = Math.round((drag.x - mainRoot.gridOffsetX - (gw * mainRoot.cellSize) / 2) / mainRoot.cellSize);
                        let gy = Math.round((drag.y - mainRoot.gridOffsetY - (gh * mainRoot.cellSize) / 2) / mainRoot.cellSize);
                        
                        gx = Math.max(0, Math.min(mainRoot.cols - gw, gx));
                        gy = Math.max(0, Math.min(mainRoot.rows - gh, gy));
                        
                        mainRoot.dragGridX = gx;
                        mainRoot.dragGridY = gy;
                        mainRoot.dragGridW = gw;
                        mainRoot.dragGridH = gh;
                        mainRoot.showDragHighlight = true;
                    }
                }
            }
        }

        Repeater {
            model: activeWidgets
            delegate: InteractiveWidget {
                id: widgetInstance
                widgetModel: activeWidgets

                spatialZoneRef: null

                gridX: model.grid_x
                gridY: model.grid_y
                gridW: model.grid_w
                gridH: model.grid_h
                cellSize: mainRoot.cellSize
                indexInModel: index
                
                isActiveSelection: (mainRoot.selectedWidgetIndex === index)
                
                offsetX: model.offsetX !== undefined ? model.offsetX : 0
                offsetY: model.offsetY !== undefined ? model.offsetY : 0
                gridOffsetX: mainRoot.gridOffsetX
                gridOffsetY: mainRoot.gridOffsetY

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

                isDraggingWidget: mainRoot.isDraggingWidget

                // THE FIX: Replaced explicit Binding node with an event handler to survive dynamic context switches
                onIsDraggingChanged: {
                    mainRoot.isDraggingWidget = isDragging;
                }

                onSettingsClicked: { 
                    if (wallpaperBackend) {
                        wallpaperBackend.selectedWidgetIndex = (wallpaperBackend.selectedWidgetIndex === index) ? -1 : index;
                    }
                }
                
                onWidgetChanged: { mainRoot.triggerSave(); }
                
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
                    mainRoot.triggerSave(); 
                }
            }
        }
    }

    WidgetDrawer {
        id: widgetDrawer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        z: 99999
        
        active: wallpaperBackend ? wallpaperBackend.isEditing : false
        activeWidgets: mainRoot.activeWidgets
        selectedIndex: mainRoot.selectedWidgetIndex
        forceCollapse: mainRoot.showDragHighlight
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => { 
            if (wallpaperBackend && !wallpaperBackend.isPickingWallpaper && !wallpaperBackend.isEditing && !wallpaperBackend.isEditingLockscreen) { 
                contextMenu.x = mouse.x; 
                contextMenu.y = mouse.y; 
                contextMenu.open() 
            } 
        }
    }

    Menu {
        id: contextMenu
        enter: Transition { 
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 120 } 
            NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 120 } 
        }
        exit: Transition { 
            NumberAnimation { property: "opacity"; to: 0.0; duration: 80 } 
        }
        background: Rectangle { 
            implicitWidth: Math.round(180 * appTheme.scale); 
            color: appTheme.bg; 
            border.width: 1; 
            radius: appTheme.radius; 
            border.color: appTheme.accentDimmed 
        }
        MenuItem {
            text: "Change Wallpaper"
            onTriggered: if (wallpaperBackend) wallpaperBackend.isPickingWallpaper = true
            contentItem: Text { 
                text: parent.text; 
                color: parent.hovered ? appTheme.accent : appTheme.textPrimary; 
                font.family: "Lexend"; 
                font.pointSize: 9 * appTheme.scale; 
                font.bold: true; 
                verticalAlignment: Text.AlignVCenter; 
                leftPadding: 10 
            }
            background: Rectangle { 
                implicitWidth: Math.round(180 * appTheme.scale); 
                implicitHeight: Math.round(34 * appTheme.scale); 
                radius: appTheme.radius - 2; 
                color: parent.hovered ? Qt.rgba(1,1,1,0.1) : "transparent"; 
                Behavior on color { ColorAnimation { duration: 80 } } 
            }
        }
        MenuItem {
            text: "Edit Desktop"
            onTriggered: { 
                if (wallpaperBackend) wallpaperBackend.ToggleEditMode(); 
                if (wallpaperBackend) wallpaperBackend.selectedWidgetIndex = -1; 
            }
            contentItem: Text { 
                text: parent.text; 
                color: parent.hovered ? appTheme.accent : appTheme.textPrimary; 
                font.family: "Lexend"; 
                font.pointSize: 9 * appTheme.scale; 
                font.bold: true; 
                verticalAlignment: Text.AlignVCenter; 
                leftPadding: 10 
            }
            background: Rectangle { 
                implicitWidth: Math.round(180 * appTheme.scale); 
                implicitHeight: Math.round(34 * appTheme.scale); 
                radius: appTheme.radius - 2; 
                color: parent.hovered ? Qt.rgba(1,1,1,0.1) : "transparent"; 
                Behavior on color { ColorAnimation { duration: 80 } } 
            }
        }
        MenuItem {
            text: "Edit Lockscreen"
            onTriggered: { 
                if (wallpaperBackend) wallpaperBackend.ToggleLockscreenEditMode(); 
                if (wallpaperBackend) wallpaperBackend.selectedWidgetIndex = -1; 
            }
            contentItem: Text { 
                text: parent.text; 
                color: parent.hovered ? appTheme.accent : appTheme.textPrimary; 
                font.family: "Lexend"; 
                font.pointSize: 9 * appTheme.scale; 
                font.bold: true; 
                verticalAlignment: Text.AlignVCenter; 
                leftPadding: 10 
            }
            background: Rectangle { 
                implicitWidth: Math.round(180 * appTheme.scale); 
                implicitHeight: Math.round(34 * appTheme.scale); 
                radius: appTheme.radius - 2; 
                color: parent.hovered ? Qt.rgba(1,1,1,0.1) : "transparent"; 
                Behavior on color { ColorAnimation { duration: 80 } } 
            }
        }
    }

    Shortcut { 
        sequence: "Super+W"; 
        context: Qt.WindowShortcut; 
        onActivated: if (wallpaperBackend) wallpaperBackend.isPickingWallpaper = !wallpaperBackend.isPickingWallpaper 
    }
    
    Shortcut {
        sequence: "Escape"; 
        context: Qt.WindowShortcut
        onActivated: {
            if (wallpaperBackend) {
                if (wallpaperBackend.isPickingWallpaper) { 
                    wallpaperBackend.currentWallpaper = wallpaperBackend.confirmedWallpaper; 
                    wallpaperBackend.isPickingWallpaper = false; 
                }
                else if (wallpaperBackend.isEditing) {
                    if (wallpaperBackend.selectedWidgetIndex !== -1) {
                        wallpaperBackend.selectedWidgetIndex = -1;
                    } else {
                        wallpaperBackend.isEditing = false;
                    }
                }
            }
        }
    }
}