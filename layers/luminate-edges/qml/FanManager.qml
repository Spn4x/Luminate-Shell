import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Luminate.Shell

Item {
    id: root
    clip: true

    property int activeTab: 0

    // Dynamic color based on temperature
    property color fanColor: {
        let spinning = false;
        if (FanBackend.mode === "auto") { if (FanBackend.rpm > 0) spinning = true; } 
        else if (FanBackend.mode === "full-speed" || FanBackend.mode === "disengaged") { spinning = true; } 
        else { let lvl = parseInt(FanBackend.mode); if (!isNaN(lvl) && lvl > 0) spinning = true; }

        if (!spinning) return AppTheme.fg;
        if (FanBackend.temperature >= 75) return AppTheme.colorKill;
        if (FanBackend.temperature >= 55) return "#f8e45c";
        return AppTheme.colorCam;
    }

    // =====================================
    // REUSABLE "LINKED" CLASPED BUTTONS
    // =====================================
    component LinkedGroup: Rectangle {
        property var items: []
        property int currentIndex: 0
        signal itemSelected(int index, string value)

        height: 36
        radius: 8
        color: AppTheme.actionBg
        border.color: AppTheme.actionBorder
        border.width: 1

        Row {
            anchors.fill: parent
            Repeater {
                model: items
                delegate: Item {
                    width: parent.width / items.length
                    height: parent.height
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 6
                        color: currentIndex === index ? AppTheme.accent : (ma.containsMouse ? AppTheme.actionBgHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: currentIndex === index ? AppTheme.bg : AppTheme.fg
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: itemSelected(index, modelData.value) 
                    }
                }
            }
        }
    }

    // =====================================
    // REUSABLE CANVAS FAN GRAPHIC
    // =====================================
    component FanGraphic: Item {
        width: 140
        height: 140

        Canvas {
            id: fanCanvas
            anchors.fill: parent
            antialiasing: true

            property color renderColor: fanColor
            onRenderColorChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.resetTransform(); 
                ctx.clearRect(0, 0, width, height);

                var cx = width / 2;
                var cy = height / 2;
                var radius = Math.min(width, height) / 2 - 2;

                ctx.translate(cx, cy);

                var blades = 7;
                var step = (2 * Math.PI) / blades;

                ctx.fillStyle = Qt.rgba(renderColor.r, renderColor.g, renderColor.b, 0.35);

                for (var i = 0; i < blades; i++) {
                    ctx.save();
                    ctx.rotate(i * step);
                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    ctx.bezierCurveTo(radius * 0.2, -radius * 0.05, radius * 0.6, -radius * 0.1, radius, -radius * 0.5);
                    ctx.bezierCurveTo(radius * 0.8, -radius * 0.1, radius * 0.4, 0, 0, 0);
                    ctx.closePath(); 
                    ctx.fill();
                    ctx.restore();
                }

                // Hub
                ctx.strokeStyle = Qt.rgba(renderColor.r, renderColor.g, renderColor.b, 0.5);
                ctx.lineWidth = 2.0;
                ctx.beginPath();
                ctx.arc(0, 0, radius * 0.35, 0, 2 * Math.PI);
                ctx.stroke();

                ctx.fillStyle = Qt.rgba(renderColor.r, renderColor.g, renderColor.b, 0.2);
                ctx.beginPath();
                ctx.arc(0, 0, radius * 0.2, 0, 2 * Math.PI);
                ctx.fill();
            }
        }

        RotationAnimator {
            target: fanCanvas
            from: 0
            to: 360
            duration: FanBackend.rpm > 0 ? Math.max(100, (60000 / FanBackend.rpm) * 1.5) : 1000
            loops: Animation.Infinite
            running: FanBackend.rpm > 0
        }
    }

    // =====================================
    // HIERARCHY / LAYOUT
    // =====================================
    anchors.fill: parent
    
    // Tight bottom margin pulls the slider all the way down
    anchors.topMargin: 20
    anchors.leftMargin: 24
    anchors.rightMargin: 24
    anchors.bottomMargin: 16

    // 1. TOP GREEN BOX: Dashboard / Graphs
    LinkedGroup {
        id: topTabs
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 320
        items: [
            { label: "Dashboard", value: "dash" },
            { label: "Graphs", value: "graphs" }
        ]
        currentIndex: activeTab
        onItemSelected: (index, val) => { activeTab = index }
    }

    // 2. CENTER AREA: Fans and Text
    Item {
        anchors.top: topTabs.bottom
        anchors.bottom: bottomControls.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: activeTab === 0

        // Center Blue Text (Slightly shifted up to sit symmetrically with the bottom controls)
        Column {
            id: centerStats
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -16
            spacing: 2
            
            Text { 
                text: Math.round(FanBackend.temperature) + "°C"
                color: fanColor
                font.pixelSize: 42
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text { 
                text: FanBackend.rpm + " RPM"
                color: AppTheme.fg
                font.pixelSize: 22
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text { 
                text: "Mode: " + FanBackend.mode.toUpperCase()
                color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.5)
                font.pixelSize: 12
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 8
            }
        }

        // Left Green Circle
        FanGraphic {
            anchors.verticalCenter: centerStats.verticalCenter
            anchors.right: centerStats.left
            anchors.rightMargin: 40
        }

        // Right Green Circle
        FanGraphic {
            anchors.verticalCenter: centerStats.verticalCenter
            anchors.left: centerStats.right
            anchors.leftMargin: 40
        }
    }

    // 3. BOTTOM AREA: Yellow & Blue Boxes
    ColumnLayout {
        id: bottomControls
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0 // Hitting the absolute floor of the padded layout
        anchors.horizontalCenter: parent.horizontalCenter
        width: 420
        spacing: 16
        visible: activeTab === 0

        // Yellow Box: Mode Switcher
        LinkedGroup {
            Layout.fillWidth: true
            items: [
                { label: "Auto", value: "auto" },
                { label: "Full Speed", value: "full-speed" },
                { label: "Manual", value: "manual" }
            ]
            currentIndex: {
                if (FanBackend.mode === "auto") return 0;
                if (FanBackend.mode === "full-speed" || FanBackend.mode === "disengaged") return 1;
                return 2;
            }
            onItemSelected: (index, val) => {
                if (val === "manual") {
                    FanBackend.setMode(Math.round(levelSlider.value).toString());
                } else {
                    FanBackend.setMode(val);
                }
            }
        }

        // Blue Box: The 100% Custom QML Slider
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            opacity: !isNaN(parseInt(FanBackend.mode)) ? 1.0 : 0.4
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Slider {
                id: levelSlider
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                from: 0
                to: 7
                stepSize: 1
                snapMode: Slider.SnapAlways
                value: isNaN(parseInt(FanBackend.mode)) ? 0 : parseInt(FanBackend.mode)

                onMoved: {
                    FanBackend.setMode(value.toString());
                }

                // Custom Background with Tick Marks
                background: Item {
                    x: levelSlider.leftPadding
                    y: levelSlider.topPadding + levelSlider.availableHeight / 2 - height / 2
                    implicitWidth: 200
                    implicitHeight: 20
                    width: levelSlider.availableWidth
                    height: implicitHeight

                    // Base inactive track
                    Rectangle {
                        width: parent.width - 16
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.1)
                        anchors.centerIn: parent
                    }

                    // Active colored track
                    Rectangle {
                        x: 8
                        y: (parent.height - height) / 2
                        width: levelSlider.handle.x + (levelSlider.handle.width / 2) - 8
                        height: 4
                        radius: 2
                        color: AppTheme.accent
                    }

                    // Vertical tick marks (Lines for levels)
                    Repeater {
                        model: 8
                        Rectangle {
                            width: 2
                            height: 12
                            radius: 1
                            color: levelSlider.value >= index ? AppTheme.accent : Qt.rgba(1, 1, 1, 0.3)
                            x: 8 + index * (parent.width - 16) / 7 - 1
                            y: 4
                        }
                    }
                }

                // Custom Pill Handle
                handle: Rectangle {
                    x: levelSlider.leftPadding + levelSlider.visualPosition * (levelSlider.availableWidth - width)
                    y: levelSlider.topPadding + levelSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: levelSlider.pressed ? AppTheme.bg : AppTheme.accent
                    border.color: levelSlider.pressed ? AppTheme.accent : AppTheme.bg
                    border.width: 2
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
            }

            // Number Readout Box
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: 8
                color: AppTheme.actionBg
                border.color: AppTheme.actionBorder
                Text {
                    anchors.centerIn: parent
                    text: levelSlider.value
                    color: AppTheme.fg
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }
    }

    // =====================================
    // GRAPHS TAB
    // =====================================
    RowLayout {
        anchors.top: topTabs.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20
        spacing: 20
        visible: activeTab === 1

        // RPM Sparkline
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: AppTheme.actionBg
            border.color: AppTheme.actionBorder
            border.width: 1
            radius: 12
            clip: true

            Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 16; text: "RPM History"; color: AppTheme.fg; font.pixelSize: 14; font.bold: true; z: 10 }
            Text { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 16; text: FanBackend.rpm; color: AppTheme.fg; font.pixelSize: 14; font.bold: true; z: 10 }

            Canvas {
                anchors.fill: parent
                anchors.topMargin: 40
                property var history: FanBackend.rpmHistory
                onHistoryChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.resetTransform();
                    ctx.clearRect(0, 0, width, height);

                    var maxVal = 5000;
                    var stepX = width / 59.0;

                    ctx.beginPath();
                    for (var i = 0; i < 60; i++) {
                        var x = i * stepX;
                        var y = height - ((history[i] / maxVal) * (height - 4)) - 2;
                        if (i === 0) ctx.moveTo(x, y);
                        else ctx.lineTo(x, y);
                    }

                    ctx.strokeStyle = AppTheme.accent;
                    ctx.lineWidth = 2.0;
                    ctx.stroke();

                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                    ctx.closePath();

                    var grad = ctx.createLinearGradient(0, 0, 0, height);
                    grad.addColorStop(0, Qt.rgba(AppTheme.accent.r, AppTheme.accent.g, AppTheme.accent.b, 0.3));
                    grad.addColorStop(1, Qt.rgba(AppTheme.accent.r, AppTheme.accent.g, AppTheme.accent.b, 0.0));
                    ctx.fillStyle = grad;
                    ctx.fill();
                }
            }
        }

        // Temp Sparkline
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: AppTheme.actionBg
            border.color: AppTheme.actionBorder
            border.width: 1
            radius: 12
            clip: true

            Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 16; text: "Temp History"; color: AppTheme.colorKill; font.pixelSize: 14; font.bold: true; z: 10 }
            Text { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 16; text: Math.round(FanBackend.temperature) + "°C"; color: AppTheme.colorKill; font.pixelSize: 14; font.bold: true; z: 10 }

            Canvas {
                anchors.fill: parent
                anchors.topMargin: 40
                property var history: FanBackend.tempHistory
                onHistoryChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.resetTransform();
                    ctx.clearRect(0, 0, width, height);

                    var maxVal = 100;
                    var stepX = width / 59.0;

                    ctx.beginPath();
                    for (var i = 0; i < 60; i++) {
                        var x = i * stepX;
                        var y = height - ((history[i] / maxVal) * (height - 4)) - 2;
                        if (i === 0) ctx.moveTo(x, y);
                        else ctx.lineTo(x, y);
                    }

                    ctx.strokeStyle = AppTheme.colorKill;
                    ctx.lineWidth = 2.0;
                    ctx.stroke();

                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                    ctx.closePath();

                    var grad = ctx.createLinearGradient(0, 0, 0, height);
                    grad.addColorStop(0, Qt.rgba(AppTheme.colorKill.r, AppTheme.colorKill.g, AppTheme.colorKill.b, 0.3));
                    grad.addColorStop(1, Qt.rgba(AppTheme.colorKill.r, AppTheme.colorKill.g, AppTheme.colorKill.b, 0.0));
                    ctx.fillStyle = grad;
                    ctx.fill();
                }
            }
        }
    }
}