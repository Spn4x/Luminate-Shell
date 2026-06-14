import QtQuick
import Luminate.Shell 

Item {
    id: nodeRoot
    property var nodeData: null
    property string busName: ""
    property string menuPath: ""

    property var props: nodeData ? (nodeData.props || {}) : {}
    property var childrenData: nodeData ? (nodeData.children || []) : []
    property bool hasChildren: childrenData.length > 0 || props["children-display"] === "submenu"
    property bool isSeparator: props.type === "separator"
    property string label: (props.label || "").replace(/_([a-zA-Z0-9])/g, "$1")
    property bool isEnabled: props.enabled !== undefined ? props.enabled : true
    
    property bool isCheckable: props["toggle-type"] === "checkmark" || props["toggle-type"] === "radio"
    property bool isChecked: props["toggle-state"] === 1

    width: parent.width
    height: isSeparator ? 9 : 32
    visible: props.visible !== undefined ? props.visible : true

    property bool isSubmenuOpen: false

    function restoreState() {
        if (typeof pulltabMenu !== "undefined" && nodeData && pulltabMenu.openSubmenus[nodeData.id]) {
            isSubmenuOpen = true;
        }
    }
    
    Component.onCompleted: restoreState()
    onNodeDataChanged: restoreState()

    onIsSubmenuOpenChanged: {
        if (isSubmenuOpen) {
            if (typeof pulltabMenu !== "undefined" && nodeData) pulltabMenu.openSubmenus[nodeData.id] = true;
            if (hasChildren) Systray.requestSubmenu(nodeData.id);
        } else {
            if (typeof pulltabMenu !== "undefined" && nodeData) pulltabMenu.openSubmenus[nodeData.id] = false;
        }
    }

    Item { 
        visible: isSeparator
        width: parent.width
        height: 9
        
        Rectangle { 
            width: parent.width
            height: 1
            color: AppTheme.borderAlpha
            anchors.centerIn: parent 
        } 
    }

    // EXACT TEST VERSION HEIGHT DECLARATION
    Rectangle {
        id: headerRect
        visible: !isSeparator && label !== ""
        width: parent.width
        height: visible ? 32 : 0
        color: isSubmenuOpen || mouseArea.containsMouse ? AppTheme.accentAlpha15 : "transparent"
        radius: 6

        Text { 
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "✓"
            font.family: AppTheme.mainFont
            font.pixelSize: AppTheme.fontSize
            font.bold: true
            color: AppTheme.accent
            visible: isCheckable && isChecked 
        }

        Text { 
            x: isCheckable ? 28 : 8
            anchors.verticalCenter: parent.verticalCenter
            text: label
            font.family: AppTheme.mainFont
            font.pixelSize: AppTheme.fontSize
            font.bold: true
            color: isEnabled ? AppTheme.fg : AppTheme.fgAlpha40
            elide: Text.ElideRight
            width: parent.width - x - 20 
        }

        Text { 
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "▶"
            color: AppTheme.fg
            font.pixelSize: 10
            visible: hasChildren 
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: isEnabled
            cursorShape: isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            
            onClicked: {
                if (!isEnabled) return;
                
                if (!hasChildren) {
                    Systray.triggerMenuEvent(busName, menuPath, nodeData.id, "clicked");
                    if (typeof pulltabMenu !== "undefined") {
                        pulltabMenu.expanded = false; 
                    }
                } else {
                    isSubmenuOpen = !isSubmenuOpen;
                }
            }
        }
    }

    // --- SIDE FLYOUT CONTAINER ---
    Item {
        id: flyoutContainer
        x: parent.width + 8 
        y: -8 
        
        width: isSubmenuOpen ? 250 : 0
        height: subCol.implicitHeight + 16 
        clip: true 
        visible: width > 0

        Behavior on width { 
            NumberAnimation { 
                duration: 250
                easing.type: Easing.OutQuint 
            } 
        }

        Item {
            width: 250
            height: parent.height
            anchors.right: parent.right

            Rectangle {
                anchors.fill: parent
                color: AppTheme.bg
                border.color: AppTheme.borderAlpha
                border.width: 1
                radius: 8

                // CRITICAL FIX: This swallows the click inside the flyout!
                MouseArea { 
                    anchors.fill: parent
                    hoverEnabled: true 
                }

                // Optical illusion connection patch
                Rectangle { 
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 8
                    color: AppTheme.bg 
                }

                Column {
                    id: subCol
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    width: 250 - 16
                    spacing: 2
                    
                    Repeater {
                        model: childrenData
                        
                        // EXACT 1:1 TEST VERSION BINDINGS
                        delegate: Loader {
                            width: parent.width
                            height: item ? item.height : 0
                            source: "SystrayMenuNode.qml"
                            
                            Binding { target: item; property: "nodeData"; value: modelData }
                            Binding { target: item; property: "busName"; value: nodeRoot.busName }
                            Binding { target: item; property: "menuPath"; value: nodeRoot.menuPath }
                        }
                    }
                }
            }
        }
    }
}