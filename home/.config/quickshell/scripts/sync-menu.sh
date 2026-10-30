#!/usr/bin/env bash
# Control the driftless sync of THIS machine: the work behind the sync icon's popup (bar/SyncPopup.qml),
# and without an argument the same as a walker menu (settings-menu.sh, a machine without the shell).
# Usage: sync-menu.sh [now|toggle|auto|review|off|installs|packages|install|trust FINGERPRINT|check|diff|log|github]  (no argument: pick in walker)
# The switches live in ~/.local/state/driftless (mode, installs) and never leave the machine.
REPO=$(dirname "$(readlink -f ~/.local/bin/driftless)")
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/driftless
mode=$(cat "$STATE/mode" 2> /dev/null || echo review)
installs=$(cat "$STATE/installs" 2> /dev/null || echo on)
refresh() { "$(dirname "$(readlink -f "$0")")/poke" sync; }
# the switches themselves are driftless's (it pokes the bar)
set_mode() {
  "$REPO/driftless" mode "$1" > /dev/null
  notify-send -a driftless "Their changes" "$2"
}

action=$1
if [ -z "$action" ]; then
  incoming=$(git -C "$REPO" rev-list --count HEAD..origin/main 2> /dev/null || echo 0)
  mark() { [ "$mode" = "$1" ] && echo "●" || echo "○"; }
  items=("󰓦  Sync now$( ((incoming)) && echo " (take over $incoming incoming)")")
  ((incoming)) && items+=("󰈈  Review incoming changes")
  pending=$(grep -c . "$STATE/install-pending" 2> /dev/null)
  ((pending)) && items+=("󰏗  Install missing packages ($pending)")
  # machines that sign incoming commits but are not trusted here yet (lib/signing.sh)
  while read -r fp host; do
    items+=("󰒃  Trust new machine: $host ($fp)")
  done < <(awk '$2 == "U" && $4 != "-" { print $3, $4 }' "$STATE/untrusted" 2> /dev/null | sort -u)
  items+=("$(mark review)  Mode: review GitHub changes first"
  "$(mark auto)  Mode: automatic"
  "$(mark off)  Mode: off"
  "󰏔  Install packages from the lists: $installs → $([ "$installs" = on ] && echo off || echo on)"
  "󰑓  Check GitHub now"
  "󰈙  Show sync log"
  "  Open commits on GitHub")
  choice=$(printf '%s\n' "${items[@]}" | walker --dmenu -p "driftless sync ($mode)") || exit 0
  case $choice in
    *"Sync now"*) action=now ;;
    *Review*) action="diff" ;;
    *"Mode: auto"*) action=auto ;;
    *"Mode: review"*) action=review ;;
    *"Mode: off"*) action=off ;;
    *"Install pack"*) action=installs ;;
    *"Install miss"*) action=packages ;;
    *"Trust new"*)
      action=trust
      fp=${choice##*(}
      fp=${fp%)}
      ;;
    *Check*) action=check ;;
    *log*) action=log ;;
    *GitHub) action=github ;;
    *) exit 0 ;;
  esac
fi

case $action in
  # the service consumes $STATE/now: one full run, whatever the mode (review: takes over what waits)
  now)
    touch "$STATE/now"
    systemctl --user start --no-block driftless-sync.service
    refresh
    ;;
  toggle) if [ "$mode" = off ]; then
    resume=$(cat "$STATE/mode.resume" 2> /dev/null || echo review)
    set_mode "$resume" "$([ "$resume" = auto ] && echo "Automatic: they come in by themselves, every hour" || echo "Ask first: they wait at the sync icon until you take them over")"
  else set_mode off "Paused: this machine does not sync"; fi ;;
  auto) set_mode auto "Automatic: they come in by themselves, every hour" ;;
  review) set_mode review "Ask first: they wait at the sync icon until you take them over" ;;
  off) set_mode off "Paused: this machine does not sync" ;;
  installs)
    new=$([ "$installs" = on ] && echo off || echo on)
    "$REPO/driftless" installs "$new" > /dev/null
    notify-send -a driftless "New packages" "Offer to install them: $new"
    ;;
  # what the sync left waiting: the shell's review of them (bar/SyncPopup.qml), without the
  # shell in a terminal
  packages) "$(dirname "$(readlink -f "$0")")/install-review.py" open || "$0" install ;;
  # in a terminal, with the password; yay shows each AUR package's PKGBUILD diff before building it
  install)
    # shellcheck disable=SC2016 # expanded by the inner bash
    ghostty -e bash -c '
            p=$1; repo=($(awk "\$1 == \"repo\" { print \$2 }" "$p")); aur=($(awk "\$1 == \"aur\" { print \$2 }" "$p"))
            ((${#repo[@]})) && sudo pacman -S --needed -- "${repo[@]}"
            grep -q "^flatpak " "$p" && ~/.local/bin/driftless packages install flatpak
            ((${#aur[@]})) && yay -S --needed -- "${aur[@]}"
            while read -r k x; do case $k in flatpak) flatpak info "$x" ;; *) pacman -Q "$x" ;; esac >/dev/null 2>&1 || echo "$k $x"; done < "$p" > "$p.new"; mv "$p.new" "$p"
            ~/.config/quickshell/scripts/poke sync; read -rp "Done. Enter closes this window. "' _ "$STATE/install-pending"
    ;;
  # compare the fingerprint in a terminal, then one sync takes over what the machine sent
  trust)
    fp=${fp:-$2}
    # shellcheck disable=SC2016 # expanded by the inner bash
    ghostty -e bash -c '"$1/driftless" trust "$2" && touch "$3/now" && systemctl --user start --no-block driftless-sync.service
            read -rp "Enter closes this window. "' _ "$REPO" "$fp" "$STATE"
    ;;
  # fetch only (nothing applied), under the sync's lock so it never races a running sync
  check)
    if flock -n "$STATE/lock" timeout 30 git -C "$REPO" fetch -q origin main; then
      n=$(git -C "$REPO" rev-list --count HEAD..origin/main)
      notify-send -a driftless "GitHub checked" "$n incoming change(s)"
    else notify-send -a driftless "GitHub not checked" "A sync is running or GitHub is not reachable"; fi
    refresh
    ;;
  diff) ghostty -e bash -c "cd '$REPO' && git -c color.ui=always log --reverse --stat -p HEAD..origin/main | less -R" ;;
  log) ghostty -e bash -c "journalctl --user -u driftless-sync.service -n 200 --no-pager | less -R +G" ;;
  github)
    url=$(git -C "$REPO" remote get-url origin | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##')
    xdg-open "$url/commits/main"
    ;;
  *)
    echo "usage: $0 [now|toggle|auto|review|off|installs|packages|install|trust FINGERPRINT|check|diff|log|github]" >&2
    exit 2
    ;;
esac
