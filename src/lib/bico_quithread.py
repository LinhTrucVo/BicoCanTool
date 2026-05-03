"""
Thread class integrating QThread and QML UI.

Classes
-------
Bico_QUIThread
    Thread class for running tasks with QML UI integration.
"""

from PySide6.QtCore import QObject, QThread, QMutex, Signal, Slot, QMetaObject, Qt, Q_ARG, QDirIterator
from PySide6.QtQml import QQmlApplicationEngine

from .PyQtLib_Project_Template import Bico_QThread
from .PyQtLib_Project_Template import Bico_QMessData

class ThreadFactory(QObject):
    """Helper class that lives in the main thread to create new threads safely."""
    
    def __init__(self):
        super().__init__()
        self.created_thread = None
        self.pending_params = None
    
    @Slot()
    def createThread(self):
        if self.pending_params is None:
            return
        
        # Create new thread directly (we're already in main thread)
        self.created_thread = self.pending_params['creator'](
            self.pending_params['qin'],
            self.pending_params['qin_owner'],
            self.pending_params['qout'],
            self.pending_params['qout_owner'],
            self.pending_params['obj_name'],
            self.pending_params['ui_path'],
            self.pending_params['parent']
        )
        
        # Clear pending params
        self.pending_params = None

class EngineFactory(QObject):
    """Helper class that lives in the main thread to load QML engines safely."""
    
    def __init__(self):
        super().__init__()
        self.pending_params = None
    
    @Slot()
    def loadEngine(self):
        if self.pending_params is None:
            return
        
        thread = self.pending_params['thread']
        if thread is None:
            self.pending_params = None
            return
        
        # Create the QML engine
        thread._engine = QQmlApplicationEngine()
        
        # Use cached import paths instead of iterating QRC every time
        for path in Bico_QUIThread.qml_import_paths:
            thread._engine.addImportPath(path)
        
        # Let subclass expose context properties before QML is loaded
        for name, obj in thread.getContextProperties().items():
            thread._engine.rootContext().setContextProperty(name, obj)
        
        # Load the QML file (but window visibility is controlled by QML visible property)
        thread._engine.load(self.pending_params['ui_path'])

        if thread._engine.rootObjects():
            root = thread._engine.rootObjects()[0]
            # Connect signals between thread and UI
            root.toThread.connect(thread.fromUI, Qt.QueuedConnection)
            thread.toUI.connect(root.fromThread, Qt.QueuedConnection)
        
        # Start the thread with the specified priority
        QThread.start(thread, self.pending_params['priority'])
        
        # Clear pending params
        self.pending_params = None

class Bico_QUIThread(QThread, Bico_QThread):
    """
    Thread class with QML UI integration and message queue support.

    Attributes
    ----------
    thread_hash : dict
        Stores all running threads.
    main_app : QGuiApplication
        Reference to the main application.
    toUI : Signal
        Signal to send data to UI.
    """
    thread_hash = {}
    thread_hash_mutex = QMutex()
    main_app = None
    thread_factory = None
    engine_factory = None
    qml_import_paths = []  # Cached QML import paths from QRC
    toUI = Signal(str, "QVariant")

    def __init__(self, qin=None, qin_owner=0, qout=None, qout_owner=0, obj_name="", ui_path="", parent=None):
        """
        Initialize the thread.

        Parameters
        ----------
        qin : Bico_QMutexQueue
            Input queue.
        qin_owner : int
            Ownership flag for input queue.
        qout : Bico_QMutexQueue
            Output queue.
        qout_owner : int
            Ownership flag for output queue.
        obj_name : str
            Name of the thread object.
        ui_path : str
            Path to the QML UI file.
        parent : QObject
            Parent object.
        """
        QThread.__init__(self, parent)
        Bico_QThread.__init__(self, qin, qin_owner, qout, qout_owner)
        
        self.setObjectName(obj_name)
        __class__.thread_hash_mutex.lock()
        __class__.thread_hash[obj_name] = self
        __class__.thread_hash_mutex.unlock()
        
        # Connect finished signal to selfRemove slot for automatic cleanup
        self.finished.connect(lambda: __class__.selfRemove(obj_name))
        
        self._ui_path = ui_path
        self._engine = None
        
    def __del__(self):
        """
        Destructor is now minimal - cleanup is handled by selfRemove slot.
        """
        pass

    def start(self, priority=QThread.InheritPriority):
        """
        Start the thread and load the QML UI if specified.

        Parameters
        ----------
        priority : QThread.Priority
            Thread priority.
        """
        if (self._ui_path != None) and (self._ui_path != ""):
            # Can not create QQmlApplicationEngine directly if this "start" func
            # is called by worker Thread (not main thread), because
            # QQmlApplicationEngine must be created in main thread.
            # That's why using EngineFactory to handle engine creation in main thread.

            # Check if we're in the main thread
            main_thread = __class__.main_app.thread()
            current_thread = QThread.currentThread()
            
            if current_thread == main_thread:
                # We're in the main thread, create engine directly
                self._engine = QQmlApplicationEngine()
                
                # Use cached import paths instead of iterating QRC every time
                for path in __class__.qml_import_paths:
                    self._engine.addImportPath(path)
                
                # Let subclass expose context properties before QML is loaded
                for name, obj in self.getContextProperties().items():
                    self._engine.rootContext().setContextProperty(name, obj)
                
                # Load the QML file (but window visibility is controlled by QML visible property)
                self._engine.load(self._ui_path)

                if self._engine.rootObjects():
                    root = self._engine.rootObjects()[0]
                    # Connect signals between thread and UI
                    root.toThread.connect(self.fromUI, Qt.QueuedConnection)
                    self.toUI.connect(root.fromThread, Qt.QueuedConnection)
                
                # Start the thread with the specified priority
                QThread.start(self, priority)
            else:
                # We're in a worker thread, must use factory to create engine in main thread
                __class__.engine_factory.pending_params = {
                    'thread': self,
                    'ui_path': self._ui_path,
                    'priority': priority
                }
                # Use DirectConnection if already in main thread, else QueuedConnection
                connection_type = Qt.DirectConnection if current_thread == main_thread else Qt.QueuedConnection
                QMetaObject.invokeMethod(
                    __class__.engine_factory,
                    "loadEngine",
                    connection_type
                )
        else:
            QThread.start(self, priority)

    def getContextProperties(self):
        """
        Return a dict of {name: QObject} to expose as QML context properties.

        Override in subclasses to register models or other objects on the
        QML engine root context before the QML file is loaded.

        Returns
        -------
        dict
        """
        return {}

    def MainTask(self):
        """
        Virtual method to be implemented in subclasses.

        Returns
        -------
        int
            0 to stop the thread, 1 to continue.
        """
        return 0

    def run(self):
        """
        Main thread loop.
        """
        while True:
            if(not self.MainTask()):
                break
        
        # No deleteLater() here - cleanup is handled by selfRemove() 
        # which is called when the 'finished' signal is emitted

    def create(custom_class=None, qin=None, qin_owner=0, qout=None, qout_owner=0, obj_name="", ui_path="", parent=None):
        """
        Factory method to create a new thread instance if not already existing.
        
        Uses the ThreadFactory pattern to ensure thread-safe creation, especially
        when creating threads from worker threads that need to be parented to the main thread.

        Parameters
        ----------
        custom_class : type
            The class type to instantiate (must inherit from Bico_QUIThread).
        qin : Bico_QMutexQueue, optional
            Input queue for the thread.
        qin_owner : int, optional
            Ownership flag for input queue (1 if this thread owns it).
        qout : Bico_QMutexQueue, optional
            Output queue for the thread.
        qout_owner : int, optional
            Ownership flag for output queue (1 if this thread owns it).
        obj_name : str
            Unique name/identifier for the thread object.
        ui_path : str, optional
            Path to the QML UI file (e.g., "qrc:/path/to/file.qml").
        parent : QObject, optional
            Parent QObject for establishing parent-child relationship.

        Returns
        -------
        Bico_QUIThread or None
            Instance of custom_class if created successfully, None if thread name already exists.
        """
        # Thread-safe check for existing thread
        __class__.thread_hash_mutex.lock()
        exists = obj_name in __class__.thread_hash
        __class__.thread_hash_mutex.unlock()
        
        if exists:
            print(f"Warning: Thread '{obj_name}' already exists. Returning None.")
            return None
        
        # Check if we're in the main thread
        main_thread = __class__.main_app.thread() if __class__.main_app else None
        current_thread = QThread.currentThread()
        
        if main_thread and current_thread != main_thread:
            # We're in a worker thread - use factory to create in main thread
            # This ensures proper parent-child relationships and signal connections
            __class__.thread_factory.pending_params = {
                'creator': custom_class,
                'qin': qin,
                'qin_owner': qin_owner,
                'qout': qout,
                'qout_owner': qout_owner,
                'obj_name': obj_name,
                'ui_path': ui_path,
                'parent': parent
            }
            
            # Invoke factory method in main thread
            QMetaObject.invokeMethod(
                __class__.thread_factory,
                "createThread",
                Qt.BlockingQueuedConnection  # Wait for creation to complete
            )
            
            # Return the created thread
            created_thread = __class__.thread_factory.created_thread
            __class__.thread_factory.created_thread = None  # Clear for next use
            return created_thread
        else:
            # We're in the main thread or no main_app set - create directly
            return custom_class(qin, qin_owner, qout, qout_owner, obj_name, ui_path, parent)

    def getThreadHash():
        """
        Get the dictionary of running threads.

        Returns
        -------
        dict
        """
        return __class__.thread_hash

    def getMainApp():
        """
        Get the main application instance.

        Returns
        -------
        QGuiApplication
        """
        return __class__.main_app

    def setMainApp(app):
        """
        Set the main application instance.

        Parameters
        ----------
        app : QGuiApplication
        """
        __class__.main_app = app

    def initializeFactories():
        """
        Initialize global factory instances (they live in main thread).
        This MUST be called from the main thread before any worker threads are created.
        """
        # Initialize global factory instances
        if __class__.thread_factory is None:
            __class__.thread_factory = ThreadFactory()
        if __class__.engine_factory is None:
            __class__.engine_factory = EngineFactory()
        
        # Cache QML import paths from QRC (only scan once at startup)
        # without this cache, every thread creation would scan QRC which is inefficient
        # and we can see the delay on every time a thread's qml engine is created
        if not __class__.qml_import_paths:
            qrc = QDirIterator(":", QDirIterator.Subdirectories)
            while qrc.hasNext():
                __class__.qml_import_paths.append(qrc.next())

    def getThreadFactory():
        """
        Get the thread factory instance.

        Returns
        -------
        ThreadFactory
        """
        return __class__.thread_factory

    def getEngineFactory():
        """
        Get the engine factory instance.

        Returns
        -------
        EngineFactory
        """
        return __class__.engine_factory

    @Slot(str)
    def selfRemove(objectName):
        """
        Remove a thread from the thread hash and clean up resources.

        Parameters
        ----------
        objectName : str
        """
        thread = __class__.thread_hash.get(objectName)
        if thread is None:
            return
        
        # Clean up engine connection
        if thread._ui_path != "" and thread._engine is not None:
            root_object = None
            if thread._engine.rootObjects():
                root_object = thread._engine.rootObjects()[0]
            
            if root_object:
                thread.toUI.disconnect(root_object.fromThread)
                root_object.toThread.disconnect(thread.fromUI)

            # SAFE: Schedule deletion in the main thread (where _engine was created)
            # The engine will be deleted by Qt's event loop in the main thread
            # All root QML objects will be automatically deleted as children of the engine
            thread._engine.deleteLater()
            thread._engine = None  # Clear our pointer after scheduling deletion
        
        # Remove from hash and schedule for deletion
        __class__.thread_hash_mutex.lock()
        __class__.thread_hash.pop(objectName, None)
        __class__.thread_hash_mutex.unlock()
        
        thread.deleteLater()
        
        # Exit app if no more threads
        if len(__class__.thread_hash) < 1:
            if __class__.main_app is not None:
                __class__.main_app.exit(0)

    @Slot(str, "QVariant")
    def fromUI(self, mess, data):
        """
        Receive data from the UI.

        Parameters
        ----------
        mess : str
        data : object
        """
        mess_data = Bico_QMessData()
        mess_data.setMess(mess)
        mess_data.setData(data)
        self.qinEnqueue(mess_data)
