"""
Main entry point for the PyQtQuick project.

This module initializes the QGuiApplication, sets up the main threads, and loads the QML UI.
"""

import sys
import os
from PySide6.QtGui import QGuiApplication

from lib import Bico_QMutexQueue
from lib import Bico_QUIThread
from Client_Code.BicoCanBasic.BicoCanBasic import BicoCanBasic

current_path = os.getcwd()

# Allow QML XMLHttpRequest to read local files (needed for loading message_keys.json)
os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"

# Import the qml resource, do not delete this import
import qt_resource.resource

if __name__ == "__main__":

    app = QGuiApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    Bico_QUIThread.setMainApp(app)
    
    # Initialize factories in main thread to ensure thread safety
    Bico_QUIThread.initializeFactories()
    
    # # Print all available resource paths (now cached in initializeFactories)
    # for path in Bico_QUIThread.qml_import_paths:
    #     print(path)
#  ------------------------------------------------------------------------------
    Bico_QUIThread.create(
        # Using pure qml
        BicoCanBasic,
        Bico_QMutexQueue(), 
        1, 
        Bico_QMutexQueue(), 
        1, 
        "BicoCanBasicTask", 
        os.path.join(current_path, "Client_Code/BicoCanBasic/UI/BicoCanBasicContent/App.qml")
        
        # # Using qml which is intergrated to Qt resource
        # BicoCanBasic,
        # Bico_QMutexQueue(),
        # 1, 
        # Bico_QMutexQueue(), 
        # 1, 
        # "task_0", 
        # "qrc:/Client_Code/BicoCanBasic/UI/BicoCanBasicContent/App.qml"
    )
    Bico_QUIThread.getThreadHash()["BicoCanBasicTask"].start()
#  ------------------------------------------------------------------------------


    sys.exit(app.exec())
