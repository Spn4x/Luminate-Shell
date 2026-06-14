import QtQuick

Item {
    id: root
    anchors.fill: parent
    property int cellSize: 80

    // Coordinates mapped to centered boundaries
    property int offsetX: 0
    property int offsetY: 0

    visible: wallpaperBackend.isEditing
    opacity: visible ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    Canvas {
        id: gridCanvas
        anchors.fill: parent
        
        Connections {
            target: root
            function onCellSizeChanged() { gridCanvas.requestPaint() }
            function onWidthChanged() { gridCanvas.requestPaint() }
            function onHeightChanged() { gridCanvas.requestPaint() }
            function onOffsetXChanged() { gridCanvas.requestPaint() }
            function onOffsetYChanged() { gridCanvas.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            
            // Solid, thick, visible grid points
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.60);
            ctx.lineWidth = 2; 
            
            var crossSize = 6; 
            var cols = Math.floor(width / cellSize);
            var rows = Math.floor(height / cellSize);

            ctx.beginPath();
            // Start rendering offsets from the translated margins
            for (var x = offsetX; x <= offsetX + (cols * cellSize); x += cellSize) {
                for (var y = offsetY; y <= offsetY + (rows * cellSize); y += cellSize) {
                    // Horizontal slice
                    ctx.moveTo(x - crossSize, y);
                    ctx.lineTo(x + crossSize, y);
                    // Vertical slice
                    ctx.moveTo(x, y - crossSize);
                    ctx.lineTo(x, y + crossSize);
                }
            }
            ctx.stroke();
        }
    }
}