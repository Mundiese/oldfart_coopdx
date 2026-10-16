BASE = {
    "viewport": "#1d1f23",
    "window": "#1a1c1f",
    "panel": "#25282d",
    "raised": "#2e3238",
    "hover": "#363b42",
    "border": "#3a3f46",
    "text": "#dedfe1",
    "text_dim": "#9a9da3",
    "text_off": "#62666c",
    "accent": "#5b8cff",
    "ok": "#5cc879",
    "warn": "#f5b041",
    "bad": "#ef5350",
    "info": "#61a0f5",
    "axis_x": "#ed5160",
    "axis_y": "#8cd145",
    "axis_z": "#4d8ff5",
}
def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
def rgb_hex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(c)))) for c in rgb)
def rgbf(h):
    return tuple(c / 255.0 for c in hex_rgb(h))
def mix(a, b, t):
    ra, rb = hex_rgb(a), hex_rgb(b)
    return rgb_hex(tuple(x + (y - x) * t for x, y in zip(ra, rb)))
def luminance(h):
    r, g, b = (c / 255.0 for c in hex_rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
MEANINGS = ("good", "warn", "bad", "neutral")
GLYPH = {"good": "✓", "warn": "!", "bad": "✕", "neutral": "•"}
VISION = {
    "safe": {"good": "#0072B2", "warn": "#E69F00", "bad": "#D55E00", "neutral": "#56B4E9"},
    "classic": {"good": "#5cc879", "warn": "#f5b041", "bad": "#ef5350", "neutral": "#61a0f5"},
    "blue-yellow": {"good": "#009E73", "warn": "#CC79A7", "bad": "#D55E00",
                    "neutral": "#56B4E9"},
    "high contrast": {"good": "#ffffff", "warn": "#ffd400", "bad": "#ff3b3b",
                      "neutral": "#00e5ff"},
}
VISION_MODES = tuple(VISION)
def semantic(mode="safe"):
    return dict(VISION.get(mode) or VISION["safe"])
def _hue_sat(rgb):
    r, g, b = rgb[:3]
    mx, mn = max(r, g, b), min(r, g, b)
    if mx - mn < 1e-6:
        return 0.0, 0.0
    d = mx - mn
    if mx == r:
        h = ((g - b) / d) % 6
    elif mx == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    return h * 60.0, d / mx
def meaning_of(rgba):
    h, s = _hue_sat(rgba)
    if s < 0.2:
        return "neutral"
    if h < 18 or h >= 330:
        return "bad"
    if h < 65:
        return "warn"
    if h < 170:
        return "good"
    return "neutral"
def remap(rgba, mode="safe"):
    if mode == "classic" or mode not in VISION:
        return tuple(rgba)
    meaning = meaning_of(rgba)
    if meaning == "neutral" and _hue_sat(rgba)[1] < 0.2:
        return tuple(rgba)
    c = rgbf(VISION[mode][meaning])
    return c + (tuple(rgba[3:4]) or (1.0,))
def tokens(accent=None, background=None, vision=None):
    t = dict(BASE)
    if vision:
        s = semantic(vision)
        t["ok"], t["warn"], t["bad"], t["info"] = s["good"], s["warn"], s["bad"], s["neutral"]
    if accent:
        t["accent"] = accent
    if background:
        t["viewport"] = background
    t["accent_soft"] = mix(t["panel"], t["accent"], 0.28)
    t["accent_text"] = "#0e1116" if luminance(t["accent"]) > 0.6 else "#ffffff"
    return t
def stylesheet(t, font_px=13, font_family="", scale=1.0):
    sheet = _sheet(t, font_px, font_family)
    if abs(scale - 1.0) < 1e-6:
        return sheet
    import re
    return re.sub(r"(\d+)px", lambda m: "%dpx" % max(1, int(round(int(m.group(1)) * scale))),
                  sheet)
def _sheet(t, font_px=13, font_family=""):
    family = ("font-family: \"%s\";" % font_family) if font_family else ""
    return """
* { font-size: %(fs)dpx; %(family)s }
QMainWindow, QDialog { background: %(window)s; color: %(text)s; }
QWidget { color: %(text)s; }
QToolTip { background: %(raised)s; color: %(text)s; border: 1px solid %(border)s;
           padding: 4px 6px; border-radius: 4px; }
QMenuBar { background: %(window)s; border-bottom: 1px solid %(border)s; padding: 2px; }
QMenuBar::item { padding: 4px 10px; border-radius: 4px; }
QMenuBar::item:selected { background: %(hover)s; }
QMenu { background: %(raised)s; border: 1px solid %(border)s; padding: 4px; border-radius: 6px; }
QMenu::item { padding: 5px 24px 5px 12px; border-radius: 4px; }
QMenu::item:selected { background: %(accent_soft)s; }
QMenu::separator { height: 1px; background: %(border)s; margin: 4px 8px; }
QToolBar { background: %(window)s; border: none; border-bottom: 1px solid %(border)s;
           spacing: 2px; padding: 3px 6px; }
QToolBar::separator { width: 1px; background: %(border)s; margin: 4px 6px; }
QToolButton { background: transparent; border: 1px solid transparent; border-radius: 5px;
              padding: 4px; min-width: 24px; min-height: 24px; }
QToolButton:hover { background: %(hover)s; }
QToolButton:checked { background: %(accent_soft)s; border-color: %(accent)s; }
QToolButton:pressed { background: %(raised)s; }
QPushButton#quiet { background: transparent; border: 1px solid transparent; color: %(text_dim)s; }
QPushButton#quiet:hover { color: %(bad)s; border-color: %(bad)s; }
QToolButton#toggleText { border: 1px solid %(border)s; padding: 3px 8px; }
QToolButton#toggleText:checked { background: %(accent_soft)s; border-color: %(accent)s; }
QToolButton#musicChip[ok="true"] { color: %(ok)s; }
QToolButton#musicChip[ok="false"] { color: %(warn)s; }
QToolButton#qt_toolbar_ext_button { min-width: 0px; min-height: 0px; padding: 0px; margin: 0px;
                                    border: none; background: %(raised)s; border-radius: 3px; }
QDockWidget { color: %(text_dim)s; titlebar-close-icon: none; }
QDockWidget::title { background: %(panel)s; padding: 6px 10px; text-align: left;
                     border-bottom: 1px solid %(border)s; }
QDockWidget > QWidget { background: %(panel)s; }
QTabBar::tab { background: %(window)s; color: %(text_dim)s; padding: 6px 12px;
               border: none; border-bottom: 2px solid transparent; }
QTabBar::tab:selected { color: %(text)s; border-bottom: 2px solid %(accent)s; }
QTabBar::tab:hover { color: %(text)s; }
QStatusBar { background: %(window)s; color: %(text_dim)s; border-top: 1px solid %(border)s; }
QStatusBar QLabel { color: %(text_dim)s; padding: 0 8px; }
QLabel#dim { color: %(text_dim)s; }
QLabel#title { font-size: %(fs_title)dpx; font-weight: 600; }
QLabel#caption { color: %(text_off)s; font-size: %(fs_small)dpx; }
QPushButton { background: %(raised)s; border: 1px solid %(border)s; border-radius: 6px;
              padding: 5px 14px; min-height: 18px; }
QPushButton:hover { background: %(hover)s; }
QPushButton#primary:hover { background: %(accent)s; border-color: %(text)s; }
QPushButton { color: %(text)s; }
QPushButton:default { border-color: %(accent)s; }
QPushButton#primary { background: %(accent)s; color: %(accent_text)s;
              border-color: %(accent)s; }
QPushButton:disabled { color: %(text_off)s; background: transparent;
              border: 1px dashed %(border)s; }
QPushButton:default:disabled, QPushButton#primary:disabled { background: transparent;
              color: %(text_off)s; border: 1px dashed %(border)s; }
QLineEdit, QSpinBox, QDoubleSpinBox, QComboBox, QKeySequenceEdit {
    background: %(window)s; border: 1px solid %(border)s; border-radius: 5px;
    padding: 4px 6px; selection-background-color: %(accent)s; min-height: 18px; }
QLineEdit:focus, QSpinBox:focus, QDoubleSpinBox:focus, QComboBox:focus {
    border-color: %(accent)s; }
QLineEdit[bad="true"], QLineEdit[bad="true"]:focus { border: 1px solid %(bad)s; }
QComboBox::drop-down { border: none; width: 18px; }
QComboBox QAbstractItemView { background: %(raised)s; border: 1px solid %(border)s;
    selection-background-color: %(accent_soft)s; }
QCheckBox::indicator { width: 14px; height: 14px; border-radius: 4px;
    border: 1px solid %(text_off)s; background: %(window)s; }
QCheckBox::indicator:checked { background: %(accent)s; border-color: %(accent)s; }
QRadioButton::indicator { width: 13px; height: 13px; border-radius: 7px;
                          border: 2px solid %(text_off)s; background: %(window)s; }
QRadioButton::indicator:hover { border-color: %(accent)s; }
QRadioButton::indicator:checked { background: qradialgradient(cx: 0.5, cy: 0.5, radius: 0.5,
    fx: 0.5, fy: 0.5, stop: 0 %(accent)s, stop: 0.55 %(accent)s, stop: 0.6 %(window)s,
    stop: 1 %(window)s); border-color: %(accent)s; }
QListWidget, QTreeWidget, QTableWidget { background: %(panel)s; border: none;
    alternate-background-color: %(raised)s; }
QListWidget::item, QTreeWidget::item { padding: 4px; border-radius: 4px; }
QListWidget::item:selected, QTreeWidget::item:selected, QTableWidget::item:selected {
    background: %(accent_soft)s; color: %(text)s; }
QHeaderView::section { background: %(panel)s; color: %(text_dim)s; border: none;
    border-bottom: 1px solid %(border)s; padding: 4px 6px; }
QScrollBar:vertical { background: transparent; width: 10px; margin: 0; }
QScrollBar::handle:vertical { background: %(raised)s; border-radius: 5px; min-height: 24px; }
QScrollBar::handle:vertical:hover { background: %(hover)s; }
QScrollBar:horizontal { background: transparent; height: 10px; margin: 0; }
QScrollBar::handle:horizontal { background: %(raised)s; border-radius: 5px; min-width: 24px; }
QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; }
QSplitter::handle { background: %(window)s; }
QSplitter::handle:hover { background: %(accent)s; }
QFrame#paneHeader { background: %(panel)s; border-bottom: 1px solid %(border)s; }
QFrame#paneHeader QToolButton { padding: 2px 6px; min-height: 20px; }
QFrame#paneHeader[active="true"] { border-bottom: 1px solid %(accent)s; }
QFrame#card { background: %(raised)s; border: 1px solid %(border)s; border-radius: 8px; }
QFrame#card QLabel#title { font-weight: 600; }
QPushButton#bigChoice { background: %(raised)s; border: 1px solid %(border)s;
    border-radius: 8px; padding: 10px 14px; font-weight: 600; text-align: left; }
QPushButton#bigChoice:hover { background: %(hover)s; border-color: %(accent)s; }
QPushButton#bigChoice:checked { background: %(accent_soft)s; border-color: %(accent)s; }
QPushButton#bigChoice[attention="true"] { border: 2px solid %(accent)s; }
QPushButton#bigChoice[attention="true"][pulse="on"] { background: %(accent_soft)s; }
QToolButton:disabled { color: %(text_off)s; }
QPushButton:focus, QToolButton:focus { border-color: %(accent)s; }
QTableWidget { gridline-color: %(border)s; }
QPlainTextEdit { background: %(window)s; border: 1px solid %(border)s; border-radius: 5px;
    padding: 4px; selection-background-color: %(accent)s; }
QPlainTextEdit:focus { border-color: %(accent)s; }
QProgressBar { background: %(window)s; border: 1px solid %(border)s; border-radius: 5px;
    text-align: center; min-height: 14px; }
QProgressBar::chunk { background: %(accent)s; border-radius: 4px; }
QToolButton#levelPill { border: 1px solid %(accent)s; border-radius: 12px; padding: 3px 12px;
    font-weight: 600; color: %(text)s; background: %(accent_soft)s; }
QToolButton#levelPill:hover { background: %(accent)s; color: %(accent_text)s; }
QToolButton#bigHeader { border: 1px solid %(border)s; border-radius: 7px; padding: 3px 7px;
    font-weight: 600; background: %(raised)s; }
QToolButton#bigHeader:hover { border-color: %(accent)s; background: %(hover)s; }
QFrame#contextBar { background: %(window)s; border: 1px solid %(border)s; border-radius: 12px; }
QToolButton#contextButton { border: 1px solid transparent; border-radius: 9px; padding: 4px 8px;
    font-weight: 600; background: transparent; }
QToolButton#contextButton:hover { background: %(accent_soft)s; border-color: %(accent)s; }
QFrame#firstRun { background: %(raised)s; border: 1px solid %(border)s; border-radius: 16px; }
QLabel#firstTitle { font-size: %(fs_huge)dpx; font-weight: 800; }
QPushButton#whoChoice { background: %(window)s; border: 2px solid %(border)s;
    border-radius: 14px; padding: 0; }
QPushButton#whoChoice:hover, QPushButton#whoChoice:focus { border-color: %(accent)s;
    background: %(accent_soft)s; }
QLabel#whoGlyph { font-size: %(fs_huge)dpx; color: %(accent)s; }
QLabel#whoTitle { font-size: %(fs_title)dpx; font-weight: 700; }
QLabel#whoWords { color: %(text_dim)s; }
QFrame#coachBubble { background: %(raised)s; border: 2px solid %(accent)s; border-radius: 14px; }
QLabel#coachTitle { font-size: %(fs_title)dpx; font-weight: 700; }
QLabel#coachCount { color: %(text_dim)s; font-size: %(fs_small)dpx; font-weight: 600; }
QLabel#coachDots { color: %(accent)s; font-size: %(fs_small)dpx; }
QLabel#coachDid { color: %(ok)s; font-weight: 600; }
QPushButton#coachLink { background: transparent; border: none; color: %(text_dim)s;
    padding: 5px 4px; }
QPushButton#coachLink:hover { color: %(text)s; }
QFrame#tipChip { background: %(raised)s; border: 1px solid %(accent)s; border-radius: 12px; }
QLabel#tipGlyph { color: %(accent)s; font-size: %(fs_title)dpx; }
QLabel#tipHead { color: %(accent)s; font-weight: 700; }
QPushButton#tipButton { padding: 3px 12px; }
QFrame#faceCard { background: %(raised)s; border: 1px solid %(border)s; border-radius: 12px; }
QLabel#faceTitle { font-size: %(fs_title)dpx; font-weight: 700; }
QLabel#faceTip { font-size: %(fs)dpx; padding: 2px 0; }
QToolButton#issueFix { background: transparent; border: 1px solid %(accent)s;
    color: %(accent)s; border-radius: 6px; padding: 2px 8px; font-weight: 600; margin: 2px 4px; }
QToolButton#issueFix:hover { background: %(accent)s; color: %(accent_text)s; }
QToolButton#issueShow { background: %(raised)s; border: 1px solid %(border)s;
    border-radius: 6px; padding: 2px 8px; margin: 2px 4px; }
QToolButton#issueShow:hover { border-color: %(accent)s; background: %(hover)s; }
""" % dict(t, fs=font_px, fs_title=font_px + 3, fs_small=max(9, font_px - 2),
                    fs_huge=font_px + 13, family=family)
