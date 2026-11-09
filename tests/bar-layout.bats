#!/usr/bin/env bats
# home/.config/quickshell/scripts/bar_layout.py: which bar a monitor gets under the saved bar size
# (the shell decides the same in services/BarLayout.qml, variantFor).

setup() {
  export HOME=$BATS_TEST_TMPDIR XDG_STATE_HOME=$BATS_TEST_TMPDIR/state
  SCRIPTS=$BATS_TEST_DIRNAME/../home/.config/quickshell/scripts
}

variant() {
  python3 -I -c 'import json, sys
sys.path.insert(0, sys.argv[1])
from bar_layout import variant_for
print(variant_for(json.loads(sys.argv[3]), {"mode": sys.argv[2]}, ["eDP-1"]))' "$SCRIPTS" "$@"
}

@test "automatic: notebook panels and screens under 1280 px get the compact bar" {
  [ "$(variant auto '{"name": "eDP-1", "width": 1920, "height": 1080, "scale": 1.25}')" = compact ]
  [ "$(variant auto '{"name": "HDMI-A-1", "width": 1024, "height": 768, "scale": 1}')" = compact ]
  [ "$(variant auto '{"name": "DP-1", "width": 1366, "height": 768, "scale": 1.25}')" = compact ]
  [ "$(variant auto '{"name": "DP-1", "width": 1280, "height": 720, "scale": 1}')" = spacious ]
  [ "$(variant auto '{"name": "DP-1", "width": 3440, "height": 1440, "scale": 1.25}')" = spacious ]
}

@test "automatic: a turned screen counts its height" {
  [ "$(variant auto '{"name": "DP-2", "width": 1920, "height": 1080, "scale": 1, "transform": 1}')" = compact ]
  [ "$(variant auto '{"name": "DP-2", "width": 1920, "height": 1080, "scale": 1, "transform": 2}')" = spacious ]
}

@test "a fixed size wins over the screen" {
  [ "$(variant spacious '{"name": "HDMI-A-1", "width": 1024, "height": 768, "scale": 1}')" = spacious ]
  [ "$(variant compact '{"name": "DP-1", "width": 3440, "height": 1440, "scale": 1}')" = compact ]
}
