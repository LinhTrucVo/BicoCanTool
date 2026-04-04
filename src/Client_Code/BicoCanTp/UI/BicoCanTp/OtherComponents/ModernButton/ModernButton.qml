import QtQuick 2.12
import QtQuick.Controls 2.12

Button {
    id: modernButton
    
    property color primaryColor: '#5a8a00'
    property color hoverColor: '#29b965'
    property color pressedColor: '#1fb3b3'
    property color textColor: "#ffffff"
    property color disabledColor: "#bdc3c7"
    property int animationDuration: 150
    property int borderRadius: 8
    property bool glowEffect: true
    
    implicitWidth: 120
    implicitHeight: 40
    
    background: Rectangle {
        id: backgroundRect
        radius: modernButton.borderRadius
        color: modernButton.enabled ? 
               (modernButton.pressed ? modernButton.pressedColor : 
                modernButton.hovered ? modernButton.hoverColor : modernButton.primaryColor) 
               : modernButton.disabledColor
        
        Behavior on color {
            ColorAnimation {
                duration: modernButton.animationDuration
                easing.type: Easing.OutCubic
            }
        }
        
        // Subtle shadow effect
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            radius: parent.radius
            color: "#20000000"
            z: -1
            visible: modernButton.enabled
        }
        
        // Glow effect when hovered
        Rectangle {
            id: glowRect
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: modernButton.primaryColor
            border.width: modernButton.hovered && modernButton.glowEffect ? 2 : 0
            opacity: modernButton.hovered ? 0.6 : 0
            z: -2
            
            Behavior on border.width {
                NumberAnimation {
                    duration: modernButton.animationDuration
                    easing.type: Easing.OutCubic
                }
            }
            
            Behavior on opacity {
                NumberAnimation {
                    duration: modernButton.animationDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
        
        // Ripple effect on click
        Rectangle {
            id: ripple
            anchors.centerIn: parent
            width: 0
            height: 0
            radius: width / 2
            color: "#40ffffff"
            opacity: 0
            
            ParallelAnimation {
                id: rippleAnimation
                
                NumberAnimation {
                    target: ripple
                    properties: "width,height"
                    from: 0
                    to: Math.max(modernButton.width, modernButton.height) * 2
                    duration: 300
                    easing.type: Easing.OutCubic
                }
                
                SequentialAnimation {
                    NumberAnimation {
                        target: ripple
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 150
                    }
                    NumberAnimation {
                        target: ripple
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 150
                    }
                }
            }
        }
        
        // Scale animation on press
        scale: modernButton.pressed ? 0.98 : 1.0
        
        Behavior on scale {
            NumberAnimation {
                duration: modernButton.animationDuration / 2
                easing.type: Easing.OutCubic
            }
        }
    }
    
    contentItem: Text {
        text: modernButton.text
        font: modernButton.font
        color: modernButton.enabled ? modernButton.textColor : "#7f8c8d"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        
        Behavior on color {
            ColorAnimation {
                duration: modernButton.animationDuration
            }
        }
    }
    
    // Trigger ripple effect on click
    onClicked: {
        if (enabled) {
            rippleAnimation.restart()
        }
    }
    
    // Focus handling
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    
    // Custom focus indicator
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: modernButton.borderRadius + 2
        color: "transparent"
        border.color: modernButton.primaryColor
        border.width: modernButton.activeFocus ? 2 : 0
        opacity: 0.7
        
        Behavior on border.width {
            NumberAnimation {
                duration: modernButton.animationDuration
            }
        }
    }
}
