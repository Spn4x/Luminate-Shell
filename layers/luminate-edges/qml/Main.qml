import QtQuick
import QtQuick.Window
import Luminate.Shell

Window {
    id: root
    width: Screen.width 
    height: Screen.height 
    visible: false 
    color: "transparent"
    flags: Qt.FramelessWindowHint

    LuminateEdge {
        id: edge
        objectName: "luminateEdge"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 0 
    }
}