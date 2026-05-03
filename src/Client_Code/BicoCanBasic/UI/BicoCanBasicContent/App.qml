import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material
import QtQuick.Layouts 2.15
import Qt.labs.qmlmodels 1.0
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


    // CAN log table view
    Rectangle {
        id: canLogRect
        x: _margin
        y: _logTop
        width: window.width - 2 * _margin
        height: _logH
        color: "transparent"
        border.color: Material.foreground
        border.width: 1

        readonly property var colHeaders:  ["Time", "Port", "Dir", "FD", "Ext", "ID", "DLC", "Data"]
        readonly property var colWidths:   [130,     130,    35,    30,   30,    80,   40,    280]
        readonly property int totalWidth:  130 + 130 + 35 + 30 + 30 + 80 + 40 + 280

        // Header row — clips at border and scrolls with the TableView
        Item {
            id: headerClip
            x: 1; y: 2
            width: canLogRect.width - 2
            height: 20
            clip: true

            Row {
                x: -canLogView.contentX
                spacing: 0
                Repeater {
                    model: canLogRect.colHeaders
                    Text {
                        width: canLogRect.colWidths[index]
                        height: 20
                        text: modelData
                        font.pixelSize: 13
                        font.family: "Consolas"
                        font.bold: true
                        color: Material.foreground
                    }
                }
            }
        }

        // Header separator
        Rectangle {
            x: 1; y: 23
            width: canLogRect.width - 2
            height: 1
            color: Material.foreground
            opacity: 0.5
        }

        // Auto-scroll to bottom when rows are added
        Connections {
            target: canLogModel
            function onRowsInserted(parent, first, last) {
                canLogView.positionViewAtRow(canLogModel.rowCount() - 1, TableView.AlignBottom)
            }
        }

        TableView {
            id: canLogView
            x: 1; y: 24
            width: canLogRect.width - 2
            height: canLogRect.height - 25
            model: canLogModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: canLogRect.totalWidth
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

            columnWidthProvider: function(col) { return canLogRect.colWidths[col] }
            rowHeightProvider: function(row) { return 20 }

            delegate: Text {
                text: display || ""
                font.pixelSize: 13
                font.family: "Consolas"
                color: Material.foreground
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            anchors.centerIn: parent
            text: "CAN log appears here...."
            visible: canLogModel.count === 0
            font.pixelSize: 15
            color: Material.foreground
            opacity: 0.5
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
    }
}
/*##^##
Designer {
    D{i:0;formeditorZoom:1.1}
}
##^##*/
