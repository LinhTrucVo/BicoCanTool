"""
Sample implementation of a QUIThread for demonstration.

Classes
-------
BicoCanBasic
    Example subclass of Bico_QUIThread for handling messages and UI events.
"""

from lib import Bico_QMessData
from lib import Bico_QUIThread
from lib import Bico_QMutexQueue
from .Data_Object.BicoCanBasic_Data import BicoCanBasic_Data
from .CanLogTableModel import CanLogTableModel

import json
import os
import subprocess
import can
from can.interfaces.vector import get_channel_configs
from datetime import datetime
import serial.tools.list_ports


# Load message interface keys from BackendMessageInterface.json
_msg_keys_path = os.path.join(os.path.dirname(__file__), "BackendMessageInterface.json")
with open(_msg_keys_path) as _f:
    _MSG = json.load(_f)  # _MSG["input"] and _MSG["output"] contain message key constants

class BicoCanBasic(Bico_QUIThread):
    bus = {}  # Dict: port_name -> can.Bus instance (None if disconnected)
    _periodic_tasks = {}  # Dict: row_id -> {can_port, tx_msg, interval_ms, last_sent}
    init_done = False
    current_ports = None
    current_com_ports = None
    current_vector_can_channels = None
    _can_log_model = CanLogTableModel()
    
    def nofityUIComPortsUpdate(self):
    
        def getComPorts():
            self.current_com_ports = [port.device for port in serial.tools.list_ports.comports()]
            return self.current_com_ports
        
        def getVectorCanChannels():
            # Get list of available Vector CAN channels by name
            channel_configs = get_channel_configs()
            self.current_vector_can_channels = [config.name for config in channel_configs]
            return self.current_vector_can_channels
        
        new_ports = getComPorts() + getVectorCanChannels()
        if new_ports != self.current_ports:
            self.current_ports = new_ports
            self.toUI.emit(_MSG["output"]["COM_PORT_LIST"], self.current_ports)
            
    def getContextProperties(self):
        return {"canLogModel": self._can_log_model}

    def logCanMessage(self, can_msg: can.Message, port_name: str, direction: str = "RX"):
        """Add one CAN frame as a new row in the table model."""
        self._can_log_model.addEntry(can_msg, port_name, direction)

    def get_channel_by_name(self, channel_name):
        """Get channel index by name from Vector channel configs"""
        configs = get_channel_configs()
        for config in configs:
            if config.name == channel_name:
                return config.channel_index
        raise ValueError(f"Channel '{channel_name}' not found")

    
    def MainTask(self):
        if (self.init_done == False):
            self.nofityUIComPortsUpdate()
            self.init_done = True
            
        continue_to_run = 1
        input, result = self.qinDequeue()

        if result:
            mess = input.mess()
            data = input.data()
            if (mess == _MSG["input"]["TERMINATE"]):
                continue_to_run = 0
                
            elif (mess == _MSG["input"]["CONNECT"]):
                try:
                    # Escape backslashes in Windows file paths before JSON parsing
                    data_escaped = data.replace("\\", "\\\\")
                    json_data = json.loads(data_escaped)
                    can_port = json_data["can_port"]
                    can_baudrate = int(json_data["can_baudrate"])
                    can_fd = json_data.get("can_fd", False)

                    if self.current_com_ports and can_port in self.current_com_ports:
                        print(f"Connecting to serial CAN adapter on port {can_port} with baudrate {can_baudrate}, FD={can_fd}...")
                        self.bus[can_port] = can.Bus(interface="serial", channel=can_port, baudrate=921600, fd=can_fd, app_name=None)
                    elif self.current_vector_can_channels and can_port in self.current_vector_can_channels:
                        print(f"Connecting to Vector CAN channel {can_port} with baudrate {can_baudrate}, FD={can_fd}...")
                        self.bus[can_port] = can.Bus(
                                    interface='vector', 
                                    channel=self.get_channel_by_name(can_port),
                                    receive_own_messages=False,
                                    fd=can_fd,
                                    bitrate=can_baudrate,
                                    data_bitrate=2_000_000,
                                    # Arbitration-rate bit timing
                                    sjw_abr=16,
                                    tseg1_abr=63,
                                    tseg2_abr=16,
                                    sam_abr=1,
                                    # Data-rate bit timing
                                    sjw_dbr=8,
                                    tseg1_dbr=31,
                                    tseg2_dbr=8,
                                    app_name=None
                                )
                    self.toUI.emit(_MSG["output"]["CONNECTION_STATUS"], json.dumps({"can_port": can_port, "connected": True}))
                except:
                    print("Error, but I don't know what it is >_<")
                finally:
                    pass
                
            elif (mess == _MSG["input"]["DISCONNECT"]):
                try:
                    # Escape backslashes in Windows file paths before JSON parsing
                    data_escaped = data.replace("\\", "\\\\")
                    json_data = json.loads(data_escaped)
                    can_port = json_data["can_port"]
                    can_baudrate = int(json_data["can_baudrate"])
                    # print(self.objectName() + " " + mess + ": ")
                    # print(f'can_port: {can_port}')
                    # print(f'can_baudrate: {can_baudrate}')
                    if can_port in self.bus and self.bus[can_port] is not None:
                        self.bus[can_port].shutdown()
                        print(f'BUS: {self.bus[can_port]}')
                        self.bus[can_port] = None
                    self.toUI.emit(_MSG["output"]["CONNECTION_STATUS"], json.dumps({"can_port": can_port, "connected": False}))
                except:
                    print("Error, but I don't know what it is >_<")
                finally:
                    pass
                    
            elif (mess == _MSG["input"]["SEND"]):
                try:
                    # Escape backslashes in Windows file paths before JSON parsing
                    data_escaped = data.replace("\\", "\\\\")
                    json_data = json.loads(data_escaped)
                    can_port = json_data["can_port"]
                    can_data_str = str(json_data["can_data"])

                    if os.path.isfile(can_data_str):
                        # Resolve path with tilde expansion and normalize
                        resolved_path = os.path.expanduser(can_data_str)
                        resolved_path = os.path.normpath(resolved_path)
                        print(f"Executing script file: {resolved_path}")
                        subprocess.Popen(resolved_path, shell=True)
                        print(f"Script launched: {resolved_path}")
                        
                    else:
                        hex_string = can_data_str.replace(" ", "")
                        hex_stream = list(bytes.fromhex(hex_string))

                        can_id = int(json_data["can_id"].rstrip("x"), 16)
                        is_extended = json_data["can_id"].endswith("x")
                        is_fd = (can.CanProtocol.CAN_FD == self.bus[can_port].__dict__.get('_can_protocol', ''))

                        tx_msg = can.Message(
                                    arbitration_id=can_id,
                                    is_extended_id=is_extended,
                                    is_fd = is_fd,
                                    data=hex_stream,
                                )

                        if can_port in self.bus and self.bus[can_port] is not None:
                            self.bus[can_port].send(tx_msg, timeout=0.01)
                            self.logCanMessage(tx_msg, can_port, "TX")

                        interval_ms = json_data.get("interval_ms", 0)
                        row_id = json_data.get("row_id", "")
                        if interval_ms > 0 and row_id:
                            self._periodic_tasks[row_id] = {
                                "can_port": can_port,
                                "tx_msg": tx_msg,
                                "interval_ms": interval_ms,
                                "last_sent": datetime.now(),
                            }
                except:
                    print("Error, but I don't know what it is >_<")
                finally:
                    pass
                
            elif (mess == _MSG["input"]["STOP_SEND"]):
                try:
                    # Escape backslashes in Windows file paths before JSON parsing
                    data_escaped = data.replace("\\", "\\\\")
                    json_data = json.loads(data_escaped)
                    row_id = json_data.get("row_id", "")
                    self._periodic_tasks.pop(row_id, None)
                except:
                    print("Error, but I don't know what it is >_<")
                finally:
                    pass

            elif (mess == _MSG["input"]["COM_PORT_LIST_UPDATE"]):
                self.nofityUIComPortsUpdate()
                
            elif (mess == _MSG["input"]["QUERY_CONNECTION_STATUS"]):
                can_port = data
                connected = can_port in self.bus and self.bus[can_port] is not None
                self.toUI.emit(_MSG["output"]["CONNECTION_STATUS"], json.dumps({"can_port": can_port, "connected": connected}))

        # Check for incoming CAN messages on all connected buses
        # Note: In a production application, consider using asynchronous I/O or separate threads for each bus to avoid blocking
        try: 
            for port_name, port_bus in self.bus.items():
                if port_bus is not None:
                    rx_msg = port_bus.recv(0.1)
                    if rx_msg is not None and not rx_msg.is_error_frame:
                        self.logCanMessage(rx_msg, port_name, "RX")
        except:
            print("Error, but I don't know what it is >_<")
        finally:
            pass
        

        # Tick periodic send tasks
        now = datetime.now()
        for row_id, task in list(self._periodic_tasks.items()):
            if (now - task["last_sent"]).total_seconds() * 1000 >= task["interval_ms"]:
                can_port = task["can_port"]
                tx_msg = task["tx_msg"]
                try:
                    if can_port in self.bus and self.bus[can_port] is not None:
                        self.bus[can_port].send(tx_msg, timeout=0.01)
                        self.logCanMessage(tx_msg, can_port, "TX")
                        task["last_sent"] = now
                except:
                    pass

        # self.msleep(1)

        return continue_to_run

