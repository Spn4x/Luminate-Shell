import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Luminate.Shell

Item {
    id: editorRoot
    width: AppTheme.screenshotEditWidth
    height: AppTheme.screenshotEditHeight
    focus: Backend.displayMode === "screenshot_edit"
    
    visible: Backend.displayMode === "screenshot_edit"
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    property bool annotateToggle: true
    property bool saveToggle: false
    property bool isAnnotating: canvas.activeMode === 4
    
    property bool uiHidden: canvas.isInteracting 
    property bool isTextMode: canvas.annMode === 5

    // Fullscreen Toggle State
    property bool isMaximized: false
    property int originalWidth: 1100
    property int originalHeight: 620

    onIsMaximizedChanged: {
        if (isMaximized) {
            AppTheme.screenshotEditWidth = Screen.width;
            AppTheme.screenshotEditHeight = Screen.height;
        } else {
            AppTheme.screenshotEditWidth = originalWidth;
            AppTheme.screenshotEditHeight = originalHeight;
        }
    }

    Keys.onPressed: (event) => {
        if (textInputOverlay.visible || confirmDialog.visible) {
            return;
        }

        if (event.key === Qt.Key_Escape) {
            confirmDialog.ask("cancel");
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            if (isAnnotating && canvas.annMode === 6) {
                canvas.deleteSelected();
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
            if (isAnnotating) {
                canvas.pasteFromClipboard();
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
            if (event.modifiers & Qt.ShiftModifier) canvas.redo();
            else canvas.undo();
            event.accepted = true;
        } else if (event.key === Qt.Key_Y && (event.modifiers & Qt.ControlModifier)) {
            canvas.redo();
            event.accepted = true;
        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            if (isAnnotating) {
                confirmDialog.ask("commit");
            } else if (canvas.activeMode === 0) { 
                if (annotateToggle) {
                    canvas.activeMode = 4;
                } else {
                    confirmDialog.ask("commit");
                }
            }
            event.accepted = true;
        }
    }

    Connections {
        target: Backend
        function onWindowScreenshotReady(path) {
            canvas.loadImage(path);
            if (annotateToggle) canvas.activeMode = 4;
        }
        function onScreenshotStateChanged() {
            if (Backend.displayMode === "screenshot_edit") {
                canvas.activeMode = editorRoot.annotateToggle ? 4 : 0;
                editorRoot.isMaximized = false; 
            }
        }
    }

    component SystemIcon: Button {
        property string iconName: ""
        property color iconColor: "white"
        property int size: 24
        width: size; height: size
        icon.name: iconName; icon.color: iconColor
        icon.width: size; icon.height: size
        opacity: 1.0
        background: Item {} 
        focusPolicy: Qt.NoFocus; hoverEnabled: false; down: false
    }

    component ToolBtn: Rectangle {
        id: btnRoot
        property string iconName: ""
        property string text: ""
        property bool isActive: false
        signal clicked()

        width: text !== "" ? (rowLayout.implicitWidth + 24) : 38
        height: 38
        radius: AppTheme.actionRadius
        color: (mouseArea.pressed || isActive) ? AppTheme.actionBgHover : AppTheme.actionBg
        border.color: isActive ? AppTheme.accent : AppTheme.actionBorder
        border.width: 1

        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 6
            SystemIcon {
                iconName: btnRoot.iconName
                iconColor: btnRoot.isActive ? AppTheme.accent : "white"
                size: 16
            }
            Text {
                visible: btnRoot.text !== ""
                text: btnRoot.text
                color: btnRoot.isActive ? AppTheme.accent : "white"
                font.pixelSize: 13
                font.bold: true
            }
        }
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { btnRoot.clicked(); editorRoot.forceActiveFocus(); }
        }
    }

    ScreenshotCanvas {
        id: canvas
        anchors.fill: parent
        
        onVisibleChanged: {
            if (visible) {
                editorRoot.forceActiveFocus();
                loadImage("/tmp/qscreen_overlay.png");
            }
        }
        
        onRegionSelected: {
            if (editorRoot.annotateToggle) {
                canvas.activeMode = 4;
            } else {
                confirmDialog.ask("commit");
            }
        }

        onCaptureFinished: Backend.cancelScreenshot()

        Repeater {
            model: (Backend.displayMode === "screenshot_edit" && canvas.activeMode === 2) ? Backend.ocrResults : 0
            Rectangle {
                property var mappedPos: canvas.mapToScreen(modelData.x, modelData.y)
                property var mappedSize: canvas.mapToScreenSize(modelData.width, modelData.height)
                x: mappedPos.x; y: mappedPos.y; width: mappedSize.x; height: mappedSize.y
                color: "#440077ff"; border.color: "#880077ff"; border.width: 1
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { Backend.copyTextToClipboard(modelData.text); Backend.cancelScreenshot(); }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: textInputOverlay.visible
        onClicked: {
            if (textInputOverlay.text.trim() !== "") {
                canvas.addTextAnnotation(textInputOverlay.imgX, textInputOverlay.imgY, textInputOverlay.text);
            }
            textInputOverlay.text = "";
            textInputOverlay.visible = false;
            editorRoot.forceActiveFocus();
        }
    }

    TextField {
        id: textInputOverlay
        visible: false
        font.pixelSize: Math.round(canvas.textSize * canvas.scaleFactor)
        font.bold: true
        color: canvas.currentColor
        
        background: Rectangle {
            color: "transparent"
            border.color: Qt.rgba(AppTheme.accent.r, AppTheme.accent.g, AppTheme.accent.b, 0.5)
            border.width: 1
            radius: 4
        }
        
        property double imgX: 0
        property double imgY: 0
        
        onVisibleChanged: {
            if (visible) {
                forceActiveFocus();
            }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                if (text.trim() !== "") {
                    canvas.addTextAnnotation(imgX, imgY, text);
                }
                text = "";
                visible = false;
                editorRoot.forceActiveFocus();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                text = "";
                visible = false;
                editorRoot.forceActiveFocus();
                event.accepted = true;
            }
        }
    }
    
    Connections {
        target: canvas
        function onTextPromptRequested(x, y) {
            if (textInputOverlay.visible && textInputOverlay.text.trim() !== "") {
                canvas.addTextAnnotation(textInputOverlay.imgX, textInputOverlay.imgY, textInputOverlay.text);
            }
            let mapped = canvas.mapToScreen(x, y);
            textInputOverlay.imgX = x;
            textInputOverlay.imgY = y;
            textInputOverlay.x = mapped.x;
            textInputOverlay.y = mapped.y - textInputOverlay.font.pixelSize; 
            textInputOverlay.text = "";
            textInputOverlay.visible = true;
        }
        function onScaleChanged() {
            textInputOverlay.font.pixelSize = Math.round(canvas.textSize * canvas.scaleFactor);
        }
    }

    // TOP-LEFT WINDOW CONTROL - Fully distinct overlay
    Rectangle {
        id: maximizeBtn
        z: 100 // Explicitly set as a floating overlay above the canvas
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        width: 42
        height: 42
        radius: AppTheme.actionRadius
        
        // Force completely solid background so it NEVER blends with the image
        color: maMax.pressed ? AppTheme.actionBgHover : Qt.rgba(AppTheme.bg.r, AppTheme.bg.g, AppTheme.bg.b, 1.0)
        border.color: maMax.containsMouse ? AppTheme.accent : AppTheme.borderAlpha
        border.width: 1
        
        visible: !editorRoot.uiHidden
        opacity: editorRoot.uiHidden ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        SystemIcon {
            anchors.centerIn: parent
            iconName: editorRoot.isMaximized ? "window-restore-symbolic" : "window-maximize-symbolic"
            size: 20
            iconColor: maMax.containsMouse ? AppTheme.accent : "white"
        }
        MouseArea {
            id: maMax
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                editorRoot.isMaximized = !editorRoot.isMaximized;
                editorRoot.forceActiveFocus();
            }
        }
    }

    Rectangle {
        id: topBarContainer
        anchors.top: parent.top; anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: topLayout.width + 16; height: topLayout.height + 16
        color: AppTheme.bg
        border.color: AppTheme.borderAlpha; border.width: 1; radius: AppTheme.expandedRadius
        
        y: (editorRoot.visible && !editorRoot.uiHidden) ? 16 : -100 
        opacity: (editorRoot.visible && !editorRoot.uiHidden) ? 1 : 0
        Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        RowLayout {
            id: topLayout
            anchors.centerIn: parent
            spacing: 10

            ToolBtn { iconName: "image-x-generic-symbolic"; isActive: canvas.activeMode === 0; onClicked: canvas.activeMode = 0 }
            ToolBtn { iconName: "window-new-symbolic"; isActive: canvas.activeMode === 1; onClicked: { canvas.activeMode = 1; Backend.fetchNiriWindows(); } }
            ToolBtn { iconName: "edit-find-symbolic"; isActive: canvas.activeMode === 2; onClicked: { canvas.activeMode = 2; Backend.runOcrAsync(); } }
            ToolBtn { iconName: "color-select-symbolic"; isActive: canvas.activeMode === 3; onClicked: canvas.activeMode = 3 }
            
            ToolBtn { 
                iconName: "video-display-symbolic"
                isActive: false
                onClicked: {
                    canvas.selectAll();
                    if (editorRoot.annotateToggle) {
                        canvas.activeMode = 4;
                    } else {
                        confirmDialog.ask("commit");
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: AppTheme.borderAlpha }

            ToolBtn { 
                iconName: "document-edit-symbolic"
                isActive: editorRoot.annotateToggle || canvas.activeMode === 4
                onClicked: {
                    if (canvas.activeMode === 4) canvas.activeMode = 0; 
                    else editorRoot.annotateToggle = !editorRoot.annotateToggle;
                } 
            }
            ToolBtn { 
                iconName: "document-save-symbolic"
                isActive: editorRoot.saveToggle
                onClicked: editorRoot.saveToggle = !editorRoot.saveToggle
            }

            Rectangle { width: 1; height: 24; color: AppTheme.borderAlpha; visible: canvas.activeMode === 4 }

            ToolBtn { visible: canvas.activeMode === 4; iconName: "edit-undo-symbolic"; onClicked: canvas.undo() }
            ToolBtn { visible: canvas.activeMode === 4; iconName: "edit-redo-symbolic"; onClicked: canvas.redo() }

            Rectangle { width: 1; height: 24; color: AppTheme.borderAlpha }

            ToolBtn { 
                iconName: "emblem-ok-symbolic"; 
                isActive: false
                onClicked: {
                    if (isAnnotating) { confirmDialog.ask("commit"); } 
                    else if (canvas.activeMode === 0) {
                        if (annotateToggle) { canvas.activeMode = 4; } 
                        else { confirmDialog.ask("commit"); }
                    }
                }
            }
            ToolBtn { iconName: "window-close-symbolic"; onClicked: confirmDialog.ask("cancel") }
        }
    }

    Rectangle {
        id: bottomBarContainer
        anchors.bottom: parent.bottom; anchors.bottomMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: bottomLayout.width + 16; height: bottomLayout.height + 16
        color: AppTheme.bg
        border.color: AppTheme.borderAlpha; border.width: 1; radius: AppTheme.expandedRadius
        
        visible: canvas.activeMode === 4
        y: (canvas.activeMode === 4 && editorRoot.visible && !editorRoot.uiHidden) ? (parent.height - height - 16) : parent.height + 100
        opacity: (canvas.activeMode === 4 && editorRoot.visible && !editorRoot.uiHidden) ? 1 : 0
        Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        RowLayout {
            id: bottomLayout
            anchors.centerIn: parent
            spacing: 10

            ToolBtn { iconName: "edit-select-symbolic"; isActive: canvas.annMode===6; onClicked: canvas.annMode=6 }
            Rectangle { width: 1; height: 16; color: AppTheme.borderAlpha }

            ToolBtn { iconName: "insert-text-symbolic"; isActive: canvas.annMode===5; onClicked: canvas.annMode=5 }
            ToolBtn { iconName: "document-edit-symbolic"; isActive: canvas.annMode===0; onClicked: canvas.annMode=0 }
            ToolBtn { iconName: "media-playback-stop-symbolic"; isActive: canvas.annMode===1; onClicked: canvas.annMode=1 }
            ToolBtn { iconName: "media-record-symbolic"; isActive: canvas.annMode===2; onClicked: canvas.annMode=2 }
            ToolBtn { iconName: "go-next-symbolic"; isActive: canvas.annMode===3; onClicked: canvas.annMode=3 }
            ToolBtn { iconName: "view-conceal-symbolic"; isActive: canvas.annMode===4; onClicked: canvas.annMode=4 }

            Rectangle { width: 1; height: 16; color: AppTheme.borderAlpha }

            SpinBox {
                id: brushSpinBox
                Layout.preferredWidth: 120
                Layout.preferredHeight: 38
                from: (editorRoot.isTextMode || canvas.isTextSelected) ? 12 : 2
                to: (editorRoot.isTextMode || canvas.isTextSelected) ? 120 : 100
                editable: true

                Connections {
                    target: canvas
                    function onSizeChanged() {
                        if (!editorRoot.isTextMode && !canvas.isTextSelected) {
                            let v = Math.round(canvas.brushSize);
                            if (brushSpinBox.value !== v) brushSpinBox.value = v;
                        }
                    }
                    function onTextSizeChanged() {
                        if (editorRoot.isTextMode || canvas.isTextSelected) {
                            let v = Math.round(canvas.textSize);
                            if (brushSpinBox.value !== v) brushSpinBox.value = v;
                        }
                    }
                    function onSelectionChanged() {
                        if (canvas.annMode === 6) {
                            brushSpinBox.value = Math.round((editorRoot.isTextMode || canvas.isTextSelected) ? canvas.textSize : canvas.brushSize);
                        }
                    }
                }

                Connections {
                    target: editorRoot
                    function onIsTextModeChanged() {
                        brushSpinBox.value = Math.round((editorRoot.isTextMode || canvas.isTextSelected) ? canvas.textSize : canvas.brushSize);
                    }
                }

                Component.onCompleted: {
                    brushSpinBox.value = Math.round((editorRoot.isTextMode || canvas.isTextSelected) ? canvas.textSize : canvas.brushSize);
                }

                onValueModified: {
                    if (editorRoot.isTextMode || canvas.isTextSelected) {
                        if (canvas.textSize !== value) canvas.textSize = value;
                    } else {
                        if (canvas.brushSize !== value) canvas.brushSize = value;
                    }
                }

                contentItem: TextInput {
                    z: 2
                    text: brushSpinBox.value
                    font.pixelSize: 13
                    font.bold: true
                    color: "white"
                    selectionColor: AppTheme.accent
                    selectedTextColor: "black"
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    readOnly: !brushSpinBox.editable
                    validator: brushSpinBox.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    
                    leftPadding: 30
                    rightPadding: 30
                    
                    onTextEdited: {
                        let v = parseInt(text);
                        if (!isNaN(v)) {
                            brushSpinBox.value = v;
                            if (editorRoot.isTextMode || canvas.isTextSelected) {
                                if (canvas.textSize !== v) canvas.textSize = v;
                            } else {
                                if (canvas.brushSize !== v) canvas.brushSize = v;
                            }
                        }
                    }
                }

                up.indicator: Rectangle {
                    x: brushSpinBox.mirrored ? 0 : brushSpinBox.width - width
                    height: brushSpinBox.height
                    implicitWidth: 30
                    color: brushSpinBox.up.pressed ? AppTheme.actionBgHover : "transparent"
                    radius: AppTheme.actionRadius
                    Text { text: "+"; font.pixelSize: 16; font.bold: true; color: "white"; anchors.centerIn: parent }
                }

                down.indicator: Rectangle {
                    x: brushSpinBox.mirrored ? brushSpinBox.width - width : 0
                    height: brushSpinBox.height
                    implicitWidth: 30
                    color: brushSpinBox.down.pressed ? AppTheme.actionBgHover : "transparent"
                    radius: AppTheme.actionRadius
                    Text { text: "-"; font.pixelSize: 16; font.bold: true; color: "white"; anchors.centerIn: parent }
                }

                background: Rectangle {
                    radius: AppTheme.actionRadius
                    color: AppTheme.actionBg
                    border.color: AppTheme.actionBorder
                    border.width: 1
                }
            }

            Rectangle { 
                width: 1; height: 16; color: AppTheme.borderAlpha 
                visible: canvas.annMode === 6 && canvas.hasSelection 
            }

            SpinBox {
                id: rotationSpinBox
                visible: canvas.annMode === 6 && canvas.hasSelection
                Layout.preferredWidth: 100
                Layout.preferredHeight: 38
                from: -180
                to: 180
                editable: true

                Connections {
                    target: canvas
                    function onRotationChanged() {
                        let v = Math.round(canvas.currentRotation);
                        if (rotationSpinBox.value !== v) rotationSpinBox.value = v;
                    }
                }

                onValueModified: {
                    if (Math.round(canvas.currentRotation) !== value) {
                        canvas.currentRotation = value;
                    }
                }

                contentItem: TextInput {
                    z: 2
                    text: rotationSpinBox.value + "°"
                    font.pixelSize: 13
                    font.bold: true
                    color: "white"
                    selectionColor: AppTheme.accent
                    selectedTextColor: "black"
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    readOnly: !rotationSpinBox.editable
                    validator: RegularExpressionValidator { regularExpression: /^-?\d+°?$/ }
                    
                    leftPadding: 30
                    rightPadding: 30
                    
                    onTextEdited: {
                        let clean = text.replace("°", "");
                        let v = parseInt(clean);
                        if (!isNaN(v)) {
                            rotationSpinBox.value = v;
                            canvas.currentRotation = v;
                        }
                    }
                }

                up.indicator: Rectangle {
                    x: rotationSpinBox.mirrored ? 0 : rotationSpinBox.width - width
                    height: rotationSpinBox.height
                    implicitWidth: 30
                    color: rotationSpinBox.up.pressed ? AppTheme.actionBgHover : "transparent"
                    radius: AppTheme.actionRadius
                    Text { text: "+"; font.pixelSize: 16; font.bold: true; color: "white"; anchors.centerIn: parent }
                }

                down.indicator: Rectangle {
                    x: rotationSpinBox.mirrored ? rotationSpinBox.width - width : 0
                    height: rotationSpinBox.height
                    implicitWidth: 30
                    color: rotationSpinBox.down.pressed ? AppTheme.actionBgHover : "transparent"
                    radius: AppTheme.actionRadius
                    Text { text: "-"; font.pixelSize: 16; font.bold: true; color: "white"; anchors.centerIn: parent }
                }

                background: Rectangle {
                    radius: AppTheme.actionRadius
                    color: AppTheme.actionBg
                    border.color: AppTheme.actionBorder
                    border.width: 1
                }
            }

            Rectangle { width: 1; height: 16; color: AppTheme.borderAlpha }

            Repeater {
                model: ["#ffffff", "#000000", "#ff3333", "#33ff33", "#3333ff", "#ffff33"]
                Rectangle {
                    width: 24; height: 24; radius: 12
                    color: modelData
                    border.color: canvas.currentColor.toString() === modelData ? "white" : "transparent"
                    border.width: 2
                    MouseArea { anchors.fill: parent; onClicked: canvas.currentColor = modelData }
                }
            }
        }
    }

    Rectangle {
        id: pickerContainer
        anchors.centerIn: parent
        width: 320; height: Math.min(niriList.contentHeight + 20, 400)
        color: AppTheme.bg
        border.color: AppTheme.borderAlpha; border.width: 1; radius: 12
        visible: canvas.activeMode === 1
        
        opacity: (canvas.activeMode === 1 && editorRoot.visible && !editorRoot.uiHidden) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        ListView {
            id: niriList
            anchors.fill: parent; anchors.margins: 10
            clip: true; model: Backend.niriWindows; spacing: 4
            delegate: Rectangle {
                width: ListView.view.width; height: 42; radius: 8
                color: winMa.containsMouse ? AppTheme.actionBgHover : "transparent"
                Text {
                    anchors.centerIn: parent; text: modelData.title
                    color: AppTheme.fg; font.bold: true; width: parent.width - 20; elide: Text.ElideRight
                }
                MouseArea {
                    id: winMa
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        Backend.captureNiriWindow(modelData.id, editorRoot.annotateToggle);
                    }
                }
            }
        }
    }

    // Modal Confirmation Dialog
    Rectangle {
        id: confirmDialog
        anchors.fill: parent
        color: "#88000000"
        visible: false
        z: 999

        property string pendingAction: ""

        function ask(action) {
            pendingAction = action;
            visible = true;
            yesBtn.forceActiveFocus();
        }

        MouseArea { anchors.fill: parent; onClicked: {} } // Block clicks behind dialog

        Rectangle {
            anchors.centerIn: parent
            width: 306  // 15% Reduction in width (down from 360)
            height: 110
            color: AppTheme.bg
            border.color: AppTheme.borderAlpha
            border.width: 1
            radius: AppTheme.expandedRadius

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: confirmDialog.pendingAction === "commit" ? "Save and copy screenshot?" : "Cancel screenshot?"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                RowLayout {
                    spacing: 16
                    Layout.alignment: Qt.AlignHCenter

                    Rectangle {
                        id: yesBtn
                        Layout.preferredWidth: 110
                        Layout.preferredHeight: 42
                        radius: AppTheme.actionRadius
                        
                        // Gorgeous Focus Styling with colored outline and subtle tint
                        color: activeFocus ? Qt.rgba(AppTheme.accent.r, AppTheme.accent.g, AppTheme.accent.b, 0.2) : (maYes.pressed ? AppTheme.actionBgHover : AppTheme.actionBg)
                        border.color: activeFocus ? AppTheme.accent : AppTheme.actionBorder
                        border.width: activeFocus ? 2 : 1
                        
                        Text { 
                            anchors.centerIn: parent; text: "Yes"; 
                            color: yesBtn.activeFocus ? AppTheme.accent : "white";
                            font.bold: true; font.pixelSize: 14 
                        }
                        
                        MouseArea {
                            id: maYes; anchors.fill: parent; hoverEnabled: true
                            onClicked: confirmDialog.executeYes()
                        }
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                                confirmDialog.executeYes();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                                noBtn.forceActiveFocus();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                confirmDialog.executeNo();
                                event.accepted = true;
                            }
                        }
                    }

                    Rectangle {
                        id: noBtn
                        Layout.preferredWidth: 110
                        Layout.preferredHeight: 42
                        radius: AppTheme.actionRadius
                        
                        // Gorgeous Focus Styling with colored outline and subtle tint
                        color: activeFocus ? Qt.rgba(AppTheme.accent.r, AppTheme.accent.g, AppTheme.accent.b, 0.2) : (maNo.pressed ? AppTheme.actionBgHover : AppTheme.actionBg)
                        border.color: activeFocus ? AppTheme.accent : AppTheme.actionBorder
                        border.width: activeFocus ? 2 : 1
                        
                        Text { 
                            anchors.centerIn: parent; text: "No"; 
                            color: noBtn.activeFocus ? AppTheme.accent : "white"; 
                            font.bold: true; font.pixelSize: 14 
                        }
                        
                        MouseArea {
                            id: maNo; anchors.fill: parent; hoverEnabled: true
                            onClicked: confirmDialog.executeNo()
                        }
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                                confirmDialog.executeNo();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Tab) {
                                yesBtn.forceActiveFocus();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                confirmDialog.executeNo();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }
        }

        function executeYes() {
            visible = false;
            if (pendingAction === "commit") {
                canvas.processFinalImage(editorRoot.saveToggle);
                Backend.cancelScreenshot();
            } else if (pendingAction === "cancel") {
                Backend.cancelScreenshot();
            }
        }

        function executeNo() {
            visible = false;
            editorRoot.forceActiveFocus();
        }
    }
}