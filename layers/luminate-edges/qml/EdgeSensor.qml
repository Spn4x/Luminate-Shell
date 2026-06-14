import QtQuick

Item {
    id: root
    anchors.fill: parent

    property bool isActive: false
    signal toggleActive()

    // Expose whether the physical spring simulation is currently active
    readonly property bool animating: widthAnim.running || heightAnim.running

    // 1. The Visual Panel Container (Acts as the top-only outline)
    Rectangle {
        id: panelOutline
        
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        
        // Push the bottom border off-screen to clip it out
        anchors.bottomMargin: -2
        
        width: root.isActive ? mainWindow.activeWidth : mainWindow.passiveWidth
        height: root.isActive ? (mainWindow.activeHeight + 2) : (mainWindow.passiveHeight + 2)

        topLeftRadius: 12
        topRightRadius: 12
        
        color: root.isActive ? "#00ffcc" : "#44ffffff"

        // Realistic spring-physics animations
        Behavior on width { 
            SpringAnimation {
                id: widthAnim
                spring: 2.8      // Stiffness of the spring
                damping: 0.35    // Bounciness (lower values wobble longer)
                epsilon: 0.25    // Precision threshold to stop animating
            }
        }
        Behavior on height { 
            SpringAnimation {
                id: heightAnim
                spring: 2.8
                damping: 0.35
                epsilon: 0.25
            }
        }
        Behavior on color { ColorAnimation { duration: 200 } }

        // 2. The Solid Body (Shifted down by 1.5px to hide left/right borders)
        Rectangle {
            id: panelBody
            anchors.fill: parent
            
            anchors.topMargin: 1.5 
            anchors.leftMargin: 0
            anchors.rightMargin: 0
            anchors.bottomMargin: 0

            topLeftRadius: 11
            topRightRadius: 11
            
            // 100% Solid dark background
            color: "#121214"

            // Centered pill-indicator handle
            Rectangle {
                id: handleLine
                width: root.isActive ? 60 : 40
                height: 4
                radius: 2
                color: root.isActive ? "#00ffcc" : "#55ffffff"
                anchors.top: parent.top
                anchors.topMargin: root.isActive ? 6 : 4
                anchors.horizontalCenter: parent.horizontalCenter
                
                Behavior on width { 
                    SpringAnimation {
                        spring: 3.0
                        damping: 0.4
                        epsilon: 0.25
                    }
                }
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            // Core UI content
            Text {
                id: mainText
                anchors.centerIn: parent
                text: "Luminate Edges"
                color: "#ffffff"
                font.pixelSize: 18
                font.bold: true
                
                opacity: root.isActive ? 1.0 : 0.0
                visible: opacity > 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
    }

    // Active mouse trigger
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.toggleActive()
        }
    }
}