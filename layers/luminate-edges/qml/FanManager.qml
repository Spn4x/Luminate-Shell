import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Luminate.Shell

Item {
    id: root
    clip: true

    property int activeTab: 0
    property bool authAttempted: false

    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus();
            if (!authAttempted) {
                authAttempted = true;
                FanBackend.requestPermissions();
            }
        }
        if (!visible && Backend.displayMode !== "polkit") {
            authAttempted = false;
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: Backend.closeFan()
    }

    property color fanColor: {
        let spinning = false;
        if (FanBackend.mode === "auto") { if (FanBackend.rpm > 0) spinning = true; } 
        else if (FanBackend.mode === "full-speed" || FanBackend.mode === "disengaged") { spinning = true; } 
        else { let lvl = parseInt(FanBackend.mode); if (!Number.isNaN(lvl) && lvl > 0) spinning = true; }

        if (!spinning) return AppTheme.fg;
        if (FanBackend.temperature >= 75) return AppTheme.colorKill;
        if (FanBackend.temperature >= 55) return "#f8e45c";
        return AppTheme.colorCam;
    }

    component LinkedGroup: Rectangle {
        id: groupRoot
        property var items: []
        property int currentIndex: 0
        signal itemSelected(int index, string value)

        height: 36
        radius: 8
        color: AppTheme.actionBg
        border.color: AppTheme.actionBorder
        border.width: 1

        Rectangle {
            property real slotWidth: groupRoot.width / Math.max(1, groupRoot.items.length)
            
            y: 3
            height: parent.height - 6
            width: slotWidth - 6
            x: 3 + (groupRoot.currentIndex * slotWidth)
            
            radius: 6
            color: AppTheme.accent
            
            Behavior on x { 
                SpringAnimation { spring: 4.0; damping: 0.4; epsilon: 0.5 } 
            }
        }

        Row {
            anchors.fill: parent
            Repeater {
                model: groupRoot.items
                delegate: Item {
                    width: groupRoot.width / Math.max(1, groupRoot.items.length)
                    height: groupRoot.height
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 6
                        color: (ma.containsMouse && groupRoot.currentIndex !== index) ? AppTheme.actionBgHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: groupRoot.currentIndex === index ? AppTheme.bg : AppTheme.fg
                        font.pixelSize: 13
                        font.bold: true
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: groupRoot.itemSelected(index, modelData.value) 
                    }
                }
            }
        }
    }

    component FanGraphic: Item {
        width: 140
        height: 140

        Canvas {
            id: fanCanvas
            anchors.fill: parent
            antialiasing: true

            property color renderColor: root.fanColor
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

    anchors.fill: parent
    anchors.topMargin: 20
    anchors.leftMargin: 24
    anchors.rightMargin: 24
    anchors.bottomMargin: 16

    LinkedGroup {
        id: topTabs
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 320
        items: [
            { label: "Dashboard", value: "dash" },
            { label: "Graphs", value: "graphs" }
        ]
        currentIndex: root.activeTab
        onItemSelected: function(index, val) { root.activeTab = index }
    }

    Item {
        anchors.top: topTabs.bottom
        anchors.bottom: bottomControls.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: activeTab === 0

        Column {
            id: centerStats
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -16
            spacing: 2
            
            Text { 
                text: Math.round(FanBackend.temperature) + "°C"
                color: root.fanColor
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

        FanGraphic {
            anchors.verticalCenter: centerStats.verticalCenter
            anchors.right: centerStats.left
            anchors.rightMargin: 40
        }

        FanGraphic {
            anchors.verticalCenter: centerStats.verticalCenter
            anchors.left: centerStats.right
            anchors.leftMargin: 40
        }
    }

    ColumnLayout {
        id: bottomControls
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0 
        anchors.horizontalCenter: parent.horizontalCenter
        width: 420
        spacing: 16
        visible: activeTab === 0

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
            onItemSelected: function(index, val) {
                if (val === "manual") {
                    FanBackend.setMode(Math.round(levelSlider.value).toString());
                } else {
                    FanBackend.setMode(val);
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 32 
            
            property bool isLocked: Number.isNaN(parseInt(FanBackend.mode))
            
            opacity: isLocked ? 0.4 : 1.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            RowLayout {
                anchors.fill: parent
                spacing: 16

                Slider {
                    id: levelSlider
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    from: 0
                    to: 7
                    stepSize: 1
                    snapMode: Slider.SnapAlways
                    value: Number.isNaN(parseInt(FanBackend.mode)) ? 0 : parseInt(FanBackend.mode)

                    // Proxy property for buttery smooth handle/track animations
                    property real smoothPos: visualPosition
                    Behavior on smoothPos {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    onMoved: {
                        FanBackend.setMode(value.toString());
                    }

                    background: Item {
                        x: levelSlider.leftPadding
                        y: levelSlider.topPadding + levelSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 20
                        width: levelSlider.availableWidth
                        height: implicitHeight

                        Rectangle {
                            width: parent.width - 16
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.1)
                            anchors.centerIn: parent
                        }

                        Rectangle {
                            x: 8
                            y: (parent.height - height) / 2
                            width: (levelSlider.smoothPos * (levelSlider.availableWidth - levelHandle.width)) + (levelHandle.width / 2) - 8
                            height: 4
                            radius: 2
                            color: AppTheme.accent
                        }

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

                    handle: Rectangle {
                        id: levelHandle
                        // Use the smoothed proxy property for flawless gliding
                        x: levelSlider.leftPadding + levelSlider.smoothPos * (levelSlider.availableWidth - width)
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

            // Authentication blocker overlay
            MouseArea {
                anchors.fill: parent
                enabled: parent.isLocked
                cursorShape: Qt.PointingHandCursor
                onClicked: FanBackend.requestPermissions()
                z: 100
            }
        }
    }

    RowLayout {
        anchors.top: topTabs.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20
        spacing: 20
        visible: activeTab === 1

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

                    // Dynamic Y-Axis Auto-Scaling for RPM
                    var currentMax = 0;
                    for (var m = 0; m < 60; m++) {
                        if (history[m] > currentMax) currentMax = history[m];
                    }
                    var maxVal = Math.max(1500, currentMax * 1.15); // Adds 15% headroom, bottom floor of 1500 RPM

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

                    // Dynamic Y-Axis Auto-Scaling for Temperature
                    var currentMax = 0;
                    for (var m = 0; m < 60; m++) {
                        if (history[m] > currentMax) currentMax = history[m];
                    }
                    var maxVal = Math.max(60, currentMax * 1.15); // Adds 15% headroom, bottom floor of 60 C

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