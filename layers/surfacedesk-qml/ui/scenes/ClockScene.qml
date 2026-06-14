import QtQuick
import QtQuick.Controls
import ".."

Item {
    id: root
    width: parent ? parent.width : 200
    height: parent ? parent.height : 150

    AppTheme { id: appTheme }

    property int variant: 0
    property string customFontFamily: "system-ui"
    property string customDateFontFamily: "system-ui:600"
    property bool useTheme: true
    property bool isBold: false 

    property int padding: 0
    property bool isTransparent: true
    property bool is24h: true
    property int customFontSize: 32 
    property int customDateSize: 10

    property real timeOpacity: 1.0
    property real dateOpacity: 0.7

    // Explicit color and spacing properties mapped from DB
    property int timeColorIndex: 8
    property int dateColorIndex: 5
    property int dateSpacing: 4

    property string timeString: "00:00"
    property string dateString: ""

    signal propertyChanged(string name, var value)

    // Select color explicitly directly from the extracted Wallust 16-color palette
    property color timeColor: (typeof wallpaperBackend !== "undefined" && wallpaperBackend && wallpaperBackend.wallpaperPalette.length > timeColorIndex) ? wallpaperBackend.wallpaperPalette[timeColorIndex] : "#CDD6F4"
    property color dateColor: (typeof wallpaperBackend !== "undefined" && wallpaperBackend && wallpaperBackend.wallpaperPalette.length > dateColorIndex) ? wallpaperBackend.wallpaperPalette[dateColorIndex] : "#89B4FA"

    property string baseFontFamily: customFontFamily.split(':')[0]
    property int baseFontWeight: (customFontFamily.indexOf(':') !== -1 && !isNaN(parseInt(customFontFamily.split(':')[1]))) ? parseInt(customFontFamily.split(':')[1]) : (isBold ? Font.Black : Font.ExtraBold)

    property string baseDateFontFamily: customDateFontFamily.split(':')[0] || "system-ui"
    property int baseDateFontWeight: (customDateFontFamily.indexOf(':') !== -1 && !isNaN(parseInt(customDateFontFamily.split(':')[1]))) ? parseInt(customDateFontFamily.split(':')[1]) : Font.DemiBold

    Timer {
        id: clockTimer
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            let date = new Date();
            let hours = date.getHours();
            if (!is24h) { hours = hours % 12; if (hours === 0) hours = 12; }
            let mins = String(date.getMinutes()).padStart(2, '0');
            root.timeString = String(hours).padStart(2, '0') + ":" + mins;
            
            // Exact match to GTK C Code: "%A, %B %d"
            root.dateString = date.toLocaleDateString(Qt.locale(), "dddd, MMMM d");
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.isTransparent ? "transparent" : Qt.rgba(20, 20, 30, 0.45)
        border.color: root.isTransparent ? "transparent" : Qt.rgba(255, 255, 255, 0.05)
        border.width: 1; radius: 12; visible: !root.isTransparent
    }

    Item {
        anchors.fill: parent; anchors.margins: root.padding
        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (variant === 0) return simpleLayout;
                if (variant === 1) return dateTimeLayout;
                if (variant === 2) return stackedLayout;
                return simpleLayout;
            }
        }
    }

    Component {
        id: simpleLayout
        Text {
            anchors.centerIn: parent; text: root.timeString; font.family: root.baseFontFamily
            font.pointSize: root.customFontSize * appTheme.scale
            font.weight: root.baseFontWeight
            color: root.timeColor 
            opacity: root.timeOpacity
            
            lineHeight: root.customFontSize >= 48 ? 0.8 : 1.0
            lineHeightMode: Text.ProportionalHeight
            font.letterSpacing: root.customFontSize >= 48 ? -1.0 : (root.customFontSize >= 32 ? -0.5 : 0)
        }
    }

    Component {
        id: dateTimeLayout
        Column {
            anchors.centerIn: parent
            spacing: root.dateSpacing * appTheme.scale
            width: parent.width

            Text {
                width: parent.width; text: root.timeString; font.family: root.baseFontFamily
                font.pointSize: root.customFontSize * appTheme.scale
                font.weight: root.baseFontWeight
                color: root.timeColor 
                opacity: root.timeOpacity
                horizontalAlignment: Text.AlignHCenter
                
                lineHeight: root.customFontSize >= 48 ? 0.8 : 1.0
                lineHeightMode: Text.ProportionalHeight
                font.letterSpacing: root.customFontSize >= 48 ? -1.0 : (root.customFontSize >= 32 ? -0.5 : 0)
            }
            Text {
                width: parent.width; text: root.dateString; font.family: root.baseDateFontFamily
                font.pointSize: root.customDateSize * appTheme.scale
                font.weight: root.baseDateFontWeight
                color: root.dateColor; horizontalAlignment: Text.AlignHCenter
                opacity: root.dateOpacity
            }
        }
    }

    Component {
        id: stackedLayout
        Column {
            anchors.centerIn: parent
            // Base tight stacking margin, padded down by custom date spacing
            spacing: -(root.customFontSize * appTheme.scale * 0.25) + (root.dateSpacing * appTheme.scale)

            Text {
                text: root.timeString.split(':')[0]; font.family: root.baseFontFamily
                font.pointSize: root.customFontSize * appTheme.scale
                font.weight: root.baseFontWeight; color: root.timeColor; anchors.horizontalCenter: parent.horizontalCenter
                opacity: root.timeOpacity
                
                lineHeight: root.customFontSize >= 48 ? 0.8 : 1.0
                lineHeightMode: Text.ProportionalHeight
                font.letterSpacing: root.customFontSize >= 48 ? -1.0 : (root.customFontSize >= 32 ? -0.5 : 0)
            }
            Text {
                text: root.timeString.split(':')[1]; font.family: root.baseFontFamily
                font.pointSize: root.customFontSize * appTheme.scale
                font.weight: root.baseFontWeight; color: root.dateColor; anchors.horizontalCenter: parent.horizontalCenter
                opacity: root.timeOpacity
                
                lineHeight: root.customFontSize >= 48 ? 0.8 : 1.0
                lineHeightMode: Text.ProportionalHeight
                font.letterSpacing: root.customFontSize >= 48 ? -1.0 : (root.customFontSize >= 32 ? -0.5 : 0)
            }
        }
    }

    property Component configComponent: Component {
        ClockConfigPanel {
            onPropertyChanged: (name, val) => root.propertyChanged(name, val)
        }
    }
}