#!/usr/bin/env bats
# home/.config/quickshell/scripts/prefs.py: the settings beyond the look and the bar, stored per machine
# and written for Hyprland (input.lua) and hypridle (idle.conf). hyprctl and systemctl are stubs that
# record what they were asked.

setup() {
  T=$BATS_TEST_TMPDIR
  mkdir -p "$T/bin" "$T/home"
  for c in hyprctl systemctl; do
    # shellcheck disable=SC2016 # expanded by the stub
    printf '#!/bin/sh\necho "%s $*" >> "%s/calls.log"\n' "$c" "$T" > "$T/bin/$c"
    chmod +x "$T/bin/$c"
  done
  export HOME=$T/home XDG_STATE_HOME=$T/home/.local/state PATH=$T/bin:$PATH
  PREFS=$BATS_TEST_DIRNAME/../home/.config/quickshell/scripts/prefs.py
}

@test "only what was changed is stored" {
  run python3 -I "$PREFS" set clock24 false
  [ "$status" -eq 0 ]
  run python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1])))' "$XDG_STATE_HOME/driftless-shell/settings.json"
  [ "$output" = "{'clock24': False}" ]
}

@test "input options go to input.lua and to the running Hyprland" {
  python3 -I "$PREFS" set tapToClick false
  python3 -I "$PREFS" set pointerSpeed 0.3
  python3 -I "$PREFS" set followMouse false
  grep -qx 'hl.config({ input = { sensitivity = 0.3, follow_mouse = 0, touchpad = { tap_to_click = false } } })' \
    "$XDG_STATE_HOME/hypr/input.lua"
  grep -qx 'hyprctl eval hl.config({ input = { touchpad = { tap_to_click = false } } })' "$T/calls.log"
}

@test "back to the default: forgotten, and Hyprland reloads its configuration" {
  python3 -I "$PREFS" set tapToClick false
  python3 -I "$PREFS" set tapToClick default
  ! grep -q tap_to_click "$XDG_STATE_HOME/hypr/input.lua"
  grep -qx 'hyprctl reload' "$T/calls.log"
}

@test "idle times go to idle.conf as hypridle variables, never is a week" {
  python3 -I "$PREFS" set saverAfter 120
  python3 -I "$PREFS" set lockAfter 300
  python3 -I "$PREFS" set screenOffAfter 0
  grep -qx '$saver_after = 120' "$HOME/.local/state/hypr/idle.conf"
  grep -qx '$lock_after = 300' "$HOME/.local/state/hypr/idle.conf"
  grep -qx '$screen_off_after = 604800' "$HOME/.local/state/hypr/idle.conf"
  grep -qx 'systemctl --user try-restart hypridle.service' "$T/calls.log"
}

@test "values out of range and unknown keys are refused" {
  for bad in "lockAfter 5" "lockAfter soon" "repeatRate 99" "clock24 yes" "nonsense 1"; do
    # shellcheck disable=SC2086 # two words on purpose
    run python3 -I "$PREFS" set $bad
    [ "$status" -eq 2 ] || { echo "accepted: $bad"; return 1; }
  done
  [ ! -e "$XDG_STATE_HOME/driftless-shell/settings.json" ]
}

@test "the pointer speed is kept between -1 and 1" {
  python3 -I "$PREFS" set pointerSpeed 3
  grep -q 'sensitivity = 1.0' "$XDG_STATE_HOME/hypr/input.lua"
}

@test "night light: off, at night or always, and four warmths" {
  python3 -I "$PREFS" set nightLight sun
  python3 -I "$PREFS" set nightTemp 3500
  for bad in "nightLight dusk" "nightTemp 2000"; do
    # shellcheck disable=SC2086 # two words on purpose
    run python3 -I "$PREFS" set $bad
    [ "$status" -eq 2 ] || { echo "accepted: $bad"; return 1; }
  done
  run python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1])))' "$XDG_STATE_HOME/driftless-shell/settings.json"
  [ "$output" = "{'nightLight': 'sun', 'nightTemp': 3500}" ]
}

@test "the pinned tray apps are a list of ids, empty is none" {
  python3 -I "$PREFS" set trayPinned "nm-applet,Nextcloud"
  run python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["trayPinned"])' "$XDG_STATE_HOME/driftless-shell/settings.json"
  [ "$output" = "['nm-applet', 'Nextcloud']" ]
  python3 -I "$PREFS" set trayPinned ""
  run python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["trayPinned"])' "$XDG_STATE_HOME/driftless-shell/settings.json"
  [ "$output" = "[]" ]
}
