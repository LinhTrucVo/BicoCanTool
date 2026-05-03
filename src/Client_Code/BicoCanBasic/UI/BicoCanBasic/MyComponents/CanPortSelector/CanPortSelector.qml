import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Controls.Material
import "../MyText"
import "../PortSelector"

Row {
    id: canPortSelectorRoot
    spacing: 3
    
    // Properties exposed to parent
    property var portModel: portSelector.portModel
    property alias currentPort: portSelector.currentText
    property alias canFdEnabled: fdCheckBox.checked
    property alias currentBaudrate: baudrateField.currentText
    property alias connectButtonText: connectButton.text
    
    // Signals from port selector
    signal portSelected(string port)
    signal updatePortListRequested()
    signal connectClicked()
    signal disconnectClicked()

    height: 44
    
    // Baudrate field
    ComboBox {
        id: baudrateField
        width: 115
        height: parent.height - 2
        model: ["500000", "1000000", "2000000"]
        currentIndex: 0
        font.pixelSize: 15
    }
    
    // Port selector component
    PortSelector {
        id: portSelector
        width: 191
        height: parent.height - 2
        onPortSelected: function(port) { canPortSelectorRoot.portSelected(port) }
        onUpdatePortListRequested: canPortSelectorRoot.updatePortListRequested()
    }
    
    // FD label
    MyText {
        y: parent.height / 2 - height / 2
        text: "FD:"
        font.pixelSize: 15
        leftPadding: 5
    }
    
    // FD checkbox
    CheckBox {
        id: fdCheckBox
        y: parent.height / 2 - height / 2
        width: 20
        height: 40
        checked: false
    }

    
    // Connect button
    Button {
        id: connectButton
        text: "Connect"
        width: 128
        height: parent.height - 2
        font.pixelSize: 15
        onClicked: {
            if (portSelector.currentText !== "") {
                if (connectButton.text === "Connect") {
                    canPortSelectorRoot.connectClicked()
                } else {
                    canPortSelectorRoot.disconnectClicked()
                }
            }
        }
    }
}

