import QtQuick
import Qt5Compat.GraphicalEffects
import Luminate.Shell 

Item {
    id: clockRoot
    implicitWidth: 120
    implicitHeight: AppTheme.moduleHeight

    signal clicked(var targetItem)

    // 1. Base Background
    Rectangle {
        id: baseBg
        anchors.fill: parent
        color: AppTheme.moduleBg
        radius: AppTheme.moduleRadius
    }

    // 2. The Progress Bars (Rendered off-screen with sharp edges)
    Item {
        id: barsContainer
        anchors.fill: parent
        visible: false

        // Left Bar: Time Progress (Grows from left edge towards center)
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: (parent.width / 2) * Topbar.timeProgress
            color: AppTheme.accent
        }

        // Right Bar: Month Progress (Grows from right edge towards center)
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: (parent.width / 2) * Topbar.monthProgress
            color: AppTheme.accentDark1 
        }
    }

    // 3. The perfect rounded boundary mask
    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: AppTheme.moduleRadius
        visible: false
    }

    // 4. Apply the mask (Cuts off any sharp corners pushing outside the boundaries)
    OpacityMask {
        anchors.fill: parent
        source: barsContainer
        maskSource: maskShape
    }

    // 5. Text Overlay
    Row {
        anchors.fill: parent
        Text {
            width: parent.width / 2; height: parent.height
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            text: Topbar.clockTime
            color: AppTheme.fg
            font.family: AppTheme.mainFont
            font.bold: true; font.pixelSize: AppTheme.fontSize
        }
        Text {
            width: parent.width / 2; height: parent.height
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            text: Topbar.clockDate
            color: AppTheme.fg
            font.family: AppTheme.mainFont
            font.pixelSize: AppTheme.fontSize
        }
    }

    // 6. Interactive Click Target
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: clockRoot.clicked(clockRoot)
    }
}