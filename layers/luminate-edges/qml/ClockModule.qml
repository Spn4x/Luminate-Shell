import QtQuick
import Luminate.Shell 

Item {
    implicitWidth: 120
    implicitHeight: AppTheme.moduleHeight

    Rectangle {
        id: containerRect
        anchors.fill: parent
        color: AppTheme.moduleBg
        radius: AppTheme.moduleRadius
        clip: true

        // Left Bar: Time Progress
        Item {
            x: 0; y: 0; height: parent.height
            width: (parent.width / 2) * Topbar.timeProgress
            clip: true // Chops off the right edge cleanly
            
            Rectangle {
                x: 0; y: 0; height: parent.height
                // Make it intentionally wider so the rounded right edge is hidden outside the clip
                width: (containerRect.width / 2) + AppTheme.moduleRadius
                color: AppTheme.accent
                radius: AppTheme.moduleRadius
            }
        }

        // Right Bar: Month Progress
        Item {
            x: containerRect.width - width; y: 0; height: parent.height
            width: (containerRect.width / 2) * Topbar.monthProgress
            clip: true // Chops off the left edge cleanly
            
            Rectangle {
                // Push it left so the rounded left edge is hidden outside the clip
                x: -AppTheme.moduleRadius; y: 0; height: parent.height
                width: (containerRect.width / 2) + AppTheme.moduleRadius
                color: Qt.rgba(AppTheme.accent.r, AppTheme.accent.g, AppTheme.accent.b, 0.6)
                radius: AppTheme.moduleRadius
            }
        }

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
    }
}