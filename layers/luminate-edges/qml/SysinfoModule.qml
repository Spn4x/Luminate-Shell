import QtQuick
import Luminate.Shell 

Item {
    implicitWidth: 200 
    implicitHeight: AppTheme.moduleHeight

    Rectangle {
        anchors.fill: parent
        color: AppTheme.moduleBg
        radius: AppTheme.moduleRadius
        clip: true

        // Clean, solid, mathematically darkened layers
        Rectangle { x: 0; y: 0; height: parent.height; width: parent.width * Topbar.cpuPct; color: AppTheme.accentDark3; radius: AppTheme.moduleRadius; Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } } }
        Rectangle { x: 0; height: parent.height * 0.75; anchors.verticalCenter: parent.verticalCenter; width: parent.width * Topbar.ramPct; color: AppTheme.accentDark2; radius: AppTheme.moduleRadius; Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } } }
        Rectangle { x: 0; height: parent.height * 0.50; anchors.verticalCenter: parent.verticalCenter; width: parent.width * Topbar.tempPct; color: AppTheme.accentDark1; radius: AppTheme.moduleRadius; Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } } }
        Rectangle { x: 0; height: parent.height * 0.25; anchors.verticalCenter: parent.verticalCenter; width: parent.width * Topbar.batPct; color: AppTheme.accent; radius: AppTheme.moduleRadius; Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } } }

        Item {
            anchors.fill: parent
            opacity: hoverHandler.hovered ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }

            component TipGlyph : Text {
                property real pct: 0
                text: ""
                color: AppTheme.fg
                font.family: AppTheme.iconFont
                font.pixelSize: AppTheme.fontSize
                y: (parent.height - height) / 2
                x: Math.max(2, Math.min(parent.width * pct - (width / 2), parent.width - width - 2))
                visible: pct > 0.01
                Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            }

            TipGlyph { pct: Topbar.cpuPct; text: "󰍛" }
            TipGlyph { pct: Topbar.ramPct; text: "󰾆" }
            TipGlyph { pct: Topbar.tempPct; text: "󰔏" }
            TipGlyph { pct: Topbar.batPct; text: "󰁹" }
        }

        Row {
            anchors.centerIn: parent
            spacing: 12
            opacity: hoverHandler.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Row { spacing: 4; Text { text: "󰍛"; color: AppTheme.fg; font.family: AppTheme.iconFont; font.pixelSize: AppTheme.fontSize } Text { text: Math.round(Topbar.cpuPct * 100) + "%"; color: AppTheme.fg; font.family: AppTheme.mainFont; font.pixelSize: AppTheme.fontSize; font.bold: true } }
            Row { spacing: 4; Text { text: "󰾆"; color: AppTheme.fg; font.family: AppTheme.iconFont; font.pixelSize: AppTheme.fontSize } Text { text: Math.round(Topbar.ramPct * 100) + "%"; color: AppTheme.fg; font.family: AppTheme.mainFont; font.pixelSize: AppTheme.fontSize; font.bold: true } }
            Row { spacing: 4; Text { text: "󰔏"; color: AppTheme.fg; font.family: AppTheme.iconFont; font.pixelSize: AppTheme.fontSize } Text { text: Topbar.tempVal + "°C"; color: AppTheme.fg; font.family: AppTheme.mainFont; font.pixelSize: AppTheme.fontSize; font.bold: true } }
            Row { spacing: 4; Text { text: "󰁹"; color: AppTheme.fg; font.family: AppTheme.iconFont; font.pixelSize: AppTheme.fontSize } Text { text: Math.round(Topbar.batPct * 100) + "%"; color: AppTheme.fg; font.family: AppTheme.mainFont; font.pixelSize: AppTheme.fontSize; font.bold: true } }
        }

        HoverHandler { id: hoverHandler }
    }
}