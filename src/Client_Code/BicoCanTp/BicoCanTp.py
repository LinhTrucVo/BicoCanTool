"""
Sample implementation of a QUIThread for demonstration.

Classes
-------
BicoCanTp
    Example subclass of Bico_QUIThread for handling messages and UI events.
"""

from lib import Bico_QMessData
from lib import Bico_QUIThread
from lib import Bico_QMutexQueue
from .Data_Object.BicoCanTp_Data import BicoCanTp_Data

class BicoCanTp(Bico_QUIThread):
    """
    Example subclass of Bico_QUIThread for handling messages and UI events.
    """
    i = 0
    count = 0  # Static count for thread naming
    ex_data_obj = BicoCanTp_Data()

    def __init__(self, qin=None, qin_owner=0, qout=None, qout_owner=0, obj_name="", ui_path="", parent=None):
        """
        Initialize BicoCanTp thread with message handlers.
        
        Parameters
        ----------
        qin : Bico_QMutexQueue, optional
            Input queue for the thread.
        qin_owner : int, optional
            Ownership flag for input queue.
        qout : Bico_QMutexQueue, optional
            Output queue for the thread.
        qout_owner : int, optional
            Ownership flag for output queue.
        obj_name : str
            Name/identifier for the thread object.
        ui_path : str, optional
            Path to the QML UI file.
        parent : QObject, optional
            Parent QObject for parent-child relationship.
        """
        # Call parent class __init__
        super().__init__(qin, qin_owner, qout, qout_owner, obj_name, ui_path, parent)
        
        # Message handler dictionary - cleaner than if-else chains
        self.message_handlers = {
            "terminate": self._handle_terminate,
            "num1": self._handle_num1,
            "num2": self._handle_num2,
            "text": self._handle_text,
            "create": self._handle_create,
            "create_child": self._handle_create_child,
            "size": self._handle_size,
            "from_another_thread": self._handle_from_another_thread,
        }

    def cleanupChildren(self):
        """
        Cleanup child threads before this thread is destroyed.
        """
        # Get all children from this QObject's children() and terminate them
        child_list = self.children()
        for child in child_list:
            if isinstance(child, Bico_QUIThread):
                thread = child
                child_name = thread.objectName()
                mess_data = Bico_QMessData("terminate", "")
                thread.qinEnqueue(mess_data)
                print(f"Sent terminate message to child thread: {child_name}")
                
                # Wait for child thread to finish, otherwise, the app will be failed and terminated
                if thread.isRunning():
                    thread.wait(5000)  # Wait up to 5 seconds

    def MainTask(self):
        """
        Main task loop for the thread.

        Returns
        -------
        int
            1 to continue, 0 to terminate.
        """
        continue_to_run = 1
        
        input, result = self.qinDequeue()

        if result:
            mess = input.mess()
            data = input.data()
            
            # Use the message handler dictionary from __init__
            handler = self.message_handlers.get(mess)
            if handler:
                continue_to_run = handler(data, input)

        print("Hello from " + self.objectName())
        print("Num of running thread: " + str(len(Bico_QUIThread.getThreadHash())))
        self.msleep(100)

        if ((self.objectName() == "task_1") and (Bico_QUIThread.getThreadHash().get("task_0") != None)):
            self.i += 1
            mess_data = Bico_QMessData("from_another_thread", self.i)
            mess_data.setSrc(self.objectName())
            Bico_QUIThread.getThreadHash().get("task_0").qinEnqueue(mess_data)

        return continue_to_run

    def _handle_terminate(self, data, input_msg_queue):
        """Handle terminate message."""
        self.cleanupChildren()
        return 0  # Signal to stop running

    def _handle_num1(self, data, input_msg_queue):
        """Handle num1 message."""
        print(self.objectName() + " num1 " + str(self.ex_data_obj.getData_1()))
        return 1

    def _handle_num2(self, data, input_msg_queue):
        """Handle num2 message."""
        print(self.objectName() + " num2 " + str(self.ex_data_obj.getData_2()))
        return 1

    def _handle_text(self, data, input_msg_queue):
        """Handle text message."""
        print(self.objectName() + " text " + data)
        return 1

    def _handle_create(self, data, input_msg_queue):
        """Handle create message to create sibling thread."""
        print(self.objectName() + " create " + data)
        BicoCanTp.count += 1
        thread_name = "task_" + str(BicoCanTp.count)
        thread = Bico_QUIThread.create(
            BicoCanTp,
            Bico_QMutexQueue(),
            1, 
            Bico_QMutexQueue(), 
            1, 
            thread_name, 
            "qrc:/Client_Code/BicoCanTp/UI/BicoCanTpContent/App.qml"
        )
        if thread:
            thread.start()
        return 1

    def _handle_create_child(self, data, input_msg_queue):
        """Handle create_child message to create child thread."""
        print(self.objectName() + " create_child " + data)
        BicoCanTp.count += 1
        thread_name = "task_" + str(BicoCanTp.count)
        thread = Bico_QUIThread.create(
            BicoCanTp,
            Bico_QMutexQueue(),
            1, 
            Bico_QMutexQueue(), 
            1, 
            thread_name, 
            "qrc:/Client_Code/BicoCanTp/UI/BicoCanTpContent/App.qml",
            self  # set parent
        )
        if thread:
            thread.start()
        return 1

    def _handle_size(self, data, input_msg_queue):
        """Handle size message."""
        print(self.objectName() + " size " + str(data.width()) + str(data.height()))
        self.toUI.emit("size", data)
        return 1

    def _handle_from_another_thread(self, data, input_msg_queue):
        """Handle from_another_thread message."""
        print(self.objectName() + " from_another_thread: " + input_msg_queue.src() + " - " + str(data))
        return 1