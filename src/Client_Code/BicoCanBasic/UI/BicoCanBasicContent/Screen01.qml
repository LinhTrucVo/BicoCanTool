import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12

// By importing module by path, the component appears
// in the Component tab in design mode.
// This makes the component available for preview and
// be able to dropped in design mode.
import "../BicoCanBasic/Constants"
import "../BicoCanBasic/MyComponents/ModernButton"
import "../BicoCanBasic/OtherComponents/ModernButton"
import QtQuick.Timeline 1.0

Rectangle {
    id: screen01
    objectName: "Screen01"
    width: Constants.width
    height: Constants.height
    visible: true
    color: "#acacac"

    // Add these signal properties to connect with parent
    property var toThreadSignal: function(msg, data) {}
    property var fromThreadSignal: function(msg, data) {
        if (msg === "size")
        {
            button.height = data.height
            button.width = data.width
        }

    }

    Component.onCompleted: {
        screen01.state = "State1"
    }

    // this ModernButton is from OtherComponents
    // not from the MyComponents.
    // Reason: if there are multiple module have
    // the same component name (ModernButton in this case)
    // the component in the last imported module is used
    ModernButton {
        objectName: "button"
        id: button
        x: 218
        y: 186
        text: qsTr("main")
        width: 140
        height: 45

        onClicked:
        {
            var data_to_thread
            if (qmess.text === "size")
            {
                // data_to_thread = Qt.size(int(qdata.text), int(qdata.text))
                data_to_thread = Qt.size(Number(qdata.text), Number(qdata.text))
            }
            else
            {
                data_to_thread = qdata.text
            }

            console.log(qmess.text + " " + data_to_thread)
            toThreadSignal(qmess.text, data_to_thread)
        }
    }

    TextField {
        id: qmess
        x: 40
        y: 49
        width: 318
        height: 40
        placeholderText: qsTr("mess")
    }

    TextField {
        id: qdata
        x: 40
        y: 112
        width: 318
        height: 40
        placeholderText: qsTr("data")
    }

    OtherComponentsWrapperModernButton {
        id: otherComponentsWrapperModernButton
        x: 273
        y: 327
        width: 139
        height: 49
        scale: 1

        onClicked: {
            if (screen01.state === "State1") {
                screen01.state = "State2";
            }
            else if (screen01.state === "State2") {
                screen01.state = "State1";
            }
        }
    }

    Timeline {
        id: timeline
        animations: [
            TimelineAnimation {
                id: timelineAnimation
                duration: 1000
                running: true
                loops: -1
                to: 1000
                from: 0
            }
        ]
        startFrame: 0
        endFrame: 1000
        enabled: true

        KeyframeGroup {
            target: otherComponentsWrapperModernButton
            property: "scale"
            Keyframe {
                value: 1
                frame: 0
            }

            Keyframe {
                value: 0.5
                frame: 231
            }

            Keyframe {
                value: 0.89904
                easing.bezierCurve: [0.333,0,0.667,1,1,1]
                frame: 526
            }

            Keyframe {
                value: 0
                frame: 773
            }

            Keyframe {
                value: 1
                frame: 1000
            }
        }
    }

    Text {
        id: text1
        x: 21
        y: 17
        width: 59
        height: 26
        text: qsTr("Screen01")
        font.pixelSize: 15
    }

    Button {
        id: button1
        x: 40
        y: 164
        width: 138
        height: 40
        text: qsTr("Create another App")

        onClicked:
        {
            toThreadSignal("create", "")
        }
    }

    Button {
        id: button2
        x: 40
        y: 220
        width: 138
        height: 40
        text: qsTr("Create child App")

        onClicked:
        {
            toThreadSignal("create_child", "")
        }
    }

    states: [
        State {
            name: "State1"

            PropertyChanges {
                target: otherComponentsWrapperModernButton
                x: 251
                y: 270
            }

            PropertyChanges {
                target: timeline
                enabled: true
            }

            PropertyChanges {
                target: timelineAnimation
                running: true
            }
        },
        State {
            name: "State2"

            PropertyChanges {
                target: otherComponentsWrapperModernButton
                x: 40
                y: 340
            }

            PropertyChanges {
                target: timelineAnimation
                running: false
            }

            PropertyChanges {
                target: timeline
                enabled: false
            }
        }
    ]
    transitions: [
        Transition {
            id: transition
            ParallelAnimation {
                SequentialAnimation {
                    PauseAnimation {
                        duration: 1
                    }

                    PropertyAnimation {
                        target: otherComponentsWrapperModernButton
                        property: "x"
                        easing.bezierCurve: [0.0605,0.156,0.0398,-0.143,0.0615,-0.147,0.0832,-0.15,0.0841,0.0608,0.0985,0.151,0.113,0.241,0.147,-0.0754,0.175,-0.105,0.204,-0.135,0.186,0.0701,0.201,0.153,0.216,0.236,0.402,0.59,0.537,0.532,0.673,0.474,0.707,1.04,0.752,1.1,0.797,1.16,0.758,0.943,0.806,0.883,0.854,0.823,0.831,1.07,0.869,1.07,0.907,1.08,0.91,0.899,0.948,0.895,0.986,0.89,0.967,1.15,1,1]
                        duration: 999
                    }
                }

                SequentialAnimation {
                    PauseAnimation {
                        duration: 0
                    }

                    PropertyAnimation {
                        target: otherComponentsWrapperModernButton
                        property: "y"
                        duration: 492
                    }
                }
            }
            to: "State2"
            from: "State1"
        }
    ]
}

/*##^##
Designer {
    D{i:0}D{i:15}D{i:24;transitionDuration:2000}
}
##^##*/
