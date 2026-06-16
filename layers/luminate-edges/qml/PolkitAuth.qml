import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Luminate.Shell

Item {
    id: authRoot
    clip: true

    property color flashColor: "transparent"
    property bool isAuthenticating: false

    onVisibleChanged: {
        if (visible) {
            pwdInput.text = "";
            isAuthenticating = false;
            focusTimer.restart();
        }
    }

    Timer {
        id: focusTimer
        interval: 350
        onTriggered: pwdInput.forceActiveFocus()
    }

    Shortcut {
        sequence: "Escape"
        enabled: authRoot.visible
        onActivated: PolkitAgent.cancelAuth()
    }

    Connections {
        target: PolkitAgent
        function onAuthFailed() {
            isAuthenticating = false;
            pwdInput.text = "";
            pwdInput.forceActiveFocus();
            shakeAnim.restart();
            colorFlashAnim.restart();
        }
    }

    SequentialAnimation {
        id: shakeAnim
        loops: 2
        NumberAnimation { target: contentWrapper; property: "anchors.horizontalCenterOffset"; to: -14; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: contentWrapper; property: "anchors.horizontalCenterOffset"; to: 14; duration: 110; easing.type: Easing.InOutQuad }
        NumberAnimation { target: contentWrapper; property: "anchors.horizontalCenterOffset"; to: 0; duration: 55; easing.type: Easing.OutQuad }
    }

    SequentialAnimation {
        id: colorFlashAnim
        ColorAnimation { target: authRoot; property: "flashColor"; to: Qt.rgba(AppTheme.colorKill.r, AppTheme.colorKill.g, AppTheme.colorKill.b, 0.4); duration: 80 }
        ColorAnimation { target: authRoot; property: "flashColor"; to: "transparent"; duration: 220 }
    }

    Rectangle {
        anchors.fill: parent
        color: flashColor
        radius: AppTheme.expandedRadius
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Item {
        id: contentWrapper
        anchors.fill: parent
        anchors.horizontalCenterOffset: 0

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 16

            Text {
                Layout.fillWidth: true
                text: "Authentication Required"
                color: AppTheme.accent
                font.family: AppTheme.mainFont
                font.pixelSize: 16
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: PolkitAgent.authMessage
                color: AppTheme.fg
                font.family: AppTheme.mainFont
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.8
            }

            Rectangle {
                Layout.fillWidth: true
                height: 46
                radius: 12
                color: AppTheme.actionBg
                border.color: pwdInput.activeFocus ? AppTheme.accent : AppTheme.actionBorder
                border.width: pwdInput.activeFocus ? 2 : 1
                
                Behavior on border.color { ColorAnimation { duration: 150 } }

                TextInput {
                    id: pwdInput
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    color: AppTheme.fg
                    font.family: AppTheme.mainFont
                    font.pixelSize: 16
                    font.bold: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    
                    // Disable typing when validating
                    enabled: !isAuthenticating
                    
                    Keys.onReturnPressed: (event) => {
                        if (!isAuthenticating && text.length > 0) {
                            isAuthenticating = true;
                            PolkitAgent.submitPassword(text);
                        }
                        event.accepted = true;
                    }
                }
                
                Text {
                    text: isAuthenticating ? "AUTHENTICATING..." : "ENTER PASSWORD"
                    color: isAuthenticating ? AppTheme.accent : Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.4)
                    font.family: AppTheme.mainFont
                    font.pixelSize: 12
                    font.bold: true
                    anchors.centerIn: parent
                    visible: pwdInput.text.length === 0 || isAuthenticating

                    SequentialAnimation on opacity {
                        running: isAuthenticating
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 400; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }
    }
}