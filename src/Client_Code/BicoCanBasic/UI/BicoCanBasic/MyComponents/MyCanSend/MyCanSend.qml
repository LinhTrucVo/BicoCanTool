import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Controls.Material

Item {
    id: root
    width: 910
    height: 50

    property string canIdDefault: "18DA10F1x"
    property string canDataDefault: "02 10 01"
    property string rowId: ""
    property bool isSending: false

    readonly property string effectiveCanId: canIDField.text.length > 0 ? canIDField.text : canIdDefault
    readonly property string effectiveCanData: canDataField.text.length > 0 ? canDataField.text : canDataDefault
    readonly property string ms: msField.text

    signal sendClicked()
    signal stopClicked()

    TextField {
        id: canIDField
        x: 15
        y: 5
        width: 127
        height: 40
        placeholderText: root.canIdDefault
        font.pixelSize: 15
        onTextChanged: text = text.toUpperCase()
    }

    TextField {
        id: canDataField
        x: 148
        y: 5
        width: 550
        height: 40
        placeholderText: root.canDataDefault
        font.pixelSize: 15
        onTextChanged: text = text.toUpperCase()
    }

    TextField {
        id: msField
        x: 708
        y: 5
        width: 60
        height: 40
        text: "0"
        placeholderText: "ms"
        font.pixelSize: 15
        enabled: !root.isSending
        opacity: root.isSending ? 0.4 : 1.0
    }

    Button {
        id: sendButton
        x: 775
        y: 5
        width: 125
        height: 40
        text: root.isSending ? "Stop" : "Send"
        font.pixelSize: 15
        onClicked: {
            if (root.isSending) {
                root.isSending = false
                root.stopClicked()
            } else {
                var interval = parseInt(msField.text)
                if (!isNaN(interval) && interval > 0) {
                    root.isSending = true
                }
                root.sendClicked()
            }
        }
    }
}


