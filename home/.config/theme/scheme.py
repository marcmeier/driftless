"""The two looks of the desktop, dark and light, as named colours for the templates and the shell.

The plain look: neutral greys and one fixed accent (blue), nothing taken from an image. The accent
marks what is active, selected or focused; red and orange are the only other colours outside the
terminal's palette. Both looks are fixed palettes, the light one is not an inverted dark one: its
accent is deeper so it reads on the light grey (contrast checked in tests/theme.bats).

Names (every template can use them, see apply.py):
  desk        the desktop behind the windows (also the lock and the login screen)
  bg          window and terminal background      bg_alt     raised: popovers, cards, menus
  bg_high     buttons, wells                       bg_sunken  deepest shade
  line        borders, separators                  line_strong a border that shows
  faint       barely there (disabled, captions)    muted      hints, comments
  dim         secondary text                       fg         text
  fg_strong   the brightest text (headlines)       ink        text on the accent
  overlay     what hovers are made of (white on dark, ink on light)
  shadow      only where a program insists on one
  red orange yellow green blue purple cyan (+ _bright): status colours and the terminal's palette
  bevel_light bevel_midlight bevel_mid bevel_dark: Qt's 3D roles
  field       where you type and lists             window     behind them
  selection   selected text                        glass      the shell's surfaces (opaque)
  primary secondary: the accent (both the same) (+ _dim: a quiet tint of it over bg, + on_dim)
"""

ACCENT = {"dark": "#7aa6d9", "light": "#2d5f9e"}

DARK = {
    "desk": "#0e0e0e",
    "bg": "#161616",
    "bg_alt": "#1c1c1c",
    "bg_high": "#232323",
    "bg_sunken": "#111111",
    "line": "#2b2b2b",
    "line_strong": "#3a3a3a",
    "faint": "#4a4a4a",
    "muted": "#6a6a6a",
    "dim": "#8a8a8a",
    "fg": "#d6d6d6",
    "fg_strong": "#f2f2f2",
    "ink": "#0e0e0e",
    "overlay": "#ffffff",
    "shadow": "#000000",
    "black": "#1c1c1c",
    "white": "#d6d6d6",
    "bright_black": "#4a4a4a",
    "bright_white": "#f2f2f2",
    "red": "#e06666",
    "red_bright": "#eb8a8a",
    "orange": "#e0a040",
    "yellow": "#d6b56a",
    "yellow_bright": "#e6c98a",
    "green": "#8fbf8a",
    "blue": "#7aa6d9",
    "blue_bright": "#9dbde4",
    "purple": "#b49ad6",
    "purple_bright": "#c8b4e2",
    "cyan": "#7fb8b8",
    "cyan_bright": "#9ccaca",
    "bevel_light": "#3a3a3a",
    "bevel_midlight": "#2b2b2b",
    "bevel_mid": "#2b2b2b",
    "bevel_dark": "#0e0e0e",
    "field": "#111111",
    "window": "#161616",
    "selection": "#26364a",
    "glass": "#161616",
}

LIGHT = {
    "desk": "#e2e2e2",
    "bg": "#f4f4f4",
    "bg_alt": "#fbfbfb",
    "bg_high": "#e9e9e9",
    "bg_sunken": "#e2e2e2",
    "line": "#d0d0d0",
    "line_strong": "#b8b8b8",
    "faint": "#a8a8a8",
    "muted": "#8a8a8a",
    "dim": "#686868",
    "fg": "#242424",
    "fg_strong": "#000000",
    "ink": "#ffffff",
    "overlay": "#242424",
    "shadow": "#000000",
    "black": "#242424",
    "white": "#8a8a8a",
    "bright_black": "#686868",
    "bright_white": "#a8a8a8",
    "red": "#b83030",
    "red_bright": "#c85050",
    "orange": "#a8650a",
    "yellow": "#8a6d10",
    "yellow_bright": "#9c7d1c",
    "green": "#2e7540",
    "blue": "#2d5f9e",
    "blue_bright": "#3d72b4",
    "purple": "#6a4a9a",
    "purple_bright": "#7d5cb0",
    "cyan": "#23707a",
    "cyan_bright": "#2f8590",
    "bevel_light": "#ffffff",
    "bevel_midlight": "#f4f4f4",
    "bevel_mid": "#b8b8b8",
    "bevel_dark": "#8a8a8a",
    "field": "#fbfbfb",
    "window": "#f4f4f4",
    "selection": "#c9d7ea",
    "glass": "#f4f4f4",
}


def _linear(channel):
    channel /= 255
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def luminance(rgb):
    """Relative luminance (WCAG)."""
    r, g, b = (_linear(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    lum_a, lum_b = luminance(a), luminance(b)
    return (max(lum_a, lum_b) + 0.05) / (min(lum_a, lum_b) + 0.05)


def mix(a, b, f):
    """f of b over a."""
    return tuple(round(x + (y - x) * f) for x, y in zip(a, b, strict=True))


def rgb(hex_color):
    digits = hex_color.lstrip("#")
    return tuple(int(digits[i : i + 2], 16) for i in (0, 2, 4))


def to_hex(color):
    return "#{:02x}{:02x}{:02x}".format(*color)


def scheme(name):
    """RGB tuples for every name of the look `name` ("dark" or "light")."""
    light = name == "light"
    colors = {key: rgb(value) for key, value in (LIGHT if light else DARK).items()}
    colors["primary"] = colors["secondary"] = rgb(ACCENT["light" if light else "dark"])
    colors["primary_dim"] = colors["secondary_dim"] = mix(colors["bg"], colors["primary"], 0.20 if light else 0.33)
    colors["on_dim"] = colors["fg_strong"]
    return colors


def describe(colors):
    """Hex strings, for colors.json."""
    return {key: to_hex(value) for key, value in colors.items()}
