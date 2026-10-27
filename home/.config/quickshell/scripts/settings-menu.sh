#!/usr/bin/env bash
# Desktop settings. The avatar in the bar opens them as a popup of the shell (bar/SettingsPopup.qml),
# which calls the actions below; without an argument ("Desktop settings" in the app launcher) this opens
# that popup, or a walker menu when the shell does not answer.
# Usage: settings-menu.sh [widgets|size|look|monitors|sync|keys]
#        settings-menu.sh monitors-arrange|monitors-reset|display-mode
#        settings-menu.sh avatar               your picture (~/.face) for the bar, the lock and login screen
#        settings-menu.sh appearance dark|light|auto   the look (auto: light from sunrise to sunset)
#        settings-menu.sh palette NAME         the palette (plain, catppuccin, ...: theme/apply.py --palettes)
#        settings-menu.sh avatar-save IMAGE [X Y SIZE]   the square the picture editor chose
# Per machine choices: widget layout, bar size, monitor layout and the look (~/.local/state), and the
# files rendered from the look (not in the repository). None of them travels to your other machines.
# Started from a service (the bar, elephant), a restart of that service would kill the menu halfway (the
# login screen step of a new picture never ran): move to a scope of its own first.
if grep -q '\.service$' /proc/self/cgroup 2> /dev/null; then
  exec systemd-run --user --scope --collect --quiet -- "$0" "$@"
fi
SCRIPTS=$(dirname "$(readlink -f "$0")")
STATE=${XDG_STATE_HOME:-$HOME/.local/state}
pick() { walker --dmenu -p "$1"; }

# your picture: picked here, placed in the shell's editor (avatar/AvatarEditor.qml: drag, zoom), which
# hands the square back to avatar-save; without the shell the middle of the image is taken
avatar() {
  local f
  f=$(zenity --file-selection --title "Your picture" --filename "$HOME/Pictures/" \
    --file-filter "Images | *.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG *.WEBP") || return 0
  [[ $(quickshell ipc -p "$HOME/.config/quickshell" call avatar edit "$f" 2> /dev/null) == true ]] && return 0
  avatar_save "$f"
}

# avatar_save IMAGE [X Y SIZE]: the square at X, Y (fractions of the width and height, the image turned
# upright as its camera says) and SIZE wide (a fraction of the width), else the middle. Written to
# ~/.face, through its link when personal/manifest links it into the repository (then the sync takes
# it to your other machines), and rendered round for the bar, the lock and the login screen.
avatar_save() {
  local face=$HOME/.face
  [[ -L $face ]] && face=$(readlink -f "$face")
  python3 - "$face.new" "$@" << 'PY' || {
import sys
from PIL import Image, ImageOps

out, src, *box = sys.argv[1:]
image = ImageOps.exif_transpose(Image.open(src)).convert("RGB")
if box:
    w, h = image.size
    x, y, size = (float(v) for v in box)
    image = image.crop((round(x * w), round(y * h), round((x + size) * w), round(y * h + size * w)))
    image = image.resize((512, 512), Image.LANCZOS)
else:
    image = ImageOps.fit(image, (512, 512), Image.LANCZOS)
image.save(out, "PNG")
PY
    rm -f "$face.new"
    notify-send -a settings -u critical "Your picture" "Not an image: ${1##*/}"
    return 0
  }
  mv -f "$face.new" "$face"
  if "$HOME/.config/theme/set-wallpaper.sh" --current > "$STATE/set-wallpaper.log" 2>&1; then
    notify-send -a settings "Your picture" "Done: the bar, the lock and the login screen show it"
  else notify-send -a settings -u critical "Your picture" "Failed, see $STATE/set-wallpaper.log"; fi
}

# a new palette is also the login screen's (its dark look): hand it the files (polkit, no password)
login_screen() {
  [[ -x /usr/lib/driftless/greeter-update ]] || return 0
  pkexec /usr/lib/driftless/greeter-update "$HOME/.cache/theme" >> "$STATE/set-wallpaper.log" 2>&1 || true
}

# the look in walker, when the shell does not answer: dark, light or auto, then the palettes
look() {
  local choice key label
  local -a entries=("Dark" "Light" "Auto (light from sunrise to sunset)")
  local -A palettes=()
  while IFS=$'\t' read -r key label; do
    entries+=("Palette: $label")
    palettes["Palette: $label"]=$key
  done < <(python3 "$HOME/.config/theme/apply.py" --palettes)
  choice=$(printf '%s\n' "${entries[@]}" | pick "Appearance") || return 0
  case $choice in
    Dark) set -- --appearance dark ;;
    Light) set -- --appearance light ;;
    Auto*) set -- --appearance auto ;;
    Palette:*)
      [[ -n ${palettes[$choice]:-} ]] || return 0
      set -- --palette "${palettes[$choice]}"
      ;;
    *) return 0 ;;
  esac
  mkdir -p "$STATE"
  python3 "$HOME/.config/theme/apply.py" "$@" > "$STATE/set-wallpaper.log" 2>&1 ||
    notify-send -a settings -u critical "Appearance" "Failed, see $STATE/set-wallpaper.log"
  [[ $1 == --palette ]] && login_screen
  return 0
}

# nwg-displays writes monitors.lua/workspaces.lua next to the paths it gets; hyprland.lua loads them
# from ~/.local/state/hypr. Hyprland does not watch those files: reload whenever nwg-displays saves
# (also when its "keep these settings?" countdown restores the old ones).
arrange() {
  local dir=$STATE/hypr seen now
  mkdir -p "$dir"
  stamp() { stat -c %Y "$dir/monitors.lua" "$dir/workspaces.lua" 2> /dev/null | paste -sd' '; }
  seen=$(stamp)
  nwg-displays -m "$dir/monitors.conf" -w "$dir/workspaces.conf" &
  local pid=$!
  while kill -0 "$pid" 2> /dev/null; do
    sleep 0.5
    now=$(stamp)
    [[ $now != "$seen" ]] && seen=$now && hyprctl reload > /dev/null
  done
  now=$(stamp)
  [[ $now != "$seen" ]] && hyprctl reload > /dev/null
}

monitors() {
  local items=("󰍹  Arrange monitors (position, resolution, scale)")
  # laptop panel + external monitor: quick modes like Win+P (display-mode.sh)
  hyprctl -j monitors all | grep -q '"name": "eDP-' && items+=("󰍺  Display mode (extend, mirror, one screen)")
  [[ -f $STATE/hypr/monitors.lua ]] && items+=("󰑓  Reset to the automatic layout")
  local choice
  choice=$(printf '%s\n' "${items[@]}" | pick "Monitors") || return 0
  case $choice in
    *Arrange*) arrange ;;
    *"Display mode"*) "$HOME/.config/hypr/display-mode.sh" ;;
    *Reset*) exec "$0" monitors-reset ;;
  esac
}

# bar size: automatic (compact bar on the narrow outputs, bar_layout.py) or one size on every monitor;
# the bar follows at once
size() {
  local current choice mode items=() label
  current=$("$SCRIPTS/bar_layout.py" --get-mode)
  for mode in auto spacious compact; do
    case $mode in
      auto) label="󰁨  Automatic (compact on notebook panels)" ;;
      spacious) label="󰍹  Always full size" ;;
      compact) label="󰍺  Always compact" ;;
    esac
    [[ $mode == "$current" ]] && label+="  (current)"
    items+=("$label")
  done
  choice=$(printf '%s\n' "${items[@]}" | pick "Bar size") || return 0
  case $choice in
    *Automatic*) mode=auto ;;
    *full*) mode=spacious ;;
    *compact) mode=compact ;;
    *) return 0 ;;
  esac
  [[ $mode == "$current" ]] && return 0
  "$SCRIPTS/bar_layout.py" --mode "$mode"
}

action=$1
# no argument: the shell's popup on the focused screen, else the walker menu
if [[ -z $action ]] && [[ $(quickshell ipc -p "$HOME/.config/quickshell" call bar popup settings 2> /dev/null) == true ]]; then
  exit 0
fi
if [[ -z $action ]]; then
  choice=$(printf '%s\n' "󰕮  Bar widgets (show, hide, move)" "󰯌  Bar size (full, compact, automatic)" "󰔎  Appearance (dark, light, auto)" "󰍹  Monitors" "󰓦  Sync with your other machines" "󰌌  Keybindings (search)" |
    pick "Settings") || exit 0
  case $choice in
    *widgets*) action=widgets ;;
    *size*) action=size ;;
    *Appearance*) action=look ;;
    *Monitors) action=monitors ;;
    *sync) action=sync ;;
    *Keybindings*) action=keys ;;
    *) exit 0 ;;
  esac
fi
case $action in
  widgets) exec "$SCRIPTS/widgets.py" ;;
  size) size ;;
  look) look ;;
  monitors) monitors ;;
  monitors-arrange) arrange ;;
  monitors-reset)
    rm -f "$STATE"/hypr/{monitors,workspaces}.{conf,lua}
    hyprctl reload > /dev/null
    notify-send -a settings "Monitors" "Automatic layout again"
    ;;
  display-mode) exec "$HOME/.config/hypr/display-mode.sh" ;;
  avatar)
    mkdir -p "$STATE"
    avatar
    ;;
  appearance)
    mkdir -p "$STATE"
    [[ ${2:-} =~ ^(dark|light|auto)$ ]] || exit 2
    python3 "$HOME/.config/theme/apply.py" --appearance "$2" > "$STATE/set-wallpaper.log" 2>&1 ||
      notify-send -a settings -u critical "Appearance" "Failed, see $STATE/set-wallpaper.log"
    ;;
  palette)
    mkdir -p "$STATE"
    [[ ${2:-} =~ ^[a-z-]+$ ]] || exit 2
    if python3 "$HOME/.config/theme/apply.py" --palette "$2" > "$STATE/set-wallpaper.log" 2>&1; then
      login_screen
    else
      notify-send -a settings -u critical "Palette" "Failed, see $STATE/set-wallpaper.log"
    fi
    ;;
  avatar-save)
    mkdir -p "$STATE"
    [[ -f ${2:-} ]] || exit 2
    avatar_save "${@:2}"
    ;;
  sync) exec "$SCRIPTS/sync-menu.sh" ;;
  keys) exec "$HOME/.config/hypr/keybinds.py" ;;
  *)
    echo "usage: $0 [widgets|size|look|monitors|sync|keys]" >&2
    exit 2
    ;;
esac
