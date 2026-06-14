import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." 
import "../scenes" 

Item {
    id: widgetDrawer 

    width: Math.round(750 * appTheme.scale)
    height: effectivelyVisible ? Math.round(250 * appTheme.scale) : Math.round(20 * appTheme.scale)
    Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

    AppTheme { 
        id: appTheme
        objectName: "appTheme" 
    }

    property bool active: false
    property var activeWidgets: null
    property int selectedIndex: -1
    property bool forceCollapse: false
    
    property int dummyTrigger: 0
    property var activeWidgetData: {
        let trigger = dummyTrigger;
        return (selectedIndex >= 0 && activeWidgets && selectedIndex < activeWidgets.count) ? activeWidgets.get(selectedIndex) : null;
    }

    property bool userCollapsed: false
    property bool effectivelyVisible: widgetDrawer.active && !widgetDrawer.userCollapsed && !widgetDrawer.forceCollapse
    
    property int expandedGroup: -1
    property bool isLoaded: false

    onSelectedIndexChanged: {
        if (wallpaperBackend && wallpaperBackend.selectedWidgetIndex !== selectedIndex) {
            wallpaperBackend.selectedWidgetIndex = selectedIndex;
        }
        widgetDrawer.dummyTrigger++;
    }

    Timer {
        id: entryAnimationTimer
        interval: 50
        running: true
        repeat: false
        onTriggered: { 
            widgetDrawer.isLoaded = true; 
        }
    }

    Rectangle {
        id: drawerBackground
        width: parent.width
        height: Math.round(230 * appTheme.scale)
        color: appTheme.bg
        border.width: 0 
        radius: appTheme.radius
        clip: false 

        y: (effectivelyVisible && widgetDrawer.isLoaded) ? -appTheme.radius : -height
        Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

        // Squares off the top corners to sit flush against the top screen edge
        Rectangle { 
            width: parent.width
            height: appTheme.radius
            color: parent.color
            border.width: 0
            anchors.top: parent.top 
        }

        Item {
            anchors.fill: parent
            anchors.margins: Math.round(14 * appTheme.scale)
            anchors.topMargin: Math.round(14 * appTheme.scale) + appTheme.radius 

            // VIEW 1: CATALOG
            Item {
                id: catalogView
                anchors.fill: parent
                visible: widgetDrawer.selectedIndex === -1
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Item {
                    id: catalogHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.round(32 * appTheme.scale)

                    Rectangle {
                        id: backToCatalogBtnContainer
                        width: Math.round(32 * appTheme.scale)
                        height: Math.round(32 * appTheme.scale)
                        radius: Math.round(16 * appTheme.scale)
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: widgetDrawer.expandedGroup !== -1
                        color: backToCatalogBtn.containsMouse ? appTheme.accent : Qt.rgba(255, 255, 255, 0.08)
                        border.color: Qt.rgba(255, 255, 255, 0.1)
                        border.width: 1
                        
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Canvas {
                            id: backVectorArrow 
                            anchors.centerIn: parent
                            width: Math.round(12 * appTheme.scale)
                            height: Math.round(12 * appTheme.scale)
                            antialiasing: true
                            onPaint: { 
                                var ctx = getContext("2d"); 
                                ctx.clearRect(0, 0, width, height); 
                                ctx.strokeStyle = backToCatalogBtn.containsMouse ? appTheme.bg : appTheme.textPrimary; 
                                ctx.lineWidth = Math.max(2, 2 * appTheme.scale); 
                                ctx.lineCap = "round"; 
                                ctx.lineJoin = "round"; 
                                ctx.beginPath(); 
                                ctx.moveTo(width * 0.5, height * 0.15); 
                                ctx.lineTo(width * 0.15, height * 0.5); 
                                ctx.lineTo(width * 0.5, height * 0.85); 
                                ctx.moveTo(width * 0.15, height * 0.5); 
                                ctx.lineTo(width * 0.85, height * 0.5); 
                                ctx.stroke(); 
                            }
                            Connections { 
                                target: backToCatalogBtn
                                function onContainsMouseChanged() { backVectorArrow.requestPaint(); } 
                            }
                        }
                        MouseArea { 
                            id: backToCatalogBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: widgetDrawer.expandedGroup = -1 
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: widgetDrawer.expandedGroup === -1 ? "COMPONENTS CATALOG" : (widgetDrawer.expandedGroup === 0 ? "CLOCKS GROUP" : (widgetDrawer.expandedGroup === 1 ? "TYPOGRAPHY GROUP" : (widgetDrawer.expandedGroup === 2 ? "SYSTEM GROUP" : "SECURITY GROUP")))
                        color: "#A6E3A1"
                        font.family: "Inter"
                        font.pointSize: 9.5 * appTheme.scale
                        font.bold: true 
                    }
                }

                Item {
                    id: catalogContentArea
                    anchors.top: catalogHeader.bottom
                    anchors.topMargin: Math.round(10 * appTheme.scale)
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right

                    // Group Box A: Clocks
                    Rectangle {
                        id: clockGroupContainer
                        width: widgetDrawer.expandedGroup === 0 ? parent.width : Math.round(160 * appTheme.scale)
                        height: parent.height
                        y: 0
                        x: { 
                            if (widgetDrawer.expandedGroup === 0) return 0; 
                            if (widgetDrawer.expandedGroup === -1) return Math.round(10 * appTheme.scale); 
                            return Math.round(-400 * appTheme.scale); 
                        }
                        color: "transparent"
                        border.color: appTheme.accentDimmed
                        border.width: widgetDrawer.expandedGroup === 0 ? 0 : 1
                        radius: Math.round(6 * appTheme.scale)
                        visible: widgetDrawer.expandedGroup === -1 || widgetDrawer.expandedGroup === 0
                        
                        Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                        Repeater {
                            model: clockGroupModel
                            delegate: Rectangle {
                                id: clockCard
                                property int offset: index 
                                width: Math.round(140 * appTheme.scale)
                                height: clockGroupContainer.height - Math.round(12 * appTheme.scale)
                                radius: Math.round(6 * appTheme.scale)
                                
                                x: widgetDrawer.expandedGroup === 0 ? (index * Math.round(155 * appTheme.scale) + Math.round(16 * appTheme.scale)) : (offset * Math.round(12 * appTheme.scale) + Math.round(10 * appTheme.scale))
                                y: widgetDrawer.expandedGroup === 0 ? Math.round(6 * appTheme.scale) : (offset * Math.round(6 * appTheme.scale) + Math.round(6 * appTheme.scale))
                                scale: widgetDrawer.expandedGroup === 0 ? 1.0 : (1.0 - (offset * 0.08))
                                opacity: { 
                                    if (widgetDrawer.expandedGroup === 0) return 1.0; 
                                    if (widgetDrawer.expandedGroup === -1) return (1.0 - (offset * 0.25)); 
                                    return 0.0; 
                                }
                                
                                color: clockDrag.containsMouse ? appTheme.elementBg : Qt.alpha(appTheme.bg, 0.4)
                                border.color: clockDrag.containsMouse ? appTheme.accent : appTheme.borderSubtle
                                border.width: clockDrag.containsMouse ? 1.5 : 1
                                z: 10 - offset

                                Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                                Loader { 
                                    anchors.fill: parent
                                    anchors.margins: Math.round(10 * appTheme.scale)
                                    clip: true
                                    sourceComponent: Component { ClockScene { variant: model.variant; customFontSize: 14 } } 
                                }
                                
                                Drag.dragType: Drag.Automatic
                                Drag.mimeData: { "text/plain": "Clock:" + model.variant }
                                Drag.onDragFinished: { clockCard.Drag.active = false; }

                                MouseArea { 
                                    id: clockDrag
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    
                                    property int pressX: 0
                                    property int pressY: 0
                                    
                                    onPressed: (mouse) => { 
                                        pressX = mouse.x; 
                                        pressY = mouse.y 
                                    }
                                    
                                    onPositionChanged: (mouse) => { 
                                        if (pressed && (widgetDrawer.expandedGroup === 0 || widgetDrawer.expandedGroup === -1)) { 
                                            let dx = mouse.x - pressX; 
                                            let dy = mouse.y - pressY; 
                                            if (Math.abs(dx) > 10 || Math.abs(dy) > 10) { 
                                                if (!clockCard.Drag.active) {
                                                    clockCard.Drag.active = true; 
                                                }
                                            } 
                                        } 
                                    }
                                    
                                    onReleased: { clockCard.Drag.active = false; }
                                    
                                    onClicked: { 
                                        if (widgetDrawer.expandedGroup === -1) widgetDrawer.expandedGroup = 0; 
                                    }
                                }
                            }
                        }
                    }

                    // Group Box B: Typography
                    Rectangle {
                        id: textGroupContainer
                        width: widgetDrawer.expandedGroup === 1 ? parent.width : Math.round(160 * appTheme.scale)
                        height: parent.height
                        y: 0
                        x: { 
                            if (widgetDrawer.expandedGroup === 1) return 0; 
                            if (widgetDrawer.expandedGroup === -1) return Math.round(180 * appTheme.scale); 
                            return (widgetDrawer.expandedGroup < 1) ? parent.width + Math.round(200 * appTheme.scale) : Math.round(-400 * appTheme.scale); 
                        }
                        color: "transparent"
                        border.color: appTheme.accentDimmed
                        border.width: widgetDrawer.expandedGroup === 1 ? 0 : 1
                        radius: Math.round(6 * appTheme.scale)
                        visible: widgetDrawer.expandedGroup === -1 || widgetDrawer.expandedGroup === 1
                        
                        Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                        Repeater {
                            model: textGroupModel
                            delegate: Rectangle {
                                id: textCard
                                property int offset: index 
                                width: Math.round(140 * appTheme.scale)
                                height: textGroupContainer.height - Math.round(12 * appTheme.scale)
                                radius: Math.round(6 * appTheme.scale)
                                
                                x: widgetDrawer.expandedGroup === 1 ? (index * Math.round(155 * appTheme.scale) + Math.round(16 * appTheme.scale)) : (offset * Math.round(12 * appTheme.scale) + Math.round(10 * appTheme.scale))
                                y: widgetDrawer.expandedGroup === 1 ? Math.round(6 * appTheme.scale) : (offset * Math.round(6 * appTheme.scale) + Math.round(6 * appTheme.scale))
                                scale: widgetDrawer.expandedGroup === 1 ? 1.0 : (1.0 - (offset * 0.08))
                                opacity: { 
                                    if (widgetDrawer.expandedGroup === 1) return 1.0; 
                                    if (widgetDrawer.expandedGroup === -1) return (1.0 - (offset * 0.25)); 
                                    return 0.0; 
                                }
                                
                                color: textDrag.containsMouse ? appTheme.elementBg : Qt.alpha(appTheme.bg, 0.4)
                                border.color: textDrag.containsMouse ? appTheme.accent : appTheme.borderSubtle
                                border.width: textDrag.containsMouse ? 1.5 : 1
                                z: 10 - offset

                                Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                                Loader { 
                                    anchors.fill: parent
                                    anchors.margins: Math.round(10 * appTheme.scale)
                                    clip: true
                                    sourceComponent: Component { TextScene { labelText: "Creative Workspace" } } 
                                }
                                
                                Drag.dragType: Drag.Automatic
                                Drag.mimeData: { "text/plain": "Label:" + model.variant }
                                Drag.onDragFinished: { textCard.Drag.active = false; }

                                MouseArea { 
                                    id: textDrag
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    
                                    property int pressX: 0
                                    property int pressY: 0
                                    
                                    onPressed: (mouse) => { 
                                        pressX = mouse.x; 
                                        pressY = mouse.y 
                                    }
                                    
                                    onPositionChanged: (mouse) => { 
                                        if (pressed && (widgetDrawer.expandedGroup === 1 || widgetDrawer.expandedGroup === -1)) { 
                                            let dx = mouse.x - pressX; 
                                            let dy = mouse.y - pressY; 
                                            if (Math.abs(dx) > 10 || Math.abs(dy) > 10) { 
                                                if (!textCard.Drag.active) {
                                                    textCard.Drag.active = true;
                                                }
                                            } 
                                        } 
                                    }
                                    
                                    onReleased: { textCard.Drag.active = false; }
                                    
                                    onClicked: { 
                                        if (widgetDrawer.expandedGroup === -1) widgetDrawer.expandedGroup = 1; 
                                    }
                                }
                            }
                        }
                    }

                    // Group Box C: System Monitor & Auth Security
                    Rectangle {
                        id: systemGroupContainer
                        width: widgetDrawer.expandedGroup === 2 ? parent.width : Math.round(160 * appTheme.scale)
                        height: parent.height
                        y: 0
                        x: { 
                            if (widgetDrawer.expandedGroup === 2) return 0; 
                            if (widgetDrawer.expandedGroup === -1) return Math.round(350 * appTheme.scale); 
                            return (widgetDrawer.expandedGroup < 2) ? parent.width + Math.round(200 * appTheme.scale) : Math.round(-400 * appTheme.scale); 
                        }
                        color: "transparent"
                        border.color: appTheme.accentDimmed
                        border.width: widgetDrawer.expandedGroup === 2 ? 0 : 1
                        radius: Math.round(6 * appTheme.scale)
                        visible: widgetDrawer.expandedGroup === -1 || widgetDrawer.expandedGroup === 2
                        
                        Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                        Repeater {
                            model: systemGroupModel
                            delegate: Rectangle {
                                id: systemCard
                                property int offset: index 
                                width: Math.round(140 * appTheme.scale)
                                height: systemGroupContainer.height - Math.round(12 * appTheme.scale)
                                radius: Math.round(6 * appTheme.scale)
                                
                                x: widgetDrawer.expandedGroup === 2 ? (index * Math.round(155 * appTheme.scale) + Math.round(16 * appTheme.scale)) : (offset * Math.round(12 * appTheme.scale) + Math.round(10 * appTheme.scale))
                                y: widgetDrawer.expandedGroup === 2 ? Math.round(6 * appTheme.scale) : (offset * Math.round(6 * appTheme.scale) + Math.round(6 * appTheme.scale))
                                scale: widgetDrawer.expandedGroup === 2 ? 1.0 : (1.0 - (offset * 0.08))
                                opacity: { 
                                    if (widgetDrawer.expandedGroup === 2) return 1.0; 
                                    if (widgetDrawer.expandedGroup === -1) return (1.0 - (offset * 0.25)); 
                                    return 0.0; 
                                }
                                
                                color: systemDrag.containsMouse ? appTheme.elementBg : Qt.alpha(appTheme.bg, 0.4)
                                border.color: systemDrag.containsMouse ? appTheme.accent : appTheme.borderSubtle
                                border.width: systemDrag.containsMouse ? 1.5 : 1
                                z: 10 - offset

                                Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                                Loader { 
                                    anchors.fill: parent
                                    anchors.margins: Math.round(10 * appTheme.scale)
                                    clip: true
                                    sourceComponent: {
                                        if (model.type === "Auth") return authCompPreview;
                                        return sysCompPreview;
                                    }
                                }
                                
                                Component { 
                                    id: sysCompPreview
                                    SystemScene { variant: model.variant } 
                                }
                                
                                Component { 
                                    id: authCompPreview
                                    AuthScene { 
                                        variant: model.variant 
                                        authPlaceholderText: "ENTER PASSWORD"
                                        authEchoChar: "•"
                                        authShowBorder: true
                                        isTransparent: false
                                    } 
                                }
                                
                                Drag.dragType: Drag.Automatic
                                Drag.mimeData: { "text/plain": model.type + ":" + model.variant }
                                Drag.onDragFinished: { systemCard.Drag.active = false; }

                                MouseArea { 
                                    id: systemDrag
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    
                                    property int pressX: 0
                                    property int pressY: 0
                                    
                                    onPressed: (mouse) => { 
                                        pressX = mouse.x; 
                                        pressY = mouse.y 
                                    }
                                    
                                    onPositionChanged: (mouse) => { 
                                        if (pressed && (widgetDrawer.expandedGroup === 2 || widgetDrawer.expandedGroup === -1)) { 
                                            let dx = mouse.x - pressX; 
                                            let dy = mouse.y - pressY; 
                                            if (Math.abs(dx) > 10 || Math.abs(dy) > 10) { 
                                                if (!systemCard.Drag.active) {
                                                    systemCard.Drag.active = true; 
                                                }
                                            } 
                                        } 
                                    }
                                    
                                    onReleased: { systemCard.Drag.active = false; }
                                    
                                    onClicked: { 
                                        if (widgetDrawer.expandedGroup === -1) widgetDrawer.expandedGroup = 2; 
                                    }
                                }
                            }
                        }
                    }

                    // Group Box D: Media
                    Rectangle {
                        id: mediaGroupContainer
                        width: widgetDrawer.expandedGroup === 3 ? parent.width : Math.round(160 * appTheme.scale)
                        height: parent.height
                        y: 0
                        x: { 
                            if (widgetDrawer.expandedGroup === 3) return 0; 
                            if (widgetDrawer.expandedGroup === -1) return Math.round(520 * appTheme.scale); 
                            return parent.width + Math.round(200 * appTheme.scale); 
                        }
                        color: "transparent"
                        border.color: appTheme.accentDimmed
                        border.width: widgetDrawer.expandedGroup === 3 ? 0 : 1
                        radius: Math.round(6 * appTheme.scale)
                        visible: widgetDrawer.expandedGroup === -1 || widgetDrawer.expandedGroup === 3
                        
                        Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                        Repeater {
                            model: mediaGroupModel
                            delegate: Rectangle {
                                id: mediaCard
                                property int offset: index 
                                width: Math.round(140 * appTheme.scale)
                                height: mediaGroupContainer.height - Math.round(12 * appTheme.scale)
                                radius: Math.round(6 * appTheme.scale)
                                
                                x: widgetDrawer.expandedGroup === 3 ? (index * Math.round(155 * appTheme.scale) + Math.round(16 * appTheme.scale)) : (offset * Math.round(12 * appTheme.scale) + Math.round(10 * appTheme.scale))
                                y: widgetDrawer.expandedGroup === 3 ? Math.round(6 * appTheme.scale) : (offset * Math.round(6 * appTheme.scale) + Math.round(6 * appTheme.scale))
                                scale: widgetDrawer.expandedGroup === 3 ? 1.0 : (1.0 - (offset * 0.08))
                                opacity: { 
                                    if (widgetDrawer.expandedGroup === 3) return 1.0; 
                                    if (widgetDrawer.expandedGroup === -1) return (1.0 - (offset * 0.25)); 
                                    return 0.0; 
                                }
                                
                                color: mediaDrag.containsMouse ? appTheme.elementBg : Qt.alpha(appTheme.bg, 0.4)
                                border.color: mediaDrag.containsMouse ? appTheme.accent : appTheme.borderSubtle
                                border.width: mediaDrag.containsMouse ? 1.5 : 1
                                z: 10 - offset

                                Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } } 
                                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                                Loader { 
                                    anchors.fill: parent
                                    anchors.margins: Math.round(10 * appTheme.scale)
                                    clip: true
                                    sourceComponent: Component { MediaScene { variant: model.variant } } 
                                }
                                
                                Drag.dragType: Drag.Automatic
                                Drag.mimeData: { "text/plain": "Media:" + model.variant }
                                Drag.onDragFinished: { mediaCard.Drag.active = false; }

                                MouseArea { 
                                    id: mediaDrag
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    
                                    property int pressX: 0
                                    property int pressY: 0
                                    
                                    onPressed: (mouse) => { 
                                        pressX = mouse.x; 
                                        pressY = mouse.y 
                                    }
                                    
                                    onPositionChanged: (mouse) => { 
                                        if (pressed && (widgetDrawer.expandedGroup === 3 || widgetDrawer.expandedGroup === -1)) { 
                                            let dx = mouse.x - pressX; 
                                            let dy = mouse.y - pressY; 
                                            if (Math.abs(dx) > 10 || Math.abs(dy) > 10) { 
                                                if (!mediaCard.Drag.active) {
                                                    mediaCard.Drag.active = true; 
                                                }
                                            } 
                                        } 
                                    }
                                    
                                    onReleased: { mediaCard.Drag.active = false; }
                                    
                                    onClicked: { 
                                        if (widgetDrawer.expandedGroup === -1) widgetDrawer.expandedGroup = 3; 
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // VIEW 2: EDITOR
            Item {
                id: editorView
                anchors.fill: parent
                visible: widgetDrawer.selectedIndex !== -1
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Item {
                    id: editorHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.round(32 * appTheme.scale)
                    
                    Rectangle {
                        id: backBtnAreaContainer
                        width: Math.round(32 * appTheme.scale)
                        height: Math.round(32 * appTheme.scale)
                        radius: Math.round(16 * appTheme.scale)
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: backBtnArea.containsMouse ? appTheme.accent : Qt.rgba(255, 255, 255, 0.08)
                        border.color: Qt.rgba(255, 255, 255, 0.1)
                        border.width: 1
                        
                        Behavior on color { ColorAnimation { duration: 120 } }
                        
                        Canvas { 
                            id: backEditorArrow
                            anchors.centerIn: parent
                            width: Math.round(12 * appTheme.scale)
                            height: Math.round(12 * appTheme.scale)
                            antialiasing: true
                            onPaint: { 
                                var ctx = getContext("2d"); 
                                ctx.clearRect(0, 0, width, height); 
                                ctx.strokeStyle = backBtnArea.containsMouse ? appTheme.bg : appTheme.textPrimary; 
                                ctx.lineWidth = Math.max(2, 2 * appTheme.scale); 
                                ctx.lineCap = "round"; 
                                ctx.lineJoin = "round"; 
                                ctx.beginPath(); 
                                ctx.moveTo(width * 0.5, height * 0.15); 
                                ctx.lineTo(width * 0.15, height * 0.5); 
                                ctx.lineTo(width * 0.5, height * 0.85); 
                                ctx.moveTo(width * 0.15, height * 0.5); 
                                ctx.lineTo(width * 0.85, height * 0.5); 
                                ctx.stroke(); 
                            }
                            Connections { 
                                target: backBtnArea
                                function onContainsMouseChanged() { backEditorArrow.requestPaint(); } 
                            }
                        }
                        
                        MouseArea { 
                            id: backBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { 
                                if (wallpaperBackend) wallpaperBackend.selectedWidgetIndex = -1; 
                            } 
                        }
                    }
                    
                    Text { 
                        text: widgetDrawer.activeWidgetData ? widgetDrawer.activeWidgetData.type.toUpperCase() + " PROPERTIES" : "WIDGET PROPERTIES"
                        color: appTheme.accent
                        font.family: "Inter"
                        font.pointSize: 10 * appTheme.scale
                        font.bold: true
                        font.letterSpacing: 1.0
                        anchors.centerIn: parent 
                    }
                }

                Item {
                    id: editorContent
                    anchors.top: editorHeader.bottom
                    anchors.topMargin: Math.round(10 * appTheme.scale)
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right

                    ScrollView {
                        id: editorLeftCol
                        width: parent.width * 0.55
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        
                        Loader { 
                            width: editorLeftCol.width - Math.round(24 * appTheme.scale)
                            height: item ? item.implicitHeight : 0
                            sourceComponent: widgetHelper.item ? widgetHelper.item.configComponent : null
                            property var widgetData: widgetDrawer.activeWidgetData
                            property int widgetIndex: widgetDrawer.selectedIndex 
                        }
                    }

                    Loader {
                        id: widgetHelper
                        active: widgetDrawer.activeWidgetData !== null
                        source: { 
                            if (!widgetDrawer.activeWidgetData) return ""; 
                            let type = widgetDrawer.activeWidgetData.type; 
                            if (type === "Label") return "qrc:/ui/scenes/TextScene.qml"; 
                            if (type === "Auth") return "qrc:/ui/scenes/AuthScene.qml"; 
                            return "qrc:/ui/scenes/" + type + "Scene.qml"; 
                        }
                        visible: false
                    }

                    Connections {
                        target: widgetHelper.item
                        ignoreUnknownSignals: true
                        function onPropertyChanged(name, value) { 
                            if (widgetDrawer.selectedIndex !== -1 && widgetDrawer.activeWidgets) { 
                                widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, name, value); 
                                widgetDrawer.dummyTrigger++;
                            } 
                        }
                    }

                    Rectangle {
                        id: editorRightCol
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: editorLeftCol.right
                        anchors.leftMargin: Math.round(16 * appTheme.scale)
                        anchors.right: parent.right
                        color: "transparent"
                        border.color: appTheme.accent
                        border.width: 1
                        radius: Math.round(6 * appTheme.scale)

                        Item {
                            id: deckContainer
                            anchors.fill: parent
                            property int currentVariant: widgetDrawer.activeWidgetData ? widgetDrawer.activeWidgetData.variant : 0
                            property int totalVariants: (widgetDrawer.activeWidgetData && (widgetDrawer.activeWidgetData.type === "Clock" || widgetDrawer.activeWidgetData.type === "System" || widgetDrawer.activeWidgetData.type === "Media" || widgetDrawer.activeWidgetData.type === "Auth")) ? (widgetDrawer.activeWidgetData.type === "Clock" ? 3 : 2) : 1

                            Repeater {
                                model: deckContainer.totalVariants
                                delegate: Rectangle {
                                    property int offset: (index - deckContainer.currentVariant + deckContainer.totalVariants) % deckContainer.totalVariants
                                    
                                    width: Math.round(220 * appTheme.scale)
                                    height: Math.round(110 * appTheme.scale)
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: offset * Math.round(8 * appTheme.scale)
                                    anchors.horizontalCenterOffset: offset * Math.round(14 * appTheme.scale)
                                    z: 10 - offset
                                    scale: 1.0 - (offset * 0.08)
                                    opacity: 1.0 - (offset * 0.3) 
                                    
                                    color: appTheme.bg
                                    border.color: offset === 0 ? appTheme.accent : appTheme.borderSubtle
                                    border.width: offset === 0 ? 2 : 1
                                    radius: Math.round(6 * appTheme.scale)
                                    clip: true
                                    
                                    Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack } } 
                                    Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack } } 
                                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } } 
                                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

                                    Loader {
                                        anchors.fill: parent
                                        anchors.margins: Math.round(12 * appTheme.scale)
                                        
                                        sourceComponent: { 
                                            if (widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.type === "Label") return labelComp; 
                                            if (widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.type === "System") return systemComp; 
                                            if (widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.type === "Media") return mediaComp; 
                                            if (widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.type === "Auth") return authComp; 
                                            return clockComp; 
                                        }
                                        
                                        Component { 
                                            id: clockComp
                                            ClockScene { 
                                                variant: index
                                                customFontSize: 22
                                                customFontFamily: widgetDrawer.activeWidgetData ? widgetDrawer.activeWidgetData.fontFamily : "system-ui"
                                                customDateFontFamily: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.dateFontFamily !== undefined ? widgetDrawer.activeWidgetData.dateFontFamily : "system-ui:600"
                                                is24h: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.is24h !== undefined ? widgetDrawer.activeWidgetData.is24h : true
                                                timeOpacity: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.timeOpacity !== undefined ? widgetDrawer.activeWidgetData.timeOpacity : 1.0
                                                dateOpacity: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.dateOpacity !== undefined ? widgetDrawer.activeWidgetData.dateOpacity : 0.7
                                                timeColorIndex: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.timeColorIndex !== undefined ? widgetDrawer.activeWidgetData.timeColorIndex : 8
                                                dateColorIndex: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.dateColorIndex !== undefined ? widgetDrawer.activeWidgetData.dateColorIndex : 5
                                                dateSpacing: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.dateSpacing !== undefined ? widgetDrawer.activeWidgetData.dateSpacing : 4
                                            } 
                                        }
                                        
                                        Component { 
                                            id: labelComp
                                            TextScene { 
                                                labelText: widgetDrawer.activeWidgetData ? widgetDrawer.activeWidgetData.text : "" 
                                            } 
                                        }
                                        
                                        Component { 
                                            id: systemComp
                                            SystemScene { 
                                                variant: index 
                                                showTemp: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.showTemp !== undefined ? widgetDrawer.activeWidgetData.showTemp : true
                                            } 
                                        }
                                        
                                        Component { 
                                            id: mediaComp
                                            MediaScene { variant: index } 
                                        }
                                        
                                        Component { 
                                            id: authComp
                                            AuthScene { 
                                                variant: index 
                                                authPlaceholderText: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.text !== undefined ? widgetDrawer.activeWidgetData.text : "ENTER PASSWORD"
                                                authEchoChar: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.echoChar !== undefined ? widgetDrawer.activeWidgetData.echoChar : "•"
                                                authShowBorder: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.showFocusBorder !== undefined ? widgetDrawer.activeWidgetData.showFocusBorder : true
                                                isTransparent: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.transparent !== undefined ? widgetDrawer.activeWidgetData.transparent : false
                                            } 
                                        }
                                    }
                                }
                            }
                            
                            MouseArea { 
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { 
                                    if (widgetDrawer.selectedIndex !== -1 && deckContainer.totalVariants > 1 && widgetDrawer.activeWidgets) { 
                                        let nextVar = (deckContainer.currentVariant + 1) % deckContainer.totalVariants; 
                                        widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "variant", nextVar); 
                                    } 
                                } 
                            }
                        }
                        
                        Rectangle { 
                            anchors.fill: parent
                            color: "transparent"
                            border.color: appTheme.accent
                            border.width: 1
                            radius: Math.round(6 * appTheme.scale)
                            z: 100 
                        }
                    }
                }
            }
        }
    }

    // THE FLUSHED, SEAMLESS PULL TAB
    Item {
        id: pullTab
        visible: widgetDrawer.active
        width: Math.round(140 * appTheme.scale)
        height: Math.round(26 * appTheme.scale)
        
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(0, drawerBackground.y + drawerBackground.height - 1)
        
        Canvas {
            anchors.fill: parent
            antialiasing: true
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = appTheme.bg;
                
                var w = width;
                var h = height;
                var c = Math.round(20 * appTheme.scale); // Curve intensity offset
                
                ctx.beginPath();
                ctx.moveTo(0, 0);
                
                // Smooth curve left-to-bottom
                ctx.bezierCurveTo(c, 0, c, h, c * 2, h);
                
                // Bottom flat line
                ctx.lineTo(w - (c * 2), h);
                
                // Smooth curve right-to-top
                ctx.bezierCurveTo(w - c, h, w - c, 0, w, 0);
                
                ctx.closePath();
                ctx.fill();
            }
            
            Connections {
                target: appTheme
                function onBgChanged() { parent.requestPaint(); }
            }
        }
        
        // Grabber dots inside the tab
        Row { 
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Math.round(-3 * appTheme.scale) // visually center inside the curved bounds
            spacing: Math.round(6 * appTheme.scale)
            
            Repeater {
                model: 3
                Rectangle { 
                    width: Math.round(6 * appTheme.scale)
                    height: Math.round(6 * appTheme.scale)
                    radius: Math.round(3 * appTheme.scale)
                    color: appTheme.textSecondary
                    opacity: 0.6
                }
            }
        }
        
        MouseArea { 
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: widgetDrawer.userCollapsed = !widgetDrawer.userCollapsed 
        }
    }

    ListModel { 
        id: clockGroupModel
        Component.onCompleted: { 
            append({ "name": "Minimal", "type": "Clock", "variant": 0 }); 
            append({ "name": "Date & Time", "type": "Clock", "variant": 1 }); 
            append({ "name": "Stacked", "type": "Clock", "variant": 2 }); 
        } 
    }
    
    ListModel { 
        id: textGroupModel
        Component.onCompleted: { 
            append({ "name": "Typography", "type": "Label", "variant": 0 }); 
        } 
    }
    
    ListModel { 
        id: systemGroupModel
        Component.onCompleted: { 
            append({ "name": "Concentric Rings", "type": "System", "variant": 0 }); 
            append({ "name": "Linear Bars", "type": "System", "variant": 1 }); 
            append({ "name": "Auth Prompt", "type": "Auth", "variant": 0 }); 
        } 
    }
    
    ListModel { 
        id: mediaGroupModel
        Component.onCompleted: { 
            append({ "name": "Compact Controller", "type": "Media", "variant": 0 }); 
            append({ "name": "Backdrop Blur Controller", "type": "Media", "variant": 1 }); 
        } 
    }
}