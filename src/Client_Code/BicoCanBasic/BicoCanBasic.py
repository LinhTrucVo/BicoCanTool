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

import json
import os
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
    _log_queue = []        # Pending CAN log lines
    _last_log_time = None  # datetime of last log added
    _queue_start_time = None  # datetime when first item entered current batch
    init_done = False
    current_ports = None
    current_com_ports = None
    current_vector_can_channels = None
    
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
            
    def generateCanLog(self, can_msg:can.Message, port_name:str, direction:str="RX"):
        dlc = can_msg.dlc
        hex_string = ""
        can_id_as_hex_str = hex(can_msg.arbitration_id)[2:].upper()
        if (can_msg.is_extended_id):
            can_id_as_hex_str = can_id_as_hex_str + "x"
        for i in range(0, dlc):
            if (i != 0) and ((i % 8) == 0):
                hex_string = hex_string + '\n'
                hex_string = hex_string + ''.ljust(61, " ")
                hex_string = hex_string + f'[{i}]'.ljust(8, " ")
                hex_string = hex_string + f"{can_msg.data[i]:02X}"
            else:
                hex_string = hex_string + '   ' + f"{can_msg.data[i]:02X}"
                pass
        can_log = f'{datetime.now().time()}\t{port_name.ljust(17, " ")}\t{direction}\t{can_id_as_hex_str.ljust(9, " ")}    {str(can_msg.dlc).ljust(4, " ")}{hex_string.upper()}'
        print(can_log)
        return can_log
    
    def updateCanLog(self, can_log):
        if not self._log_queue:
            self._queue_start_time = datetime.now()
        self._log_queue.append(can_log)
        self._last_log_time = datetime.now()
        if len(self._log_queue) >= 100:
            self.flushCanLog()

    def flushCanLog(self):
        if self._log_queue:
            self.toUI.emit(_MSG["output"]["CAN_LOG"], "\n".join(self._log_queue))
            self._log_queue.clear()
            self._last_log_time = None
            self._queue_start_time = None

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
                    json_data = json.loads(data)
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
                    json_data = json.loads(data)
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
                    json_data = json.loads(data)
                    can_port = json_data["can_port"]
                    hex_string = str(json_data["can_data"]).replace(" ", "")
                    hex_stream = list(bytes.fromhex(hex_string))
                    
                    is_extended = json_data["can_id"].endswith("x")
                    can_id = int(json_data["can_id"].rstrip("x"), 16)
                    
                    tx_msg = can.Message(
                                arbitration_id=can_id,
                                is_extended_id=is_extended,
                                is_fd= (can.CanProtocol.CAN_FD == self.bus[can_port].__dict__.get('_can_protocol', '')),
                                data=hex_stream,
                            )
                    
                    if can_port in self.bus and self.bus[can_port] is not None:
                        self.bus[can_port].send(tx_msg, timeout=0.01)
                        can_log = self.generateCanLog(tx_msg, can_port, "TX")
                        self.updateCanLog(can_log)
                    
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
                    json_data = json.loads(data)
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

        # Tick periodic send tasks
        now = datetime.now()
        for row_id, task in list(self._periodic_tasks.items()):
            if (now - task["last_sent"]).total_seconds() * 1000 >= task["interval_ms"]:
                can_port = task["can_port"]
                tx_msg = task["tx_msg"]
                try:
                    if can_port in self.bus and self.bus[can_port] is not None:
                        self.bus[can_port].send(tx_msg, timeout=0.01)
                        can_log = self.generateCanLog(tx_msg, can_port, "TX")
                        self.updateCanLog(can_log)
                        task["last_sent"] = now
                except:
                    pass

        # Check for incoming CAN messages on all connected buses
        # Note: In a production application, consider using asynchronous I/O or separate threads for each bus to avoid blocking
        try: 
            for port_name, port_bus in self.bus.items():
                if port_bus is not None:
                    rx_msg = port_bus.recv(0)
                    if rx_msg is not None and not rx_msg.is_error_frame:
                        can_log = self.generateCanLog(rx_msg, port_name, "RX")
                        self.updateCanLog(can_log)
        except:
            print("Error, but I don't know what it is >_<")
        finally:
            pass

        # Flush log queue if 100ms has passed since last log (idle) or since first item (max latency)
        if self._log_queue:
            now = datetime.now()
            idle = self._last_log_time is not None and (now - self._last_log_time).total_seconds() * 1000 >= 100
            overdue = self._queue_start_time is not None and (now - self._queue_start_time).total_seconds() * 1000 >= 100
            if idle or overdue:
                self.flushCanLog()

        # self.msleep(1)

        return continue_to_run

