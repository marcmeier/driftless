#!/usr/bin/env bash
# The bar: pending pacman, AUR and flatpak updates as {"repo": N, "aur": N, "flatpak": N} (the pill
# hides itself at 0). Flatpak counts apps and runtimes of both installations.
# each network call with a limit: the bar waits for the answer (services/Feed.qml stops it at 120 s)
repo=$(timeout 60 checkupdates 2> /dev/null | wc -l)
aur=$(timeout 60 yay -Qua 2> /dev/null | wc -l)
flatpak=0
command -v flatpak > /dev/null && flatpak=$(timeout 60 flatpak remote-ls --updates --columns=ref 2> /dev/null | wc -l)
printf '{"repo":%d,"aur":%d,"flatpak":%d}\n' "$repo" "$aur" "$flatpak"
