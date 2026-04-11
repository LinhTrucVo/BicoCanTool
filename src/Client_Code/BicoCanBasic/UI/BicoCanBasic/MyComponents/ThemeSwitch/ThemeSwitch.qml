import QtQuick 2.12
import QtQuick.Controls 2.12

Row {
    id: themeSwitchRoot
    
    // Theme mode enum
    readonly property string light: "light"
    readonly property string dark: "dark"
    readonly property string auto: "auto"
    
    // Properties exposed to parent
    property string themeMode: light
    
    // Styling input parameters
    property color foreground: "#000000"
    property color background: "#000000"
    property color accent: "#000000"
    
    // Signals for parent to connect to
    signal themeChanged()
    
    spacing: 0
    z: 10

    Repeater {
        model: [
            { label: "\u2600", mode: light },  // ☀ Light
            { label: "Auto",   mode: auto },  // System
            { label: "\u263E", mode: dark }   // ☾ Dark
        ]
        delegate: Rectangle {
            width: 40
            height: 24
            radius: index === 0 ? 12 : (index === 2 ? 12 : 0)
            color: themeSwitchRoot.themeMode === modelData.mode ? themeSwitchRoot.accent : themeSwitchRoot.background
            
            // Round only the appropriate corners
            Rectangle {
                visible: index === 0
                anchors.right: parent.right
                width: parent.width / 2
                height: parent.height
                color: parent.color
            }
            Rectangle {
                visible: index === 2
                anchors.left: parent.left
                width: parent.width / 2
                height: parent.height
                color: parent.color
            }

            Text {
                anchors.centerIn: parent
                text: modelData.label
                font.pixelSize: index === 1 ? 10 : 14
                color: themeSwitchRoot.themeMode === modelData.mode ? themeSwitchRoot.back : themeSwitchRoot.foreground
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    themeSwitchRoot.themeMode = modelData.mode
                    themeSwitchRoot.themeChanged()
                }
            }
        }
    }
}
