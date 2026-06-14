import QtQuick

Item {
    id: root
    width: parent ? parent.width : 1920
    height: parent ? parent.height : 1080
    focus: true

    property bool isExiting: false
    property int lastIndex: -1
    property color accentColor: wallpaperBackend.wallpaperPalette.length > 3 ? wallpaperBackend.wallpaperPalette[3] : "#89B4FA"

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

    function getSpecs(path) {
        if (!path) return "";
        let parts = path.split('.');
        let ext = parts[parts.length - 1].toUpperCase();
        return wallpaperBackend.currentResolution + "  •  " + ext + "  •  SYSTEM CODES";
    }

    function confirmAndExit() {
        if (root.isExiting) return;
        root.isExiting = true;
        exitAnimation.start();
    }

    function cancelAndExit() {
        if (root.isExiting) return;
        root.isExiting = true;
        wallpaperBackend.currentWallpaper = wallpaperBackend.confirmedWallpaper;
        exitAnimation.start();
    }

    property int currentIndex: wallpaperBackend.wallpaperList.indexOf(wallpaperBackend.currentWallpaper)
    property int count: wallpaperBackend.wallpaperList.length

    onCurrentIndexChanged: {
        if (currentIndex >= 0 && currentIndex < count) {
            wallpaperBackend.currentWallpaper = wallpaperBackend.wallpaperList[currentIndex];
        }
    }

    // Navigation Hooks
    Keys.onUpPressed: if (!isExiting && currentIndex > 0) currentIndex--
    Keys.onDownPressed: if (!isExiting && currentIndex < count - 1) currentIndex++
    Keys.onEscapePressed: cancelAndExit()
    Keys.onReturnPressed: confirmAndExit()
    Keys.onSpacePressed: confirmAndExit()

    Timer {
        id: previewDebounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            let nextPath = "file://" + wallpaperBackend.currentWallpaper;
            titleText.displayedText = getCleanName(wallpaperBackend.currentWallpaper);
            specsPlacard.displayedSpecs = getSpecs(wallpaperBackend.currentWallpaper).replace(/•/g, "<font color='" + root.accentColor + "'>•</font>");

            if (nextPath === imgBufferA.source) return;

            let isDown = root.currentIndex > root.lastIndex;
            root.lastIndex = root.currentIndex;

            if (isDown) {
                imgBufferB.y = sliderContainer.height;
                imgBufferB.source = nextPath;
                slideDownAnimation.restart();
            } else {
                imgBufferB.y = -sliderContainer.height;
                imgBufferB.source = nextPath;
                slideUpAnimation.restart();
            }
        }
    }

    Connections {
        target: wallpaperBackend
        function onCurrentWallpaperChanged() {
            previewDebounceTimer.restart();
        }
    }

    ParallelAnimation {
        id: slideDownAnimation
        NumberAnimation { target: imgBufferA; property: "y"; to: -sliderContainer.height; duration: 250; easing.type: Easing.OutQuint }
        NumberAnimation { target: imgBufferB; property: "y"; to: 0; duration: 250; easing.type: Easing.OutQuint }
        onFinished: {
            imgBufferA.source = imgBufferB.source;
            imgBufferA.y = 0;
            imgBufferB.source = "";
        }
    }

    ParallelAnimation {
        id: slideUpAnimation
        NumberAnimation { target: imgBufferA; property: "y"; to: sliderContainer.height; duration: 250; easing.type: Easing.OutQuint }
        NumberAnimation { target: imgBufferB; property: "y"; to: 0; duration: 250; easing.type: Easing.OutQuint }
        onFinished: {
            imgBufferA.source = imgBufferB.source;
            imgBufferA.y = 0;
            imgBufferB.source = "";
        }
    }

    ParallelAnimation {
        id: entryAnimation
        NumberAnimation { target: backdrop; property: "opacity"; from: 0.0; to: 0.85; duration: 300 }
        NumberAnimation { target: rightColumn; property: "opacity"; from: 0.0; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
        NumberAnimation { target: rightTranslate; property: "x"; from: 60; to: 0; duration: 350; easing.type: Easing.OutQuint }
        NumberAnimation { target: galleryFrame; property: "opacity"; from: 0.0; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
    }

    ParallelAnimation {
        id: exitAnimation
        NumberAnimation { target: backdrop; property: "opacity"; to: 0.0; duration: 250 }
        NumberAnimation { target: rightColumn; property: "opacity"; to: 0.0; duration: 250 }
        NumberAnimation { target: rightTranslate; property: "x"; to: 40; duration: 250 }
        NumberAnimation { target: galleryFrame; property: "opacity"; to: 0.0; duration: 250 }
        onFinished: {
            wallpaperBackend.isPickingWallpaper = false;
        }
    }

    Component.onCompleted: {
        let idx = wallpaperBackend.wallpaperList.indexOf(wallpaperBackend.currentWallpaper);
        if (idx !== -1) {
            root.currentIndex = idx;
            root.lastIndex = idx;
        }
        imgBufferA.source = "file://" + wallpaperBackend.currentWallpaper;
        titleText.displayedText = getCleanName(wallpaperBackend.currentWallpaper);
        specsPlacard.displayedSpecs = getSpecs(wallpaperBackend.currentWallpaper).replace(/•/g, "<font color='" + root.accentColor + "'>•</font>");
        entryAnimation.start();
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#08080C"
        opacity: 0.0
    }

    // =========================================================================
    // THE MATTED PORTFOLIO DISPLAY (60% width)
    // =========================================================================
    Item {
        id: leftColumn
        width: parent.width * 0.55
        anchors.left: parent.left
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.leftMargin: 80; anchors.rightMargin: 40
        anchors.topMargin: 80; anchors.bottomMargin: 80

        Rectangle {
            id: galleryFrame
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(parent.width, parent.height * 1.6)
            height: width * 0.5625
            color: "#111116"
            border.color: root.accentColor
            border.width: 1
            radius: 20
            clip: true
            opacity: 0.0

            Item {
                id: sliderContainer
                anchors.fill: parent
                anchors.margins: 16
                clip: true

                Image {
                    id: imgBufferA
                    width: parent.width; height: parent.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Image {
                    id: imgBufferB
                    width: parent.width; height: parent.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: confirmAndExit()
            }
        }
    }

    // =========================================================================
    // EDITORIAL SPECS COLUMN (45% width)
    // =========================================================================
    Item {
        id: rightColumn
        width: parent.width * 0.45
        anchors.left: leftColumn.right
        anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.leftMargin: 40; anchors.rightMargin: 80
        anchors.topMargin: 80; anchors.bottomMargin: 80
        opacity: 0.0

        transform: Translate { id: rightTranslate; x: 0 }

        Item {
            id: infoStack
            width: parent.width
            height: indexIndicator.height + titleText.height + swatchesRow.height + specsPlacard.height + 100
            anchors.verticalCenter: parent.verticalCenter

            // 1. Monospace Position Index
            Text {
                id: indexIndicator
                text: "INDEX // " + String(root.currentIndex + 1).padStart(2, '0') + " OF " + String(root.count).padStart(2, '0')
                color: "#7F849C"
                font.family: "monospace"
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1.5
            }

            // 2. Beautiful Typography Display Header
            Text {
                id: titleText
                width: parent.width
                y: indexIndicator.height + 24
                
                property string displayedText: ""
                text: displayedText
                
                font.family: "Lexend"
                font.pixelSize: 42
                font.weight: Font.Light
                color: "#CDD6F4"
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft
            }

            // 3. System Swatches Row
            Row {
                id: swatchesRow
                y: titleText.y + titleText.height + 24
                spacing: 12

                Repeater {
                    model: wallpaperBackend.wallpaperPalette
                    delegate: Rectangle {
                        width: 14; height: 14; radius: 7
                        color: modelData
                        border.color: Qt.rgba(255, 255, 255, 0.1)
                        border.width: 1
                    }
                }
            }

            // 4. Tech Spec Tag
            Text {
                id: specsPlacard
                y: swatchesRow.y + swatchesRow.height + 24
                
                property string displayedSpecs: ""
                text: displayedSpecs
                
                textFormat: Text.RichText
                color: "#7F849C"
                font.family: "monospace"
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1.5
            }
        }
    }
}