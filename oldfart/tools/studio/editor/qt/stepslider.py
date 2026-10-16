from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import QHBoxLayout, QLabel, QSlider, QWidget
class StepSlider(QWidget):
    currentIndexChanged = Signal(int)
    def __init__(self, choices, parent=None):
        super().__init__(parent)
        self.stops = [(None, "auto")] + [(v, t) for v, t in choices if v != "auto"]
        lay = QHBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        self.slider = QSlider(Qt.Horizontal)
        self.slider.setRange(0, len(self.stops) - 1)
        self.slider.setPageStep(1)
        self.slider.setTickPosition(QSlider.TicksBelow)
        self.slider.setTickInterval(1)
        self.label = QLabel()
        self.label.setMinimumWidth(60)
        lay.addWidget(self.slider, 1)
        lay.addWidget(self.label)
        self.slider.valueChanged.connect(self._moved)
        self._moved(0)
    def _moved(self, i):
        self.label.setText(self.stops[i][1])
        self.currentIndexChanged.emit(i)
    def currentIndex(self):
        return self.slider.value()
    def setCurrentIndex(self, i):
        self.slider.setValue(max(0, min(len(self.stops) - 1, int(i))))
    def currentData(self):
        return self.stops[self.slider.value()][0]
    def currentText(self):
        return self.stops[self.slider.value()][1]
    def findData(self, value):
        for i, (v, _) in enumerate(self.stops):
            if v == value:
                return i
        return -1
    def count(self):
        return len(self.stops)
