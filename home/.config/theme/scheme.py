"""The palettes of the desktop, each dark and light, as named colours for the templates and the shell.

The plain look (the default): neutral greys and one fixed accent (blue), nothing taken from an image.
The accent marks what is active, selected or focused; red and orange are the only other colours
outside the terminal's palette. Both looks are fixed palettes, the light one is not an inverted dark
one: its accent is deeper so it reads on the light grey (contrast checked in tests/theme.bats).

The other palettes are well-known schemes (Catppuccin, Dracula, Gruvbox, ...), softer than the plain
greys, each in its dark and its light variant so "auto" works with all of them. They give their own
colours where the scheme has them; what a scheme has no colour for (the steps between background
and text, the bevels, the selection) is mixed from its background and text like the plain greys.
Their colours are the originals, so their contrast is the original's (tests/theme.bats asks less).

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

DARK = {
    "accent": "#7aa6d9",
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
    "accent": "#2d5f9e",
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

# The named palettes: label, the names of the two variants, and per variant what the scheme gives
# (complete() fills in the rest). Terminal brights only where the scheme has its own.
PALETTES = {
    "plain": {"label": "Plain", "dark_name": "Dark", "light_name": "Light", "dark": DARK, "light": LIGHT},
    "catppuccin": {
        "label": "Catppuccin",
        "dark_name": "Mocha",
        "light_name": "Latte",
        "dark": {
            "accent": "#cba6f7",
            "desk": "#11111b",
            "bg_sunken": "#181825",
            "bg": "#1e1e2e",
            "bg_high": "#313244",
            "line": "#313244",
            "line_strong": "#45475a",
            "faint": "#585b70",
            "muted": "#6c7086",
            "dim": "#a6adc8",
            "fg": "#cdd6f4",
            "black": "#45475a",
            "bright_black": "#585b70",
            "white": "#bac2de",
            "bright_white": "#a6adc8",
            "red": "#f38ba8",
            "orange": "#fab387",
            "yellow": "#f9e2af",
            "green": "#a6e3a1",
            "blue": "#89b4fa",
            "purple": "#cba6f7",
            "purple_bright": "#f5c2e7",
            "cyan": "#94e2d5",
        },
        "light": {
            "accent": "#8839ef",
            "desk": "#dce0e8",
            "bg_sunken": "#e6e9ef",
            "bg": "#eff1f5",
            "bg_high": "#e6e9ef",
            "line": "#ccd0da",
            "line_strong": "#bcc0cc",
            "faint": "#9ca0b0",
            "muted": "#8c8fa1",
            "dim": "#6c6f85",
            "fg": "#4c4f69",
            "red": "#d20f39",
            "orange": "#fe640b",
            "yellow": "#df8e1d",
            "green": "#40a02b",
            "blue": "#1e66f5",
            "purple": "#8839ef",
            "purple_bright": "#ea76cb",
            "cyan": "#179299",
        },
    },
    "dracula": {
        "label": "Dracula",
        "dark_name": "Dracula",
        "light_name": "Alucard",
        "dark": {
            "accent": "#bd93f9",
            "desk": "#191a21",
            "bg_sunken": "#21222c",
            "bg": "#282a36",
            "bg_high": "#343746",
            "line_strong": "#44475a",
            "muted": "#6272a4",
            "fg": "#f8f8f2",
            "fg_strong": "#ffffff",
            "black": "#21222c",
            "bright_black": "#6272a4",
            "white": "#f8f8f2",
            "bright_white": "#ffffff",
            "red": "#ff5555",
            "red_bright": "#ff6e6e",
            "orange": "#ffb86c",
            "yellow": "#f1fa8c",
            "yellow_bright": "#ffffa5",
            "green": "#50fa7b",
            "blue": "#bd93f9",
            "blue_bright": "#d6acff",
            "purple": "#ff79c6",
            "purple_bright": "#ff92df",
            "cyan": "#8be9fd",
            "cyan_bright": "#a4ffff",
        },
        "light": {
            "accent": "#644ac9",
            "desk": "#f0ead2",
            "bg": "#fffbeb",
            "muted": "#6c664b",
            "fg": "#1f1f1f",
            "selection": "#cfcfde",
            "red": "#cb3a2a",
            "orange": "#a34d14",
            "yellow": "#846e15",
            "green": "#14710a",
            "blue": "#644ac9",
            "purple": "#a3144d",
            "cyan": "#036a96",
        },
    },
    "everforest": {
        "label": "Everforest",
        "dark_name": "Dark",
        "light_name": "Light",
        "dark": {
            "accent": "#a7c080",
            "desk": "#232a2e",
            "bg_sunken": "#272e33",
            "bg": "#2d353b",
            "bg_alt": "#343f44",
            "bg_high": "#3d484d",
            "line": "#3d484d",
            "line_strong": "#475258",
            "faint": "#56635f",
            "muted": "#7a8478",
            "dim": "#9da9a0",
            "fg": "#d3c6aa",
            "black": "#475258",
            "red": "#e67e80",
            "orange": "#e69875",
            "yellow": "#dbbc7f",
            "green": "#a7c080",
            "blue": "#7fbbb3",
            "purple": "#d699b6",
            "cyan": "#83c092",
        },
        "light": {
            "accent": "#3a94c5",
            "desk": "#efebd4",
            "bg": "#fdf6e3",
            "bg_high": "#f4f0d9",
            "line": "#e6e2cc",
            "line_strong": "#bdc3af",
            "faint": "#a6b0a0",
            "muted": "#939f91",
            "dim": "#829181",
            "fg": "#5c6a72",
            "red": "#f85552",
            "orange": "#f57d26",
            "yellow": "#dfa000",
            "green": "#8da101",
            "blue": "#3a94c5",
            "purple": "#df69ba",
            "cyan": "#35a77c",
        },
    },
    "gruvbox": {
        "label": "Gruvbox",
        "dark_name": "Dark",
        "light_name": "Light",
        "dark": {
            "accent": "#8ec07c",
            "desk": "#1d2021",
            "bg_sunken": "#1d2021",
            "bg": "#282828",
            "bg_alt": "#32302f",
            "bg_high": "#3c3836",
            "line": "#3c3836",
            "line_strong": "#504945",
            "faint": "#665c54",
            "muted": "#928374",
            "dim": "#a89984",
            "fg": "#ebdbb2",
            "fg_strong": "#fbf1c7",
            "black": "#3c3836",
            "bright_black": "#928374",
            "white": "#a89984",
            "bright_white": "#ebdbb2",
            "red": "#fb4934",
            "orange": "#fe8019",
            "yellow": "#fabd2f",
            "green": "#b8bb26",
            "blue": "#83a598",
            "purple": "#d3869b",
            "cyan": "#8ec07c",
        },
        "light": {
            "accent": "#427b58",
            "desk": "#f2e5bc",
            "bg": "#fbf1c7",
            "bg_alt": "#f9f5d7",
            "bg_high": "#ebdbb2",
            "line": "#d5c4a1",
            "line_strong": "#bdae93",
            "faint": "#a89984",
            "muted": "#928374",
            "dim": "#665c54",
            "fg": "#3c3836",
            "fg_strong": "#282828",
            "red": "#9d0006",
            "red_bright": "#cc241d",
            "orange": "#af3a03",
            "yellow": "#b57614",
            "yellow_bright": "#d79921",
            "green": "#79740e",
            "blue": "#076678",
            "blue_bright": "#458588",
            "purple": "#8f3f71",
            "purple_bright": "#b16286",
            "cyan": "#427b58",
            "cyan_bright": "#689d6a",
        },
    },
    "nord": {
        "label": "Nord",
        "dark_name": "Polar Night",
        "light_name": "Snow Storm",
        "dark": {
            "accent": "#88c0d0",
            "desk": "#242933",
            "bg": "#2e3440",
            "bg_alt": "#3b4252",
            "bg_high": "#3b4252",
            "line": "#3b4252",
            "line_strong": "#434c5e",
            "faint": "#4c566a",
            "muted": "#616e88",
            "fg": "#d8dee9",
            "fg_strong": "#eceff4",
            "black": "#3b4252",
            "bright_black": "#4c566a",
            "white": "#e5e9f0",
            "bright_white": "#eceff4",
            "red": "#bf616a",
            "orange": "#d08770",
            "yellow": "#ebcb8b",
            "green": "#a3be8c",
            "blue": "#81a1c1",
            "purple": "#b48ead",
            "cyan": "#88c0d0",
            "cyan_bright": "#8fbcbb",
        },
        "light": {
            "accent": "#5e81ac",
            "desk": "#d8dee9",
            "bg": "#eceff4",
            "bg_high": "#e5e9f0",
            "line": "#d8dee9",
            "dim": "#4c566a",
            "fg": "#2e3440",
            "red": "#bf616a",
            "orange": "#b3654c",
            "yellow": "#9a7a32",
            "green": "#6a8a52",
            "blue": "#5e81ac",
            "purple": "#9a6c92",
            "cyan": "#4c8a96",
        },
    },
    "rose-pine": {
        "label": "Rosé Pine",
        "dark_name": "Rosé Pine",
        "light_name": "Dawn",
        "dark": {
            "accent": "#c4a7e7",
            "desk": "#12101a",
            "bg": "#191724",
            "bg_alt": "#1f1d2e",
            "bg_high": "#26233a",
            "line": "#26233a",
            "line_strong": "#403d52",
            "faint": "#524f67",
            "muted": "#6e6a86",
            "dim": "#908caa",
            "fg": "#e0def4",
            "black": "#26233a",
            "bright_black": "#6e6a86",
            "white": "#e0def4",
            "red": "#eb6f92",
            "orange": "#f6c177",
            "yellow": "#f6c177",
            "green": "#31748f",
            "blue": "#9ccfd8",
            "purple": "#c4a7e7",
            "cyan": "#ebbcba",
        },
        "light": {
            "accent": "#907aa9",
            "desk": "#f2e9e1",
            "bg": "#faf4ed",
            "bg_alt": "#fffaf3",
            "bg_high": "#f4ede8",
            "line": "#dfdad9",
            "line_strong": "#cecacd",
            "faint": "#9893a5",
            "muted": "#9893a5",
            "dim": "#797593",
            "fg": "#575279",
            "red": "#b4637a",
            "orange": "#ea9d34",
            "yellow": "#ea9d34",
            "green": "#286983",
            "blue": "#56949f",
            "purple": "#907aa9",
            "cyan": "#d7827e",
        },
    },
    "solarized": {
        "label": "Solarized",
        "dark_name": "Dark",
        "light_name": "Light",
        "dark": {
            "accent": "#268bd2",
            "desk": "#00212b",
            "bg": "#002b36",
            "bg_alt": "#073642",
            "bg_high": "#073642",
            "line": "#073642",
            "faint": "#586e75",
            "muted": "#586e75",
            "dim": "#839496",
            "fg": "#93a1a1",
            "fg_strong": "#eee8d5",
            "black": "#073642",
            "white": "#eee8d5",
            "red": "#dc322f",
            "orange": "#cb4b16",
            "yellow": "#b58900",
            "green": "#859900",
            "blue": "#268bd2",
            "purple": "#6c71c4",
            "purple_bright": "#d33682",
            "cyan": "#2aa198",
        },
        "light": {
            "accent": "#268bd2",
            "desk": "#eee8d5",
            "bg": "#fdf6e3",
            "bg_high": "#eee8d5",
            "faint": "#93a1a1",
            "muted": "#93a1a1",
            "dim": "#657b83",
            "fg": "#586e75",
            "fg_strong": "#073642",
            "black": "#073642",
            "white": "#93a1a1",
            "red": "#dc322f",
            "orange": "#cb4b16",
            "yellow": "#b58900",
            "green": "#859900",
            "blue": "#268bd2",
            "purple": "#6c71c4",
            "purple_bright": "#d33682",
            "cyan": "#2aa198",
        },
    },
    "tokyo-night": {
        "label": "Tokyo Night",
        "dark_name": "Night",
        "light_name": "Day",
        "dark": {
            "accent": "#7aa2f7",
            "desk": "#16161e",
            "bg_sunken": "#16161e",
            "bg": "#1a1b26",
            "bg_high": "#292e42",
            "line": "#292e42",
            "line_strong": "#3b4261",
            "faint": "#414868",
            "muted": "#565f89",
            "dim": "#737aa2",
            "fg": "#c0caf5",
            "black": "#15161e",
            "bright_black": "#414868",
            "white": "#a9b1d6",
            "bright_white": "#c0caf5",
            "red": "#f7768e",
            "orange": "#ff9e64",
            "yellow": "#e0af68",
            "green": "#9ece6a",
            "blue": "#7aa2f7",
            "purple": "#bb9af7",
            "cyan": "#7dcfff",
        },
        "light": {
            "accent": "#2e7de9",
            "desk": "#d0d5e3",
            "bg": "#e1e2e7",
            "bg_high": "#d0d5e3",
            "line": "#c4c8da",
            "line_strong": "#a8aecb",
            "faint": "#a1a6c5",
            "muted": "#848cb5",
            "dim": "#6172b0",
            "fg": "#3760bf",
            "red": "#f52a65",
            "orange": "#b15c00",
            "yellow": "#8c6c3e",
            "green": "#587539",
            "blue": "#2e7de9",
            "purple": "#9854f1",
            "cyan": "#007197",
        },
    },
}
DEFAULT = "plain"

# the steps between background (0) and text (1), as in the plain greys
STEPS = {
    "dark": {
        "bg_alt": 0.03,
        "bg_high": 0.07,
        "line": 0.11,
        "line_strong": 0.19,
        "faint": 0.27,
        "muted": 0.44,
        "dim": 0.6,
    },
    "light": {"bg_high": 0.05, "line": 0.17, "line_strong": 0.29, "faint": 0.37, "muted": 0.51, "dim": 0.68},
}
WHITE, BLACK = (255, 255, 255), (0, 0, 0)


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


def complete(given, light):
    """Every name of the plain look, from what a palette gives (RGB tuples)."""
    c = {key: rgb(value) for key, value in given.items()}
    bg, fg = c["bg"], c["fg"]
    for key, f in STEPS["light" if light else "dark"].items():
        c.setdefault(key, mix(bg, fg, f))
    c.setdefault("fg_strong", mix(fg, BLACK if light else WHITE, 0.6))
    if light:
        c.setdefault("bg_alt", mix(bg, WHITE, 0.6))
        c.setdefault("bg_sunken", c["desk"])
        c.setdefault("overlay", fg)
        terminal = {"black": fg, "white": c["muted"], "bright_black": c["dim"], "bright_white": c["faint"]}
        bevels = {"bevel_light": WHITE, "bevel_midlight": bg, "bevel_mid": c["line_strong"], "bevel_dark": c["muted"]}
        c.setdefault("field", c["bg_alt"])
    else:
        c.setdefault("bg_sunken", mix(bg, c["desk"], 0.6))
        c.setdefault("overlay", WHITE)
        terminal = {"black": c["bg_alt"], "white": fg, "bright_black": c["faint"], "bright_white": c["fg_strong"]}
        bevels = {
            "bevel_light": c["line_strong"],
            "bevel_midlight": c["line"],
            "bevel_mid": c["line"],
            "bevel_dark": c["desk"],
        }
        c.setdefault("field", c["bg_sunken"])
    for key, value in (terminal | bevels).items():
        c.setdefault(key, value)
    for hue in ("red", "yellow", "blue", "purple", "cyan"):
        c.setdefault(hue + "_bright", mix(c[hue], WHITE, 0.12 if light else 0.25))
    c.setdefault("shadow", BLACK)
    c.setdefault("window", bg)
    c.setdefault("glass", bg)
    c.setdefault("selection", mix(bg, c["accent"], 0.22 if light else 0.2))
    # text on the accent: whichever of the palette's darkest and lightest reads best
    c.setdefault("ink", max((c["desk"], c["bg_alt"], fg, c["fg_strong"]), key=lambda x: contrast(x, c["accent"])))
    return c


def palette_name(palette):
    return palette if palette in PALETTES else DEFAULT


def scheme(name, palette=DEFAULT):
    """RGB tuples for every name of the look `name` ("dark" or "light") in `palette`."""
    light = name == "light"
    colors = complete(PALETTES[palette_name(palette)]["light" if light else "dark"], light)
    colors["primary"] = colors["secondary"] = colors.pop("accent")
    colors["primary_dim"] = colors["secondary_dim"] = mix(colors["bg"], colors["primary"], 0.20 if light else 0.33)
    colors["on_dim"] = colors["fg_strong"]
    return colors


def describe(colors):
    """Hex strings, for colors.json."""
    return {key: to_hex(value) for key, value in colors.items()}
