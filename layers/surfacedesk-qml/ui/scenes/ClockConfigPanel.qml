import QtQuick
import QtQuick.Controls
import ".."

Column {
    id: clockConfig
    spacing: Math.round(14 * appTheme.scale)
    width: parent ? parent.width : 200

    property string expandedAccordion: "" 

    signal propertyChanged(string name, var value)

    function setModelProp(name, val) { 
        clockConfig.propertyChanged(name, val);
    }

    function getActiveFontFamily() {
        if (!widgetDrawer.activeWidgetData || widgetDrawer.activeWidgetData.fontFamily === undefined) return "system-ui";
        return widgetDrawer.activeWidgetData.fontFamily.split(':')[0];
    }

    function getActiveDateFontFamily() {
        if (!widgetDrawer.activeWidgetData || widgetDrawer.activeWidgetData.dateFontFamily === undefined) return "system-ui";
        return widgetDrawer.activeWidgetData.dateFontFamily.split(':')[0];
    }

    function getActiveTimeColorIndex() { 
        return widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.timeColorIndex !== undefined ? widgetDrawer.activeWidgetData.timeColorIndex : 8; 
    }

    function getActiveDateColorIndex() { 
        return widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.dateColorIndex !== undefined ? widgetDrawer.activeWidgetData.dateColorIndex : 5; 
    }

    function getWeightLabel(w) {
        if (w <= 150) return "Thin (100)";
        if (w <= 250) return "ExtraLight (200)";
        if (w <= 350) return "Light (300)";
        if (w <= 450) return "Normal (400)";
        if (w <= 550) return "Medium (500)";
        if (w <= 650) return "DemiBold (600)";
        if (w <= 750) return "Bold (700)";
        if (w <= 850) return "ExtraBold (800)";
        return "Black (900)";
    }

    function getActiveFontWeight() {
        if (!widgetDrawer.activeWidgetData || widgetDrawer.activeWidgetData.fontFamily === undefined) return 800;
        let parts = widgetDrawer.activeWidgetData.fontFamily.split(':');
        if (parts.length > 1) {
            let w = parseInt(parts[1]);
            if (!isNaN(w)) return w;
        }
        return 800;
    }

    function getActiveDateFontWeight() {
        if (!widgetDrawer.activeWidgetData || widgetDrawer.activeWidgetData.dateFontFamily === undefined) return 600;
        let parts = widgetDrawer.activeWidgetData.dateFontFamily.split(':');
        if (parts.length > 1) {
            let w = parseInt(parts[1]);
            if (!isNaN(w)) return w;
        }
        return 600;
    }

    function getActiveTimeOpacity() {
        if (!widgetDrawer.activeWidgetData || widgetDrawer.activeWidgetData.timeOpacity === undefined) return 1.0;
        return widgetDrawer.activeWidgetData.timeOpacity;
    }

    function getActiveDateOpacity() {
        if (!widgetDrawer.activeWidgetData || widgetDrawer.activeWidgetData.dateOpacity === undefined) return 0.7;
        return widgetDrawer.activeWidgetData.dateOpacity;
    }

    function queryInstalledFonts() {
        let wishlist = ["Ubuntu", "Cantarell", "system-ui", "Inter", "JetBrains Mono", "Lexend", "monospace", "Roboto", "Fira Code", "DejaVu Sans"];
        let sysList = Qt.fontFamilies();
        let output = [];
        for (let i = 0; i < wishlist.length; ++i) {
            if (sysList.indexOf(wishlist[i]) !== -1) {
                output.push(wishlist[i]);
            }
        }
        if (output.indexOf("system-ui") === -1) output.unshift("system-ui");
        if (output.indexOf("monospace") === -1) output.push("monospace");
        return output;
    }

    function getUniqueWeightsForFamily(family) {
        if (!wallpaperBackend || !family) return [100, 300, 400, 500, 600, 700, 800, 900];
        let styles = wallpaperBackend.getFontStyles(family);
        if (styles.length === 0) {
            return [100, 300, 400, 500, 600, 700, 800, 900];
        }
        
        let weightsMap = {};
        for (let i = 0; i < styles.length; ++i) {
            let w = wallpaperBackend.getFontWeight(family, styles[i]);
            if (w > 0) {
                weightsMap[w] = true;
            }
        }
        
        let uniqueList = Object.keys(weightsMap).map(Number).sort((a, b) => a - b);
        if (uniqueList.length === 0) {
            return [100, 300, 400, 500, 600, 700, 800, 900];
        }
        return uniqueList;
    }

    // --- 1. Grid Size ---
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
                        activeFocusOnTab: true
                        selectByMouse: true
                        validator: IntValidator { bottom: 1; top: 20 }
                        text: widgetDrawer.activeWidgetData ? String(widgetDrawer.activeWidgetData.grid_w) : "4"
                        onEditingFinished: {
                            let val = parseInt(text);
                            if (!isNaN(val)) {
                                clockConfig.setModelProp("grid_w", Math.max(1, Math.min(20, val)));
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
                                clockConfig.setModelProp("grid_w", Math.max(1, widgetDrawer.activeWidgetData.grid_w - 1));
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
                                clockConfig.setModelProp("grid_w", Math.min(20, widgetDrawer.activeWidgetData.grid_w + 1));
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
                        activeFocusOnTab: true
                        selectByMouse: true
                        validator: IntValidator { bottom: 1; top: 20 }
                        text: widgetDrawer.activeWidgetData ? String(widgetDrawer.activeWidgetData.grid_h) : "2"
                        onEditingFinished: {
                            let val = parseInt(text);
                            if (!isNaN(val)) {
                                clockConfig.setModelProp("grid_h", Math.max(1, Math.min(20, val)));
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
                                clockConfig.setModelProp("grid_h", Math.max(1, widgetDrawer.activeWidgetData.grid_h - 1));
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
                                clockConfig.setModelProp("grid_h", Math.min(20, widgetDrawer.activeWidgetData.grid_h + 1));
                            }
                        }
                    }
                }
            }
        }
    }

    // --- 2. Inner Padding ---
    Row {
        spacing: Math.round(20 * appTheme.scale)
        Text { 
            width: Math.round(120 * appTheme.scale)
            text: "Inner Padding"
            color: appTheme.textSecondary
            font.family: "Inter"
            font.pointSize: 10 * appTheme.scale
            anchors.verticalCenter: parent.verticalCenter 
        }
        
        Row {
            spacing: Math.round(4 * appTheme.scale)
            
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
                    activeFocusOnTab: true
                    selectByMouse: true
                    validator: IntValidator { bottom: 0; top: 60 }
                    text: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.padding !== undefined ? String(widgetDrawer.activeWidgetData.padding) : "0"
                    onEditingFinished: {
                        let val = parseInt(text);
                        if (!isNaN(val)) {
                            clockConfig.setModelProp("padding", Math.max(0, Math.min(60, val)));
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
                            clockConfig.setModelProp("padding", Math.max(0, (widgetDrawer.activeWidgetData.padding || 0) - 2));
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
                            clockConfig.setModelProp("padding", Math.min(60, (widgetDrawer.activeWidgetData.padding || 0) + 2));
                        }
                    }
                }
            }
        }
    }

    // --- 3. Transparent ---
    Row {
        spacing: Math.round(20 * appTheme.scale)
        Text { 
            width: Math.round(120 * appTheme.scale)
            text: "Transparent"
            color: appTheme.textSecondary
            font.family: "Inter"
            font.pointSize: 10 * appTheme.scale
            anchors.verticalCenter: parent.verticalCenter 
        }
        
        Rectangle {
            id: transTrack
            width: Math.round(44 * appTheme.scale)
            height: Math.round(24 * appTheme.scale)
            radius: Math.round(12 * appTheme.scale)
            property bool isChecked: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.transparent !== undefined ? widgetDrawer.activeWidgetData.transparent : true
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
                onClicked: clockConfig.setModelProp("transparent", !transTrack.isChecked) 
            }
        }
    }

    // --- 4. Date Margin ---
    Row {
        spacing: Math.round(20 * appTheme.scale)
        Text { 
            width: Math.round(120 * appTheme.scale)
            text: "Date Margin"
            color: appTheme.textSecondary
            font.family: "Inter"
            font.pointSize: 10 * appTheme.scale
            anchors.verticalCenter: parent.verticalCenter 
        }
        
        Row {
            spacing: Math.round(4 * appTheme.scale)
            
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
                    activeFocusOnTab: true
                    selectByMouse: true
                    validator: IntValidator { bottom: -60; top: 60 }
                    text: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.dateSpacing !== undefined ? String(widgetDrawer.activeWidgetData.dateSpacing) : "4"
                    onEditingFinished: {
                        let val = parseInt(text);
                        if (!isNaN(val)) clockConfig.setModelProp("dateSpacing", Math.max(-60, Math.min(60, val)));
                    }
                }
            }
            
            Rectangle { 
                width: Math.round(26 * appTheme.scale); height: Math.round(26 * appTheme.scale); radius: Math.round(6 * appTheme.scale); color: appTheme.elementBg 
                Text { text: "-"; color: appTheme.textPrimary; font.pointSize: 11 * appTheme.scale; font.bold: true; anchors.centerIn: parent }
                MouseArea { anchors.fill: parent; onClicked: if (widgetDrawer.activeWidgetData) clockConfig.setModelProp("dateSpacing", Math.max(-60, (widgetDrawer.activeWidgetData.dateSpacing || 4) - 2)); }
            }
            
            Rectangle { 
                width: Math.round(26 * appTheme.scale); height: Math.round(26 * appTheme.scale); radius: Math.round(6 * appTheme.scale); color: appTheme.elementBg 
                Text { text: "+"; color: appTheme.textPrimary; font.pointSize: 11 * appTheme.scale; font.bold: true; anchors.centerIn: parent }
                MouseArea { anchors.fill: parent; onClicked: if (widgetDrawer.activeWidgetData) clockConfig.setModelProp("dateSpacing", Math.min(60, (widgetDrawer.activeWidgetData.dateSpacing || 4) + 2)); }
            }
        }
    }

    // --- 5. Time Color Matrix Accordion ---
    Rectangle {
        id: timeColorAccordionContainer
        width: parent.width
        height: timeColorAccordion.expanded ? (Math.round(36 * appTheme.scale) + timeColorGrid.implicitHeight + Math.round(16 * appTheme.scale)) : Math.round(36 * appTheme.scale)
        color: "transparent"
        border.color: appTheme.borderSubtle
        border.width: 1
        radius: Math.round(8 * appTheme.scale)
        clip: true

        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        Column {
            id: timeColorAccordion
            width: parent.width
            property bool expanded: clockConfig.expandedAccordion === "timeColor"

            Item {
                id: timeColorAccordionHeader
                width: parent.width
                height: Math.round(36 * appTheme.scale)

                MouseArea {
                    anchors.fill: parent
                    onClicked: clockConfig.expandedAccordion = (clockConfig.expandedAccordion === "timeColor") ? "" : "timeColor"
                }

                Text { 
                    text: "Time Color" 
                    color: appTheme.textSecondary 
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale 
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter 
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(8 * appTheme.scale)

                    Rectangle {
                        width: Math.round(16 * appTheme.scale)
                        height: Math.round(16 * appTheme.scale)
                        radius: Math.round(8 * appTheme.scale)
                        color: (wallpaperBackend && wallpaperBackend.wallpaperPalette.length > clockConfig.getActiveTimeColorIndex()) ? wallpaperBackend.wallpaperPalette[clockConfig.getActiveTimeColorIndex()] : "#FFFFFF"
                        border.color: Qt.rgba(255,255,255,0.2)
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text { 
                        text: timeColorAccordion.expanded ? "-" : "+"
                        color: appTheme.textPrimary
                        font.pointSize: 12 * appTheme.scale
                        font.bold: true
                        font.family: "monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Item {
                width: parent.width - Math.round(24 * appTheme.scale)
                height: timeColorGrid.implicitHeight + Math.round(16 * appTheme.scale)
                x: Math.round(12 * appTheme.scale)
                visible: opacity > 0.0
                opacity: timeColorAccordion.expanded ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Grid {
                    id: timeColorGrid
                    columns: 7
                    spacing: Math.round(8 * appTheme.scale)
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(4 * appTheme.scale)
                    
                    Repeater {
                        model: wallpaperBackend ? wallpaperBackend.wallpaperPalette : []
                        Rectangle {
                            width: Math.round(24 * appTheme.scale)
                            height: Math.round(24 * appTheme.scale)
                            radius: Math.round(12 * appTheme.scale)
                            color: modelData
                            border.color: clockConfig.getActiveTimeColorIndex() === index ? appTheme.textPrimary : Qt.rgba(255,255,255,0.1)
                            border.width: clockConfig.getActiveTimeColorIndex() === index ? 2 : 1
                            MouseArea { 
                                anchors.fill: parent; 
                                onClicked: {
                                    clockConfig.setModelProp("timeColorIndex", index);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- 6. Date Color Matrix Accordion ---
    Rectangle {
        id: dateColorAccordionContainer
        width: parent.width
        height: dateColorAccordion.expanded ? (Math.round(36 * appTheme.scale) + dateColorGrid.implicitHeight + Math.round(16 * appTheme.scale)) : Math.round(36 * appTheme.scale)
        color: "transparent"
        border.color: appTheme.borderSubtle
        border.width: 1
        radius: Math.round(8 * appTheme.scale)
        clip: true

        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        Column {
            id: dateColorAccordion
            width: parent.width
            property bool expanded: clockConfig.expandedAccordion === "dateColor"

            Item {
                id: dateColorAccordionHeader
                width: parent.width
                height: Math.round(36 * appTheme.scale)

                MouseArea {
                    anchors.fill: parent
                    onClicked: clockConfig.expandedAccordion = (clockConfig.expandedAccordion === "dateColor") ? "" : "dateColor"
                }

                Text { 
                    text: "Date Color" 
                    color: appTheme.textSecondary 
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale 
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter 
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(8 * appTheme.scale)

                    Rectangle {
                        width: Math.round(16 * appTheme.scale)
                        height: Math.round(16 * appTheme.scale)
                        radius: Math.round(8 * appTheme.scale)
                        color: (wallpaperBackend && wallpaperBackend.wallpaperPalette.length > clockConfig.getActiveDateColorIndex()) ? wallpaperBackend.wallpaperPalette[clockConfig.getActiveDateColorIndex()] : "#FFFFFF"
                        border.color: Qt.rgba(255,255,255,0.2)
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text { 
                        text: dateColorAccordion.expanded ? "-" : "+"
                        color: appTheme.textPrimary
                        font.pointSize: 12 * appTheme.scale
                        font.bold: true
                        font.family: "monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Item {
                width: parent.width - Math.round(24 * appTheme.scale)
                height: dateColorGrid.implicitHeight + Math.round(16 * appTheme.scale)
                x: Math.round(12 * appTheme.scale)
                visible: opacity > 0.0
                opacity: dateColorAccordion.expanded ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Grid {
                    id: dateColorGrid
                    columns: 7
                    spacing: Math.round(8 * appTheme.scale)
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(4 * appTheme.scale)
                    
                    Repeater {
                        model: wallpaperBackend ? wallpaperBackend.wallpaperPalette : []
                        Rectangle {
                            width: Math.round(24 * appTheme.scale)
                            height: Math.round(24 * appTheme.scale)
                            radius: Math.round(12 * appTheme.scale)
                            color: modelData
                            border.color: clockConfig.getActiveDateColorIndex() === index ? appTheme.textPrimary : Qt.rgba(255,255,255,0.1)
                            border.width: clockConfig.getActiveDateColorIndex() === index ? 2 : 1
                            MouseArea { 
                                anchors.fill: parent; 
                                onClicked: {
                                    clockConfig.setModelProp("dateColorIndex", index);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- 7. Time Font Style (Accordion) ---
    Rectangle {
        id: timeFontStyleAccordionContainer
        width: parent.width
        height: timeFontStyleAccordion.expanded ? (Math.round(36 * appTheme.scale) + timeStyleListColumn.implicitHeight) : Math.round(36 * appTheme.scale)
        color: "transparent"
        border.color: appTheme.borderSubtle
        border.width: 1
        radius: Math.round(8 * appTheme.scale)
        clip: true

        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        Column {
            id: timeFontStyleAccordion
            width: parent.width
            property bool expanded: clockConfig.expandedAccordion === "timeStyle"

            Item {
                id: timeFontStyleAccordionHeader
                width: parent.width
                height: Math.round(36 * appTheme.scale)

                MouseArea {
                    anchors.fill: parent
                    onClicked: clockConfig.expandedAccordion = (clockConfig.expandedAccordion === "timeStyle") ? "" : "timeStyle"
                }

                Text { 
                    text: "Time Font Style" 
                    color: appTheme.textSecondary 
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale 
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter 
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(8 * appTheme.scale)

                    Text { 
                        text: clockConfig.getActiveFontFamily()
                        color: appTheme.accent
                        font.family: "Inter"
                        font.pointSize: 9 * appTheme.scale
                        anchors.verticalCenter: parent.verticalCenter 
                    }

                    Text { 
                        text: timeFontStyleAccordion.expanded ? "-" : "+"
                        color: appTheme.textPrimary
                        font.pointSize: 12 * appTheme.scale
                        font.bold: true
                        font.family: "monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Column {
                id: timeStyleListColumn
                width: parent.width - Math.round(20 * appTheme.scale)
                x: Math.round(10 * appTheme.scale)
                visible: opacity > 0.0
                opacity: timeFontStyleAccordion.expanded ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                spacing: Math.round(4 * appTheme.scale)

                Repeater {
                    model: clockConfig.queryInstalledFonts()
                    delegate: Rectangle {
                        width: parent.width
                        height: Math.round(28 * appTheme.scale)
                        radius: Math.round(6 * appTheme.scale)
                        color: "transparent"
                        border.width: 0

                        Text { 
                            text: modelData
                            color: clockConfig.getActiveFontFamily() === modelData ? appTheme.accent : (timeStyleItemMouse.containsMouse ? appTheme.textPrimary : appTheme.textSecondary)
                            font.family: "Inter"
                            font.pointSize: 9 * appTheme.scale
                            font.bold: clockConfig.getActiveFontFamily() === modelData
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(10 * appTheme.scale) 
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        MouseArea { 
                            id: timeStyleItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                let availableWeights = clockConfig.getUniqueWeightsForFamily(modelData);
                                let currentWeight = clockConfig.getActiveFontWeight();
                                let targetWeight = availableWeights.indexOf(currentWeight) !== -1 ? currentWeight : availableWeights[0];
                                
                                clockConfig.propertyChanged("fontFamily", modelData + ":" + targetWeight);
                                clockConfig.expandedAccordion = "";
                            }
                        }
                    }
                }

                Item { width: 1; height: Math.round(10 * appTheme.scale) }
            }
        }
    }

    // --- 8. Time Font Weight (Deduplicated Accordion) ---
    Rectangle {
        id: timeFontWeightAccordionContainer
        width: parent.width
        height: timeFontWeightAccordion.expanded ? (Math.round(36 * appTheme.scale) + timeWeightListColumn.implicitHeight) : Math.round(36 * appTheme.scale)
        color: "transparent"
        border.color: appTheme.borderSubtle
        border.width: 1
        radius: Math.round(8 * appTheme.scale)
        clip: true

        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        Column {
            id: timeFontWeightAccordion
            width: parent.width
            property bool expanded: clockConfig.expandedAccordion === "timeWeight"

            Item {
                id: timeFontWeightAccordionHeader
                width: parent.width
                height: Math.round(36 * appTheme.scale)

                MouseArea {
                    anchors.fill: parent
                    onClicked: clockConfig.expandedAccordion = (clockConfig.expandedAccordion === "timeWeight") ? "" : "timeWeight"
                }

                Text { 
                    text: "Time Font Weight" 
                    color: appTheme.textSecondary 
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale 
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter 
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(8 * appTheme.scale)

                    Text { 
                        text: clockConfig.getWeightLabel(clockConfig.getActiveFontWeight())
                        color: appTheme.accent
                        font.family: "Inter"
                        font.pointSize: 9 * appTheme.scale
                        anchors.verticalCenter: parent.verticalCenter 
                    }

                    Text { 
                        text: timeFontWeightAccordion.expanded ? "-" : "+"
                        color: appTheme.textPrimary
                        font.pointSize: 12 * appTheme.scale
                        font.bold: true
                        font.family: "monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Column {
                id: timeWeightListColumn
                width: parent.width - Math.round(20 * appTheme.scale)
                x: Math.round(10 * appTheme.scale)
                visible: opacity > 0.0
                opacity: timeFontWeightAccordion.expanded ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                spacing: Math.round(4 * appTheme.scale)

                Repeater {
                    model: clockConfig.getUniqueWeightsForFamily(clockConfig.getActiveFontFamily())
                    delegate: Rectangle {
                        width: parent.width
                        height: Math.round(28 * appTheme.scale)
                        radius: Math.round(6 * appTheme.scale)
                        color: "transparent"
                        border.width: 0

                        Text { 
                            text: clockConfig.getWeightLabel(modelData)
                            color: clockConfig.getActiveFontWeight() === modelData ? appTheme.accent : (timeWeightItemMouse.containsMouse ? appTheme.textPrimary : appTheme.textSecondary)
                            font.family: "Inter"
                            font.pointSize: 9 * appTheme.scale
                            font.bold: clockConfig.getActiveFontWeight() === modelData
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(10 * appTheme.scale) 
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        MouseArea { 
                            id: timeWeightItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                clockConfig.propertyChanged("fontFamily", clockConfig.getActiveFontFamily() + ":" + modelData);
                                clockConfig.expandedAccordion = "";
                            }
                        }
                    }
                }

                Item { width: 1; height: Math.round(10 * appTheme.scale) }
            }
        }
    }
    
    // --- 9. Date Font Style (Accordion) ---
    Rectangle {
        id: dateFontStyleAccordionContainer
        width: parent.width
        height: dateFontStyleAccordion.expanded ? (Math.round(36 * appTheme.scale) + dateStyleListColumn.implicitHeight) : Math.round(36 * appTheme.scale)
        color: "transparent"
        border.color: appTheme.borderSubtle
        border.width: 1
        radius: Math.round(8 * appTheme.scale)
        clip: true

        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        Column {
            id: dateFontStyleAccordion
            width: parent.width
            property bool expanded: clockConfig.expandedAccordion === "dateStyle"

            Item {
                id: dateFontStyleAccordionHeader
                width: parent.width
                height: Math.round(36 * appTheme.scale)

                MouseArea {
                    anchors.fill: parent
                    onClicked: clockConfig.expandedAccordion = (clockConfig.expandedAccordion === "dateStyle") ? "" : "dateStyle"
                }

                Text { 
                    text: "Date Font Style" 
                    color: appTheme.textSecondary 
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale 
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter 
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(8 * appTheme.scale)

                    Text { 
                        text: clockConfig.getActiveDateFontFamily()
                        color: appTheme.accent
                        font.family: "Inter"
                        font.pointSize: 9 * appTheme.scale
                        anchors.verticalCenter: parent.verticalCenter 
                    }

                    Text { 
                        text: dateFontStyleAccordion.expanded ? "-" : "+"
                        color: appTheme.textPrimary
                        font.pointSize: 12 * appTheme.scale
                        font.bold: true
                        font.family: "monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Column {
                id: dateStyleListColumn
                width: parent.width - Math.round(20 * appTheme.scale)
                x: Math.round(10 * appTheme.scale)
                visible: opacity > 0.0
                opacity: dateFontStyleAccordion.expanded ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                spacing: Math.round(4 * appTheme.scale)

                Repeater {
                    model: clockConfig.queryInstalledFonts()
                    delegate: Rectangle {
                        width: parent.width
                        height: Math.round(28 * appTheme.scale)
                        radius: Math.round(6 * appTheme.scale)
                        color: "transparent"
                        border.width: 0

                        Text { 
                            text: modelData
                            color: clockConfig.getActiveDateFontFamily() === modelData ? appTheme.accent : (dateStyleItemMouse.containsMouse ? appTheme.textPrimary : appTheme.textSecondary)
                            font.family: "Inter"
                            font.pointSize: 9 * appTheme.scale
                            font.bold: clockConfig.getActiveDateFontFamily() === modelData
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(10 * appTheme.scale) 
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        MouseArea { 
                            id: dateStyleItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                let availableWeights = clockConfig.getUniqueWeightsForFamily(modelData);
                                let currentWeight = clockConfig.getActiveDateFontWeight();
                                let targetWeight = availableWeights.indexOf(currentWeight) !== -1 ? currentWeight : availableWeights[0];
                                
                                clockConfig.propertyChanged("dateFontFamily", modelData + ":" + targetWeight);
                                clockConfig.expandedAccordion = "";
                            }
                        }
                    }
                }

                Item { width: 1; height: Math.round(10 * appTheme.scale) }
            }
        }
    }

    // --- 10. Date Font Weight (Deduplicated Accordion) ---
    Rectangle {
        id: dateFontWeightAccordionContainer
        width: parent.width
        height: dateFontWeightAccordion.expanded ? (Math.round(36 * appTheme.scale) + dateWeightListColumn.implicitHeight) : Math.round(36 * appTheme.scale)
        color: "transparent"
        border.color: appTheme.borderSubtle
        border.width: 1
        radius: Math.round(8 * appTheme.scale)
        clip: true

        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        Column {
            id: dateFontWeightAccordion
            width: parent.width
            property bool expanded: clockConfig.expandedAccordion === "dateWeight"

            Item {
                id: dateFontWeightAccordionHeader
                width: parent.width
                height: Math.round(36 * appTheme.scale)

                MouseArea {
                    anchors.fill: parent
                    onClicked: clockConfig.expandedAccordion = (clockConfig.expandedAccordion === "dateWeight") ? "" : "dateWeight"
                }

                Text { 
                    text: "Date Font Weight" 
                    color: appTheme.textSecondary 
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale 
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter 
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(8 * appTheme.scale)

                    Text { 
                        text: clockConfig.getWeightLabel(clockConfig.getActiveDateFontWeight())
                        color: appTheme.accent
                        font.family: "Inter"
                        font.pointSize: 9 * appTheme.scale
                        anchors.verticalCenter: parent.verticalCenter 
                    }

                    Text { 
                        text: dateFontWeightAccordion.expanded ? "-" : "+"
                        color: appTheme.textPrimary
                        font.pointSize: 12 * appTheme.scale
                        font.bold: true
                        font.family: "monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Column {
                id: dateWeightListColumn
                width: parent.width - Math.round(20 * appTheme.scale)
                x: Math.round(10 * appTheme.scale)
                visible: opacity > 0.0
                opacity: dateFontWeightAccordion.expanded ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                spacing: Math.round(4 * appTheme.scale)

                Repeater {
                    model: clockConfig.getUniqueWeightsForFamily(clockConfig.getActiveDateFontFamily())
                    delegate: Rectangle {
                        width: parent.width
                        height: Math.round(28 * appTheme.scale)
                        radius: Math.round(6 * appTheme.scale)
                        color: "transparent"
                        border.width: 0

                        Text { 
                            text: clockConfig.getWeightLabel(modelData)
                            color: clockConfig.getActiveDateFontWeight() === modelData ? appTheme.accent : (dateWeightItemMouse.containsMouse ? appTheme.textPrimary : appTheme.textSecondary)
                            font.family: "Inter"
                            font.pointSize: 9 * appTheme.scale
                            font.bold: clockConfig.getActiveDateFontWeight() === modelData
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(10 * appTheme.scale) 
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        MouseArea { 
                            id: dateWeightItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                clockConfig.propertyChanged("dateFontFamily", clockConfig.getActiveDateFontFamily() + ":" + modelData);
                                clockConfig.expandedAccordion = "";
                            }
                        }
                    }
                }

                Item { width: 1; height: Math.round(10 * appTheme.scale) }
            }
        }
    }

    // --- 11. Opacity Settings (Accordion) ---
    Rectangle {
        id: opacityAccordionContainer
        width: parent.width
        height: opacityAccordion.expanded ? (Math.round(36 * appTheme.scale) + opacitySlidersColumn.implicitHeight) : Math.round(36 * appTheme.scale)
        color: "transparent"
        border.color: appTheme.borderSubtle
        border.width: 1
        radius: Math.round(8 * appTheme.scale)
        clip: true

        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        Column {
            id: opacityAccordion
            width: parent.width
            property bool expanded: clockConfig.expandedAccordion === "opacity"

            Item {
                id: opacityAccordionHeader
                width: parent.width
                height: Math.round(36 * appTheme.scale)

                MouseArea {
                    anchors.fill: parent
                    onClicked: clockConfig.expandedAccordion = (clockConfig.expandedAccordion === "opacity") ? "" : "opacity"
                }

                Text { 
                    text: "Opacity Settings" 
                    color: appTheme.textSecondary 
                    font.family: "Inter"
                    font.pointSize: 10 * appTheme.scale 
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter 
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(12 * appTheme.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(8 * appTheme.scale)

                    Text { 
                        text: "T: " + Math.round(clockConfig.getActiveTimeOpacity() * 100) + "% / D: " + Math.round(clockConfig.getActiveDateOpacity() * 100) + "%"
                        color: appTheme.accent
                        font.family: "Inter"
                        font.pointSize: 9 * appTheme.scale
                        anchors.verticalCenter: parent.verticalCenter 
                    }

                    Text { 
                        text: opacityAccordion.expanded ? "-" : "+"
                        color: appTheme.textPrimary
                        font.pointSize: 12 * appTheme.scale
                        font.bold: true
                        font.family: "monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Column {
                id: opacitySlidersColumn
                width: parent.width - Math.round(24 * appTheme.scale)
                x: Math.round(12 * appTheme.scale)
                visible: opacity > 0.0
                opacity: opacityAccordion.expanded ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                spacing: Math.round(12 * appTheme.scale)

                Column {
                    width: parent.width
                    spacing: Math.round(4 * appTheme.scale)
                    
                    Text {
                        text: "Time Opacity: " + Math.round(timeOpacitySlider.value * 100) + "%"
                        color: appTheme.textSecondary
                        font.family: "Inter"
                        font.pointSize: 9 * appTheme.scale
                    }

                    Slider {
                        id: timeOpacitySlider
                        anchors.left: parent.left
                        anchors.right: parent.right
                        from: 0.1
                        to: 1.0
                        value: clockConfig.getActiveTimeOpacity()
                        onMoved: {
                            clockConfig.setModelProp("timeOpacity", value);
                        }
                        background: Rectangle {
                            x: timeOpacitySlider.leftPadding
                            y: timeOpacitySlider.topPadding + timeOpacitySlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 4
                            width: timeOpacitySlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: appTheme.elementBg
                            Rectangle {
                                width: timeOpacitySlider.visualPosition * parent.width
                                height: parent.height
                                color: appTheme.accent
                                radius: 2
                            }
                        }
                        handle: Rectangle {
                            x: timeOpacitySlider.leftPadding + timeOpacitySlider.visualPosition * (timeOpacitySlider.availableWidth - width)
                            y: timeOpacitySlider.topPadding + timeOpacitySlider.availableHeight / 2 - height / 2
                            implicitWidth: 12
                            implicitHeight: 12
                            radius: 6
                            color: appTheme.accent
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Math.round(4 * appTheme.scale)
                    
                    Text {
                        text: "Date Opacity: " + Math.round(dateOpacitySlider.value * 100) + "%"
                        color: appTheme.textSecondary
                        font.family: "Inter"
                        font.pointSize: 9 * appTheme.scale
                    }

                    Slider {
                        id: dateOpacitySlider
                        anchors.left: parent.left
                        anchors.right: parent.right
                        from: 0.1
                        to: 1.0
                        value: clockConfig.getActiveDateOpacity()
                        onMoved: {
                            clockConfig.setModelProp("dateOpacity", value);
                        }
                        background: Rectangle {
                            x: dateOpacitySlider.leftPadding
                            y: dateOpacitySlider.topPadding + dateOpacitySlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 4
                            width: dateOpacitySlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: appTheme.elementBg
                            Rectangle {
                                width: dateOpacitySlider.visualPosition * parent.width
                                height: parent.height
                                color: appTheme.accent
                                radius: 2
                            }
                        }
                        handle: Rectangle {
                            x: dateOpacitySlider.leftPadding + dateOpacitySlider.visualPosition * (dateOpacitySlider.availableWidth - width)
                            y: dateOpacitySlider.topPadding + dateOpacitySlider.availableHeight / 2 - height / 2
                            implicitWidth: 12
                            implicitHeight: 12
                            radius: 6
                            color: appTheme.accent
                        }
                    }
                }

                Item { width: 1; height: Math.round(12 * appTheme.scale) }
            }
        }
    }

    // --- 12. 24h Format ---
    Row {
        spacing: Math.round(20 * appTheme.scale)
        Text { 
            width: Math.round(120 * appTheme.scale)
            text: "24h Format"
            color: appTheme.textSecondary
            font.family: "Inter"
            font.pointSize: 10 * appTheme.scale
            anchors.verticalCenter: parent.verticalCenter 
        }
        
        Rectangle {
            id: formatTrack
            width: Math.round(44 * appTheme.scale)
            height: Math.round(24 * appTheme.scale)
            radius: Math.round(12 * appTheme.scale)
            property bool isChecked: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.is24h !== undefined ? widgetDrawer.activeWidgetData.is24h : true
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
                onClicked: clockConfig.setModelProp("is24h", !formatTrack.isChecked) 
            }
        }
    }

    // --- 13. Time Size ---
    Row {
        spacing: Math.round(20 * appTheme.scale)
        Text { 
            width: Math.round(120 * appTheme.scale)
            text: "Time Size"
            color: appTheme.textSecondary
            font.family: "Inter"
            font.pointSize: 10 * appTheme.scale
            anchors.verticalCenter: parent.verticalCenter 
        }
        
        Row {
            spacing: Math.round(4 * appTheme.scale)
            
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
                    activeFocusOnTab: true
                    selectByMouse: true
                    validator: IntValidator { bottom: 10; top: 200 }
                    text: widgetDrawer.activeWidgetData ? String(widgetDrawer.activeWidgetData.fontSize) : "32"
                    onEditingFinished: {
                        let val = parseInt(text);
                        if (!isNaN(val)) {
                            clockConfig.setModelProp("fontSize", Math.max(10, Math.min(200, val)));
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
                            clockConfig.setModelProp("fontSize", Math.max(10, widgetDrawer.activeWidgetData.fontSize - 1));
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
                            clockConfig.setModelProp("fontSize", Math.min(200, widgetDrawer.activeWidgetData.fontSize + 1));
                        } 
                    } 
                }
            }
        }
    }

    // --- 14. Date Size ---
    Row {
        spacing: Math.round(20 * appTheme.scale)
        Text { 
            width: Math.round(120 * appTheme.scale)
            text: "Date Size"
            color: appTheme.textSecondary
            font.family: "Inter"
            font.pointSize: 10 * appTheme.scale
            anchors.verticalCenter: parent.verticalCenter 
        }
        
        Row {
            spacing: Math.round(4 * appTheme.scale)
            
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
                    activeFocusOnTab: true
                    selectByMouse: true
                    validator: IntValidator { bottom: 4; top: 80 }
                    text: widgetDrawer.activeWidgetData && widgetDrawer.activeWidgetData.dateSize !== undefined ? String(widgetDrawer.activeWidgetData.dateSize) : "10"
                    onEditingFinished: {
                        let val = parseInt(text);
                        if (!isNaN(val)) {
                            clockConfig.setModelProp("dateSize", Math.max(4, Math.min(80, val)));
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
                            clockConfig.setModelProp("dateSize", Math.max(4, (widgetDrawer.activeWidgetData.dateSize || 10) - 1));
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
                            clockConfig.setModelProp("dateSize", Math.min(80, (widgetDrawer.activeWidgetData.dateSize || 10) + 1));
                        } 
                    } 
                }
            }
        }
    }

    // --- 15. Fine Tune Position ---
    Column {
        spacing: Math.round(6 * appTheme.scale)
        Text { 
            text: "Fine Tune Position"
            color: appTheme.textSecondary
            font.family: "Inter"
            font.pointSize: 10 * appTheme.scale 
        }
        
        Row {
            spacing: Math.round(8 * appTheme.scale)
            
            Rectangle { 
                width: Math.round(32 * appTheme.scale)
                height: Math.round(32 * appTheme.scale)
                radius: Math.round(6 * appTheme.scale)
                color: appTheme.elementBg
                Text { 
                    text: "\u25c0"
                    color: appTheme.textPrimary
                    font.pointSize: 9 * appTheme.scale
                    anchors.centerIn: parent 
                }
                MouseArea { 
                    anchors.fill: parent
                    onClicked: { 
                        if (widgetDrawer.activeWidgetData) {
                            clockConfig.setModelProp("offsetX", (widgetDrawer.activeWidgetData.offsetX || 0) - 1);
                        } 
                    } 
                }
            }
            
            Rectangle { 
                width: Math.round(32 * appTheme.scale)
                height: Math.round(32 * appTheme.scale)
                radius: Math.round(6 * appTheme.scale)
                color: appTheme.elementBg
                Text { 
                    text: "\u25b2"
                    color: appTheme.textPrimary
                    font.pointSize: 9 * appTheme.scale
                    anchors.centerIn: parent 
                }
                MouseArea { 
                    anchors.fill: parent
                    onClicked: { 
                        if (widgetDrawer.activeWidgetData) {
                            clockConfig.setModelProp("offsetY", (widgetDrawer.activeWidgetData.offsetY || 0) - 1);
                        } 
                    } 
                }
            }
            
            Rectangle { 
                width: Math.round(32 * appTheme.scale)
                height: Math.round(32 * appTheme.scale)
                radius: Math.round(6 * appTheme.scale)
                color: appTheme.elementBg
                Text { 
                    text: "\u25bc"
                    color: appTheme.textPrimary
                    font.pointSize: 9 * appTheme.scale
                    anchors.centerIn: parent 
                }
                MouseArea { 
                    anchors.fill: parent
                    onClicked: { 
                        if (widgetDrawer.activeWidgetData) {
                            clockConfig.setModelProp("offsetY", (widgetDrawer.activeWidgetData.offsetY || 0) + 1);
                        } 
                    } 
                }
            }
            
            Rectangle { 
                width: Math.round(32 * appTheme.scale)
                height: Math.round(32 * appTheme.scale)
                radius: Math.round(6 * appTheme.scale)
                color: appTheme.elementBg
                Text { 
                    text: "\u25b2"
                    rotation: 90
                    color: appTheme.textPrimary
                    font.pointSize: 9 * appTheme.scale
                    anchors.centerIn: parent 
                }
                MouseArea { 
                    anchors.fill: parent
                    onClicked: { 
                        if (widgetDrawer.activeWidgetData) {
                            clockConfig.setModelProp("offsetX", (widgetDrawer.activeWidgetData.offsetX || 0) + 1);
                        } 
                    } 
                }
            }
        }
    }

    Item { width: 1; height: Math.round(28 * appTheme.scale) }
}