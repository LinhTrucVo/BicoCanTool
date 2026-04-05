import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
// import QtQuick.Controls.Fusion
import QtQuick.Controls.Material
// import QtQuick.Controls.Universal
import QtQuick.Layouts 2.12
import "../BicoCanBasic/MyComponents/MyText"
import "../BicoCanBasic/MyComponents/MyCanSend"

// ApplicationWindow {
Window {
    id: window
    objectName: "window"
    width: 910
    height: 880
    visible: true
    title: qsTr("BICO CAN Basic")

    // Message interface loaded from MessageInterface.json (same folder)
    property var _MSG: ({})
    // Define tab order here
    Component.onCompleted: {
        // Load message key constants from JSON
        var request = new XMLHttpRequest()
        var url = Qt.resolvedUrl("UIMessageInterface.json").toString()
        request.open("GET", url, false)
        request.send()
        if (request.responseText.length > 0) {
            _MSG = JSON.parse(request.responseText)
            console.log("Message keys loaded: " + JSON.stringify(_MSG))
        } else {
            console.log("Failed to load UIMessageInterface.json from: " + url + " (status=" + request.status + ")")
        }
    }

    // Signal transfer send data to Thread - begin ------------------------------------------------------------------
    signal toThread(string rev_mess, var rev_data)
    // Signal transfer send data to Thread - end ------------------------------------------------------------------
    // Handle data from Thread - begin ------------------------------------------------------------------
    signal fromThread(string rev_mess, var rev_data)
    onFromThread: function(rev_mess, rev_data)
    {
        // This block of code is allowed to be changed - begin -------------------
        if (rev_mess === _MSG.input.COM_PORT_LIST)
        {
            console.log(rev_mess + " " + rev_data)
            availablePortsModel.clear()
            for (var i = 0; i < rev_data.length; i++) {
                availablePortsModel.append({"port": rev_data[i]});
            }
        }
        else if (rev_mess === _MSG.input.CAN_LOG)
        {
            var newLines = rev_data.split("\n")
            for (var i = 0; i < newLines.length; i++) {
                if (newLines[i].length > 0) {
                    if (canLogModel.count >= 50000)
                        canLogModel.remove(0, 1)
                    canLogModel.append({"line": newLines[i]})
                }
            }
            canLogView.positionViewAtEnd()
        }
        else if (rev_mess === _MSG.input.CONNECTION_STATUS)
        {
            var statusData = JSON.parse(rev_data)
            // Update connect button if the status is for the currently selected port
            if (statusData.can_port === comPortDropdown.currentText)
            {
                connectButton.text = statusData.connected ? "Disconnect" : "Connect"
            }
        }
        // This block of code is allowed to be changed - end -------------------
    }
    // Handle data from Thread - end ------------------------------------------------------------------

    // Send data to Thread - begin ------------------------------------------------------------------
    Connections
    {
        target: window
//		onClosing: fromUI("terminate", "") // old syntax
        function onClosing (){ toThread(_MSG.output.TERMINATE, "") } // new syntax
    }
    // Send data to Thread - begin ------------------------------------------------------------------



    // Theme mode: 0 = Light, 1 = System, 2 = Dark
    property int themeMode: 0
    Material.theme: themeMode === 0 ? Material.Light : (themeMode === 2 ? Material.Dark : Material.System)

    // Tri-state theme switch (top-right)
    Row {
        id: themeSwitch
        x: window.width - width - 5
        y: 4
        z: 10
        spacing: 0

        Repeater {
            model: [
                { label: "\u2600", mode: 0 },  // ☀ Light
                { label: "Auto",   mode: 1 },  // System
                { label: "\u263E", mode: 2 }   // ☾ Dark
            ]
            delegate: Rectangle {
                width: 40
                height: 24
                radius: index === 0 ? 12 : (index === 2 ? 12 : 0)
                color: window.themeMode === modelData.mode
                       ? Material.accent
                       : (window.Material.theme === Material.Dark ? "#555" : "#ccc")

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
                    color: window.themeMode === modelData.mode ? "white" : Material.foreground
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.themeMode = modelData.mode
                }
            }
        }
    }


    // Input field for CAN baudrate
    ComboBox {
        id: baudrateField
        x: 426
        y: 556
        width: 115
        height: 40
        model: ["500000", "1000000", "2000000"]
        currentIndex: 0  // Default to 500000
        font.pixelSize: 15
    }

    ComboBox {
        id: comPortDropdown
        x: 547
        y: 556
        width: 191
        height: 40
        model: availablePortsModel
        font.pixelSize: 15
        anchors.verticalCenterOffset: 196
        anchors.horizontalCenterOffset: 220
        onActivated: {
            console.log("Selected CAN port: " + comPortDropdown.currentText)
            // Query backend for the connection status of the selected port
            toThread(_MSG.output.QUERY_CONNECTION_STATUS, comPortDropdown.currentText)
        }
        onPressedChanged: {
            if (!pressed)
            {
                toThread(_MSG.output.COM_PORT_LIST_UPDATE, "")
            }
        }
    }

    // ListModel to hold the CAN port data
    ListModel {
        id: availablePortsModel
    }

    // FD checkbox label
    MyText {
        x: 745
        y: 550
        text: "FD:"
        font.pixelSize: 15
    }

    // FD checkbox
    CheckBox {
        id: fdCheckBox
        x: 745
        y: 565
        width: 20
        height: 40
        checked: false
    }

    // Button to connect to the device
    Button {
        id: connectButton
        x: 776
        y: 556
        text: "Connect"
        width: 128
        height: 40
        font.pixelSize: 15
        onClicked: {
            if (comPortDropdown.currentText != "")
            {
                toThread(this.text, `{"can_port": "${comPortDropdown.currentText}", "can_baudrate": ${baudrateField.currentText}, "can_fd": ${fdCheckBox.checked}}`)
            }
        }
    }


    // Wide area to monitor CAN frames
    Rectangle {
        x: 10
        y: 55
        width: 890
        height: 490
        color: "transparent"
        border.color: Material.foreground
        border.width: 1

        ListModel { id: canLogModel }

        ListView {
            id: canLogView
            anchors.fill: parent
            anchors.margins: 1
            model: canLogModel
            clip: true
            ScrollBar.vertical: ScrollBar {}

            delegate: Text {
                width: canLogView.width
                text: model.line
                font.pixelSize: 15
                font.family: "Consolas"
                color: Material.foreground
                wrapMode: Text.NoWrap
            }

            Text {
                anchors.centerIn: parent
                text: "CAN log appear here...."
                visible: canLogModel.count === 0
                font.pixelSize: 15
                color: Material.foreground
                opacity: 0.5
            }
        }
    }


    MyText {
        x: 12
        y: 33
        text: "Time"
        font.pixelSize: 15
    }

    MyText {
        x: 170
        y: 33
        text: "Port"
        font.pixelSize: 15
    }

    MyText {
        x: 331
        y: 33
        text: "Dir"
        font.pixelSize: 15
    }

    MyText {
        x: 413
        y: 33
        text: "ID"
        font.pixelSize: 15
    }

    MyText {
        x: 495
        y: 33
        text: "DLC/[idx]"
        font.pixelSize: 15
    }

    Repeater {
        model: 8
        MyText {
            x: 575 + index * 41
            y: 33
            text: "[" + index + "]"
            font.pixelSize: 15
        }
    }

    // Input field for CAN data

    // Flickable Item for Send Rows
    Flickable {
        id: sendRowsFlickable
        x: 0
        y: 616
        width: 910
        height: 251
        contentWidth: 910
        contentHeight: row15.y + row15.height
        clip: true

        MyCanSend { id: row0;  rowId: "row0";  y: 0;   canIdDefault: "18DA10F1x"; onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row0.effectiveCanId}",  "can_data": "${row0.effectiveCanData}",  "interval_ms": ${parseInt(row0.ms)||0}, "row_id": "${row0.rowId}"}`)  ; onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row0.rowId}"}`)  }
        MyCanSend { id: row1;  rowId: "row1";  y: 46;  canIdDefault: "18DA10F1x"; onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row1.effectiveCanId}",  "can_data": "${row1.effectiveCanData}",  "interval_ms": ${parseInt(row1.ms)||0}, "row_id": "${row1.rowId}"}`)  ; onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row1.rowId}"}`)  }
        MyCanSend { id: row2;  rowId: "row2";  y: 92;  canIdDefault: "18DAF110x"; onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row2.effectiveCanId}",  "can_data": "${row2.effectiveCanData}",  "interval_ms": ${parseInt(row2.ms)||0}, "row_id": "${row2.rowId}"}`)  ; onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row2.rowId}"}`)  }
        MyCanSend { id: row3;  rowId: "row3";  y: 138; canIdDefault: "18DAF110x"; onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row3.effectiveCanId}",  "can_data": "${row3.effectiveCanData}",  "interval_ms": ${parseInt(row3.ms)||0}, "row_id": "${row3.rowId}"}`)  ; onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row3.rowId}"}`)  }
        MyCanSend { id: row4;  rowId: "row4";  y: 184; canIdDefault: "712";       onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row4.effectiveCanId}",  "can_data": "${row4.effectiveCanData}",  "interval_ms": ${parseInt(row4.ms)||0}, "row_id": "${row4.rowId}"}`)  ; onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row4.rowId}"}`)  }
        MyCanSend { id: row5;  rowId: "row5";  y: 230; canIdDefault: "712";       onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row5.effectiveCanId}",  "can_data": "${row5.effectiveCanData}",  "interval_ms": ${parseInt(row5.ms)||0}, "row_id": "${row5.rowId}"}`)  ; onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row5.rowId}"}`)  }
        MyCanSend { id: row6;  rowId: "row6";  y: 276; canIdDefault: "123x";      onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row6.effectiveCanId}",  "can_data": "${row6.effectiveCanData}",  "interval_ms": ${parseInt(row6.ms)||0}, "row_id": "${row6.rowId}"}`)  ; onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row6.rowId}"}`)  }
        MyCanSend { id: row7;  rowId: "row7";  y: 322; canIdDefault: "321x";      onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row7.effectiveCanId}",  "can_data": "${row7.effectiveCanData}",  "interval_ms": ${parseInt(row7.ms)||0}, "row_id": "${row7.rowId}"}`)  ; onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row7.rowId}"}`)  }
        MyCanSend { id: row8;  rowId: "row8";  y: 368; canIdDefault: "7DA";       onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row8.effectiveCanId}",  "can_data": "${row8.effectiveCanData}",  "interval_ms": ${parseInt(row8.ms)||0}, "row_id": "${row8.rowId}"}`)  ; onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row8.rowId}"}`)  }
        MyCanSend { id: row9;  rowId: "row9";  y: 414; canIdDefault: "7DA";       onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row9.effectiveCanId}",  "can_data": "${row9.effectiveCanData}",  "interval_ms": ${parseInt(row9.ms)||0}, "row_id": "${row9.rowId}"}`)  ; onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row9.rowId}"}`)  }
        MyCanSend { id: row10; rowId: "row10"; y: 460; canIdDefault: "7DA";       onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row10.effectiveCanId}", "can_data": "${row10.effectiveCanData}", "interval_ms": ${parseInt(row10.ms)||0}, "row_id": "${row10.rowId}"}`); onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row10.rowId}"}`) }
        MyCanSend { id: row11; rowId: "row11"; y: 506; canIdDefault: "7DA";       onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row11.effectiveCanId}", "can_data": "${row11.effectiveCanData}", "interval_ms": ${parseInt(row11.ms)||0}, "row_id": "${row11.rowId}"}`); onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row11.rowId}"}`) }
        MyCanSend { id: row12; rowId: "row12"; y: 552; canIdDefault: "7DA";       onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row12.effectiveCanId}", "can_data": "${row12.effectiveCanData}", "interval_ms": ${parseInt(row12.ms)||0}, "row_id": "${row12.rowId}"}`); onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row12.rowId}"}`) }
        MyCanSend { id: row13; rowId: "row13"; y: 598; canIdDefault: "7DA";       onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row13.effectiveCanId}", "can_data": "${row13.effectiveCanData}", "interval_ms": ${parseInt(row13.ms)||0}, "row_id": "${row13.rowId}"}`); onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row13.rowId}"}`) }
        MyCanSend { id: row14; rowId: "row14"; y: 644; canIdDefault: "7DA";       onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row14.effectiveCanId}", "can_data": "${row14.effectiveCanData}", "interval_ms": ${parseInt(row14.ms)||0}, "row_id": "${row14.rowId}"}`); onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row14.rowId}"}`) }
        MyCanSend { id: row15; rowId: "row15"; y: 690; canIdDefault: "7DA";       onSendClicked: toThread("Send", `{"can_port": "${comPortDropdown.currentText}", "can_id": "${row15.effectiveCanId}", "can_data": "${row15.effectiveCanData}", "interval_ms": ${parseInt(row15.ms)||0}, "row_id": "${row15.rowId}"}`); onStopClicked: toThread(_MSG.output.STOP_SEND, `{"row_id": "${row15.rowId}"}`) }
    }
}
/*##^##
Designer {
    D{i:0;formeditorZoom:1.1}
}
##^##*/
