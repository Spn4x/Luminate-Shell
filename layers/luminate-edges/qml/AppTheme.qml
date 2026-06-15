pragma Singleton
import QtQuick
import Luminate.Shell

QtObject {
    property var theme: Backend.themeData

    property color bg: theme["bg"] !== undefined ? theme["bg"] : "#1A1A1D"
    property color fg: theme["fg"] !== undefined ? theme["fg"] : "#f2f2f2"
    property color accent: theme["accent"] !== undefined ? theme["accent"] : "#00ffcc"
    property color surface: theme["surface"] !== undefined ? theme["surface"] : "#3E3E41"
    
    // Solid, darker variants of the accent color for stacking
    property color accentDark1: Qt.darker(accent, 1.25)
    property color accentDark2: Qt.darker(accent, 1.5)
    property color accentDark3: Qt.darker(accent, 1.8)

    property color surfaceAlpha: Qt.rgba(surface.r, surface.g, surface.b, 0.5)
    property color borderAlpha: Qt.rgba(accent.r, accent.g, accent.b, 0.4)
    property color accentAlpha15: Qt.rgba(accent.r, accent.g, accent.b, 0.15)
    property color accentAlpha30: Qt.rgba(accent.r, accent.g, accent.b, 0.3)
    property color fgAlpha40: Qt.rgba(fg.r, fg.g, fg.b, 0.4)

    property color selectedText: "#1E1E2E"
    property color moduleBg: surface   

    property color colorMic: "#ff9e64" 
    property color colorCam: "#8ff0a4" 
    property color colorKill: "#ff7b63" 

    property color actionBg: "#14ffffff"
    property color actionBgHover: "#26ffffff"
    property color actionBorder: "#0dffffff"
    property int actionRadius: 10

    property string mainFont: "Lexend"             
    property string iconFont: "JetBrainsMono Nerd Font" 
    property int fontSize: 12            

    property int barHeight: 32           
    property int barRadius: 16           
    property int moduleRadius: 8         
    property int moduleHeight: 24   

    property int passiveWidth: 150
    property int passiveHeight: 13
    
    property int expandedMinWidth: 420
    property int expandedMinHeight: 120

    // Initial fallback window boundaries for the screenshot tool 
    property int screenshotEditWidth: 1115
    property int screenshotEditHeight: 635

    property int launcherWidth: 420
    property int itemHeight: 56
    property int searchHeight: 46
    
    property int rowRadius: 6
    property int rowSelectedRadius: 8
    
    property int passiveRadius: 6
    property int sideInfoRadius: 16
    property int expandedRadius: 16

    property int summarySize: 13 
    property int bodySize: 12    
    property bool summaryBold: true
}