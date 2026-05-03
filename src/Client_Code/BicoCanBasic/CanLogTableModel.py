"""
Table model for CAN log entries.

Classes
-------
CanLogTableModel
    QAbstractTableModel providing CAN log data to QML TableView.
"""

from PySide6.QtCore import QAbstractTableModel, QModelIndex, Qt, Slot, Property, Signal
from datetime import datetime
import can


_COLUMNS = ["Time", "Port", "Dir", "FD", "Ext", "ID", "DLC", "Data"]


class CanLogTableModel(QAbstractTableModel):
    """
    Table model that stores CAN log entries and exposes them to QML TableView.

    Each row represents one CAN frame (sent or received).
    """

    countChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._rows: list[list[str]] = []

    # ── QAbstractTableModel interface ──────────────────────────────────

    def rowCount(self, parent=QModelIndex()):
        return len(self._rows)

    def columnCount(self, parent=QModelIndex()):
        return len(_COLUMNS)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        if role == Qt.DisplayRole:
            return self._rows[index.row()][index.column()]
        return None

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if role == Qt.DisplayRole and orientation == Qt.Horizontal:
            return _COLUMNS[section]
        return None

    def roleNames(self):
        return {Qt.DisplayRole: b"display"}

    @Property(int, notify=countChanged)
    def count(self):
        return len(self._rows)

    # ── Public API ────────────────────────────────────────────────────

    def addEntry(self, msg: can.Message, port_name: str, direction: str = "RX"):
        """Build a row from a can.Message and append it to the model."""
        time_str = datetime.now().time().isoformat(timespec="milliseconds")
        can_id_hex = format(msg.arbitration_id, "X")
        data_hex = " ".join(f"{b:02X}" for b in msg.data[:msg.dlc])

        row_idx = len(self._rows)
        self.beginInsertRows(QModelIndex(), row_idx, row_idx)
        self._rows.append([
            time_str,
            port_name,
            direction,
            "FD" if msg.is_fd else "",
            "X" if msg.is_extended_id else "",
            can_id_hex,
            str(msg.dlc),
            data_hex,
        ])
        self.endInsertRows()
        self.countChanged.emit()

    @Slot()
    def clear(self):
        """Remove all rows."""
        if self._rows:
            self.beginResetModel()
            self._rows.clear()
            self.endResetModel()
            self.countChanged.emit()
