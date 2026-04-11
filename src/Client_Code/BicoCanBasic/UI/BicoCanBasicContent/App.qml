import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
// import QtQuick.Controls.Fusion
import QtQuick.Controls.Material
// import QtQuick.Controls.Universal
import QtQuick.Layouts 2.12
import "../BicoCanBasic/Constants"
import "../BicoCanBasic/MyComponents/MyText"
import "../BicoCanBasic/MyComponents/MyCanSend"
import "../BicoCanBasic/MyComponents/ThemeSwitch"
import "../BicoCanBasic/MyComponents/CanPortSelector"

import "js/utils.js" as Utils

// ApplicationWindow {
Window {
    id: window
    objectName: "window"
    width: Constants.width
    height: Constants.height
    visible: true
    title: qsTr("BICO CAN Basic")

    // Message interface loaded from MessageInterface.json (same folder)
    property var _MSG: ({})
    
    property int loopIdx: 0
    
    // Define tab order here
    Component.onCompleted: {
        // Load message key constants from JSON using utility function
        // Use Qt.resolvedUrl to get the absolute path to the JSON file
        var absJsonPath = Qt.resolvedUrl("UIMessageInterface.json");
        _MSG = Utils.loadUIMessageInterface(absJsonPath) || {};
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
            comCanPortSelector.portModel.clear()
            for (loopIdx = 0; loopIdx < rev_data.length; loopIdx++) {
                comCanPortSelector.portModel.append({"port": rev_data[loopIdx]});
            }
        }
        else if (rev_mess === _MSG.input.CAN_LOG)
        {
            var newLines = rev_data.split("\n")
            for (loopIdx = 0; loopIdx < newLines.length; loopIdx++) {
                if (newLines[loopIdx].length > 0) {
                    if (canLogModel.count >= 50000)
                        canLogModel.remove(0, 1)
                    canLogModel.append({"line": newLines[loopIdx]})
                }
            }
            canLogView.positionViewAtEnd()
        }
        else if (rev_mess === _MSG.input.CONNECTION_STATUS)
        {
            var statusData = JSON.parse(rev_data)
            // Update connect button if the status is for the currently selected port
            if (statusData.can_port === comCanPortSelector.currentPort)
            {
                comCanPortSelector.connectButtonText = statusData.connected ? "Disconnect" : "Connect"
            }
        }
        // This block of code is allowed to be changed - end -------------------
    }
    // Handle data from Thread - end ------------------------------------------------------------------

    // Send data to Thread - begin ------------------------------------------------------------------
    Connections
    {
        target: window
        function onClosing (){ toThread(_MSG.output.TERMINATE, "") } // new syntax
    }
    // Send data to Thread - begin ------------------------------------------------------------------




    // Responsive layout constants
    readonly property int _margin    : 10    // left/right margin
    readonly property int _logTop    : 55    // y where log area starts
    readonly property int _ctrlGap   : 5     // gap: log bottom → controls
    readonly property int _ctrlH     : 46    // controls band height
    readonly property int _sendGap   : 20    // gap: controls bottom → send rows
    readonly property int _sendH     : 251   // send rows fixed height
    readonly property int _botMargin : 13    // bottom margin
    // Derived positions — update automatically when window resizes
    readonly property int _ctrlY : height - _botMargin - _sendH - _sendGap - _ctrlH
    readonly property int _sendY : height - _botMargin - _sendH
    readonly property int _logH  : _ctrlY - _ctrlGap - _logTop

    // Theme mode:
    property string themeMode: themeSwitch.light
    Material.theme: themeMode === themeSwitch.light ? Material.Light : (themeMode === themeSwitch.dark ? Material.Dark : Material.System)
    // Tri-state theme switch (top-right)
    ThemeSwitch {
        id: themeSwitch
        x: window.width - width - 5
        y: 4        
        foreground: Material.foreground
        background: Material.backgroundColor
        accent: Material.accent

        themeMode: window.themeMode === ThemeSwitch.auto ? (window.Material.theme === Material.Dark ? ThemeSwitch.dark : ThemeSwitch.light) : window.themeMode
        onThemeChanged: {
            window.themeMode = themeSwitch.themeMode
            console.log("Theme changed to: " + window.themeMode)
        }
    }


    // CAN Port Selector Control Bar (Baudrate, Port, FD, Connect button)
    CanPortSelector {
        id: comCanPortSelector
        x: window.width - 500
        y: _ctrlY + 6
        height: 40
        onPortSelected: function(port) {
            console.log("Selected CAN port: " + port)
            toThread(_MSG.output.QUERY_CONNECTION_STATUS, port)
        }
        onUpdatePortListRequested: {
            toThread(_MSG.output.COM_PORT_LIST_UPDATE, "")
        }
        onConnectClicked: {
            toThread("Connect", `{"can_port": "${comCanPortSelector.currentPort}", "can_baudrate": ${comCanPortSelector.currentBaudrate}, "can_fd": ${comCanPortSelector.canFdEnabled}}`)
        }
        onDisconnectClicked: {
            toThread("Disconnect", `{"can_port": "${comCanPortSelector.currentPort}"}`)
        }
    }


    MyText {
        x: 12
        y: 33
        text: "Time" + " ".repeat(27) + "Port" + " ".repeat(27) + "Dir" + " ".repeat(15) + "ID" + " ".repeat(14) + "DLC/[idx]"
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

    // Wide area to monitor CAN frames
    Rectangle {
        x: _margin
        y: _logTop
        width: window.width - 2 * _margin
        height: _logH
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

    // Flickable Item for Send Rows
    Flickable {
        id: sendRowsFlickable
        x: 0
        y: _sendY
        width: window.width
        height: _sendH
        contentWidth: window.width
        contentHeight: ((rowCount - 1) * 46) + 50
        clip: true
        ScrollBar.vertical: ScrollBar {}

        property int rowCount: 100

        Repeater {
            id: rowRepeater
            model: sendRowsFlickable.rowCount

            MyCanSend {
                rowId: "row" + index
                y: index * 46
                onSendClicked: {
                    var currentRow = rowRepeater.itemAt(index)
                    toThread("Send", `{"can_port": "${comCanPortSelector.currentPort}", "can_id": "${currentRow.effectiveCanId}", "can_data": "${currentRow.effectiveCanData}", "interval_ms": ${parseInt(currentRow.ms)||0}, "row_id": "row${index}"}`)
                }
                onStopClicked: {
                    toThread(_MSG.output.STOP_SEND, `{"row_id": "row${index}"}`)
                }
            }
        }

        Tumbler {
            id: tumbler
            x: 335
            y: -44
            model: 10
        }
    }
}
/*##^##
Designer {
    D{i:0;formeditorZoom:1.1}
}
##^##*/
