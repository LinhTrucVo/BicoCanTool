import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
// import QtQuick.Controls.Fusion
// import QtQuick.Controls.Material
// import QtQuick.Controls.Universal
import QtQuick.Layouts 2.12
import "../BicoCanBasic/MyComponents/MyText"

// ApplicationWindow{
Window{
    id: window
    objectName: "window"
    width: 910
    height: 880
    visible: true
    title: qsTr("BICO CAN Basic")
    // Material.theme: Material.System

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
            console.log(rev_mess + " " + rev_data)
            canLogArea.text += rev_data + "\r\n"
            canLogArea.cursorPosition = canLogArea.text.length
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



    // Input field for CAN baudrate
    MyText {
        x: 497
        y: 424
        text: "CAN Baud:"
        font.pixelSize: 15
    }
    ComboBox {
        id: baudrateField
        x: 497
        y: 446
        width: 115
        height: 40
        model: ["500000", "1000000", "2000000"]
        currentIndex: 0  // Default to 500000
        font.pixelSize: 15
    }

    MyText {
        x: 616
        y: 424
        text: "Serial Port:"
        font.pixelSize: 15
    }

    ComboBox {
        id: comPortDropdown
        x: 616
        y: 446
        width: 153
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
        x: 778
        y: 424
        text: "FD:"
        font.pixelSize: 15
    }

    // FD checkbox
    CheckBox {
        id: fdCheckBox
        x: 778
        y: 446
        width: 20
        height: 40
        checked: false
    }

    // Button to connect to the device
    Button {
        id: connectButton
        x: 807
        y: 446
        text: "Connect"
        width: 91
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
    Item {
        x: 5
        y: 30
        width: 770
        height: 350
        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.rightMargin: -132
            TextArea {
                id: canLogArea
                x: 0
                y: 0
                width: parent.width
                height: parent.height
                // placeholderText: "CAN log appear here...."
                placeholderText: "00:27:22.676474	Virtual Channel 1	TX	18DA10F1x    8	DD   DD   DD   DD   DD   DD   DD   DD"
                readOnly: false
                font.pixelSize: 15
                font.family: "Consolas" // Replace with your desired font
            }
        }
    }


    // Button to send CAN frame
    Button {
        id: sendButton
        x: 356
        y: 446
        text: "Send"
        width: 78
        height: 40
        font.pixelSize: 15
        onClicked: {
            // Logic to send CAN frame goes here
            // console.log("Sending CAN frame with ID: " + canIDField.text + " and Data: " + canDataField.text)
            var can_id = canIDField.text
            var can_data = canDataField.text
            if (can_id == "")
            {
                can_id = canIDField.placeholderText
            }
            if (can_data == "")
            {
                can_data = canDataField.placeholderText
            }
            toThread(text, `{"can_port": "${comPortDropdown.currentText}", "can_id": "${can_id}", "can_data": "${can_data}"}`)
        }
    }
    
    // Input field for CAN ID
    TextField {
        id: canIDField
        x: 15
        y: 446
        width: 127
        height: 40
        placeholderText: "18DA10F1x"
        font.pixelSize: 15
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    // Input field for CAN data
    MyText {
        x: 146
        y: 424
        text: "CAN Data:"
        font.pixelSize: 15
    }
    TextField {
        id: canDataField
        x: 148
        y: 446
        width: 202
        height: 40
        placeholderText: "02 10 01"
        font.pixelSize: 15
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    MyText {
        x: 12
        y: 12
        text: "Time"
        font.pixelSize: 15
    }

    MyText {
        x: 170
        y: 12
        text: "Port"
        font.pixelSize: 15
    }

    MyText {
        x: 331
        y: 12
        text: "Dir"
        font.pixelSize: 15
    }

    MyText {
        x: 15
        y: 424
        text: "CAN ID"
        font.pixelSize: 15
    }

    MyText {
        x: 413
        y: 12
        text: "ID"
        font.pixelSize: 15
    }

    MyText {
        x: 515
        y: 12
        text: "DLC"
        font.pixelSize: 15
    }

    MyText {
        id: byte0
        x: 571
        y: 12
        text: "[0]"
        font.pixelSize: 15
    }

    MyText {
        id: byte1
        x: 612
        y: 12
        text: "[1]"
        font.pixelSize: 15
    }

    MyText {
        id: byte2
        x: 653
        y: 12
        text: "[2]"
        font.pixelSize: 15
    }

    MyText {
        id: byte3
        x: 694
        y: 12
        text: "[3]"
        font.pixelSize: 15
    }

    MyText {
        id: byte4
        x: 735
        y: 12
        text: "[4]"
        font.pixelSize: 15
    }

    MyText {
        id: byte5
        x: 776
        y: 12
        text: "[5]"
        font.pixelSize: 15
    }

    MyText {
        id: byte6
        x: 817
        y: 12
        text: "[6]"
        font.pixelSize: 15
    }

    MyText {
        id: byte7
        x: 858
        y: 12
        text: "[7]"
        font.pixelSize: 15
    }

    Button {
        id: sendButton1
        x: 356
        y: 492
        width: 78
        height: 40
        text: "Send"
        font.pixelSize: 15
        onClicked: {
                // Logic to send CAN frame goes here
                // console.log("Sending CAN frame with ID: " + canIDField.text + " and Data: " + canDataField.text)
                var can_id = canIDField1.text
                var can_data = canDataField1.text
                if (can_id == "")
                {
                    can_id = canIDField1.placeholderText
                }
                if (can_data == "")
                {
                    can_data = canDataField1.placeholderText
                }
                toThread(text, `{"can_port": "${comPortDropdown.currentText}", "can_id": "${can_id}", "can_data": "${can_data}"}`)
        }
    }

    TextField {
        id: canIDField1
        x: 15
        y: 492
        width: 127
        height: 40
        font.pixelSize: 15
        placeholderText: "18DA10F1x"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    TextField {
        id: canDataField1
        x: 148
        y: 492
        width: 202
        height: 40
        font.pixelSize: 15
        placeholderText: "02 10 01"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    Button {
        id: sendButton2
        x: 356
        y: 538
        width: 78
        height: 40
        text: "Send"
        font.pixelSize: 15
        onClicked: {
                // Logic to send CAN frame goes here
                // console.log("Sending CAN frame with ID: " + canIDField.text + " and Data: " + canDataField.text)
                var can_id = canIDField2.text
                var can_data = canDataField2.text
                if (can_id == "")
                {
                    can_id = canIDField2.placeholderText
                }
                if (can_data == "")
                {
                    can_data = canDataField2.placeholderText
                }
                toThread(text, `{"can_port": "${comPortDropdown.currentText}", "can_id": "${can_id}", "can_data": "${can_data}"}`)
        }
    }

    TextField {
        id: canIDField2
        x: 15
        y: 538
        width: 127
        height: 40
        font.pixelSize: 15
        placeholderText: "18DAF110x"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    TextField {
        id: canDataField2
        x: 148
        y: 538
        width: 202
        height: 40
        font.pixelSize: 15
        placeholderText: "02 10 01"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    Button {
        id: sendButton3
        x: 356
        y: 584
        width: 78
        height: 40
        text: "Send"
        font.pixelSize: 15
        onClicked: {
                // Logic to send CAN frame goes here
                // console.log("Sending CAN frame with ID: " + canIDField.text + " and Data: " + canDataField.text)
                var can_id = canIDField3.text
                var can_data = canDataField3.text
                if (can_id == "")
                {
                    can_id = canIDField3.placeholderText
                }
                if (can_data == "")
                {
                    can_data = canDataField3.placeholderText
                }
                toThread(text, `{"can_port": "${comPortDropdown.currentText}", "can_id": "${can_id}", "can_data": "${can_data}"}`)
        }
    }

    TextField {
        id: canIDField3
        x: 15
        y: 584
        width: 127
        height: 40
        font.pixelSize: 15
        placeholderText: "18DAF110x"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    TextField {
        id: canDataField3
        x: 148
        y: 584
        width: 202
        height: 40
        font.pixelSize: 15
        placeholderText: "02 10 01"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    Button {
        id: sendButton4
        x: 356
        y: 630
        width: 78
        height: 40
        text: "Send"
        font.pixelSize: 15
        onClicked: {
                // Logic to send CAN frame goes here
                // console.log("Sending CAN frame with ID: " + canIDField.text + " and Data: " + canDataField.text)
                var can_id = canIDField4.text
                var can_data = canDataField4.text
                if (can_id == "")
                {
                    can_id = canIDField4.placeholderText
                }
                if (can_data == "")
                {
                    can_data = canDataField4.placeholderText
                }
                toThread(text, `{"can_port": "${comPortDropdown.currentText}", "can_id": "${can_id}", "can_data": "${can_data}"}`)
        }
    }

    TextField {
        id: canIDField4
        x: 15
        y: 630
        width: 127
        height: 40
        font.pixelSize: 15
        placeholderText: "712"
    }

    TextField {
        id: canDataField4
        x: 148
        y: 630
        width: 202
        height: 40
        font.pixelSize: 15
        placeholderText: "02 10 01"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    Button {
        id: sendButton5
        x: 356
        y: 676
        width: 78
        height: 40
        text: "Send"
        font.pixelSize: 15
        onClicked: {
                // Logic to send CAN frame goes here
                // console.log("Sending CAN frame with ID: " + canIDField.text + " and Data: " + canDataField.text)
                var can_id = canIDField5.text
                var can_data = canDataField5.text
                if (can_id == "")
                {
                    can_id = canIDField5.placeholderText
                }
                if (can_data == "")
                {
                    can_data = canDataField5.placeholderText
                }
                toThread(text, `{"can_port": "${comPortDropdown.currentText}", "can_id": "${can_id}", "can_data": "${can_data}"}`)
        }
    }

    TextField {
        id: canIDField5
        x: 15
        y: 676
        width: 127
        height: 40
        font.pixelSize: 15
        placeholderText: "712"

        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    TextField {
        id: canDataField5
        x: 148
        y: 676
        width: 202
        height: 40
        font.pixelSize: 15
        placeholderText: "02 10 01"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    Button {
        id: sendButton6
        x: 356
        y: 722
        width: 78
        height: 40
        text: "Send"
        font.pixelSize: 15
        onClicked: {
                // Logic to send CAN frame goes here
                // console.log("Sending CAN frame with ID: " + canIDField.text + " and Data: " + canDataField.text)
                var can_id = canIDField6.text
                var can_data = canDataField6.text
                if (can_id == "")
                {
                    can_id = canIDField6.placeholderText
                }
                if (can_data == "")
                {
                    can_data = canDataField6.placeholderText
                }
                toThread(text, `{"can_port": "${comPortDropdown.currentText}", "can_id": "${can_id}", "can_data": "${can_data}"}`)
        }
    }

    TextField {
        id: canIDField6
        x: 15
        y: 722
        width: 127
        height: 40
        font.pixelSize: 15
        placeholderText: "123x"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    TextField {
        id: canDataField6
        x: 148
        y: 722
        width: 202
        height: 40
        font.pixelSize: 15
        placeholderText: "02 10 01"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    Button {
        id: sendButton7
        x: 356
        y: 768
        width: 78
        height: 40
        text: "Send"
        font.pixelSize: 15
        onClicked: {
                // Logic to send CAN frame goes here
                // console.log("Sending CAN frame with ID: " + canIDField.text + " and Data: " + canDataField.text)
                var can_id = canIDField7.text
                var can_data = canDataField7.text
                if (can_id == "")
                {
                    can_id = canIDField7.placeholderText
                }
                if (can_data == "")
                {
                    can_data = canDataField7.placeholderText
                }
                toThread(text, `{"can_port": "${comPortDropdown.currentText}", "can_id": "${can_id}", "can_data": "${can_data}"}`)
        }
    }

    TextField {
        id: canIDField7
        x: 15
        y: 768
        width: 127
        height: 40
        font.pixelSize: 15
        placeholderText: "321x"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    TextField {
        id: canDataField7
        x: 148
        y: 768
        width: 202
        height: 40
        font.pixelSize: 15
        placeholderText: "02 10 01"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    Button {
        id: sendButton8
        x: 356
        y: 814
        width: 78
        height: 40
        text: "Send"
        font.pixelSize: 15
        onClicked: {
                // Logic to send CAN frame goes here
                // console.log("Sending CAN frame with ID: " + canIDField.text + " and Data: " + canDataField.text)
                var can_id = canIDField8.text
                var can_data = canDataField8.text
                if (can_id == "")
                {
                    can_id = canIDField8.placeholderText
                }
                if (can_data == "")
                {
                    can_data = canDataField8.placeholderText
                }
                toThread(text, `{"can_port": "${comPortDropdown.currentText}", "can_id": "${can_id}", "can_data": "${can_data}"}`)
        }
    }

    TextField {
        id: canIDField8
        x: 15
        y: 814
        width: 127
        height: 40
        font.pixelSize: 15
        placeholderText: "7DA"

        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    TextField {
        id: canDataField8
        x: 148
        y: 814
        width: 202
        height: 40
        font.pixelSize: 15
        placeholderText: "02 10 01"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }
}
/*##^##
Designer {
    D{i:0;formeditorZoom:1.1}
}
##^##*/
