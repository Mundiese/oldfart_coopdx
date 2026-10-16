from PySide6.QtCore import QSize
from PySide6.QtGui import QIcon, QImage, QPixmap
from PySide6.QtWidgets import QComboBox
from mapgen import skies
ICON = QSize(48, 30)
def real_skies(rom=None):
    try:
        from studio.library import romskies
        return romskies.previews(rom)
    except Exception:
        return {}
def picture(name, theme=None, real=None):
    from PIL import ImageDraw
    w, h = ICON.width(), ICON.height()
    auto = name in (None, skies.AUTO)
    key = skies.for_theme(theme or "castle") if auto else name
    got = (real or {}).get(key)
    if got is None:
        return skies.thumbnail(name, w, h, theme=theme)
    img = got.convert("RGB").resize((w, h))
    if auto:
        ImageDraw.Draw(img).polygon(((w - 12, 0), (w, 0), (w, 12)), fill=(255, 255, 255))
    return img
def icon(name, theme=None, real=None):
    img = picture(name, theme, real)
    data = img.tobytes("raw", "RGB")
    q = QImage(data, img.width, img.height, img.width * 3, QImage.Format_RGB888).copy()
    return QIcon(QPixmap.fromImage(q))
def rom_choice(settings):
    try:
        return (settings.state or {}).get("music_rom")
    except AttributeError:
        return None
def choices():
    return [(skies.AUTO, skies.AUTO_LABEL)] + list(skies.SKIES)
class SkyPicker(QComboBox):
    def __init__(self, theme=None, parent=None, rom=None):
        super().__init__(parent)
        self.setIconSize(ICON)
        self.real = real_skies(rom)
        self.setToolTip("The map's sky: any of the game's backgrounds, or the theme's own. "
                        "The lobby's Sky row and a round's sky still win over it in game."
                        + ("" if self.real else " (The pictures are drawn: with your SM64 "
                           "ROM chosen in the Music tab, they show the real skies.)"))
        for value, label in choices():
            self.addItem(icon(value, theme, self.real), label, value)
    def set_value(self, name):
        i = self.findData(name or skies.AUTO)
        self.setCurrentIndex(max(0, i))
    def value(self):
        return self.currentData()
