import QtQuick
import ".." 
import "../scenes"

Item {
    id: root
    
    AppTheme { id: appTheme }

    property var widgetModel: null

    // Reference to LockScreen variables (Null when deployed on standard Desktop)
    property var spatialZoneRef: null

    property int gridX: 0
    property int gridY: 0
    property int gridW: 4
    property int gridH: 2
    property int cellSize: 80

    property int offsetX: 0
    property int offsetY: 0
    property int gridOffsetX: 0
    property int gridOffsetY: 0

    property int dragOffsetX: 0
    property int dragOffsetY: 0
    property int dragOffsetW: 0
    property int dragOffsetH: 0

    property bool isEditing: (typeof wallpaperBackend !== "undefined" && wallpaperBackend !== null) ? wallpaperBackend.isEditing : false
    property int indexInModel: 0
    property bool isActiveSelection: false

    property bool isDraggingWidget: false
    property bool isDragging: false

    // State Variables for Zones/Animations
    property bool isAuthMode: true 
    
    signal requestAuthMode()
    signal requestIdleMode()

    // PREVENTS THE "SNAP ON LOAD" BUG
    property bool _animationsReady: false
    Timer {
        id: initDelayTimer
        interval: 50
        running: true
        repeat: false
        onTriggered: root._animationsReady = true
    }

    onIsAuthModeChanged: {
        if (isAuthMode && widgetType === "Auth" && sceneLoader.item) {
            if (typeof sceneLoader.item.grabFocus === "function") {
                sceneLoader.item.grabFocus();
            }
        }
    }

    // =========================================================
    // MATHEMATICAL CENTERING & ZONES
    // =========================================================
    
    property bool isInsideRedZone: {
        if (!spatialZoneRef) return false;
        
        let cx = (gridX * cellSize) + gridOffsetX + offsetX + ((gridW * cellSize) / 2.0);
        let cy = (gridY * cellSize) + gridOffsetY + offsetY + ((gridH * cellSize) / 2.0);
        
        let left = spatialZoneRef.zoneMarginX;
        let right = spatialZoneRef.width - spatialZoneRef.zoneMarginX;
        let top = spatialZoneRef.zoneRedY;
        let bottom = spatialZoneRef.zoneRedY + spatialZoneRef.zoneRedHeight;
        
        return (cx >= left && cx <= right && cy >= top && cy <= bottom);
    }

    property bool isInsideGreenZone: {
        if (!spatialZoneRef) return false;
        
        let cx = (gridX * cellSize) + gridOffsetX + offsetX + ((gridW * cellSize) / 2.0);
        let cy = (gridY * cellSize) + gridOffsetY + offsetY + ((gridH * cellSize) / 2.0);
        
        let left = spatialZoneRef.zoneMarginX;
        let right = spatialZoneRef.width - spatialZoneRef.zoneMarginX;
        let top = spatialZoneRef.zoneGreenY;
        let bottom = spatialZoneRef.zoneGreenY + spatialZoneRef.zoneGreenHeight;
        
        return (cx >= left && cx <= right && cy >= top && cy <= bottom);
    }

    property real idleTranslateY: {
        if (!spatialZoneRef || isAuthMode || isEditing) return 0;
        
        if (isInsideRedZone) {
            let cy = (gridY * cellSize) + gridOffsetY + offsetY + ((gridH * cellSize) / 2.0);
            let redCenterY = spatialZoneRef.zoneRedY + (spatialZoneRef.zoneRedHeight / 2.0);
            return redCenterY - cy;
        } 
        else if (isInsideGreenZone) {
            let cy = (gridY * cellSize) + gridOffsetY + offsetY + ((gridH * cellSize) / 2.0);
            let slideDistance = spatialZoneRef.height - (cy - ((gridH * cellSize)/2));
            return slideDistance;
        }
        
        // Static Zone (Outside Red/Green)
        return 0;
    }

    property real idleOpacity: {
        if (!spatialZoneRef || isAuthMode || isEditing) return 1.0;
        if (isInsideGreenZone) return 0.0;
        return 1.0;
    }
    // =========================================================

    // ANIMATE ZONAL SLIDE TRANSITIONS
    transform: Translate {
        y: (!root.isEditing && !root.isAuthMode) ? root.idleTranslateY : 0
        Behavior on y { 
            enabled: root._animationsReady
            NumberAnimation { duration: 450; easing.type: Easing.OutQuint } 
        }
    }

    opacity: (!root.isEditing && !root.isAuthMode) ? root.idleOpacity : 1.0
    Behavior on opacity { 
        enabled: root._animationsReady
        NumberAnimation { duration: 350; easing.type: Easing.OutQuint } 
    }

    property string widgetType: ""
    property int variant: 0
    property int fontSize: 32
    property string fontFamily: "system-ui"
    property string dateFontFamily: "system-ui:600"
    property bool useTheme: true
    property bool isBold: false
    property int padding: 0
    property bool transparent: true
    property bool is24h: true
    property int dateSize: 10
    property real timeOpacity: 1.0
    property real dateOpacity: 0.7
    property string text: ""
    property string echoChar: "•"
    property bool showFocusBorder: true
    property bool showTemp: true
    
    property int authWidth: 0
    property int authHeight: 0

    // Explicit color and spacing properties
    property int timeColorIndex: 8
    property int dateColorIndex: 5
    property int dateSpacing: 4

    signal settingsClicked()
    signal widgetChanged()
    signal deleteRequested()

    width: gridW * cellSize + dragOffsetW
    height: gridH * cellSize + dragOffsetH

    x: gridX * cellSize + offsetX + gridOffsetX + dragOffsetX
    y: gridY * cellSize + offsetY + gridOffsetY + dragOffsetY

    // Disabled animations until the 50ms startup frame has passed
    Behavior on x { 
        enabled: root._animationsReady && !root.isDraggingWidget; 
        NumberAnimation { duration: 250; easing.type: Easing.OutQuint } 
    }
    Behavior on y { 
        enabled: root._animationsReady && !root.isDraggingWidget; 
        NumberAnimation { duration: 250; easing.type: Easing.OutQuint } 
    }
    Behavior on width { 
        enabled: root._animationsReady && !root.isDraggingWidget; 
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad } 
    }
    Behavior on height { 
        enabled: root._animationsReady && !root.isDraggingWidget; 
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad } 
    }

    Item {
        anchors.fill: parent

        Item {
            id: contentLoaderContainer
            anchors.fill: parent
            anchors.margins: Math.round(8 * appTheme.scale)

            Loader {
                id: sceneLoader
                anchors.fill: parent
                sourceComponent: {
                    if (root.widgetType === "Clock") return clockComponent;
                    if (root.widgetType === "Label") return labelComponent;
                    if (root.widgetType === "System") return systemComponent;
                    if (root.widgetType === "Media") return mediaComponent;
                    if (root.widgetType === "Auth") return authComponent;
                    return null;
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.isEditing && root.isActiveSelection
            color: "transparent"
            border.width: 1.5
            border.color: appTheme.accent 
            
            Rectangle { 
                width: Math.round(10 * appTheme.scale); height: Math.round(10 * appTheme.scale); color: "#FFFFFF"; radius: 0; anchors.horizontalCenter: parent.left; anchors.verticalCenter: parent.top 
                MouseArea {
                    anchors.fill: parent; anchors.margins: Math.round(-10 * appTheme.scale); cursorShape: Qt.SizeFDiagCursor
                    property real startMouseX: 0
                    property real startMouseY: 0
                    onPressed: (mouse) => { startMouseX = mouse.x; startMouseY = mouse.y; root.isDragging = true }
                    onReleased: {
                        root.isDragging = false
                        let finalX = root.gridX * root.cellSize + root.dragOffsetX
                        let finalY = root.gridY * root.cellSize + root.dragOffsetY
                        let snapX = Math.round(finalX / root.cellSize)
                        let snapY = Math.round(finalY / root.cellSize)
                        let rightGridEdge = root.gridX + root.gridW
                        let bottomGridEdge = root.gridY + root.gridH
                        let snapW = rightGridEdge - snapX
                        let snapH = bottomGridEdge - snapY

                        root.dragOffsetX = 0; root.dragOffsetY = 0
                        root.dragOffsetW = 0; root.dragOffsetH = 0

                        if (snapW > 0 && snapH > 0 && root.widgetModel) {
                            root.widgetModel.setProperty(indexInModel, "grid_x", snapX)
                            root.widgetModel.setProperty(indexInModel, "grid_y", snapY)
                            root.widgetModel.setProperty(indexInModel, "grid_w", snapW)
                            root.widgetModel.setProperty(indexInModel, "grid_h", snapH)
                            root.widgetChanged()
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            let dx = mouse.x - startMouseX
                            let dy = mouse.y - startMouseY
                            root.dragOffsetX += dx
                            root.dragOffsetY += dy
                            root.dragOffsetW -= dx
                            root.dragOffsetH -= dy
                        }
                    }
                }
            }

            Rectangle { 
                width: Math.round(10 * appTheme.scale); height: Math.round(10 * appTheme.scale); color: "#FFFFFF"; radius: 0; anchors.horizontalCenter: parent.right; anchors.verticalCenter: parent.top 
                MouseArea {
                    anchors.fill: parent; anchors.margins: Math.round(-10 * appTheme.scale); cursorShape: Qt.SizeBDiagCursor
                    property real startMouseY: 0
                    onPressed: (mouse) => { startMouseY = mouse.y; root.isDragging = true }
                    onReleased: {
                        root.isDragging = false;
                        let finalY = root.gridY * root.cellSize + root.dragOffsetY
                        let snapY = Math.round(finalY / root.cellSize)
                        let finalW = Math.round((root.gridW * root.cellSize + root.dragOffsetW) / root.cellSize)
                        let bottomGridEdge = root.gridY + root.gridH
                        let snapH = bottomGridEdge - snapY

                        root.dragOffsetY = 0
                        root.dragOffsetW = 0; root.dragOffsetH = 0

                        if (finalW > 0 && snapH > 0 && root.widgetModel) {
                            root.widgetModel.setProperty(indexInModel, "grid_y", snapY)
                            root.widgetModel.setProperty(indexInModel, "grid_w", finalW)
                            root.widgetModel.setProperty(indexInModel, "grid_h", snapH)
                            root.widgetChanged()
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            let dy = mouse.y - startMouseY
                            root.dragOffsetY += dy
                            root.dragOffsetH -= dy
                            root.dragOffsetW += (mouse.x - width/2) * 0.1
                        }
                    }
                }
            }

            Rectangle { 
                width: Math.round(10 * appTheme.scale); height: Math.round(10 * appTheme.scale); color: "#FFFFFF"; radius: 0; anchors.horizontalCenter: parent.left; anchors.verticalCenter: parent.bottom 
                MouseArea {
                    anchors.fill: parent; anchors.margins: Math.round(-10 * appTheme.scale); cursorShape: Qt.SizeBDiagCursor
                    property real startMouseX: 0
                    onPressed: (mouse) => { startMouseX = mouse.x; root.isDragging = true }
                    onReleased: {
                        root.isDragging = false;
                        let finalX = root.gridX * root.cellSize + root.dragOffsetX
                        let snapX = Math.round(finalX / root.cellSize)
                        let rightGridEdge = root.gridX + root.gridW
                        let snapW = rightGridEdge - snapX
                        let finalH = Math.round((root.gridH * root.cellSize + root.dragOffsetH) / root.cellSize)

                        root.dragOffsetX = 0
                        root.dragOffsetW = 0; root.dragOffsetH = 0

                        if (snapW > 0 && finalH > 0 && root.widgetModel) {
                            root.widgetModel.setProperty(indexInModel, "grid_x", snapX)
                            root.widgetModel.setProperty(indexInModel, "grid_w", snapW)
                            root.widgetModel.setProperty(indexInModel, "grid_h", finalH)
                            root.widgetChanged()
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            let dx = mouse.x - startMouseX
                            root.dragOffsetX += dx
                            root.dragOffsetW -= dx
                            root.dragOffsetH += (mouse.y - height/2) * 0.1
                        }
                    }
                }
            }

            Rectangle { 
                width: Math.round(10 * appTheme.scale); height: Math.round(10 * appTheme.scale); color: "#FFFFFF"; radius: 0; anchors.horizontalCenter: parent.right; anchors.verticalCenter: parent.bottom 
                MouseArea {
                    anchors.fill: parent; anchors.margins: Math.round(-10 * appTheme.scale); cursorShape: Qt.SizeFDiagCursor
                    property real startMouseX: 0
                    property real startMouseY: 0
                    onPressed: (mouse) => { startMouseX = mouse.x; startMouseY = mouse.y; root.isDragging = true }
                    onReleased: {
                        root.isDragging = false;
                        let finalW = Math.round((root.gridW * root.cellSize + root.dragOffsetW) / root.cellSize)
                        let finalH = Math.round((root.gridH * root.cellSize + root.dragOffsetH) / root.cellSize)
                        root.dragOffsetW = 0; root.dragOffsetH = 0
                        
                        if (root.widgetModel) {
                            root.widgetModel.setProperty(indexInModel, "grid_w", Math.max(1, finalW))
                            root.widgetModel.setProperty(indexInModel, "grid_h", Math.max(1, finalH))
                            root.widgetChanged()
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            root.dragOffsetW += (mouse.x - startMouseX)
                            root.dragOffsetH += (mouse.y - startMouseY)
                        }
                    }
                }
            }
        }

        MouseArea {
            id: moveHandler
            anchors.fill: parent
            anchors.margins: Math.round(12 * appTheme.scale)
            enabled: root.isEditing
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            
            property real startParentX: 0
            property real startParentY: 0
            property real startGridX: 0
            property real startGridY: 0

            onPressed: (mouse) => { 
                let parentPos = moveHandler.mapToItem(root.parent, mouse.x, mouse.y);
                startParentX = parentPos.x;
                startParentY = parentPos.y;
                startGridX = root.gridX;
                startGridY = root.gridY;

                root.settingsClicked()
                root.isDragging = true 
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    let parentPos = moveHandler.mapToItem(root.parent, mouse.x, mouse.y);
                    root.dragOffsetX = parentPos.x - startParentX;
                    root.dragOffsetY = parentPos.y - startParentY;
                }
            }

            onReleased: {
                root.isDragging = false;
                
                let currentVisualX = startGridX * root.cellSize + root.offsetX + root.dragOffsetX;
                let currentVisualY = startGridY * root.cellSize + root.offsetY + root.dragOffsetY;
                
                let targetCellX = Math.round(currentVisualX / root.cellSize);
                let targetCellY = Math.round(currentVisualY / root.cellSize);
                if (targetCellX < 0) targetCellX = 0;
                if (targetCellY < 0) targetCellY = 0;

                root.dragOffsetX = 0;
                root.dragOffsetY = 0;

                if (root.widgetModel) {
                    root.widgetModel.setProperty(root.indexInModel, "grid_x", targetCellX);
                    root.widgetModel.setProperty(root.indexInModel, "grid_y", targetCellY);
                    root.widgetChanged();
                }
            }
        }

        Row {
            anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Math.round(8 * appTheme.scale) 
            spacing: Math.round(8 * appTheme.scale)
            visible: root.isEditing && root.isActiveSelection
            z: 100
            
            Rectangle {
                width: Math.round(32 * appTheme.scale); height: Math.round(32 * appTheme.scale); radius: Math.round(16 * appTheme.scale); color: deleteMouse.containsMouse ? "#1E1E2E" : "#11111B"; border.color: deleteMouse.containsMouse ? "#F38BA8" : Qt.rgba(255, 255, 255, 0.1); border.width: 1
                scale: deleteMouse.containsMouse ? 1.1 : 1.0; Behavior on scale { NumberAnimation { duration: 100 } }
                Text { text: "\u2715"; color: deleteMouse.containsMouse ? "#F38BA8" : "#A6ADC8"; font.pointSize: 11 * appTheme.scale; font.bold: true; anchors.centerIn: parent }
                MouseArea { 
                    id: deleteMouse; anchors.fill: parent; hoverEnabled: true; 
                    preventStealing: true; propagateComposedEvents: true
                    onClicked: root.deleteRequested() 
                }
            }
        }
    }

    Component { 
        id: clockComponent
        ClockScene { 
            variant: root.variant
            customFontSize: root.fontSize
            customFontFamily: root.fontFamily
            customDateFontFamily: root.dateFontFamily
            useTheme: root.useTheme
            isBold: root.isBold
            padding: root.padding
            isTransparent: root.transparent
            is24h: root.is24h
            customDateSize: root.dateSize
            timeOpacity: root.timeOpacity
            dateOpacity: root.dateOpacity
            timeColorIndex: root.timeColorIndex
            dateColorIndex: root.dateColorIndex
            dateSpacing: root.dateSpacing
        } 
    }
    Component { 
        id: labelComponent
        TextScene { 
            labelText: root.text 
        } 
    }
    Component { 
        id: systemComponent
        SystemScene { 
            variant: root.variant 
            showTemp: root.showTemp
        } 
    }
    Component { 
        id: mediaComponent
        MediaScene { 
            variant: root.variant 
        } 
    }
    Component { 
        id: authComponent
        AuthScene { 
            variant: root.variant 
            authPlaceholderText: root.text
            authEchoChar: root.echoChar
            authShowBorder: root.showFocusBorder
            isTransparent: root.transparent
            customWidth: root.authWidth
            customHeight: root.authHeight
        } 
    }
}