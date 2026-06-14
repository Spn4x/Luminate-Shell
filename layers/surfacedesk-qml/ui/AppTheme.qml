import QtQuick

QtObject {
    id: root

    // =========================================================
    // MASTER GLOBAL UI SCALE
    // Change this value to scale the entire interface, grid, and widgets
    property real scale: 1
    // =========================================================

    // 1. Global Background
    property color bg: "#28282C"
    
    // 2. Global Border Radius (Scaled dynamically)
    property int radius: Math.round(12 * scale)
    
    // 3. Dynamic Accent Color
    property color accent: {
        if (typeof wallpaperBackend !== "undefined" && wallpaperBackend !== null) {
            if (wallpaperBackend.wallpaperPalette.length > 4) {
                return wallpaperBackend.wallpaperPalette[4];
            } else if (wallpaperBackend.wallpaperPalette.length > 3) {
                return wallpaperBackend.wallpaperPalette[3];
            }
        }
        return "#89B4FA"; // Fallback
    }

    // 4. Accent dimmed
    property color accentDimmed: Qt.darker(accent, 1.25)
    
    // 5. Standard Text & Element Colors
    property color textPrimary: "#FFFFFF"
    property color textSecondary: "#A6ADC8"
    property color elementBg: Qt.darker(bg, 1.3)
    property color borderSubtle: Qt.rgba(1, 1, 1, 0.1)
}