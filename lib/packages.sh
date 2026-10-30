# shellcheck shell=bash
# Package groups: packages/NAME.list (or personal/packages/NAME.list), one package per line,
# "aur:" in front of AUR packages, "flatpak:" in front of a Flathub app id. The manifest's "group"
# lines pick the groups for this machine.
#
# The lists are written by hand (or with "driftless packages add"), never recorded from what a
# machine happens to have: a package you try out on one machine stays there. What is installed
# but in no list is shown by "driftless packages", so you decide: add it, or remove it.

group_file() {
  local f
  for f in "$DRIFTLESS/packages/$1.list" "$DRIFTLESS/personal/packages/$1.list"; do
    [[ -r $f ]] && {
      echo "$f"
      return 0
    }
  done
  return 1
}

# Flathub apps go into the system installation, where Arch's flatpak package puts the flathub remote:
# one copy of each runtime for every user, and none of it in the home (its snapshots, its backups).
# Flatpak's polkit rule lets a wheel user of the active local session install without a password.
FLATHUB_URL=https://dl.flathub.org/repo/flathub.flatpakrepo

# wanted: "repo NAME" / "aur NAME" / "flatpak ID" for every package this machine should have, sorted
wanted() {
  local group file
  while read -r group; do
    file=$(group_file "$group") || {
      warn "manifest names group $group, but there is no packages/$group.list"
      continue
    }
    # a list of comments only (an empty group) has no lines for grep: not an error under set -e
    { grep -v '^\s*\(#\|$\)' "$file" || true; } | sed -E 's/\s+#.*//; s/^aur:(.*)/aur \1/; t; s/^flatpak:(.*)/flatpak \1/; t; s/^/repo /'
  done < <(manifest group) | sort -u
}

wanted_names() { wanted | awk '{ print $2 }' | sort -u; }

# flatpak_apps: the installed flatpak apps (system and user installation), nothing without flatpak
flatpak_apps() {
  command -v flatpak > /dev/null || return 0
  flatpak list --app --columns=application 2> /dev/null | sort -u
}

# skipped: the packages a list names that this machine does without ("Not on this machine" in the
# shell's review of new packages, or driftless packages skip NAME). Per machine, never in the repository.
skipped() { grep -v '^\s*$' "$STATE/skip" 2> /dev/null | sort -u || true; }

# missing KIND: wanted packages of KIND (repo|aur|flatpak) that are not installed nor skipped here
missing() {
  comm -23 <(wanted | awk -v k="$1" '$1 == k { print $2 }' | sort -u) \
    <({
      if [[ $1 == flatpak ]]; then flatpak_apps; else pacman -Qq; fi
      skipped
    } | sort -u)
}

# unlisted: explicitly installed packages that no group of this machine lists
unlisted() {
  comm -23 <(pacman -Qqe | sort -u) <({
    wanted_names
    # the AUR helper and this kit's own package are never in a list
    printf '%s\n' yay yay-debug yay-bin yay-bin-debug driftless-system
  } | sort -u)
}

# flatpak_id ID: a Flathub app id (reverse DNS), never something flatpak would read as an option
flatpak_id() { [[ $1 =~ ^[A-Za-z_][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+)+$ ]]; }

# unlisted_flatpak: installed flatpak apps that no group of this machine lists
unlisted_flatpak() {
  comm -23 <(flatpak_apps) <(wanted | awk '$1 == "flatpak" { print $2 }' | sort -u)
}

# install_repo PKG...: through the root helper and a password dialog (pkexec), or plain sudo in a
# terminal. The helper takes package names only and runs nothing but pacman -S --needed.
install_repo() {
  (($#)) || return 0
  if [[ -t 0 ]]; then
    sudo pacman -S --needed -- "$@"
  elif [[ -x /usr/lib/driftless/install-packages ]]; then
    pkexec /usr/lib/driftless/install-packages "$@"
  else
    die "no terminal and no driftless-system yet: install them with  sudo pacman -S --needed $*"
  fi
}

# install_aur PKG...: yay, which shows every PKGBUILD diff before it builds. Needs a terminal: an AUR
# package is a script from the internet and is never built unattended.
install_aur() {
  (($#)) || return 0
  [[ -t 0 ]] || die "AUR packages are only built in a terminal: driftless packages install"
  command -v yay > /dev/null || die "yay is missing (install/bootstrap.sh installs it)"
  yay -S --needed --answerdiff All --answerclean None --answeredit None -- "$@"
}

# install_flatpak ID...: from Flathub into the system installation. Like a repo package, an app only
# comes from a list, and the lists only change through commits your machines signed. A terminal sees
# the progress, the sync (through its own unit, lib/sync.sh) gets the short form.
install_flatpak() {
  local id ids=() how=--noninteractive
  for id in "$@"; do
    if flatpak_id "$id"; then ids+=("$id"); else warn "not a Flathub app id, skipped: $id"; fi
  done
  ((${#ids[@]})) || return 0
  command -v flatpak > /dev/null || die "flatpak is missing (packages/apps.list has it: driftless packages install repo)"
  [[ -t 1 ]] && how=--assumeyes
  flatpak remote-add --system --if-not-exists flathub "$FLATHUB_URL"
  flatpak install --system "$how" -- flathub "${ids[@]}"
}

cmd_packages() {
  local sub=${1:-status}
  shift || true
  case $sub in
    status)
      local repo aur fp extra fpextra
      repo=$(missing repo | paste -sd' ')
      aur=$(missing aur | paste -sd' ')
      fp=$(missing flatpak | paste -sd' ')
      extra=$(unlisted | paste -sd' ')
      fpextra=$(unlisted_flatpak | paste -sd' ')
      echo "groups here: $(manifest group | paste -sd' ')"
      [[ -z $repo ]] && echo "repo packages: all installed" || echo "missing (repo): $repo"
      [[ -z $aur ]] && echo "AUR packages: all installed" || echo "missing (AUR): $aur"
      [[ -z $fp ]] && echo "flatpaks: all installed" || echo "missing (flatpak): $fp"
      [[ -z $(skipped) ]] || echo "skipped on this machine: $(skipped | paste -sd' ')
  suggest one again:    driftless packages unskip NAME"
      [[ -z $extra ]] || echo "installed, but in no list: $extra
  keep one everywhere:  driftless packages add NAME [GROUP]
  or remove it here:    sudo pacman -Rns NAME"
      [[ -z $fpextra ]] || echo "flatpaks installed, but in no list: $fpextra
  keep one everywhere:  driftless packages add ID flatpak
  or remove it here:    flatpak uninstall ID"
      ;;
    install)
      # "repo", "flatpak" or "aur" alone: e.g. the repo part over SSH, the AUR part later in a terminal
      local only=${1:-}
      mapfile -t r < <(missing repo)
      mapfile -t f < <(missing flatpak)
      mapfile -t a < <(missing aur)
      if [[ -z $only || $only == repo ]]; then install_repo "${r[@]}"; fi
      if [[ -z $only || $only == flatpak ]]; then install_flatpak "${f[@]}"; fi
      if [[ -z $only || $only == aur ]]; then install_aur "${a[@]}"; fi
      ;;
    add)
      local name=${1:?usage: driftless packages add NAME [GROUP]} group=${2:-} file entry
      if [[ -z $group ]]; then
        group=$(find "$DRIFTLESS/packages" -name '*.list' ! -name 'hw-*' -printf '%f\n' | sed 's/\.list$//' | sort |
          walker --dmenu -p "Group for $name" 2> /dev/null) || true
        [[ -n $group ]] || die "no group given"
      fi
      file=$(group_file "$group") || die "no group $group"
      entry=$name
      pacman -Qqm "$name" > /dev/null 2>&1 && entry="aur:$name"
      # an installed flatpak, or any app id for the flatpak group (one you have not installed yet)
      if [[ $group == flatpak ]] || grep -qxF "$name" < <(flatpak_apps); then
        flatpak_id "$name" || die "not a Flathub app id: $name"
        entry="flatpak:$name"
      fi
      grep -qxF "$entry" "$file" && {
        echo "$name is already in $group"
        return 0
      }
      {
        grep '^#' "$file" || true
        {
          grep -v '^#' "$file" || true
          echo "$entry"
        } | sort -u
      } > "$file.new"
      mv "$file.new" "$file"
      echo "added $entry to $group (the next sync takes it to your other machines)"
      ;;
    # skip / unskip NAME...: leave listed packages out on this machine, or take them back
    skip | unskip)
      (($#)) || die "usage: driftless packages $sub NAME..."
      mkdir -p "$STATE"
      if [[ $sub == skip ]]; then
        {
          skipped
          printf '%s\n' "$@"
        } | sort -u > "$STATE/skip.new"
      else
        skipped | grep -vxF -f <(printf '%s\n' "$@") > "$STATE/skip.new" || true
      fi
      mv "$STATE/skip.new" "$STATE/skip"
      echo "skipped on this machine: $(skipped | paste -sd' ')"
      ;;
    remove)
      local name=${1:?usage: driftless packages remove NAME} file
      for file in "$DRIFTLESS"/packages/*.list "$DRIFTLESS"/personal/packages/*.list; do
        [[ -r $file ]] && sed -i -E "/^(aur:|flatpak:)?$(printf '%s' "$name" | sed 's/[.+]/\\&/g')\$/d" "$file"
      done
      echo "removed $name from the lists. The other machines keep it until you remove it there."
      ;;
    *) die "usage: driftless packages [status|install [repo|flatpak|aur]|add NAME [GROUP]|remove NAME|skip NAME...|unskip NAME...]" ;;
  esac
}
