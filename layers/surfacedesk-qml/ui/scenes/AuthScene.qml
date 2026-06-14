import QtQuick
import QtQuick.Controls
import ".."

Item {
    id: root
    width: parent ? parent.width : 320
    height: parent ? parent.height : 60

    AppTheme { id: appTheme }

    property int variant: 0
    property int escapeCount: 0

    property string authPlaceholderText: "ENTER PASSWORD"
    property string authEchoChar: "•"
    property bool authShowBorder: true
    property bool isTransparent: false
    
    property int customWidth: 0
    property int customHeight: 0

    property color flashColor: "transparent"

    // Exposed interface function for InteractiveWidget to call when slide-up occurs
    function grabFocus() {
        passwordInput.forceActiveFocus();
    }

    SequentialAnimation {
        id: shakeAnim
        loops: 2
        NumberAnimation { target: authContainer; property: "anchors.horizontalCenterOffset"; to: -14; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: authContainer; property: "anchors.horizontalCenterOffset"; to: 14; duration: 110; easing.type: Easing.InOutQuad }
        NumberAnimation { target: authContainer; property: "anchors.horizontalCenterOffset"; to: 0; duration: 55; easing.type: Easing.OutQuad }
    }

    SequentialAnimation {
        id: colorFlashAnim
        ColorAnimation { target: root; property: "flashColor"; to: Qt.rgba(1, 0.2, 0.2, 0.5); duration: 80 }
        ColorAnimation { target: root; property: "flashColor"; to: "transparent"; duration: 220 }
    }

    Item {
        id: authContainer
        anchors.centerIn: parent
        
        width: root.customWidth > 0 ? Math.round(root.customWidth * appTheme.scale) : parent.width
        height: root.customHeight > 0 ? Math.round(root.customHeight * appTheme.scale) : parent.height

        Rectangle {
            anchors.fill: parent
            color: (root.isTransparent || root.variant === 1) ? root.flashColor : Qt.rgba(15, 15, 20, 0.8)
            radius: appTheme.radius

            Rectangle { 
                anchors.fill: parent
                color: root.flashColor
                radius: appTheme.radius 
            }

            border.color: passwordInput.activeFocus && root.authShowBorder ? appTheme.accent : (root.variant === 0 && !root.isTransparent ? Qt.rgba(255, 255, 255, 0.15) : "transparent")
            border.width: root.variant === 0 && (!root.isTransparent || root.authShowBorder) ? 1.5 : 0

            Rectangle {
                visible: root.variant === 1
                width: parent.width
                height: 2
                anchors.bottom: parent.bottom
                color: passwordInput.activeFocus && root.authShowBorder ? appTheme.accent : Qt.rgba(255, 255, 255, 0.3)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: root.variant === 1 ? TextInput.AlignHCenter : TextInput.AlignLeft
                color: "#FFFFFF"
                font.family: "Lexend"
                font.pointSize: 14 * appTheme.scale
                echoMode: TextInput.Password
                passwordCharacter: root.authEchoChar !== "" ? root.authEchoChar : "•"
                
                // Allow focus logic to remain connected to the backend state for load-in mapping
                focus: typeof wallpaperBackend !== "undefined" && wallpaperBackend && wallpaperBackend.isLocked

                // Automatically trigger Lockscreen to open sliding AuthMode when someone types their first key
                onTextChanged: {
                    if (text.length > 0) {
                        let p = root;
                        while (p) {
                            if (typeof p.requestAuthMode === "function") {
                                p.requestAuthMode();
                                break;
                            }
                            p = p.parent;
                        }
                    }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        // Clear the box and safely bubble up the slide-down idle signal
                        passwordInput.text = "";
                        root.escapeCount++;
                        if (root.escapeCount >= 5 && typeof wallpaperBackend !== "undefined" && wallpaperBackend) {
                            wallpaperBackend.isLocked = false;
                        }
                        event.accepted = true;
                        
                        let p = root;
                        while (p) {
                            if (typeof p.requestIdleMode === "function") {
                                p.requestIdleMode();
                                break;
                            }
                            p = p.parent;
                        }
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.escapeCount = 0;
                        executeAuth();
                        event.accepted = true;
                    } else {
                        root.escapeCount = 0;
                    }
                }
            }

            Text {
                text: root.authPlaceholderText
                color: Qt.rgba(255, 255, 255, 0.45)
                font.family: "Lexend"
                font.pointSize: 10 * appTheme.scale
                font.bold: true
                anchors.centerIn: parent
                visible: passwordInput.text.length === 0
            }
        }
    }

    function executeAuth() {
        if (typeof wallpaperBackend === "undefined" || !wallpaperBackend) return;
        if (wallpaperBackend.authenticatePassword(passwordInput.text)) {
            passwordInput.text = "";
            wallpaperBackend.isLocked = false;
        } else {
            passwordInput.text = "";
            shakeAnim.restart();
            colorFlashAnim.restart();
        }
    }

    Component.onCompleted: {
        if (typeof wallpaperBackend !== "undefined" && wallpaperBackend && wallpaperBackend.isLocked) {
            passwordInput.forceActiveFocus();
        }
    }

    Connections {
        target: (typeof wallpaperBackend !== "undefined" && wallpaperBackend) ? wallpaperBackend : null
        ignoreUnknownSignals: true
        
        function onIsLockedChanged() {
            if (wallpaperBackend && wallpaperBackend.isLocked) {
                passwordInput.forceActiveFocus();
            }
        }
    }

    // Settings overlay
    property Component configComponent: Component {
        Column {
            spacing: Math.round(14 * appTheme.scale)
            width: parent ? parent.width : 200

            Text { 
                text: "SECURITY PROPERTIES"
                color: "#A6E3A1"
                font.family: "Lexend"
                font.pointSize: 10
                font.bold: true 
            }

            // Grid Size W/H
            Row {
                spacing: Math.round(20 * appTheme.scale)
                Text { 
                    width: Math.round(120 * appTheme.scale)
                    text: "Grid Size"
                    color: appTheme.textSecondary
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale
                    anchors.verticalCenter: parent.verticalCenter 
                }
                
                Column {
                    spacing: Math.round(10 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        spacing: Math.round(4 * appTheme.scale)
                        Text { 
                            width: Math.round(20 * appTheme.scale)
                            text: "W:"
                            color: appTheme.textSecondary
                            font.family: "Inter"
                            font.pointSize: 10 * appTheme.scale
                            anchors.verticalCenter: parent.verticalCenter 
                        }
                        
                        Rectangle { 
                            width: Math.round(40 * appTheme.scale)
                            height: Math.round(26 * appTheme.scale)
                            radius: Math.round(6 * appTheme.scale)
                            color: appTheme.elementBg 
                            
                            TextInput { 
                                anchors.fill: parent
                                horizontalAlignment: TextInput.AlignHCenter
                                verticalAlignment: TextInput.AlignVCenter
                                color: appTheme.textPrimary
                                font.family: "Inter"
                                font.pointSize: 9 * appTheme.scale
                                text: widgetDrawer.activeWidgetData ? String(widgetDrawer.activeWidgetData.grid_w) : "4"
                                validator: IntValidator { bottom: 1; top: 20 }
                                
                                onEditingFinished: { 
                                    let val = parseInt(text); 
                                    if (!isNaN(val)) {
                                        widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "grid_w", Math.max(1, Math.min(20, val))); 
                                    }
                                } 
                            }
                        }
                        
                        Rectangle { 
                            width: Math.round(26 * appTheme.scale)
                            height: Math.round(26 * appTheme.scale)
                            radius: Math.round(6 * appTheme.scale)
                            color: appTheme.elementBg 
                            Text { 
                                text: "-"
                                color: appTheme.textPrimary
                                font.pointSize: 11 * appTheme.scale
                                font.bold: true
                                anchors.centerIn: parent 
                            }
                            MouseArea { 
                                anchors.fill: parent
                                onClicked: { 
                                    if (widgetDrawer.activeWidgetData) {
                                        widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "grid_w", Math.max(1, widgetDrawer.activeWidgetData.grid_w - 1));
                                    }
                                }
                            }
                        }
                        
                        Rectangle { 
                            width: Math.round(26 * appTheme.scale)
                            height: Math.round(26 * appTheme.scale)
                            radius: Math.round(6 * appTheme.scale)
                            color: appTheme.elementBg 
                            Text { 
                                text: "+"
                                color: appTheme.textPrimary
                                font.pointSize: 11 * appTheme.scale
                                font.bold: true
                                anchors.centerIn: parent 
                            }
                            MouseArea { 
                                anchors.fill: parent
                                onClicked: { 
                                    if (widgetDrawer.activeWidgetData) {
                                        widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "grid_w", Math.min(20, widgetDrawer.activeWidgetData.grid_w + 1));
                                    }
                                }
                            }
                        }
                    }
                    
                    Row {
                        spacing: Math.round(4 * appTheme.scale)
                        Text { 
                            width: Math.round(20 * appTheme.scale)
                            text: "H:"
                            color: appTheme.textSecondary
                            font.family: "Inter"
                            font.pointSize: 10 * appTheme.scale
                            anchors.verticalCenter: parent.verticalCenter 
                        }
                        
                        Rectangle { 
                            width: Math.round(40 * appTheme.scale)
                            height: Math.round(26 * appTheme.scale)
                            radius: Math.round(6 * appTheme.scale)
                            color: appTheme.elementBg 
                            
                            TextInput { 
                                anchors.fill: parent
                                horizontalAlignment: TextInput.AlignHCenter
                                verticalAlignment: TextInput.AlignVCenter
                                color: appTheme.textPrimary
                                font.family: "Inter"
                                font.pointSize: 9 * appTheme.scale
                                text: widgetDrawer.activeWidgetData ? String(widgetDrawer.activeWidgetData.grid_h) : "1"
                                validator: IntValidator { bottom: 1; top: 20 }
                                
                                onEditingFinished: { 
                                    let val = parseInt(text); 
                                    if (!isNaN(val)) {
                                        widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "grid_h", Math.max(1, Math.min(20, val))); 
                                    }
                                } 
                            }
                        }
                        
                        Rectangle { 
                            width: Math.round(26 * appTheme.scale)
                            height: Math.round(26 * appTheme.scale)
                            radius: Math.round(6 * appTheme.scale)
                            color: appTheme.elementBg 
                            Text { 
                                text: "-"
                                color: appTheme.textPrimary
                                font.pointSize: 11 * appTheme.scale
                                font.bold: true
                                anchors.centerIn: parent 
                            }
                            MouseArea { 
                                anchors.fill: parent
                                onClicked: { 
                                    if (widgetDrawer.activeWidgetData) {
                                        widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "grid_h", Math.max(1, widgetDrawer.activeWidgetData.grid_h - 1));
                                    }
                                }
                            }
                        }
                        
                        Rectangle { 
                            width: Math.round(26 * appTheme.scale)
                            height: Math.round(26 * appTheme.scale)
                            radius: Math.round(6 * appTheme.scale)
                            color: appTheme.elementBg 
                            Text { 
                                text: "+"
                                color: appTheme.textPrimary
                                font.pointSize: 11 * appTheme.scale
                                font.bold: true
                                anchors.centerIn: parent 
                            }
                            MouseArea { 
                                anchors.fill: parent
                                onClicked: { 
                                    if (widgetDrawer.activeWidgetData) {
                                        widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "grid_h", Math.min(20, widgetDrawer.activeWidgetData.grid_h + 1));
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Independent Auth Box Width
            Row {
                spacing: Math.round(20 * appTheme.scale)
                Text { 
                    width: Math.round(120 * appTheme.scale)
                    text: "Auth Box Width"
                    color: appTheme.textSecondary
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale
                    anchors.verticalCenter: parent.verticalCenter 
                }
                
                Row {
                    spacing: Math.round(4 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Rectangle { 
                        width: Math.round(44 * appTheme.scale)
                        height: Math.round(26 * appTheme.scale)
                        radius: Math.round(6 * appTheme.scale)
                        color: appTheme.elementBg 
                        
                        TextInput { 
                            anchors.fill: parent
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            color: appTheme.textPrimary
                            font.family: "Inter"
                            font.pointSize: 9 * appTheme.scale
                            text: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.authWidth !== undefined ? String(widgetDrawer.activeWidgetData.authWidth) : "0"
                            validator: IntValidator { bottom: 0; top: 1200 }
                            
                            onEditingFinished: { 
                                let val = parseInt(text); 
                                if (!isNaN(val)) {
                                    widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "authWidth", Math.max(0, val)); 
                                }
                            } 
                        }
                    }
                    
                    Rectangle { 
                        width: Math.round(26 * appTheme.scale)
                        height: Math.round(26 * appTheme.scale)
                        radius: Math.round(6 * appTheme.scale)
                        color: appTheme.elementBg 
                        Text { 
                            text: "-"
                            color: appTheme.textPrimary
                            font.pointSize: 11 * appTheme.scale
                            font.bold: true
                            anchors.centerIn: parent 
                        }
                        MouseArea { 
                            anchors.fill: parent
                            onClicked: { 
                                if (widgetDrawer.activeWidgetData) {
                                    widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "authWidth", Math.max(0, (widgetDrawer.activeWidgetData.authWidth || 0) - 10));
                                }
                            }
                        }
                    }
                    
                    Rectangle { 
                        width: Math.round(26 * appTheme.scale)
                        height: Math.round(26 * appTheme.scale)
                        radius: Math.round(6 * appTheme.scale)
                        color: appTheme.elementBg 
                        Text { 
                            text: "+"
                            color: appTheme.textPrimary
                            font.pointSize: 11 * appTheme.scale
                            font.bold: true
                            anchors.centerIn: parent 
                        }
                        MouseArea { 
                            anchors.fill: parent
                            onClicked: { 
                                if (widgetDrawer.activeWidgetData) {
                                    widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "authWidth", (widgetDrawer.activeWidgetData.authWidth || 0) + 10);
                                }
                            }
                        }
                    }
                }
            }

            // Independent Auth Box Height
            Row {
                spacing: Math.round(20 * appTheme.scale)
                Text { 
                    width: Math.round(120 * appTheme.scale)
                    text: "Auth Box Height"
                    color: appTheme.textSecondary
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale
                    anchors.verticalCenter: parent.verticalCenter 
                }
                
                Row {
                    spacing: Math.round(4 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Rectangle { 
                        width: Math.round(44 * appTheme.scale)
                        height: Math.round(26 * appTheme.scale)
                        radius: Math.round(6 * appTheme.scale)
                        color: appTheme.elementBg 
                        
                        TextInput { 
                            anchors.fill: parent
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            color: appTheme.textPrimary
                            font.family: "Inter"
                            font.pointSize: 9 * appTheme.scale
                            text: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.authHeight !== undefined ? String(widgetDrawer.activeWidgetData.authHeight) : "0"
                            validator: IntValidator { bottom: 0; top: 400 }
                            
                            onEditingFinished: { 
                                let val = parseInt(text); 
                                if (!isNaN(val)) {
                                    widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "authHeight", Math.max(0, val)); 
                                }
                            } 
                        }
                    }
                    
                    Rectangle { 
                        width: Math.round(26 * appTheme.scale)
                        height: Math.round(26 * appTheme.scale)
                        radius: Math.round(6 * appTheme.scale)
                        color: appTheme.elementBg 
                        Text { 
                            text: "-"
                            color: appTheme.textPrimary
                            font.pointSize: 11 * appTheme.scale
                            font.bold: true
                            anchors.centerIn: parent 
                        }
                        MouseArea { 
                            anchors.fill: parent
                            onClicked: { 
                                if (widgetDrawer.activeWidgetData) {
                                    widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "authHeight", Math.max(0, (widgetDrawer.activeWidgetData.authHeight || 0) - 5));
                                }
                            }
                        }
                    }
                    
                    Rectangle { 
                        width: Math.round(26 * appTheme.scale)
                        height: Math.round(26 * appTheme.scale)
                        radius: Math.round(6 * appTheme.scale)
                        color: appTheme.elementBg 
                        Text { 
                            text: "+"
                            color: appTheme.textPrimary
                            font.pointSize: 11 * appTheme.scale
                            font.bold: true
                            anchors.centerIn: parent 
                        }
                        MouseArea { 
                            anchors.fill: parent
                            onClicked: { 
                                if (widgetDrawer.activeWidgetData) {
                                    widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "authHeight", (widgetDrawer.activeWidgetData.authHeight || 0) + 5);
                                }
                            }
                        }
                    }
                }
            }

            // Transparent Toggle
            Row {
                spacing: Math.round(20 * appTheme.scale)
                Text { 
                    width: Math.round(120 * appTheme.scale)
                    text: "Transparent BG"
                    color: appTheme.textSecondary
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale
                    anchors.verticalCenter: parent.verticalCenter 
                }
                
                Rectangle {
                    width: Math.round(44 * appTheme.scale)
                    height: Math.round(24 * appTheme.scale)
                    radius: Math.round(12 * appTheme.scale)
                    property bool isChecked: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.transparent !== undefined ? widgetDrawer.activeWidgetData.transparent : false
                    color: isChecked ? appTheme.accent : appTheme.elementBg
                    
                    Rectangle { 
                        width: Math.round(18 * appTheme.scale)
                        height: Math.round(18 * appTheme.scale)
                        radius: Math.round(9 * appTheme.scale)
                        color: appTheme.bg
                        x: parent.isChecked ? Math.round(23 * appTheme.scale) : Math.round(3 * appTheme.scale)
                        y: Math.round(3 * appTheme.scale)
                        Behavior on x { NumberAnimation { duration: 120 } } 
                    }
                    MouseArea { 
                        anchors.fill: parent
                        onClicked: widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "transparent", !parent.isChecked) 
                    }
                }
            }

            // Focus Border Toggle
            Row {
                spacing: Math.round(20 * appTheme.scale)
                Text { 
                    width: Math.round(120 * appTheme.scale)
                    text: "Focus Border"
                    color: appTheme.textSecondary
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale
                    anchors.verticalCenter: parent.verticalCenter 
                }
                
                Rectangle {
                    width: Math.round(44 * appTheme.scale)
                    height: Math.round(24 * appTheme.scale)
                    radius: Math.round(12 * appTheme.scale)
                    property bool isChecked: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.showFocusBorder !== undefined ? widgetDrawer.activeWidgetData.showFocusBorder : true
                    color: isChecked ? appTheme.accent : appTheme.elementBg
                    
                    Rectangle { 
                        width: Math.round(18 * appTheme.scale)
                        height: Math.round(18 * appTheme.scale)
                        radius: Math.round(9 * appTheme.scale)
                        color: appTheme.bg
                        x: parent.isChecked ? Math.round(23 * appTheme.scale) : Math.round(3 * appTheme.scale)
                        y: Math.round(3 * appTheme.scale)
                        Behavior on x { NumberAnimation { duration: 120 } } 
                    }
                    MouseArea { 
                        anchors.fill: parent
                        onClicked: !widgetDrawer.activeWidgetData ? null : widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "showFocusBorder", !parent.isChecked) 
                    }
                }
            }

            // Placeholder Text Input
            Row {
                spacing: Math.round(20 * appTheme.scale)
                Text { 
                    width: Math.round(120 * appTheme.scale)
                    text: "Placeholder Text"
                    color: appTheme.textSecondary
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale
                    anchors.verticalCenter: parent.verticalCenter 
                }
                
                Rectangle {
                    width: Math.round(140 * appTheme.scale)
                    height: Math.round(26 * appTheme.scale)
                    radius: Math.round(6 * appTheme.scale)
                    color: appTheme.elementBg
                    
                    TextInput { 
                        anchors.fill: parent
                        anchors.margins: 6
                        color: appTheme.textPrimary
                        font.family: "Inter"
                        font.pointSize: 9 * appTheme.scale
                        verticalAlignment: TextInput.AlignVCenter
                        text: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.text !== undefined ? widgetDrawer.activeWidgetData.text : ""
                        onTextChanged: {
                            if (activeFocus) {
                                widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "text", text) 
                            }
                        }
                    }
                }
            }

            // Echo Mask Character Input
            Row {
                spacing: Math.round(20 * appTheme.scale)
                Text { 
                    width: Math.round(120 * appTheme.scale)
                    text: "Mask Character"
                    color: appTheme.textSecondary
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale
                    anchors.verticalCenter: parent.verticalCenter 
                }
                
                Rectangle {
                    width: Math.round(40 * appTheme.scale)
                    height: Math.round(26 * appTheme.scale)
                    radius: Math.round(6 * appTheme.scale)
                    color: appTheme.elementBg
                    
                    TextInput { 
                        anchors.fill: parent
                        color: appTheme.textPrimary
                        font.family: "Inter"
                        font.pointSize: 9 * appTheme.scale
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        maximumLength: 1
                        text: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.echoChar !== undefined ? widgetDrawer.activeWidgetData.echoChar : "•"
                        onTextChanged: {
                            if (activeFocus) {
                                widgetDrawer.activeWidgets.setProperty(widgetDrawer.selectedIndex, "echoChar", text) 
                            }
                        }
                    }
                }
            }
            
            Item { width: 1; height: Math.round(18 * appTheme.scale) }
        }
    }
}