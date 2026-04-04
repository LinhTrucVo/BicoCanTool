import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12

// By importing module by path, the component appears
// in the Component tab in design mode.
// This makes the component available for preview and
// be able to dropped in design mode.
import "../BicoCanTp/Constants"
import "../BicoCanTp/MyComponents/ModernButton"
import "../BicoCanTp/OtherComponents/ModernButton"
import QtQuick.Timeline 1.0

Window {
    id: window
    objectName: "window"
    width: Constants.width
    height: Constants.height
    // height: 480
    visible: true
    title: qsTr("Hello World")


// =====================================================================================================================================================================

    // Terminate the thread when the window is close - begin ------------------------------------------------------------------
    Connections
    {
        target: window
        function onClosing (close){ 
            close.accepted = false  // Prevent the window from closing immediately
            toThread("terminate", "") // Send terminate message to thread
        } // Thread will handle cleanup and close the window via deleteLater()
    }
    // Terminate the thread when the window is close - end ------------------------------------------------------------------


// =====================================================================================================================================================================


// Signal handling - begin ------------------------------------------------------------------------------------------------------------------------------------

    // Signal transfer send data - begin ------------------------------------------------------------------
    signal toThread(string rev_mess, var rev_data)
    signal fromThread(string rev_mess, var rev_data)
    // Signal transfer send data - end ------------------------------------------------------------------

    // Handle data from Thread - begin ------------------------------------------------------------------
    onFromThread: function(rev_mess, rev_data)
    {
        // This block of code is allowed to be changed - begin -------------------
        if (rev_mess === "size")
        {
            screen01.fromThreadSignal(rev_mess, rev_data)
        }
        else
        {
            console.log(rev_mess + " " + rev_data)
        }

        // This block of code is allowed to be changed - end -------------------
    }
    // Handle data from Thread - end ------------------------------------------------------------------

// Signal handling - end ---------------------------------------------------------------------------------------------------

    Screen01 {
        id: screen01
        x: 107
        y: 79
        width: 533
        height: 401
        objectName: "screen01"
        
        // Connect toThreadSignal properties to Window's toThread
        toThreadSignal: toThread
    }

}
