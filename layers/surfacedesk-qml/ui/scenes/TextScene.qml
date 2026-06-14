
import QtQuick

Item {
    id: root
    width: parent ? parent.width : 200
    height: parent ? parent.height : 80

    property string labelText: "Stay Focused"

    Row {
        anchors.centerIn: parent
        width: parent.width
        spacing: 12

        Rectangle {
            width: 3
            height: labelTextElement.height * 0.8
            radius: 1.5
            color: "#89B4FA"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: labelTextElement
            width: parent.width - 15
            text: root.labelText
            font.family: "Lexend"
            // Scaled up font multiplier from 0.24 to 0.35 to fill the canvas bounds better
            font.pixelSize: Math.min(parent.width, parent.height) * 0.35
            font.bold: true
            color: "#CDD6F4"
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignVCenter
            font.letterSpacing: -0.5
        }
    }

    // =========================================================================
    // INLINE CONFIGURATION PANEL (Exposed directly to the global Drawer)
    // =========================================================================
    property Component configComponent: Component {
        Column {
            spacing: 12
            width: parent ? parent.width : 200

            Text {
                text: "LABEL PROPERTIES"
                color: "#A6E3A1" // Muted Green
                font.family: "Lexend"
                font.pixelSize: 13
                font.bold: true
            }

            Row {
                spacing: 16
                Text { width: 100; text: "Label String"; color: appTheme.textSecondary; font.pixelSize: 12 }
                Rectangle {
                    width: 140; height: 24; color: "#11111B"; border.color: Qt.rgba(1,1,1,0.1); radius: appTheme.radius / 2
                    TextInput { 
                        anchors.fill: parent; anchors.margins: 6; color: "#CDD6F4"; font.pixelSize: 11; verticalAlignment: TextInput.AlignVCenter
                        text: widgetDrawer.activeWidgetData ? widgetDrawer.activeWidgetData.text : ""
                        onTextChanged: if (activeFocus && widgetDrawer.selectedIndex !== -1) widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "text", text) 
                    }
                }
            }
        }
    }
}