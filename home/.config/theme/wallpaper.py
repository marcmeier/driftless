#!/usr/bin/env python3
"""The palette "Wallpaper": a look drawn from the image on the desktop, next to the fixed palettes.

The image gives one hue (its strongest, weighted toward bright, saturated pixels) and how colourful
it is. Every grey of the plain look keeps its lightness and takes a trace of that hue (more for a
colourful image, none for a grey one), so the surfaces belong to the image without competing with it;
the accent is the hue itself, made light (dark look) or deep (light look) until it reads on the cards
as the plain accent does. The status colours (red, orange, yellow, green) and the terminal's other
colours stay the plain look's: they mean something.
Worked out in OKLCH, where steps in lightness look even and a hue keeps its character.

  wallpaper.py thumbs                  the folder's images, newest first, with a small preview each
                                       (JSON: {"folder": ..., "images": [{"image": ..., "thumb":
                                       ...}]}, made once, kept in ~/.cache/theme/thumbs)
  wallpaper.py folder                  the folder (WALLPAPER_DIR in the personal layer, else
                                       ~/Pictures/Wallpapers)
  wallpaper.py random                  another image from the folder than the one that is on

Which image is on is this machine's own: ~/.local/state/theme/wallpaper (apply.py --wallpaper).
"""

import colorsys
import functools
import hashlib
import json
import math
import os
import random
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import scheme  # noqa: E402

HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local" / "state") / "theme"
CHOSEN = STATE / "wallpaper"  # the path of the image that is on
PERSONAL = HOME / ".config" / "driftless" / "personal" / "config"
THUMBS = HOME / ".cache" / "theme" / "thumbs"
THUMB_SIZE = (256, 144)
IMAGES = {".png", ".jpg", ".jpeg", ".webp"}
BINS = 36  # hue histogram: 10 degrees each

# how much of the hue each grey takes (OKLCH chroma at a fully colourful image)
TINT = {
    "desk": 0.016,
    "bg_sunken": 0.016,
    "bg": 0.016,
    "bg_alt": 0.017,
    "bg_high": 0.018,
    "line": 0.02,
    "line_strong": 0.022,
    "faint": 0.022,
    "muted": 0.02,
    "dim": 0.016,
    "fg": 0.01,
    "fg_strong": 0.005,
}
# the status colours and the terminal's blue, purple and cyan stay the plain look's
KEPT = (
    "red",
    "red_bright",
    "orange",
    "yellow",
    "yellow_bright",
    "green",
    "blue",
    "blue_bright",
    "purple",
    "purple_bright",
    "cyan",
    "cyan_bright",
)


# ---- colour science: sRGB <-> OKLCH (Björn Ottosson) ----


def _linear(channel):
    channel /= 255
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def _gamma(channel):
    channel = channel * 12.92 if channel <= 0.0031308 else 1.055 * channel ** (1 / 2.4) - 0.055
    return channel * 255


def to_oklch(rgb):
    r, g, b = (_linear(c) for c in rgb)
    l_ = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m_ = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s_ = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    lightness = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    b_ = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    return lightness, math.hypot(a, b_), math.degrees(math.atan2(b_, a)) % 360


def oklch(lightness, chroma, hue):
    """8-bit sRGB of an OKLCH colour; chroma is reduced until it fits into sRGB (the hue stays)."""
    for _ in range(40):
        a, b = chroma * math.cos(math.radians(hue)), chroma * math.sin(math.radians(hue))
        l_ = (lightness + 0.3963377774 * a + 0.2158037573 * b) ** 3
        m_ = (lightness - 0.1055613458 * a - 0.0638541728 * b) ** 3
        s_ = (lightness - 0.0894841775 * a - 1.2914855480 * b) ** 3
        linear = (
            4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
            -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
            -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_,
        )
        if all(-0.0005 <= c <= 1.0005 for c in linear):
            break
        chroma *= 0.93
    return tuple(round(min(255, max(0, _gamma(min(1, max(0, c)))))) for c in linear)


# ---- the image ----


@functools.lru_cache(maxsize=4)
def analyse(path, mtime=0):
    """(hue in degrees, colourfulness 0..1) of an image; mtime only keys the cache."""
    from PIL import Image

    image = Image.open(path).convert("RGB")
    image.thumbnail((200, 200))
    histogram = [0.0] * BINS
    total = 0.0
    pixels = image.tobytes()
    for offset in range(0, len(pixels), 3):
        r, g, b = pixels[offset], pixels[offset + 1], pixels[offset + 2]
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if s < 0.2 or v < 0.15:
            continue
        weight = s * v * v  # bright, saturated pixels count most
        histogram[int(h * BINS) % BINS] += weight
        total += weight
    count = image.width * image.height
    if not count or total / count < 0.01:  # (almost) grey
        return None, 0.0
    # a hue split across a bin edge still wins
    smooth = [histogram[i - 1] * 0.5 + histogram[i] + histogram[(i + 1) % BINS] * 0.5 for i in range(BINS)]
    top = max(range(BINS), key=smooth.__getitem__)
    # the weighted mean hue around the top bin, in OKLCH degrees
    near = [((top + d) % BINS, histogram[(top + d) % BINS]) for d in (-1, 0, 1)]
    weight = sum(w for _, w in near) or 1
    hsv_hue = sum(((top + d) * 10 + 5) * w for d, (_, w) in zip((-1, 0, 1), near, strict=True)) / weight
    rgb = tuple(round(c * 255) for c in colorsys.hsv_to_rgb((hsv_hue % 360) / 360, 0.7, 0.9))
    colourful = min(1.0, max(0.25, (total / count) * 4))
    return to_oklch(rgb)[2], colourful


def accent(hue, light, cards):
    """The hue as an accent that reads on every card (4.5:1) and carries text on it (ink)."""
    lightness, chroma = (0.5, 0.15) if light else (0.76, 0.13)
    for _ in range(40):
        color = oklch(lightness, chroma, hue)
        if min(scheme.contrast(color, card) for card in cards) >= 4.6:
            return color
        lightness += -0.012 if light else 0.012
    return color


def given(hue, colourful, light):
    """What the palette gives for one look (scheme.complete() fills in the rest), as hex strings."""
    base = scheme.LIGHT if light else scheme.DARK
    if hue is None:  # a grey image (or none): the plain look itself
        return dict(base)
    out = {key: base[key] for key in KEPT}
    for key, chroma in TINT.items():
        lightness = to_oklch(scheme.rgb(base[key]))[0]
        out[key] = scheme.to_hex(oklch(lightness, chroma * colourful, hue))
    cards = tuple(scheme.rgb(out[key]) for key in ("bg", "bg_alt", "desk"))
    out["accent"] = scheme.to_hex(accent(hue, light, cards))
    return out


def palette(image=None):
    """The palette entry for scheme.PALETTES (label, variant names, dark and light)."""
    hue, colourful = None, 0.0
    if image and Path(image).is_file():
        try:
            hue, colourful = analyse(str(image), Path(image).stat().st_mtime_ns)
        except OSError:
            pass
    return {
        "label": "Wallpaper",
        "dark_name": "Dark",
        "light_name": "Light",
        "dark": given(hue, colourful, False),
        "light": given(hue, colourful, True),
        "image": str(image) if image else "",
    }


# ---- the folder ----


def folder():
    """WALLPAPER_DIR of the personal layer ($HOME and ~ expanded), else ~/Pictures/Wallpapers."""
    wanted = os.environ.get("WALLPAPER_DIR", "")
    if not wanted:
        try:
            match = re.search(r'^\s*WALLPAPER_DIR=["\']?([^"\'\n]*)', PERSONAL.read_text(), re.M)
            wanted = match.group(1) if match else ""
        except OSError:
            pass
    wanted = wanted.replace("${HOME}", str(HOME)).replace("$HOME", str(HOME))
    return Path(os.path.expanduser(wanted or "~/Pictures/Wallpapers"))


def images():
    """The folder's images, newest first."""
    try:
        found = [p for p in folder().iterdir() if p.is_file() and p.suffix.lower() in IMAGES]
    except OSError:
        return []
    return sorted(found, key=lambda p: p.stat().st_mtime, reverse=True)


def chosen():
    """The image that is on: the stored one if it is still there, else the newest of the folder."""
    try:
        path = Path(CHOSEN.read_text().strip())
        if path.is_file():
            return path
    except OSError:
        pass
    found = images()
    return found[0] if found else None


def thumbnail(image):
    from PIL import Image, ImageOps

    stat = image.stat()
    key = hashlib.sha1(f"{image}\0{stat.st_mtime_ns}".encode()).hexdigest()
    thumb = THUMBS / f"{key}.png"
    if not thumb.exists():
        small = ImageOps.fit(Image.open(image).convert("RGB"), THUMB_SIZE, Image.LANCZOS)
        tmp = thumb.with_name(thumb.name + ".tmp")
        small.save(tmp, "PNG")
        tmp.replace(thumb)
    return thumb


def thumbs():
    """Every image with its preview; previews of images that are gone are removed."""
    THUMBS.mkdir(parents=True, exist_ok=True)
    out, used = [], set()
    for image in images():
        try:
            thumb = thumbnail(image)
        except OSError:
            continue
        used.add(thumb)
        out.append({"image": str(image), "thumb": str(thumb)})
    for old in THUMBS.glob("*.png"):
        if old not in used:
            old.unlink(missing_ok=True)
    return out


def another():
    """An image of the folder other than the one that is on (None: there is no other)."""
    now = chosen()
    others = [p for p in images() if p != now]
    return random.choice(others) if others else None


def main(argv):
    if argv == ["thumbs"]:
        print(json.dumps({"folder": str(folder()), "images": thumbs()}))
    elif argv == ["folder"]:
        print(folder())
    elif argv == ["random"]:
        pick = another()
        if pick is None:
            sys.exit(f"no other image in {folder()}")
        print(pick)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
