"""
Example data object for demonstration purposes.

Classes
-------
BicoCanTp_Data
    Simple class with two data fields and getter/setter methods.
"""

class BicoCanTp_Data:
    """
    Simple class with two data fields and getter/setter methods.
    """
    def __init__(self):
        self.data_1 = 50
        self.data_2 = 100

    def getData_1(self):
        """
        Get data_1.

        Returns
        -------
        int
        """
        return self.data_1

    def setData_1(self, data):
        """
        Set data_1.

        Parameters
        ----------
        data : int
        """
        self.data_1 = data

    def getData_2(self):
        """
        Get data_2.

        Returns
        -------
        int
        """
        return self.data_2

    def setData_2(self, data):
        """
        Set data_2.

        Parameters
        ----------
        data : int
        """
        self.data_2 = data