
import QtQuick

Item {
    id: root
    width: parent ? parent.width : 320
    height: parent ? parent.height : 160

    property int variant: 0
    property bool showTemp: true

    property color cpuColor: "#89B4FA"  
    property color ramColor: "#A6E3A1"  
    property color tempColor: "#F38BA8" 

    property real cpuVal: (typeof wallpaperBackend !== "undefined" && wallpaperBackend) ? wallpaperBackend.cpuUsage : 0.0
    property real ramVal: (typeof wallpaperBackend !== "undefined" && wallpaperBackend) ? wallpaperBackend.ramUsage : 0.0
    property real tempVal: (typeof wallpaperBackend !== "undefined" && wallpaperBackend) ? wallpaperBackend.systemTemp : 0.0

    Loader {
        anchors.fill: parent
        sourceComponent: {
            if (variant === 0) return radialLayout;
            return linearLayout;
        }
    }

    Component {
        id: radialLayout
        Item {
            anchors.fill: parent
            
            Canvas {
                id: ringCanvas
                anchors.fill: parent
                antialiasing: true
                
                property real cpu: root.cpuVal
                property real ram: root.ramVal
                property real temp: root.tempVal

                onCpuChanged: requestPaint()
                onRamChanged: requestPaint()
                onTempChanged: requestPaint()
                
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var cx = width / 2;
                    var cy = height / 2;
                    var baseRadius = Math.min(width, height) * 0.35;
                    ctx.lineWidth = 6;
                    ctx.lineCap = "round";

                    drawTrackAndArc(ctx, cx, cy, baseRadius, cpu, root.cpuColor);
                    drawTrackAndArc(ctx, cx, cy, baseRadius - 10, ram, root.ramColor);

                    if (root.showTemp) {
                        var tRatio = Math.min(1.0, Math.max(0.0, temp / 100.0));
                        drawTrackAndArc(ctx, cx, cy, baseRadius - 20, tRatio, root.tempColor);
                    }
                }

                function drawTrackAndArc(ctx, cx, cy, radius, value, color) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.05);
                    ctx.stroke();

                    ctx.beginPath();
                    var startAngle = -Math.PI / 2;
                    var endAngle = startAngle + (value * 2 * Math.PI);
                    ctx.arc(cx, cy, radius, startAngle, endAngle);
                    ctx.strokeStyle = color;
                    ctx.stroke();
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: -2
                Text {
                    text: Math.round(root.cpuVal * 100) + "%"
                    font.family: "Lexend"
                    // Kept pixelSize here solely to compute geometric ratios on absolute Canvas dimensions
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.16
                    font.bold: true
                    color: root.cpuColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "SYSTEM"
                    font.family: "Lexend"
                    font.pixelSize: Math.min(parent.parent.width, parent.parent.height) * 0.07
                    color: appTheme.textSecondary
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Component {
        id: linearLayout
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.85
            spacing: 8

            // CPU Bar
            Column {
                width: parent.width
                spacing: 2
                Item {
                    width: parent.width
                    height: cpuLabel.height
                    Text {
                        id: cpuLabel
                        text: "CPU"
                        font.family: "Lexend"
                        font.pointSize: 9 // Swapped to pointSize
                        font.bold: true
                        color: appTheme.textPrimary
                        anchors.left: parent.left
                    }
                    Text {
                        text: Math.round(root.cpuVal * 100) + "%"
                        font.family: "Lexend"
                        font.pointSize: 9 // Swapped to pointSize
                        color: root.cpuColor
                        font.bold: true
                        anchors.right: parent.right
                    }
                }
                Rectangle {
                    width: parent.width; height: 6; radius: 3; color: Qt.rgba(1,1,1,0.06)
                    Rectangle { width: parent.width * root.cpuVal; height: parent.height; radius: 3; color: root.cpuColor }
                }
            }

            // RAM Bar
            Column {
                width: parent.width
                spacing: 2
                Item {
                    width: parent.width
                    height: ramLabel.height
                    Text {
                        id: ramLabel
                        text: "RAM"
                        font.family: "Lexend"
                        font.pointSize: 9 // Swapped to pointSize
                        font.bold: true
                        color: appTheme.textPrimary
                        anchors.left: parent.left
                    }
                    Text {
                        text: Math.round(root.ramVal * 100) + "%"
                        font.family: "Lexend"
                        font.pointSize: 9 // Swapped to pointSize
                        color: root.ramColor
                        font.bold: true
                        anchors.right: parent.right
                    }
                }
                Rectangle {
                    width: parent.width; height: 6; radius: 3; color: Qt.rgba(1,1,1,0.06)
                    Rectangle { width: parent.width * root.ramVal; height: parent.height; radius: 3; color: root.ramColor }
                }
            }

            // Temperature Bar
            Column {
                width: parent.width
                spacing: 2
                visible: root.showTemp
                Item {
                    width: parent.width
                    height: tempLabel.height
                    Text {
                        id: tempLabel
                        text: "TEMP"
                        font.family: "Lexend"
                        font.pointSize: 9 // Swapped to pointSize
                        font.bold: true
                        color: appTheme.textPrimary
                        anchors.left: parent.left
                    }
                    Text {
                        text: Math.round(root.tempVal) + "°C"
                        font.family: "Lexend"
                        font.pointSize: 9 // Swapped to pointSize
                        color: root.tempColor
                        font.bold: true
                        anchors.right: parent.right
                    }
                }
                Rectangle {
                    width: parent.width; height: 6; radius: 3; color: Qt.rgba(1,1,1,0.06)
                    Rectangle { width: parent.width * Math.min(1.0, root.tempVal / 100.0); height: parent.height; radius: 3; color: root.tempColor }
                }
            }
        }
    }

    // =========================================================================
    // INLINE CONFIGURATION PANEL
    // =========================================================================
    property Component configComponent: Component {
        Column {
            spacing: 12
            width: parent ? parent.width : 200

            Text {
                text: "SYSTEM HARDWARE PROPERTIES"
                color: "#A6E3A1"
                font.family: "Lexend"
                font.pointSize: 10 // Swapped to pointSize
                font.bold: true
            }

            Row {
                spacing: 16
                Text { width: 100; text: "Display Core Temp"; color: appTheme.textSecondary; font.pointSize: 9 } // Swapped to pointSize
                Rectangle {
                    id: tempToggle
                    width: 36; height: 20; radius: appTheme.radius / 2
                    property bool isChecked: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.showTemp !== undefined ? widgetDrawer.activeWidgetData.showTemp : true
                    color: isChecked ? appTheme.accent : appTheme.elementBg
                    
                    Rectangle { 
                        width: 14; height: 14; radius: 7; color: appTheme.bg
                        x: parent.isChecked ? 19 : 3; y: 3
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } } 
                    }
                    MouseArea { anchors.fill: parent; onClicked: if (widgetDrawer.selectedIndex !== -1) widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "showTemp", !tempToggle.isChecked) }
                }
            }
        }
    }
}