import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root
    width: parent ? parent.width : 320
    height: parent ? parent.height : 160

    AppTheme { id: appTheme }

    property int variant: 0

    property string titleString: (typeof wallpaperBackend !== "undefined" && wallpaperBackend && wallpaperBackend.mediaTitle !== "") ? wallpaperBackend.mediaTitle : "Nothing Playing"
    property string artistString: (typeof wallpaperBackend !== "undefined" && wallpaperBackend && wallpaperBackend.mediaArtist !== "") ? wallpaperBackend.mediaArtist : "No active audio player found"
    property string artSource: (typeof wallpaperBackend !== "undefined" && wallpaperBackend && wallpaperBackend.mediaArt !== "") ? wallpaperBackend.mediaArt : ""
    property string status: (typeof wallpaperBackend !== "undefined" && wallpaperBackend) ? wallpaperBackend.mediaPlaybackStatus : "Stopped"

    // Real-time grid-height tracker to switch layout models dynamically
    property bool isSingleRow: height <= Math.round(96 * appTheme.scale)

    // High-DPI anti-aliased vector media icons
    Component {
        id: vectorButton
        Item {
            id: btnRoot
            property string iconType: "play" // "play", "pause", "next", "prev"
            property color iconColor: "#FFFFFF"
            property real size: 14

            width: size
            height: size

            Canvas {
                id: iconCanvas
                anchors.fill: parent
                antialiasing: true
                
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = btnRoot.iconColor;
                    ctx.beginPath();

                    var w = width;
                    var h = height;

                    if (btnRoot.iconType === "play") {
                        ctx.moveTo(w * 0.25, h * 0.15);
                        ctx.lineTo(w * 0.25, h * 0.82);
                        ctx.lineTo(w * 0.85, h * 0.5);
                        ctx.closePath();
                        ctx.fill();
                    } else if (btnRoot.iconType === "pause") {
                        ctx.rect(w * 0.22, h * 0.18, w * 0.18, h * 0.64);
                        ctx.rect(w * 0.60, h * 0.18, w * 0.18, h * 0.64);
                        ctx.fill();
                    } else if (btnRoot.iconType === "next") {
                        ctx.moveTo(w * 0.15, h * 0.18);
                        ctx.lineTo(w * 0.15, h * 0.82);
                        ctx.lineTo(w * 0.62, h * 0.5);
                        ctx.closePath();
                        ctx.fill();
                        
                        ctx.beginPath();
                        ctx.rect(w * 0.70, h * 0.18, w * 0.15, h * 0.64);
                        ctx.fill();
                    } else if (btnRoot.iconType === "prev") {
                        ctx.rect(w * 0.15, h * 0.18, w * 0.15, h * 0.64);
                        ctx.fill();
                        
                        ctx.beginPath();
                        ctx.moveTo(w * 0.85, h * 0.18);
                        ctx.lineTo(w * 0.85, h * 0.82);
                        ctx.lineTo(w * 0.38, h * 0.5);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
                
                Connections {
                    target: btnRoot
                    function onIconColorChanged() { iconCanvas.requestPaint(); }
                    function onIconTypeChanged() { iconCanvas.requestPaint(); }
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: {
            if (root.isSingleRow) return singleRowLayout;
            if (variant === 0) return compactLayout;
            return backgroundCoverLayout;
        }
    }

    // =========================================================================
    // LAYOUT 1: SINGLE-ROW DYNAMIC BAR PLAYER
    // =========================================================================
    Component {
        id: singleRowLayout
        Item {
            anchors.fill: parent

            Row {
                anchors.fill: parent
                anchors.margins: Math.round(8 * appTheme.scale)
                spacing: Math.round(12 * appTheme.scale)

                // Tiny Cover Art Thumbnail
                Rectangle {
                    id: tinyArtFrame
                    width: parent.height
                    height: parent.height
                    radius: 6
                    color: Qt.rgba(1,1,1,0.06)
                    clip: true
                    border.width: 1
                    border.color: Qt.rgba(255,255,255,0.08)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: root.artSource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        visible: root.artSource === ""
                        Text {
                            text: "🎵"
                            font.pointSize: 10 * appTheme.scale
                            anchors.centerIn: parent
                            opacity: 0.25
                        }
                    }
                }

                // Inline, Non-overlapping Metadata Block
                Column {
                    width: parent.width - tinyArtFrame.width - controlsRow.width - Math.round(36 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    clip: true

                    Text {
                        width: parent.width
                        text: root.titleString
                        color: appTheme.textPrimary
                        font.family: "Lexend"
                        font.pointSize: 9.5
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.artistString
                        color: appTheme.textSecondary
                        font.family: "Lexend"
                        font.pointSize: 8
                        elide: Text.ElideRight
                    }
                }

                // Compact Horizontal Controls Row
                Row {
                    id: controlsRow
                    spacing: Math.round(8 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter

                    // Prev Button
                    Rectangle {
                        width: 24; height: 24; radius: 12; color: prevMouse.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                        Loader {
                            anchors.centerIn: parent
                            sourceComponent: vectorButton
                            onLoaded: {
                                item.iconType = "prev";
                                item.iconColor = appTheme.textPrimary;
                                item.size = 9 * appTheme.scale;
                            }
                        }
                        MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (wallpaperBackend) wallpaperBackend.mediaPrev() }
                    }

                    // Play / Pause Button
                    Rectangle {
                        width: 28; height: 28; radius: 14; color: appTheme.accent
                        scale: playMouse.containsMouse ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        
                        Loader {
                            anchors.centerIn: parent
                            sourceComponent: vectorButton
                            property string trackStatus: root.status
                            onTrackStatusChanged: {
                                if (item) item.iconType = (root.status === "Playing") ? "pause" : "play";
                            }
                            onLoaded: {
                                item.iconType = (root.status === "Playing") ? "pause" : "play";
                                item.iconColor = appTheme.bg;
                                item.size = 10 * appTheme.scale;
                            }
                        }
                        MouseArea { id: playMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (wallpaperBackend) wallpaperBackend.mediaPlayPause() }
                    }

                    // Next Button
                    Rectangle {
                        width: 24; height: 24; radius: 12; color: nextMouse.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                        Loader {
                            anchors.centerIn: parent
                            sourceComponent: vectorButton
                            onLoaded: {
                                item.iconType = "next";
                                item.iconColor = appTheme.textPrimary;
                                item.size = 9 * appTheme.scale;
                            }
                        }
                        MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (wallpaperBackend) wallpaperBackend.mediaNext() }
                    }
                }
            }
        }
    }

    // =========================================================================
    // LAYOUT 2: STANDARD STACKED COMPACT PLAYER (>= 2 ROWS)
    // =========================================================================
    Component {
        id: compactLayout
        Item {
            anchors.fill: parent

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                Rectangle {
                    id: thumbnailCoverFrame
                    width: parent.height
                    height: parent.height
                    radius: 8
                    color: Qt.rgba(1,1,1,0.06)
                    clip: true
                    border.width: 1
                    border.color: Qt.rgba(255,255,255,0.08)

                    Image {
                        id: coverImg
                        anchors.fill: parent
                        source: root.artSource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: root.artSource !== ""
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        visible: root.artSource === ""
                        Text {
                            text: "🎵"
                            font.pointSize: 22 * appTheme.scale
                            anchors.centerIn: parent
                            opacity: 0.25
                        }
                    }
                }

                Column {
                    width: parent.width - thumbnailCoverFrame.width - 16
                    height: parent.height
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Column {
                        width: parent.width
                        spacing: 2
                        
                        Text {
                            width: parent.width
                            text: root.titleString
                            color: appTheme.textPrimary
                            font.family: "Lexend"
                            font.pointSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.artistString
                            color: appTheme.textSecondary
                            font.family: "Lexend"
                            font.pointSize: 9
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        spacing: 14
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 28; height: 28; radius: 14; color: prevMouse0.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                            Loader {
                                anchors.centerIn: parent
                                sourceComponent: vectorButton
                                onLoaded: {
                                    item.iconType = "prev";
                                    item.iconColor = appTheme.textPrimary;
                                    item.size = 11 * appTheme.scale;
                                }
                            }
                            MouseArea { id: prevMouse0; anchors.fill: parent; hoverEnabled: true; onClicked: if (wallpaperBackend) wallpaperBackend.mediaPrev() }
                        }

                        Rectangle {
                            width: 34; height: 34; radius: 17; color: appTheme.accent
                            scale: playMouse0.containsMouse ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Loader {
                                anchors.centerIn: parent
                                sourceComponent: vectorButton
                                property string trackStatus: root.status
                                onTrackStatusChanged: {
                                    if (item) item.iconType = (root.status === "Playing") ? "pause" : "play";
                                }
                                onLoaded: {
                                    item.iconType = (root.status === "Playing") ? "pause" : "play";
                                    item.iconColor = appTheme.bg;
                                    item.size = 12 * appTheme.scale;
                                }
                            }
                            MouseArea { id: playMouse0; anchors.fill: parent; hoverEnabled: true; onClicked: if (wallpaperBackend) wallpaperBackend.mediaPlayPause() }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 14; color: nextMouse0.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                            Loader {
                                anchors.centerIn: parent
                                sourceComponent: vectorButton
                                onLoaded: {
                                    item.iconType = "next";
                                    item.iconColor = appTheme.textPrimary;
                                    item.size = 11 * appTheme.scale;
                                }
                            }
                            MouseArea { id: nextMouse0; anchors.fill: parent; hoverEnabled: true; onClicked: if (wallpaperBackend) wallpaperBackend.mediaNext() }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // LAYOUT 3: BACKDROP BLURRED COVER ART (>= 2 ROWS)
    // =========================================================================
    Component {
        id: backgroundCoverLayout
        Item {
            anchors.fill: parent
            clip: true

            Image {
                id: bgArtBlur
                anchors.fill: parent
                source: root.artSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: bgArtBlur
                blurEnabled: root.artSource !== ""
                blur: 0.8
                brightness: -0.35
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.45)
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    width: parent.width
                    spacing: 2
                    
                    Text {
                        width: parent.width
                        text: root.titleString
                        color: "#FFFFFF"
                        font.family: "Lexend"
                        font.pointSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.artistString
                        color: "#E6E6FA"
                        font.family: "Lexend"
                        font.pointSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }

                Row {
                    spacing: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 32; height: 32; radius: 16; color: Qt.rgba(255,255,255,0.15)
                        Loader {
                            anchors.centerIn: parent
                            sourceComponent: vectorButton
                            onLoaded: {
                                item.iconType = "prev";
                                item.iconColor = "#FFFFFF";
                                item.size = 11 * appTheme.scale;
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: if (wallpaperBackend) wallpaperBackend.mediaPrev() }
                    }

                    Rectangle {
                        width: 38; height: 38; radius: 19; color: "#FFFFFF"
                        Loader {
                            anchors.centerIn: parent
                            sourceComponent: vectorButton
                            property string trackStatus: root.status
                            onTrackStatusChanged: {
                                if (item) item.iconType = (root.status === "Playing") ? "pause" : "play";
                            }
                            onLoaded: {
                                item.iconType = (root.status === "Playing") ? "pause" : "play";
                                item.iconColor = "#111116";
                                item.size = 13 * appTheme.scale;
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: if (wallpaperBackend) wallpaperBackend.mediaPlayPause() }
                    }

                    Rectangle {
                        width: 32; height: 32; radius: 16; color: Qt.rgba(255,255,255,0.15)
                        Loader {
                            anchors.centerIn: parent
                            sourceComponent: vectorButton
                            onLoaded: {
                                item.iconType = "next";
                                item.iconColor = "#FFFFFF";
                                item.size = 11 * appTheme.scale;
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: if (wallpaperBackend) wallpaperBackend.mediaNext() }
                    }
                }
            }
        }
    }

    property Component configComponent: Component {
        Column {
            spacing: 12
            width: parent ? parent.width : 200

            Text {
                text: "MEDIA CONTROLLER PROPERTIES"
                color: "#A6E3A1"
                font.family: "Lexend"
                font.pointSize: 10
                font.bold: true
            }

            Text {
                text: "Active Track:"
                color: appTheme.textSecondary
                font.pointSize: 9
            }
            Text {
                text: root.titleString + " - " + root.artistString
                color: appTheme.textPrimary
                font.pointSize: 8
                font.bold: true
                wrapMode: Text.Wrap
                width: parent.width - 20
            }
        }
    }
}