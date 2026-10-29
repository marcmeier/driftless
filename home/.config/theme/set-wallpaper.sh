#!/usr/bin/env bash
# set-wallpaper.sh --current
# Renders the plain look (greys and one accent, a desktop of one colour) into all themed configs,
# reloads the running programs and hands the login screen its files (apply.py --refresh). The name
# stays from the days of image wallpapers, setup, sync and verify call it; --default is the same as
# --current. Dark or light: apply.py --appearance.
set -euo pipefail
case "${1:-}" in
  --current | --default) ;;
  *)
    echo "usage: set-wallpaper.sh --current   (the plain look has no wallpaper images)" >&2
    exit 1
    ;;
esac
exec python3 "$HOME/.config/theme/apply.py" --refresh
