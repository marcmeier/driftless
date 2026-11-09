#!/usr/bin/env bash
# The bar: pending pacman, AUR and flatpak updates as {"repo": N, "aur": N, "flatpak": N} (the pill
# hides itself at 0). Flatpak counts apps and runtimes of both installations. When the mirrors do not
# answer (offline), the last count with "stale": the time it is from, instead of a silent 0.
# each network call with a limit: the bar waits for the answer (services/Feed.qml stops it at 200 s)
cache=${XDG_RUNTIME_DIR:-/tmp}/driftless-updates.json
# checkupdates: 0 updates, 2 none, anything else (1, timeout's 124) no answer
list=$(timeout 60 checkupdates 2> /dev/null)
rc=$?
if ((rc != 0 && rc != 2)); then
  if [[ -s $cache ]]; then
    sed "s/}\$/,\"stale\":\"$(date -r "$cache" +%H:%M)\"}/" "$cache"
  else
    echo '{"repo":0,"aur":0,"flatpak":0}'
  fi
  exit 0
fi
repo=$(grep -c . <<< "$list")
aur=$(timeout 60 yay -Qua 2> /dev/null | wc -l)
flatpak=0
command -v flatpak > /dev/null && flatpak=$(timeout 60 flatpak remote-ls --updates --columns=ref 2> /dev/null | wc -l)
printf '{"repo":%d,"aur":%d,"flatpak":%d}\n' "$repo" "$aur" "$flatpak" | tee "$cache"
