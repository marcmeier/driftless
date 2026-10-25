#!/usr/bin/env bats
# home/.config/theme: the plain look's two palettes, and what apply.py renders from them

THEME=$BATS_TEST_DIRNAME/../home/.config/theme

setup() {
  T=$BATS_TEST_TMPDIR
  mkdir -p "$T/home"
}

@test "every name a template uses exists in both looks" {
  run python3 -I - "$THEME" << 'PY'
import re, sys
from pathlib import Path
theme = Path(sys.argv[1])
sys.path.insert(0, str(theme))
import scheme
strings = {"home", "scheme", "gtk_theme", "qt_style", "shadow_alpha", "terminal_opacity"}
missing = set()
for look in ("dark", "light"):
    names = set(scheme.scheme(look)) | strings
    for template in (theme / "templates").iterdir():
        for name in re.findall(r"@([a-z_]+?)(?:_hex|_rgba)?(?:\+[0-9a-f]{2}|:[0-9.]+|~)?@", template.read_text()):
            if name not in names:
                missing.add(f"{look}: {template.name}: {name}")
print("\n".join(sorted(missing)))
sys.exit(1 if missing else 0)
PY
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "text and accent read on their backgrounds in both looks" {
  run python3 -I - "$THEME" << 'PY'
import sys
sys.path.insert(0, sys.argv[1])
import scheme
bad = []
for look in ("dark", "light"):
    c = scheme.scheme(look)
    for fg, bg, least in (("fg", "bg", 7), ("fg", "desk", 7), ("dim", "bg", 4.5), ("primary", "bg", 4.5),
                          ("primary", "bg_alt", 4.5), ("ink", "primary", 4.5), ("red", "bg", 4.5)):
        ratio = scheme.contrast(c[fg], c[bg])
        if ratio < least:
            bad.append(f"{look}: {fg} on {bg} {ratio:.2f} < {least}")
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
