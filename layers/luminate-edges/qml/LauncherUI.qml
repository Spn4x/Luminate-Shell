import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Luminate.Shell

Item {
    id: launcherRoot
    clip: true

    property int maxRows: 6
    property int currentRows: Math.min(searchModel.count, maxRows)
    property int expandedHeight: AppTheme.searchHeight + 10 + (currentRows > 0 ? (currentRows * AppTheme.itemHeight) + ((currentRows - 1) * 2) + 8 : 0)

    ListModel { id: searchModel }

    function openAndFocus() {
        Launcher.clearState();
        searchModel.clear();
        launcherInput.text = "";
        if (Launcher.currentMode === 2) Launcher.query("");
        focusTimer.restart(); 
    }

    Timer {
        id: searchDebouncer
        interval: 50
        onTriggered: Launcher.query(launcherInput.text)
    }

    // THE FIX: Wait exactly 350ms (the duration of the scale animation) 
    // before taking focus, otherwise Wayland will reject it.
    Timer {
        id: focusTimer
        interval: 350
        onTriggered: {
            launcherInput.forceActiveFocus();
        }
    }

    Connections {
        target: Launcher
        function onResultsChanged() {
            let newRes = Launcher.results;
            
            for (let i = 0; i < newRes.length; i++) {
                if (i < searchModel.count) {
                    let existing = searchModel.get(i);
                    if (existing.modelPayload !== newRes[i].payload || existing.modelTitle !== newRes[i].title || existing.modelIcon !== newRes[i].icon) {
                        searchModel.setProperty(i, "modelType", newRes[i].type);
                        searchModel.setProperty(i, "modelTitle", newRes[i].title);
                        searchModel.setProperty(i, "modelDesc", newRes[i].desc);
                        searchModel.setProperty(i, "modelIcon", newRes[i].icon);
                        searchModel.setProperty(i, "modelPayload", newRes[i].payload);
                    }
                } else {
                    searchModel.append({
                        "modelType": newRes[i].type,
                        "modelTitle": newRes[i].title,
                        "modelDesc": newRes[i].desc,
                        "modelIcon": newRes[i].icon,
                        "modelPayload": newRes[i].payload
                    });
                }
            }
            
            while (searchModel.count > newRes.length) {
                searchModel.remove(searchModel.count - 1);
            }
            
            if (searchModel.count === 0) {
                launcherList.currentIndex = -1;
            } else if (launcherList.currentIndex >= searchModel.count) {
                launcherList.currentIndex = searchModel.count - 1;
            } else if (launcherList.currentIndex === -1) {
                launcherList.currentIndex = 0; 
            }
        }
    }

    component SystemIcon: Button {
        property string iconName: ""
        property color iconColor: "transparent" 
        property int size: 36 
        width: size; height: size
        icon.name: iconName
        icon.color: iconColor 
        icon.width: size; icon.height: size
        background: Item {} 
        focusPolicy: Qt.NoFocus; hoverEnabled: false; down: false
    }

    Rectangle {
        id: searchBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: AppTheme.searchHeight
        color: AppTheme.surfaceAlpha
        radius: 10
        border.color: launcherInput.activeFocus ? AppTheme.accent : "transparent"
        border.width: 2 

        Behavior on border.color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8 
            spacing: 8

            SystemIcon {
                Layout.alignment: Qt.AlignVCenter
                iconColor: AppTheme.fg 
                size: 20
                iconName: {
                    if (Launcher.currentMode === 1) return "utilities-terminal-symbolic"
                    if (Launcher.currentMode === 2) return "edit-paste-symbolic"
                    return "system-search-symbolic"
                }
            }

            TextField {
                id: launcherInput
                Layout.fillWidth: true
                color: AppTheme.fg
                font.pixelSize: 16 
                font.bold: true
                background: Item {} 
                focus: true // Helps enforce initial state
                
                placeholderText: {
                    if (Launcher.currentMode === 1) return "Run Command..."
                    if (Launcher.currentMode === 2) return "Search Clipboard..."
                    return "Search Apps or Math..."
                }
                placeholderTextColor: Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.4)
                
                onTextEdited: searchDebouncer.restart()

                // THE FIX: Explicitly manipulate the index, ignoring QML's reversed built-ins.
                Keys.onUpPressed: (event) => { 
                    if (launcherList.currentIndex < searchModel.count - 1) {
                        launcherList.currentIndex++;
                    }
                    event.accepted = true;
                }
                Keys.onDownPressed: (event) => { 
                    if (launcherList.currentIndex > 0) {
                        launcherList.currentIndex--;
                    }
                    event.accepted = true;
                }
                
                Keys.onEscapePressed: (event) => { Backend.closeLauncher(); event.accepted = true; }
                
                Keys.onTabPressed: (event) => {
                    Launcher.setMode((Launcher.currentMode + 1) % 3);
                    Launcher.query(text);
                    event.accepted = true;
                }
                
                Keys.onReturnPressed: (event) => {
                    if (launcherList.currentIndex >= 0 && launcherList.currentIndex < searchModel.count) {
                        Launcher.activateResult(launcherList.currentIndex)
                        Backend.closeLauncher();
                    }
                    event.accepted = true
                }
                Keys.onDeletePressed: (event) => {
                    if (Launcher.currentMode === 2 && launcherList.currentIndex >= 0) {
                        Launcher.deleteClipboardItem(launcherList.currentIndex)
                        Launcher.query(text)
                    }
                }
            }
        }
    }

    ListView {
        id: launcherList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: searchBox.top
        anchors.bottomMargin: 8
        
        verticalLayoutDirection: ListView.BottomToTop
        clip: true
        model: searchModel
        currentIndex: 0
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2 

        delegate: Rectangle {
            width: launcherList.width
            height: AppTheme.itemHeight
            
            property bool isSelected: ListView.isCurrentItem
            radius: isSelected ? AppTheme.rowSelectedRadius : AppTheme.rowRadius

            color: isSelected ? AppTheme.accent : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: launcherList.currentIndex = index
                onClicked: {
                    Launcher.activateResult(index);
                    Backend.closeLauncher();
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6 
                spacing: 12

                Item {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38

                    SystemIcon {
                        visible: !modelIcon.startsWith("/") 
                        anchors.centerIn: parent
                        iconName: modelIcon.startsWith("/") ? "" : modelIcon
                        size: 36 
                    }

                    Image {
                        visible: modelIcon.startsWith("/")
                        anchors.fill: parent
                        source: modelIcon.startsWith("/") ? "file://" + modelIcon : ""
                        fillMode: Image.PreserveAspectCrop
                        Rectangle { anchors.fill: parent; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1; radius: 4 }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: modelTitle
                        color: isSelected ? AppTheme.selectedText : AppTheme.fg
                        font.pixelSize: 15
                        font.bold: true
                        elide: Text.ElideRight
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelDesc
                        color: isSelected ? Qt.rgba(AppTheme.selectedText.r, AppTheme.selectedText.g, AppTheme.selectedText.b, 0.8) : Qt.rgba(AppTheme.fg.r, AppTheme.fg.g, AppTheme.fg.b, 0.6)
                        font.pixelSize: 13 
                        elide: Text.ElideRight
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }
        }
    }
}