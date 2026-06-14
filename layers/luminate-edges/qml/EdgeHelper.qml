import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Luminate.Shell

Item {
    id: helperRoot
    anchors.fill: parent

    // Expose dynamic heights to LuminateEdge for smooth shape morphing
    property real notifHeight: notifColumn.implicitHeight
    property real privacySingleHeight: privacySingleColumn.implicitHeight
    property real privacyMultiHeight: privacyMultiColumn.implicitHeight

    ListModel { 
        id: privacyAppModel 
    }

    function syncPrivacyModel() {
        let newApps = Backend.privacyApps || [];
        
        for (let i = privacyAppModel.count - 1; i >= 0; i--) {
            let pid = privacyAppModel.get(i).pid;
            let name = privacyAppModel.get(i).name;
            let found = false;
            
            for (let j = 0; j < newApps.length; j++) {
                if (newApps[j].pid === pid && newApps[j].name === name) {
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                privacyAppModel.remove(i);
            }
        }
        
        for (let i = 0; i < newApps.length; i++) {
            let newApp = newApps[i];
            let found = false;
            
            for (let j = 0; j < privacyAppModel.count; j++) {
                if (privacyAppModel.get(j).pid === newApp.pid && privacyAppModel.get(j).name === newApp.name) {
                    privacyAppModel.setProperty(j, "hasMic", newApp.hasMic);
                    privacyAppModel.setProperty(j, "hasCam", newApp.hasCam);
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                privacyAppModel.insert(i, newApp);
            }
        }
    }

    Connections {
        target: Backend
        function onPrivacyChanged() {
            helperRoot.syncPrivacyModel();
        }
    }

    Component.onCompleted: {
        syncPrivacyModel();
    }

    component SystemIcon: Button {
        property string iconName: ""
        property color iconColor: "white"
        property int size: 24
        
        width: size
        height: size
        
        icon.name: iconName
        icon.color: iconColor
        icon.width: size
        icon.height: size
        
        background: Item {} 
        focusPolicy: Qt.NoFocus
        hoverEnabled: false
        down: false
    }

    // =====================================
    // EXPANDED NOTIFICATION VIEW
    // =====================================
    Column {
        id: notifColumn
        anchors.centerIn: parent
        width: parent.width - 32
        spacing: 6
        visible: Backend.displayMode === "notification"

        Text {
            text: Backend.summary
            color: AppTheme.fg
            font.pixelSize: 16
            font.bold: true
            width: parent.width
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: Backend.body
            color: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.8)
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            width: parent.width
            maximumLineCount: 3
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            width: parent.width
            spacing: 8
            visible: Backend.hasActions

            Repeater {
                model: Backend.actions
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: AppTheme.actionRadius
                    color: actionMouse.pressed ? AppTheme.actionBgHover : AppTheme.actionBg
                    border.color: AppTheme.actionBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: "white"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Backend.invokeAction(modelData.id);
                            Backend.isExpanded = false;
                            Backend.readyForNext();
                        }
                    }
                }
            }
        }
    }

    // =====================================
    // PRIVACY VIEW (SINGLE APP)
    // =====================================
    Column {
        id: privacySingleColumn
        anchors.centerIn: parent
        width: parent.width - 32
        spacing: 16
        visible: Backend.displayMode === "privacy" && Backend.privacyApps.length === 1

        Item {
            width: parent.width
            height: childrenRect.height
            property var appData: Backend.privacyApps.length === 1 ? Backend.privacyApps[0] : null

            Column {
                width: parent.width
                spacing: 12

                SystemIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    iconName: {
                        if (!parent.parent.appData) return "";
                        if (parent.parent.appData.hasCam && parent.parent.appData.hasMic) return "camera-web-symbolic";
                        if (parent.parent.appData.hasCam) return "video-display-symbolic";
                        return "audio-input-microphone-symbolic";
                    }
                    iconColor: {
                        if (!parent.parent.appData) return "white";
                        return parent.parent.appData.hasCam ? AppTheme.colorCam : AppTheme.colorMic;
                    }
                    size: 32
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (!parent.parent.appData) return "";
                        let hardware = (parent.parent.appData.hasCam && parent.parent.appData.hasMic) ? "mic & camera" : (parent.parent.appData.hasCam ? "camera" : "microphone");
                        return parent.parent.appData.name + " is using your " + hardware;
                    }
                    color: AppTheme.fg
                    font.pixelSize: AppTheme.summarySize
                    font.bold: true
                }

                RowLayout {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: AppTheme.actionRadius
                        color: ignoreSingleMouse.pressed ? AppTheme.actionBgHover : AppTheme.actionBg
                        border.color: AppTheme.actionBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Ignore"
                            color: "white"
                            font.pixelSize: AppTheme.bodySize
                            font.bold: true
                        }

                        MouseArea {
                            id: ignoreSingleMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Backend.ignorePrivacyApp(parent.parent.parent.parent.appData.pid, parent.parent.parent.parent.appData.name);
                                Backend.isExpanded = false;
                                Backend.readyForNext();
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: AppTheme.actionRadius
                        color: killSingleMouse.pressed ? AppTheme.actionBgHover : AppTheme.actionBg
                        border.color: AppTheme.actionBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: parent.parent.parent.parent.appData ? "Kill " + parent.parent.parent.parent.appData.name : "Kill"
                            color: AppTheme.colorKill
                            font.pixelSize: AppTheme.bodySize
                            font.bold: true
                        }

                        MouseArea {
                            id: killSingleMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Backend.killPrivacyApp(parent.parent.parent.parent.appData.pid, parent.parent.parent.parent.appData.name);
                                Backend.isExpanded = false;
                                Backend.readyForNext();
                            }
                        }
                    }
                }
            }
        }
    }

    // =====================================
    // PRIVACY VIEW (MULTIPLE APPS)
    // =====================================
    Column {
        id: privacyMultiColumn
        anchors.centerIn: parent
        width: parent.width - 32
        spacing: 16
        visible: Backend.displayMode === "privacy" && Backend.privacyApps.length > 1

        SystemIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            iconName: "security-high-symbolic"
            iconColor: AppTheme.fg
            size: 32
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Backend.privacySummary
            color: AppTheme.fg
            font.pixelSize: AppTheme.summarySize
            font.bold: true
        }

        Column {
            width: parent.width
            spacing: 4

            Repeater {
                model: privacyAppModel
                delegate: Rectangle {
                    width: parent.width
                    height: 42
                    radius: 8
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: name
                            color: AppTheme.fg
                            font.pixelSize: AppTheme.bodySize
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        SystemIcon {
                            visible: hasMic
                            iconName: "audio-input-microphone-symbolic"
                            iconColor: AppTheme.colorMic
                            size: 20
                        }

                        SystemIcon {
                            visible: hasCam
                            iconName: "camera-web-symbolic"
                            iconColor: AppTheme.colorCam
                            size: 20
                        }

                        Text {
                            text: "Ignore"
                            color: AppTheme.fg
                            font.pixelSize: 13
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Backend.ignorePrivacyApp(pid, name);
                                }
                            }
                        }

                        Text {
                            text: "Kill"
                            color: AppTheme.colorKill
                            font.pixelSize: 13
                            font.bold: true
                            Layout.leftMargin: 8

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Backend.killPrivacyApp(pid, name);
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 38
            radius: AppTheme.actionRadius
            color: killAllMouse.pressed ? AppTheme.actionBgHover : AppTheme.actionBg
            border.color: AppTheme.actionBorder
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Kill All Apps"
                color: AppTheme.colorKill
                font.pixelSize: 13
                font.bold: true
            }

            MouseArea {
                id: killAllMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Backend.killAllPrivacyApps();
                    Backend.isExpanded = false;
                    Backend.readyForNext();
                }
            }
        }
    }
}