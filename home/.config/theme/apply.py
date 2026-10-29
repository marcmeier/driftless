#!/usr/bin/env python3
"""Render the theme templates in the dark or the light look of a palette (scheme.py; the default is the
plain look: greys and one accent).

  apply.py --current                   render the look that is chosen (also --default, the same)
  apply.py --refresh                   the same, then reload the programs and the login screen
                                       (set-wallpaper.sh --current)
  apply.py --appearance dark|light|auto   choose the look and render it (auto: light from sunrise
                                       to sunset, the weather feed's times, else 7 to 19 o'clock)
  apply.py --palette NAME              choose the palette (plain, catppuccin, ...) and render it,
                                       the login screen too (its dark look)
  apply.py --palettes                  list the palettes (name, a tab, the label)
  apply.py --follow-sun                with auto: render again when the sun has risen or set since

Template tokens: @primary@ -> #rrggbb, @primary+88@ -> #rrggbb88 (alpha suffix),
@primary:0.45@ -> rgba(r, g, b, 0.45), @primary~@ -> #ffrrggbb (Qt ARGB),
@primary_hex@ -> rrggbb, @primary_rgba+ee@ -> rgba(rrggbbee) (Hyprland), @home@ -> your home.
Names: every colour of scheme.py (fg, bg, dim, line, red, ..., primary, secondary, primary_dim)
in the look that is on; @scheme@ -> dark|light, @gtk_theme@, @qt_style@, @shadow_alpha@, @terminal_opacity@ (first, so
@shadow:@shadow_alpha@@ works).
The login screen and the fallback lock screen stay dark in both looks (night, like the greeter): the
palette's dark variant.

Everything written here is per machine and not in the repository (.gitignore): the desktop's plain
background ~/.config/wall.png (one colour, shown by awww), the rendered configs, the round avatar from
~/.face and the login screen files in ~/.cache/theme (login_screen() installs those as root; login.png
is the night desk colour, the shell's lock screen draws the same colour itself).
The shell (bar, notifications, lock screen, power menu) reads colors.json itself and follows it live.
"""

import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import scheme  # noqa: E402

HOME = Path.home()
CONFIG = HOME / ".config"
THEME = CONFIG / "theme"
TEMPLATES = HERE / "templates"
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local" / "state") / "theme"
APPEARANCE = STATE / "appearance"  # dark | light | auto, per machine
PALETTE = STATE / "palette"  # a name of scheme.PALETTES, per machine
SUN = HOME / ".cache" / "theme" / "sun.json"  # {"sunrise": "07:24", "sunset": "18:55"}, weather.py

# template (in theme/templates/) -> destination (relative to ~/.config); NIGHT ones are always dark
TARGETS = {
    "colors.css": "theme/colors.css",
    "colors.lua": "theme/colors.lua",
    "ghostty-colors": "theme/ghostty-colors",
    "hyprlock.conf": "hypr/hyprlock.conf",
    "starship.toml": "starship.toml",
    "qt6ct-colors.conf": "qt6ct/colors/driftless.conf",
    "qt6ct.conf": "qt6ct/qt6ct.conf",
    "walker.css": "walker/themes/driftless/style.css",
    "gtk3.css": "gtk-3.0/gtk.css",
    "gtk4.css": "gtk-4.0/gtk.css",
    "btop.theme": "btop/themes/driftless.theme",
}
NIGHT = {"hyprlock.conf"}
SWATCHES = ("bg", "primary", "red", "yellow", "green", "blue")  # a palette in brief, for the settings


def appearance():
    """The chosen look: dark, light or auto."""
    try:
        chosen = APPEARANCE.read_text().strip()
    except OSError:
        return "dark"
    return chosen if chosen in ("dark", "light", "auto") else "dark"


def palette():
    """The chosen palette (scheme.py), the plain look unless another is chosen."""
    try:
        chosen = PALETTE.read_text().strip()
    except OSError:
        return scheme.DEFAULT
    return scheme.palette_name(chosen)


def sun_is_up(now=None):
    """Between today's sunrise and sunset (weather.py notes them), else between 7 and 19 o'clock."""
    now = now or datetime.datetime.now()
    rise, down = datetime.time(7), datetime.time(19)
    try:
        sun = json.loads(SUN.read_text())
        rise, down = (datetime.time.fromisoformat(sun[key]) for key in ("sunrise", "sunset"))
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return rise <= now.time() < down


def look(chosen=None):
    """The look to render now: dark or light."""
    chosen = chosen or appearance()
    if chosen == "auto":
        return "light" if sun_is_up() else "dark"
    return chosen


STRINGS = {
    "dark": {
        "scheme": "dark",
        "gtk_theme": "adw-gtk3-dark",
        "qt_style": "Adwaita-Dark",
        "shadow_alpha": "0.45",
        "terminal_opacity": "1",
    },
    "light": {
        "scheme": "light",
        "gtk_theme": "adw-gtk3",
        "qt_style": "Adwaita",
        "shadow_alpha": "0.16",
        "terminal_opacity": "1",
    },
}


def token_pattern(names):
    alternatives = "|".join(sorted(names, key=len, reverse=True))
    return re.compile(rf"@({alternatives})(_hex|_rgba)?(?:(\+[0-9a-f]{{2}})|:([0-9.]+)|(~))?@")


def render(text, rgb_colors, name="dark"):
    text = text.replace("@home@", str(HOME))
    for key, value in STRINGS[name].items():
        text = text.replace(f"@{key}@", value)

    def replace(match):
        r, g, b = rgb_colors[match.group(1)]
        hex_rgb = f"{r:02x}{g:02x}{b:02x}"
        kind, plus, alpha, argb = match.group(2), match.group(3), match.group(4), match.group(5)
        if alpha:
            return f"rgba({r}, {g}, {b}, {alpha})"
        if argb:
            return "#ff" + hex_rgb
        if kind == "_hex":
            return hex_rgb
        if kind == "_rgba":
            return f"rgba({hex_rgb}{(plus or '+ff')[1:]})"
        return "#" + hex_rgb + (plus[1:] if plus else "")

    return token_pattern(rgb_colors).sub(replace, text)


def make_avatar(rgb_colors):
    """Round avatar from ~/.face for the bar (THEME/avatar.png) and the login screen (cache).
    Without ~/.face: the first letter of the login name on the primary colour."""
    from PIL import Image, ImageDraw, ImageFont

    size, big = 256, 1024
    face = HOME / ".face"
    if face.exists():
        image = Image.open(face).convert("RGB")
        side = min(image.size)
        image = image.crop(
            (
                (image.width - side) // 2,
                (image.height - side) // 2,
                (image.width + side) // 2,
                (image.height + side) // 2,
            )
        )
        image = image.resize((size, size), Image.LANCZOS)
    else:
        image = Image.new("RGB", (size, size), rgb_colors["primary_dim"])
        letter = (os.environ.get("USER") or "?")[0].upper()
        try:
            font = ImageFont.truetype("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf", 140)
        except OSError:
            font = ImageFont.load_default(140)
        ImageDraw.Draw(image).text((size / 2, size / 2), letter, font=font, fill=rgb_colors["primary"], anchor="mm")
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, big - 1, big - 1), fill=255)
    image.putalpha(mask.resize((size, size), Image.LANCZOS))
    for dest in (THEME / "avatar.png", HOME / ".cache" / "theme" / "avatar.png"):
        dest.parent.mkdir(parents=True, exist_ok=True)
        image.save(dest.with_name(dest.name + ".tmp"), "PNG")
        os.replace(dest.with_name(dest.name + ".tmp"), dest)


def plain(dest, color):
    """A small PNG of one colour (awww and the greeter scale it to the screen)."""
    from PIL import Image

    dest.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", (16, 16), color).save(dest.with_name(dest.name + ".tmp"), "PNG")
    os.replace(dest.with_name(dest.name + ".tmp"), dest)


def btop_use_theme():
    """btop rewrites btop.conf itself, so only the two theme keys are set (a fresh file is fine:
    btop fills in the rest). No theme background: the terminal's own shows."""
    conf = CONFIG / "btop" / "btop.conf"
    wanted = {"color_theme": '"driftless"', "theme_background": "False"}
    lines = conf.read_text().splitlines() if conf.exists() else []
    for key, value in wanted.items():
        line = f"{key} = {value}"
        index = next((i for i, old in enumerate(lines) if old.split("=")[0].strip() == key), None)
        if index is None:
            lines.append(line)
        else:
            lines[index] = line
    write(conf, "\n".join(lines) + "\n")


VSCODE_THEMES = Path("/usr/share/code/resources/app/extensions/theme-defaults/themes")
VSCODE_MANIFEST = """<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
 <Metadata>
  <Identity Language="en-US" Id="theme" Version="1.0.0" Publisher="driftless"/>
  <DisplayName>driftless</DisplayName>
  <Description xml:space="preserve">2026 Dark or Light in the desktop's palette (theme/apply.py)</Description>
  <Categories>Themes</Categories>
  <Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.80.0"/></Properties>
 </Metadata>
 <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
 <Dependencies/>
 <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets>
</PackageManifest>
"""
VSCODE_TYPES = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension=".json" ContentType="application/json"/>
 <Default Extension=".vsixmanifest" ContentType="text/xml"/>
</Types>
"""


def vscode_theme(rgb_colors, name):
    """VS Code theme "driftless": packed as a .vsix next to VS Code's own theme files (it includes
    2026 Dark) and installed in the background; VS Code only picks up registered extensions.
    Open windows show the new colours after a reload. Skipped without VS Code, and when the theme is
    installed and did not change (installing starts VS Code)."""
    import hashlib
    import shutil
    import zipfile

    code = shutil.which("code")
    if not code or not VSCODE_THEMES.is_dir():
        return
    package = {
        "name": "theme",
        "publisher": "driftless",
        "displayName": "driftless",
        "version": "1.0.0",
        "engines": {"vscode": "^1.80.0"},
        "categories": ["Themes"],
        "contributes": {
            "themes": [
                {
                    "id": "driftless",
                    "label": "driftless",
                    "uiTheme": "vs" if name == "light" else "vs-dark",
                    "path": "./themes/driftless.json",
                }
            ]
        },
    }
    theme = render((TEMPLATES / "vscode-theme.json").read_text(), rgb_colors, name)
    bases = sorted(VSCODE_THEMES.glob("*.json"))
    digest = hashlib.sha256(json.dumps(package).encode() + theme.encode())
    for base in bases:
        digest.update(base.read_bytes())
    vsix = HOME / ".cache" / "theme" / "driftless-vscode.vsix"
    stamp = vsix.with_name("driftless-vscode.sha256")
    installed = any((HOME / ".vscode" / "extensions").glob("driftless.theme-*"))
    if installed and stamp.is_file() and stamp.read_text() == digest.hexdigest():
        return
    vsix.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(vsix.with_name(vsix.name + ".tmp"), "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", VSCODE_TYPES)
        archive.writestr("extension.vsixmanifest", VSCODE_MANIFEST)
        archive.writestr("extension/package.json", json.dumps(package, indent=1))
        for base in bases:
            archive.write(base, "extension/themes/" + base.name)
        archive.writestr("extension/themes/driftless.json", theme)
    os.replace(vsix.with_name(vsix.name + ".tmp"), vsix)
    subprocess.Popen(
        [code, "--install-extension", str(vsix), "--force"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    write(stamp, digest.hexdigest())


def write(dest, text):
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(dest.name + ".tmp")
    tmp.write_text(text)
    if dest.exists():
        os.chmod(tmp, dest.stat().st_mode & 0o777)
    os.replace(tmp, dest)


def gtk_look(name):
    """GTK 3 by its theme, GTK 4, libadwaita, Electron and the portal by the colour scheme."""
    wanted = {
        "color-scheme": "prefer-light" if name == "light" else "prefer-dark",
        "gtk-theme": STRINGS[name]["gtk_theme"],
    }
    for key, value in wanted.items():
        subprocess.run(
            ["gsettings", "set", "org.gnome.desktop.interface", key, value],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )


def reload_programs():
    """What does not follow the files by itself: the desktop's colour, Hyprland's borders, the terminals
    and btop (USR2: both read their colours again). The shell follows colors.json itself."""
    quiet = {"stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL, "check": False}
    if subprocess.run(["awww", "img", "--transition-type", "none", str(CONFIG / "wall.png")], **quiet).returncode:
        subprocess.run(["systemctl", "--user", "restart", "driftless-wallpaper.service"], **quiet)
    for command in (
        ["hyprctl", "reload"],
        ["pkill", "-USR2", "-x", "ghostty"],
        ["pkill", "-USR2", "-x", "btop"],
    ):
        subprocess.run(command, **quiet)


def login_screen():
    """Hand the login screen its files from ~/.cache/theme: greeter-update of driftless-system copies
    them to /var/lib/driftless/greeter (pkexec; polkit lets the active session do it without a password)."""
    update = "/usr/lib/driftless/greeter-update"
    if not os.access(update, os.X_OK):
        print("Login screen NOT updated: driftless-system is not installed (driftless system)", file=sys.stderr)
    elif subprocess.run(["pkexec", update, str(HOME / ".cache" / "theme")], check=False).returncode:
        print("login screen NOT updated", file=sys.stderr)
    else:
        print("login screen updated")


def palettes_in_brief():
    """Every palette's label, the names of its variants and a few colours of each, for the settings."""
    return {
        key: {
            "label": entry["label"],
            "dark": {"name": entry["dark_name"]}
            | {k: scheme.to_hex(v) for k, v in scheme.scheme("dark", key).items() if k in SWATCHES},
            "light": {"name": entry["light_name"]}
            | {k: scheme.to_hex(v) for k, v in scheme.scheme("light", key).items() if k in SWATCHES},
        }
        for key, entry in scheme.PALETTES.items()
    }


def render_all(name):
    """Render every target in the look `name`, the desktop's colour and the login screen's files."""
    chosen = palette()
    rgb_colors = scheme.scheme(name, chosen)
    night_colors = scheme.scheme("dark", chosen)
    accents = {key: scheme.to_hex(night_colors[key]) for key in ("primary", "secondary")}
    write(
        THEME / "colors.json",
        json.dumps(
            {
                "primary": scheme.to_hex(rgb_colors["primary"]),
                "secondary": scheme.to_hex(rgb_colors["secondary"]),
                "appearance": appearance(),
                "scheme": name,
                "palette": chosen,
                "palettes": palettes_in_brief(),
                "accents": accents,
                "colors": scheme.describe(rgb_colors),
                "night": scheme.describe(night_colors),
            },
            indent=1,
        )
        + "\n",
    )
    for template, dest in TARGETS.items():
        night = template in NIGHT
        text = (TEMPLATES / template).read_text()
        write(CONFIG / dest, render(text, night_colors if night else rgb_colors, "dark" if night else name))
    gtk_look(name)
    btop_use_theme()
    vscode_theme(rgb_colors, name)
    make_avatar(rgb_colors)
    plain(CONFIG / "wall.png", rgb_colors["desk"])
    # login screen (root-owned): rendered here, installed by set-wallpaper.sh; always the dark look
    cache = HOME / ".cache" / "theme"
    cache.mkdir(parents=True, exist_ok=True)
    write(cache / "colors.json", json.dumps(accents | {"colors": scheme.describe(night_colors)}, indent=1) + "\n")
    write(cache / "regreet.css", render((TEMPLATES / "regreet.css").read_text(), night_colors))
    plain(cache / "login.png", night_colors["desk"])
    print(f"{scheme.PALETTES[chosen]['label']}, {name}")


def current_scheme():
    try:
        return json.loads((THEME / "colors.json").read_text()).get("scheme", "dark")
    except (OSError, ValueError):
        return "dark"


def main(argv):
    if argv and argv[0] == "--appearance":
        if len(argv) < 2 or argv[1] not in ("dark", "light", "auto"):
            sys.exit("usage: apply.py --appearance dark|light|auto")
        STATE.mkdir(parents=True, exist_ok=True)
        write(APPEARANCE, argv[1] + "\n")
        render_all(look(argv[1]))
        reload_programs()
        return
    if argv and argv[0] == "--palette":
        if len(argv) < 2 or argv[1] not in scheme.PALETTES:
            sys.exit("usage: apply.py --palette " + "|".join(scheme.PALETTES))
        STATE.mkdir(parents=True, exist_ok=True)
        write(PALETTE, argv[1] + "\n")
        render_all(look())
        reload_programs()
        login_screen()
        return
    if argv and argv[0] == "--palettes":
        for key, entry in scheme.PALETTES.items():
            print(f"{key}\t{entry['label']}")
        return
    if argv and argv[0] == "--follow-sun":
        if appearance() == "auto" and look() != current_scheme():
            render_all(look())
            reload_programs()
        return
    if argv and argv[0] in ("--current", "--default"):
        render_all(look())
        return
    if argv and argv[0] == "--refresh":
        render_all(look())
        reload_programs()
        login_screen()
        return
    sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
