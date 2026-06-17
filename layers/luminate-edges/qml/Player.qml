import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects 
import Luminate.Shell 

Item {
    id: playerRoot
    property bool isExpanded: false
    property int expandedImplicitHeight: expandedLayout.implicitHeight
    
    // THE FIX: Provide the exact width of the rendered text so LuminateEdge can snap to it
    property int pinnedContentWidth: pinnedLyricText.implicitWidth

    component SystemIcon: Button {
        property string iconName: ""
        property color iconColor: "white"
        property int size: 24
        width: size; height: size
        icon.name: iconName; icon.color: iconColor
        icon.width: size; icon.height: size
        background: Item {} 
        focusPolicy: Qt.NoFocus; hoverEnabled: false; down: false
    }

    function formatTime(seconds) {
        if (seconds <= 0) return "0:00";
        var m = Math.floor(seconds / 60);
        var s = seconds % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // =====================================
    // SIDE INFO VIEW (Lyrics / Title)
    // =====================================
    Item {
        anchors.fill: parent
        opacity: !playerRoot.isExpanded ? 1 : 0
        visible: opacity > 0
        clip: true 

        Item {
            id: pinnedLyricContainer
            anchors.fill: parent
            
            // THE FIX: Preserve the C++ binding independently of the UI texts
            property string currentText: Backend.mediaHasLyrics ? (Backend.mediaCurrentLyric !== "" ? Backend.mediaCurrentLyric : "\u266a") : Backend.mediaTitle
            
            property string displayedText: currentText
            property string outgoingText: ""
            
            onCurrentTextChanged: {
                if (playerRoot.isExpanded) {
                    displayedText = currentText;
                    return;
                }
                
                // Swap the strings logically so bindings aren't destroyed
                outgoingText = displayedText;
                oldLyricText.y = 0; 
                oldLyricText.opacity = 1;
                
                displayedText = currentText;
                pinnedLyricText.y = parent.height; 
                pinnedLyricText.opacity = 0;
                
                slideAnim.restart();
            }

            ParallelAnimation {
                id: slideAnim
                NumberAnimation { target: oldLyricText; property: "y"; to: -parent.height; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { target: oldLyricText; property: "opacity"; to: 0; duration: 300 }
                NumberAnimation { target: pinnedLyricText; property: "y"; to: 0; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { target: pinnedLyricText; property: "opacity"; to: 1; duration: 300 }
            }
            
            Text {
                id: oldLyricText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 800 - 64)
                text: pinnedLyricContainer.outgoingText
                color: AppTheme.fg 
                font.pixelSize: 16; font.bold: true; font.weight: 700; opacity: 1.0
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight; maximumLineCount: 1
            }
            
            Text {
                id: pinnedLyricText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 800 - 64)
                text: pinnedLyricContainer.displayedText
                color: AppTheme.fg
                font.pixelSize: 16; font.bold: true; font.weight: 700; opacity: 1.0
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight; maximumLineCount: 1
            }
        }
    }

    // =====================================
    // EXPANDED VIEW
    // =====================================
    ColumnLayout {
        id: expandedLayout
        anchors.centerIn: parent
        width: parent.width - 32
        spacing: 16
        opacity: playerRoot.isExpanded ? 1 : 0
        visible: opacity > 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Item {
                Layout.preferredWidth: 64; Layout.preferredHeight: 64
                Rectangle {
                    anchors.fill: parent; radius: 12; color: AppTheme.actionBg 
                    SystemIcon { anchors.centerIn: parent; iconName: "audio-x-generic-symbolic"; size: 32; iconColor: AppTheme.fg; visible: expandedImg.status !== Image.Ready }
                }
                Image { id: expandedImg; anchors.fill: parent; source: Backend.mediaArt; fillMode: Image.PreserveAspectCrop; visible: false }
                Rectangle { id: expandedMaskShape; anchors.fill: parent; radius: 12; visible: false }
                OpacityMask { anchors.fill: parent; source: expandedImg; maskSource: expandedMaskShape; visible: expandedImg.status === Image.Ready }
                Rectangle { anchors.fill: parent; radius: 12; color: "transparent"; border.color: AppTheme.actionBorder; border.width: 1 }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { 
                    text: Backend.mediaTitle !== "" ? Backend.mediaTitle : "No Media"
                    color: AppTheme.fg; font.pixelSize: 16; font.bold: true; font.weight: 700; opacity: 1.0; 
                    elide: Text.ElideRight; Layout.fillWidth: true 
                }
                Text { 
                    text: Backend.mediaArtist; 
                    color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.8) 
                    font.pixelSize: 13; font.bold: true; font.weight: 700; 
                    elide: Text.ElideRight; Layout.fillWidth: true 
                }
            }
            
            RowLayout {
                spacing: 12
                SystemIcon { 
                    iconName: "media-skip-backward-symbolic"; size: 24; iconColor: AppTheme.fg
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Backend.mediaPrev() } 
                }
                SystemIcon { 
                    iconName: Backend.mediaStatus === "Playing" ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                    size: 32; iconColor: AppTheme.fg
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Backend.mediaPlayPause() } 
                }
                SystemIcon { 
                    iconName: "media-skip-forward-symbolic"; size: 24; iconColor: AppTheme.fg
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Backend.mediaNext() } 
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text { text: formatTime(Backend.mediaPosition); color: AppTheme.fg; font.pixelSize: 12; font.bold: true; font.weight: 700; opacity: 1.0 }

            Rectangle {
                Layout.fillWidth: true
                height: 6; radius: 3
                color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.2)
                
                Rectangle {
                    width: Backend.mediaDuration > 0 ? Math.min(parent.width * (Backend.mediaPosition / Backend.mediaDuration), parent.width) : 0
                    height: parent.height; radius: 3
                    color: AppTheme.fg
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }
            }

            Text { text: formatTime(Backend.mediaDuration); color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.6); font.pixelSize: 12; font.bold: true; font.weight: 700; opacity: 1.0 }

            SystemIcon {
                iconName: "view-pin-symbolic"
                size: 20 
                iconColor: Backend.mediaPinned ? AppTheme.accent : Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.6)
                MouseArea { 
                    anchors.fill: parent; anchors.margins: -8 
                    cursorShape: Qt.PointingHandCursor; 
                    onClicked: {
                        Backend.setMediaPinned(!Backend.mediaPinned);
                        if (Backend.mediaPinned) {
                            Backend.isExpanded = false;
                        }
                    }
                }
            }
        }
    }
}