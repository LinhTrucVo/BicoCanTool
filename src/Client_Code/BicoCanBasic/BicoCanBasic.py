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
import can
from datetime import datetime
import serial.tools.list_ports

class BicoCanBasic(Bico_QUIThread):
    i = 0
    
    bus = None
    init_done = False
    current_ports = None
    
    serial_connected = False
    
    def getComPorts(self):
        return [port.device for port in serial.tools.list_ports.comports()]
    
    def nofityUIComPortsUpdate(self):
        new_ports = self.getComPorts()
        if new_ports != self.current_ports:
            self.current_ports = new_ports
            self.toUI.emit("com_port_list", self.current_ports)
            
    def generateCanLog(self, can_msg:can.Message):
        hex_string = '   '.join(f'{byte:02X}' for byte in can_msg.data)
        can_id_as_hex_str = hex(can_msg.arbitration_id)[2:].upper()
        if (can_msg.is_extended_id):
            can_id_as_hex_str = can_id_as_hex_str + "x"
        # can_log = f'{datetime.now()}\t{hex(can_msg.arbitration_id).ljust(10, " ").upper()[2:]}    {can_msg.dlc}\t{hex_string.upper()}'
        can_log = f'{datetime.now()}\t{can_id_as_hex_str.ljust(9, " ")}    {can_msg.dlc}\t{hex_string.upper()}'
        return can_log
    
    
    def MainTask(self):
        if (self.init_done == False):
            self.nofityUIComPortsUpdate()
            self.init_done = True
            
        continue_to_run = 1
        
        i = 0
        input, result = self.qinDequeue()

        if result:
            mess = input.mess()
            data = input.data()
            if (mess == "terminate"):            
                continue_to_run = 0
                
            elif (mess == "Connect"):
                try:
                    json_data = json.loads(data)
                    print(self.objectName() + " " + mess + ": ")
                    # print(data)
                    print(f'serial_port: {json_data["serial_port"]}')
                    print(f'can_baudrate: {json_data["can_baudrate"]}')
                    # self.bus = can.Bus(interface="serial", channel=json_data["serial_port"], baudrate=921600)
                    self.bus = can.Bus(
                                interface='vector', 
                                channel=2,
                                receive_own_messages=False,
                                fd=True,
                                bitrate=500_000,
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
                                app_name='truc_app',
                            )
                    self.serial_connected = True
                except:
                    print("Error, but I don't know what it is >_<")
                finally:
                    pass
                
            elif (mess == "Disconnect"):
                try:
                    json_data = json.loads(data)
                    print(self.objectName() + " " + mess + ": ")
                    # print(data)
                    print(f'serial_port: {json_data["serial_port"]}')
                    print(f'can_baudrate: {json_data["can_baudrate"]}')
                    if (self.bus != None):
                        self.bus.shutdown()
                        print(f'BUS: {self.bus}')
                        self.bus = None
                    self.serial_connected = False
                except:
                    print("Error, but I don't know what it is >_<")
                finally:
                    pass
                    
            elif (mess == "Send"):
                try:
                    json_data = json.loads(data)
                    # print(self.objectName() + " " + mess + ": ")
                    # print(data)
                    # print(f'can_id: {json_data["can_id"]}')
                    # print(f'can_data: {json_data["can_data"]}')
                    hex_string = str(json_data["can_data"]).replace(" ", "")
                    hex_list = []
                    for i in range(0, len(hex_string), 2):
                        hex_value = int(hex_string[i:i+2], 16)  # Convert each pair to hex
                        hex_list.append(hex_value)
                    
                    is_extended = False
                    can_id = 0
                    if (json_data["can_id"][-1] == "x"):
                        is_extended = True
                        can_id = int(json_data["can_id"][:-1], 16)
                    else:
                        is_extended = False
                        can_id = int(json_data["can_id"], 16)
                        
                    tx_msg = can.Message(
                                arbitration_id=can_id,
                                is_extended_id=is_extended,
                                data=hex_list,
                            )
                    if self.bus != None:
                        self.bus.send(tx_msg, timeout=0.01)
                        can_log = self.generateCanLog(tx_msg)
                        self.toUI.emit("can_log", can_log)
                except:
                    print("Error, but I don't know what it is >_<")
                finally:
                    pass
                
                
            elif (mess == "com_port_list_update"):
                self.nofityUIComPortsUpdate()
                
                
            elif (mess == "text"):
                print(self.objectName() + " " + mess + " " + data)
                self.toUI.emit(mess, data)
                
            elif (mess == "size"):
                print(self.objectName() + " " + mess + " " + str(data.width()) + str(data.height()))
                self.toUI.emit(mess, data)
                
            elif (mess == "from_another_thread"):
                print(self.objectName() + " " + mess + ": "  + input.src() + " - " + str(data))

        # print("Hello from " + self.objectName())
        # print("Num of running thread: " + str(len(Bico_QUIThread.getThreadHash())))
        # self.msleep(10)

        try: 
            if (self.bus != None):
                rx_msg = self.bus.recv(0.001)
                if rx_msg is not None:
                    # if (rx_msg.arbitration_id == 0x18DA10F1) or (rx_msg.arbitration_id == 0x18DAF110):
                    if (True):
                        can_log = self.generateCanLog(rx_msg)
                        self.toUI.emit("can_log", can_log)
        except:
            print("Error, but I don't know what it is >_<")
        finally:
            pass
        
        # if (self.bus != None):
        #     tx_msg = can.Message(
        #                 arbitration_id=int("123", 16),
        #                 data=[1, 2, 3, 4, 5, 6, 7, 8],
        #             )
        #     self.bus.send(tx_msg)
            
        # print(f'{self.objectName()} - {datetime.now()}')
            
        
        self.msleep(1)
    
        return continue_to_run

