import QtQuick 2.12
import QtQuick.Controls 2.12

ComboBox {
    id: comPortDropdown
    
    // Properties exposed to parent
    property var portModel: ListModel { id: availablePortsModel }
    
    // Signals for parent to connect to
    signal portSelected(string port)
    signal updatePortListRequested()
    
    model: portModel
    font.pixelSize: 15
    
    onActivated: {
        console.log("Selected port: " + comPortDropdown.currentText)
        portSelected(comPortDropdown.currentText)
    }
    
    onPressedChanged: {
        if (!pressed) {
            updatePortListRequested()
        }
    }
}
