#!/usr/bin/env bats
# home/.config/theme: the palettes (the plain look and the named ones), each dark and light, and what
# apply.py renders from them

THEME=$BATS_TEST_DIRNAME/../home/.config/theme

setup() {
  T=$BATS_TEST_TMPDIR
  mkdir -p "$T/home"
}

@test "every palette has the plain look's names, and every name a template uses" {
  run python3 -I - "$THEME" << 'PY'
import re, sys
from pathlib import Path
theme = Path(sys.argv[1])
sys.path.insert(0, str(theme))
import scheme
strings = {"home", "scheme", "gtk_theme", "qt_style", "shadow_alpha", "terminal_opacity"}
plain = set(scheme.scheme("dark"))
missing = set()
for palette in scheme.PALETTES:
    for look in ("dark", "light"):
        names = set(scheme.scheme(look, palette))
        if names != plain:
            missing.add(f"{palette} {look}: not the plain look's names: {sorted(names ^ plain)}")
        for template in (theme / "templates").iterdir():
            for name in re.findall(r"@([a-z_]+?)(?:_hex|_rgba)?(?:\+[0-9a-f]{2}|:[0-9.]+|~)?@", template.read_text()):
                if name not in names | strings:
                    missing.add(f"{palette} {look}: {template.name}: {name}")
print("\n".join(sorted(missing)))
sys.exit(1 if missing else 0)
PY
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "text and accent read on their backgrounds in both looks (the named palettes: as in their originals)" {
  run python3 -I - "$THEME" << 'PY'
import sys
sys.path.insert(0, sys.argv[1])
import scheme
bad = []
plain = (("fg", "bg", 7), ("fg", "desk", 7), ("dim", "bg", 4.5), ("dim", "bg_alt", 4.5), ("primary", "bg", 4.5),
         ("primary", "bg_alt", 4.5), ("ink", "primary", 4.5), ("red", "bg", 4.5))
# Solarized and Tokyo Night Day are softer by design: their text at AA, the rest readable;
# secondary text (dim) reads on every palette, scheme.readable() sees to it
named = (("fg", "bg", 4.5), ("fg", "desk", 3.5), ("dim", "bg", 4.5), ("dim", "bg_alt", 4.5), ("primary", "bg", 3),
         ("primary", "bg_alt", 3), ("ink", "primary", 3.5), ("red", "bg", 3))
for palette in scheme.PALETTES:
    for look in ("dark", "light"):
        c = scheme.scheme(look, palette)
        for fg, bg, least in plain if palette == "plain" else named:
            ratio = scheme.contrast(c[fg], c[bg])
            if ratio < least:
                bad.append(f"{palette} {look}: {fg} on {bg} {ratio:.2f} < {least}")
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "apply.py renders every target without a token left, and the plain backgrounds" {
  HOME=$T/home XDG_STATE_HOME=$T/home/.local/state run python3 -I - "$THEME" << 'PY'
import json, re, sys
sys.path.insert(0, sys.argv[1])
import apply
apply.gtk_look = lambda name: None          # no gsettings here
apply.vscode_theme = lambda colors, name: None
for look in ("light", "dark"):
    apply.render_all(look)
left = []
for dest in apply.TARGETS.values():
    text = (apply.CONFIG / dest).read_text()
    left += [f"{dest}: {m}" for m in re.findall(r"@[a-z_]+(?:\+[0-9a-f]{2}|:[0-9.]+|~)?@", text)
             if not text.startswith("@define-color") and "@define-color" not in m]
from PIL import Image
desk = json.loads((apply.THEME / "colors.json").read_text())["colors"]["desk"]
wall = "#{:02x}{:02x}{:02x}".format(*Image.open(apply.CONFIG / "wall.png").getpixel((0, 0)))
login = json.loads((apply.HOME / ".cache/theme/colors.json").read_text())["colors"]["desk"]
print("\n".join(left))
print(wall, desk, login)
sys.exit(1 if left or wall != desk else 0)
PY
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "apply.py --palette renders the palette, the lock and login screen in its dark look" {
  HOME=$T/home XDG_STATE_HOME=$T/home/.local/state run python3 -I - "$THEME" << 'PY'
import json, sys
sys.path.insert(0, sys.argv[1])
import apply, scheme
apply.gtk_look = lambda name: None
apply.vscode_theme = lambda colors, name: None
apply.reload_programs = lambda *transition: None
apply.login_screen = lambda: None            # no pkexec here
apply.main(["--appearance", "light"])
apply.main(["--palette", "nord"])
c = json.loads((apply.THEME / "colors.json").read_text())
login = json.loads((apply.HOME / ".cache/theme/colors.json").read_text())
night = scheme.describe(scheme.scheme("dark", "nord"))
ok = (c["palette"] == "nord" and c["scheme"] == "light" and c["night"] == night and login["colors"] == night
      and c["colors"] == scheme.describe(scheme.scheme("light", "nord")) and set(c["palettes"]) == set(scheme.PALETTES))
apply.PALETTE.write_text("gone\n")  # a palette that is no more: the plain look
print(c["palette"], c["scheme"], apply.palette())
sys.exit(0 if ok and apply.palette() == "plain" else 1)
PY
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "the palette Wallpaper reads like the plain look for any image, and is the plain look for a grey one" {
  run python3 -I - "$THEME" "$T" << 'PY'
import sys
from pathlib import Path
from PIL import Image
sys.path.insert(0, sys.argv[1])
import scheme, wallpaper
bad = []
images = {"grey": (128, 128, 128), "red": (200, 30, 40), "yellow": (240, 220, 40), "green": (30, 160, 60),
          "blue": (20, 60, 220), "violet": (140, 40, 200), "dark": (20, 10, 40)}
plain = (("fg", "bg", 7), ("fg", "desk", 7), ("dim", "bg", 4.5), ("dim", "bg_alt", 4.5), ("primary", "bg", 4.5),
         ("primary", "bg_alt", 4.5), ("ink", "primary", 4.5), ("red", "bg", 4.5))
for name, color in list(images.items()) + [("missing", None)]:
    path = Path(sys.argv[2]) / f"{name}.png"
    if color:
        image = Image.new("RGB", (64, 36), color)
        image.paste((240, 240, 240), (0, 0, 16, 36))  # some light that is not the image's colour
        image.save(path)
    scheme.PALETTES["wallpaper"] = wallpaper.palette(path)
    for look in ("dark", "light"):
        c = scheme.scheme(look, "wallpaper")
        if set(c) != set(scheme.scheme(look)):
            bad.append(f"{name} {look}: not the plain look's names")
        for fg, bg, least in plain:
            if (ratio := scheme.contrast(c[fg], c[bg])) < least:
                bad.append(f"{name} {look}: {fg} on {bg} {ratio:.2f} < {least}")
        if name in ("grey", "missing") and c != scheme.scheme(look):
            bad.append(f"{name} {look}: not the plain look")
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "apply.py --wallpaper puts the image up with its palette, --palette plain takes it down again" {
  mkdir -p "$T/walls"
  HOME=$T/home XDG_STATE_HOME=$T/home/.local/state WALLPAPER_DIR=$T/walls run python3 -I - "$THEME" "$T/walls" << 'PY'
import json, sys
from pathlib import Path
from PIL import Image
sys.path.insert(0, sys.argv[1])
import apply, scheme
apply.gtk_look = lambda name: None
apply.vscode_theme = lambda colors, name: None
apply.reload_programs = lambda *transition: None
apply.grow_from_pointer = lambda: ()
apply.make_previews = lambda: None
apply.login_screen = lambda: None
walls = Path(sys.argv[2])
for name, color in (("green-hills.jpg", (40, 150, 60)), ("red-dunes.png", (190, 50, 30))):
    Image.new("RGB", (320, 180), color).save(walls / name)
apply.main(["--wallpaper", str(walls / "red-dunes.png")])
c = json.loads((apply.THEME / "colors.json").read_text())
wall = Image.open(apply.CONFIG / "wall.png")
ok = c["palette"] == "wallpaper" and c["wallpaper"] == str(walls / "red-dunes.png") and wall.size == (320, 180)
ok = ok and list(c["palettes"])[:2] == ["plain", "wallpaper"] and c["primary"] != scheme.DARK["accent"]
apply.main(["--wallpaper", "--random"])  # the other one
ok = ok and json.loads((apply.THEME / "colors.json").read_text())["wallpaper"].endswith("green-hills.jpg")
apply.main(["--palette", "plain"])
c = json.loads((apply.THEME / "colors.json").read_text())
ok = ok and c["wallpaper"] == "" and Image.open(apply.CONFIG / "wall.png").size == (16, 16)
print(c["palette"], c["wallpaper"])
sys.exit(0 if ok else 1)
PY
  echo "$output"
  [ "$status" -eq 0 ]
}
