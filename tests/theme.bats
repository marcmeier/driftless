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
plain = (("fg", "bg", 7), ("fg", "desk", 7), ("dim", "bg", 4.5), ("primary", "bg", 4.5),
         ("primary", "bg_alt", 4.5), ("ink", "primary", 4.5), ("red", "bg", 4.5))
# Solarized and Tokyo Night Day are softer by design: their text at AA, the rest readable
named = (("fg", "bg", 4.5), ("fg", "desk", 3.5), ("dim", "bg", 3), ("primary", "bg", 3),
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
apply.reload_programs = lambda: None
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
