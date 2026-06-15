import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Luminate.Shell

Item {
    id: pickerRoot
    clip: true
    focus: Backend.displayMode === "wallpaper"

    function getCleanName(path) {
        if (!path) return "";
        let parts = path.split('/');
        let filename = parts[parts.length - 1];
        let dotIdx = filename.lastIndexOf('.');
        if (dotIdx !== -1) {
            filename = filename.substring(0, dotIdx);
        }
        filename = filename.replace(/[-_]/g, ' ');
        return filename.replace(/\b\w/g, c => c.toUpperCase());
    }

    property bool isProgrammaticIndexChange: false

    onVisibleChanged: {
        if (visible && Backend.wallpaperList.length > 0) {
            let idx = Backend.wallpaperList.indexOf(Backend.confirmedWallpaper);
            if (idx !== -1) {
                isProgrammaticIndexChange = true;
                
                // Jump directly to the center of our massive "infinite" track
                let midOffset = Math.floor(wallpaperList.loopMultiplier / 2) * wallpaperList.realCount;
                wallpaperList.currentIndex = midOffset + idx;
                
                // Force an instant layout update without animating the jump
                wallpaperList.positionViewAtIndex(wallpaperList.currentIndex, ListView.Center);
                
                isProgrammaticIndexChange = false;
            }
            pickerRoot.forceActiveFocus();
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left) {
            wallpaperList.decrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            wallpaperList.incrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            Backend.cancelWallpaper();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            Backend.commitWallpaper();
            event.accepted = true;
        }
    }

    // =====================================
    // GRADIENT MASK FOR THE EDGES
    // =====================================
    LinearGradient {
        id: listFadeMask
        width: wallpaperList.width
        height: wallpaperList.height
        start: Qt.point(0, 0)
        end: Qt.point(width, 0)
        gradient: Gradient {
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.15; color: "black" }
            GradientStop { position: 0.85; color: "black" }
            GradientStop { position: 1.00; color: "transparent" }
        }
        visible: false
    }

    // =====================================
    // HORIZONTAL PICKER LIST (Infinite)
    // =====================================
    ListView {
        id: wallpaperList
        anchors.fill: parent
        anchors.topMargin: 40 
        anchors.bottomMargin: 16
        z: 1

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: listFadeMask
        }

        orientation: ListView.Horizontal
        
        property int realCount: Backend.wallpaperList.length
        property int loopMultiplier: 10000 
        
        model: realCount > 0 ? (realCount * loopMultiplier) : 0
        
        spacing: 24
        snapMode: ListView.SnapToItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: width / 2 - 80 
        preferredHighlightEnd: width / 2 + 80
        
        highlightMoveDuration: 250
        
        delegate: Item {
            id: delegateRoot
            width: 160
            height: wallpaperList.height 
            
            property int actualIndex: index % wallpaperList.realCount
            property string modelData: Backend.wallpaperList[actualIndex] || ""
            
            property bool isCurrent: ListView.isCurrentItem
            property bool isConfirmed: modelData === Backend.confirmedWallpaper

            property real viewContentX: ListView.view ? ListView.view.contentX : 0
            property real viewWidth: ListView.view ? ListView.view.width : 1
            
            property real itemCenterX: x + width / 2 - viewContentX
            property real viewCenterX: viewWidth / 2
            property real dist: Math.abs(itemCenterX - viewCenterX)
            property real normalizedDist: Math.min(1.0, dist / (viewWidth / 1.8))

            scale: 1.15 - (Math.pow(normalizedDist, 2) * 0.3)
            opacity: 1.0 - Math.pow(normalizedDist, 1.8)
            z: 100 - dist

            Rectangle {
                id: cardRect
                width: 160
                height: 90
                anchors.centerIn: parent
                
                // Pushes the side-items smoothly downwards
                anchors.verticalCenterOffset: Math.pow(delegateRoot.normalizedDist, 1.5) * 30
                
                radius: 12
                color: "#111116"

                Image {
                    id: wpImage
                    anchors.fill: parent
                    anchors.margins: cardRect.border.width 
                    source: modelData !== "" ? "file://" + modelData : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false 
                }
                
                Rectangle {
                    id: maskShape
                    anchors.fill: wpImage
                    radius: 12 - cardRect.border.width
                    color: "black"
                    visible: false
                }
                
                OpacityMask {
                    anchors.fill: wpImage
                    source: wpImage
                    maskSource: maskShape
                }
                
                // Overlay Border
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: 12
                    border.color: isCurrent ? AppTheme.accent : (isConfirmed ? Qt.rgba(AppTheme.accent.r, AppTheme.accent.g, AppTheme.accent.b, 0.4) : Qt.rgba(1,1,1,0.1))
                    border.width: isCurrent ? 3 : (isConfirmed ? 2 : 1)
                    
                    Behavior on border.color { ColorAnimation { duration: 250; easing.type: Easing.OutQuad } }
                    Behavior on border.width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                }

                // Confirmed wallpaper marker
                Rectangle {
                    visible: isConfirmed
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    width: 20; height: 20; radius: 10
                    color: AppTheme.accent
                    
                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        font.family: AppTheme.mainFont
                        font.bold: true
                        font.pixelSize: 10
                        color: AppTheme.bg
                    }
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    wallpaperList.currentIndex = index;
                    Backend.selectWallpaper(modelData);
                }
            }
        }
        
        onCurrentIndexChanged: {
            if (pickerRoot.visible && !pickerRoot.isProgrammaticIndexChange && realCount > 0) {
                let actualIdx = currentIndex % realCount;
                let path = Backend.wallpaperList[actualIdx];
                if (path && path !== Backend.currentWallpaper) {
                    Backend.selectWallpaper(path);
                }
            }
        }
    }

    // =====================================
    // TOP LEFT: Preview HUD
    // =====================================
    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 14
        spacing: 4
        z: 10
        
        Row {
            spacing: 12
            Text {
                text: "PREVIEWING"
                color: AppTheme.accent
                font.family: AppTheme.mainFont
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.5
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: pickerRoot.getCleanName(Backend.currentWallpaper)
                color: AppTheme.fg
                font.family: AppTheme.mainFont
                font.pixelSize: 13
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // =====================================
    // TOP CENTER: "Clasped" Unified Color Bar
    // =====================================
    Item {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 14
        z: 10

        width: 140
        height: 20

        // 1. The Raw Content (Oversized, rotated rectangles)
        Item {
            id: paletteContent
            anchors.fill: parent
            visible: false // Hidden because it feeds the mask

            Row {
                anchors.centerIn: parent
                // Negative spacing clasps them tightly together, avoiding antialiasing gaps
                spacing: -4 
                
                Repeater {
                    model: (Backend.wallpaperPalette && Backend.wallpaperPalette.length > 1) ? Math.min(6, Backend.wallpaperPalette.length - 1) : 0
                    
                    Rectangle {
                        width: 28 
                        height: 40 // Taller than the container so corners bleed out to be masked
                        color: Backend.wallpaperPalette[index + 1] || "#ffffff"
                        rotation: 20
                        antialiasing: true
                    }
                }
            }
        }

        // 2. The Shape Mask (Perfect Pill)
        Rectangle {
            id: paletteMask
            anchors.fill: parent
            radius: 10 // Gives the whole bar rounded pill ends
            color: "black"
            visible: false
        }

        // 3. Apply the mask (Cuts off all the messy bleeding corners)
        OpacityMask {
            anchors.fill: parent
            source: paletteContent
            maskSource: paletteMask
        }

        // 4. Subtle unified border overlay
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Qt.rgba(255, 255, 255, 0.15)
            border.width: 1
            radius: 10
        }
    }

    // =====================================
    // TOP RIGHT: Instructions HUD
    // =====================================
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        spacing: 16
        z: 10

        Row {
            spacing: 6
            Rectangle {
                width: 42; height: 22; radius: 4
                color: AppTheme.actionBg
                border.color: AppTheme.actionBorder
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "Enter"
                    color: AppTheme.fg
                    font.family: AppTheme.mainFont
                    font.pixelSize: 10; font.bold: true
                }
            }
            Text {
                text: "Save"
                color: AppTheme.fg
                font.family: AppTheme.mainFont
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            spacing: 6
            Rectangle {
                width: 36; height: 22; radius: 4
                color: AppTheme.actionBg
                border.color: AppTheme.actionBorder
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "Esc"
                    color: AppTheme.fg
                    font.family: AppTheme.mainFont
                    font.pixelSize: 10; font.bold: true
                }
            }
            Text {
                text: "Cancel"
                color: AppTheme.fg
                font.family: AppTheme.mainFont
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}