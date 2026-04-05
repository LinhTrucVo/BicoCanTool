import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Controls.Material

Item {
    id: root
    width: parent ? parent.width : 910
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

    function isValidHex(str) {
        // Remove spaces
        var cleaned = str.replace(/\s/g, "")
        // Check if even number of characters
        if (cleaned.length % 2 !== 0) return false
        // Check if all characters are valid hex
        var hexRegex = /^[0-9A-Fa-f]*$/
        return hexRegex.test(cleaned)
    }

    function formatHexWithSpaces(str) {
        var cleaned = str.replace(/\s/g, "").toUpperCase()
        var formatted = ""
        for (var i = 0; i < cleaned.length; i += 2) {
            if (i > 0) formatted += " "
            formatted += cleaned[i] + (i + 1 < cleaned.length ? cleaned[i + 1] : "")
        }
        return formatted
    }

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
        width: root.width - 148 - 10 - 60 - 7 - 125 - 10
        height: 40
        placeholderText: root.canDataDefault
        font.pixelSize: 15
        color: isValidHex(text) ? Material.foreground : "#FF6B6B"
        onTextChanged: {
            text = text.toUpperCase()
        }
    }

    TextField {
        id: msField
        x: root.width - 10 - 125 - 7 - 60
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
        x: root.width - 10 - 125
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
                // Format canDataField with spaces every 2 characters
                canDataField.text = formatHexWithSpaces(canDataField.text)
                root.sendClicked()
            }
        }
    }
}


