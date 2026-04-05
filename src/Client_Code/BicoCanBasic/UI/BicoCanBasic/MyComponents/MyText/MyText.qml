import QtQuick 2.12
import QtQuick.Controls 2.12
// import QtQuick.Controls.Material 2.12

TextField {
    id: myText
    
    // Make it read-only and non-editable
    readOnly: true
    selectByMouse: false
    
    // Inherit text color from Material theme
    // color: Material.foreground
    
    // Remove all padding to match Text behavior
    padding: 0
    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0
    
    // Remove the default border appearance
    background: Rectangle {
        color: "transparent"
        border.color: "transparent"
    }
    
    // Align text to top-left like Text element
    verticalAlignment: TextField.AlignTop
    
    // Remove implicit height so it behaves like plain Text
    implicitHeight: contentHeight
}