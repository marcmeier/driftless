#!/usr/bin/env bash
# set-wallpaper.sh --current
# Renders the plain look (greys and one accent, a desktop of one colour) into all themed configs,
# reloads the running programs and hands the login screen its files. The name stays from the days of
# image wallpapers; --default is the same as --current. Dark or light: apply.py --appearance.
# The login screen follows through pkexec, without a password (polkit allows it for the session).
set -euo pipefail
THEME_DIR="$HOME/.config/theme"
case "${1:-}" in
  --current | --default) ;;
  *)
    echo "usage: set-wallpaper.sh --current   (the plain look has no wallpaper images)" >&2
    exit 1
    ;;
esac

python3 "$THEME_DIR/apply.py" --current

# reload running programs (each step optional); the bar, its popups and the Claude bubble follow
# colors.json and avatar.png by themselves
if awww query > /dev/null 2>&1; then
  awww img --transition-type none "$HOME/.config/wall.png" || true
else
  systemctl --user restart driftless-wallpaper.service 2> /dev/null || true
fi
hyprctl reload > /dev/null 2>&1 || true
pkill -USR2 -x ghostty 2> /dev/null || true

# login screen: its colour, colours and avatar go to /var/lib/driftless/greeter (root, from the
# driftless-system package; polkit lets the active session run it without a password)
update=/usr/lib/driftless/greeter-update
if [[ ! -x $update ]]; then
  echo "Login screen NOT updated: driftless-system is not installed (driftless system)" >&2
else
  pkexec "$update" "$HOME/.cache/theme" && echo "login screen updated" || echo "login screen NOT updated" >&2
fi
