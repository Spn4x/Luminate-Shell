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
            clip: true 
            
            Rectangle {
                x: 0; y: 0; height: parent.height
                width: (containerRect.width / 2) + AppTheme.moduleRadius
                color: AppTheme.accent
                radius: AppTheme.moduleRadius
            }
        }

        // Right Bar: Month Progress
        Item {
            x: containerRect.width - width; y: 0; height: parent.height
            width: (containerRect.width / 2) * Topbar.monthProgress
            clip: true 
            
            Rectangle {
                x: -AppTheme.moduleRadius; y: 0; height: parent.height
                width: (containerRect.width / 2) + AppTheme.moduleRadius
                color: AppTheme.accentDark1 // Solid, dark accent!
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