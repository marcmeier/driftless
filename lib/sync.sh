# shellcheck shell=bash
# driftless sync: keep this machine and GitHub in step. Run by driftless-sync.timer (after login,
# then hourly) and from the sync pill.
#
#   1. commit   edits to files the repository already tracks (the home is linked, so an edit in
#               ~/.config is an edit here). New files are never picked up on their own, and a staged
#               change that looks like a secret stops the run before anything is committed.
#   2. fetch    and check that every incoming commit is signed by a trusted machine (lib/signing.sh)
#   3. update   review mode (default): stop while GitHub has something new, until "sync --now".
#               Otherwise rebase this machine's commits onto GitHub's. A conflict aborts the
#               rebase: nothing changes, the pill names the files.
#   4. apply    links, reloads and packages for what the update changed. The files themselves need
#               no copying: the links already point at the new versions.
#   5. push
#
# Per machine switches, never in the repository ($STATE): mode (review|auto|off), installs (on|off).
# The old versions of every file are in git; nothing needs a backup folder.

# what the sync commits by itself: content. The code (driftless, lib/, install/, system/, tests/)
# changes in a development clone and arrives through GitHub like everything else.
AUTO_PATHS=(home personal hosts packages manifest dconf.ini signers)

# added lines in the staged diff that look like credentials
SECRET_RE='(ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|sk-ant-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|(password|passwd|secret|token)[[:space:]]*[=:][[:space:]]*["'"'"']?[^[:space:]"'"'"'$]{8,})'

git_() { git -C "$DRIFTLESS" "$@"; }
# the calls to GitHub: with a limit (a connection that died while the notebook slept would hang for
# hours) and without the lock's file descriptor 9 (an ssh left in the background would hold the lock)
git_net() { timeout 300 git -C "$DRIFTLESS" "$@" 9>&-; }

write_status() {
  local rc=$?
  ((rc)) && [[ $RESULT == ok || $RESULT == offline ]] && RESULT=failed
  printf 'time=%s\nresult=%s\napplied=%s\n' "$(date +%s)" "$RESULT" "$APPLIED" > "$STATE/status"
  poke_bar
}

# notify_once KEY URGENCY TITLE TEXT: a notification only when TEXT differs from the last one for KEY
notify_once() {
  [[ $4 == "$(cat "$STATE/$1.notified" 2> /dev/null)" ]] && {
    echo "driftless: $3: $4"
    return 0
  }
  notify "$2" "$3" "$4"
  echo "$4" > "$STATE/$1.notified"
}

# commit_local: this machine's edits, as one signed commit "<host>: <what changed>"
commit_local() {
  local files hits what
  heal_all
  # only paths that exist: git refuses the whole add for one that does not (no personal/ in a template)
  local p paths=()
  for p in "${AUTO_PATHS[@]}"; do [[ -e $DRIFTLESS/$p ]] && paths+=("$p"); done
  git_ add -u -- "${paths[@]}"
  git_ diff --cached --quiet && return 0
  hits=$(git_ diff --cached -U0 --no-color | grep '^+[^+]' | grep -Eio "$SECRET_RE" | head -3 || true)
  if [[ -n $hits ]]; then
    git_ reset -q
    RESULT=secret
    notify_once secret critical "Nothing committed" "A change looks like it contains a secret. Check: git -C $DRIFTLESS diff"
    exit 1
  fi
  rm -f "$STATE/secret.notified"
  mapfile -t files < <(git_ diff --cached --name-only | sed -E 's#^home/(\.config/)?##; s#^personal/(home/(\.config/)?)?#personal: #')
  what=$(printf '%s\n' "${files[@]:0:3}" | paste -sd, | sed 's/,/, /g')
  ((${#files[@]} > 3)) && what+=" and $((${#files[@]} - 3)) more"
  git_ commit -q -m "$HOST: $what" -m "Driftless-Host: $HOST"
}

# verify_incoming: end the run while GitHub has a commit no trusted machine signed. A key in signers/
# that is not trusted yet is a new machine asking to join ($STATE/untrusted, sync menu).
verify_incoming() {
  local bad joining
  [[ -e $ALLOWED ]] || {
    rm -f "$STATE/untrusted"
    return 0
  } # signing not set up here yet
  bad=$(signing_check HEAD..origin/main)
  [[ -n $bad ]] || {
    rm -f "$STATE/untrusted"
    return 0
  }
  echo "$bad" > "$STATE/untrusted"
  joining=$(awk '$2 == "U" && $4 != "-" { print $4 }' <<< "$bad" | sort -u | paste -sd' ')
  if [[ -n $joining && -z $(awk '$2 != "U" || $4 == "-"' <<< "$bad") ]]; then
    RESULT=joining
    notify_once untrusted normal "New machine" "$joining: nothing taken over until you trust it (sync icon)"
  else
    RESULT=untrusted
    notify_once untrusted critical "Unsigned changes on GitHub" "$(wc -l <<< "$bad") commit(s) not signed by any of your machines. Nothing taken over (sync icon: Log)"
  fi
  exit 0
}

# update: bring origin/main in. Returns 1 on a conflict (nothing changed then).
update() {
  local ahead behind
  behind=$(git_ rev-list --count HEAD..origin/main)
  ahead=$(git_ rev-list --count origin/main..HEAD)
  ((behind)) || return 0
  if ((ahead == 0)); then
    git_ merge -q --ff-only origin/main
    return
  fi
  # a linear history: this machine's commits go on top of GitHub's, signed again on the way
  git_ rebase -q --autostash origin/main > /dev/null 2>&1 && return 0
  git_ diff --name-only --diff-filter=U > "$STATE/conflict"
  git_ rebase --abort 2> /dev/null || true
  return 1
}

# changed OLD: the files that differ between OLD and HEAD
changed() { if [[ -n $1 ]]; then git_ diff --name-only "$1" HEAD; else git_ ls-files; fi; }

# reload_code OLD: an update that changed driftless itself is applied by the new code, not by the old
# code that is running (a new manifest kind, a new reload rule, a unit to switch off, ...)
reload_code() {
  local lib
  git_ diff --quiet "$1" HEAD -- lib && return 0
  for lib in ${LIBS:-common link packages signing sync setup system verify publish}; do
    # shellcheck source=/dev/null
    source "$DRIFTLESS/lib/$lib.sh"
  done
}

# apply_changes OLD: links, reloads and packages for what came in
apply_changes() {
  local old=$1 files
  files=$(changed "$old")
  [[ -n $files ]] || return 0
  APPLIED=$(grep -c . <<< "$files")
  local reload=()
  grep -qE '^(personal/|hosts/[^/]+/)?manifest$' <<< "$files" && {
    cmd_link > /dev/null || warn "links not complete (driftless link)"
    setup_units
  }
  if grep -q '^dconf.ini$' <<< "$files"; then dconf load / < "$DRIFTLESS/dconf.ini" 2> /dev/null || warn "dconf not loaded"; fi
  grep -qE '^home/\.config/theme/(templates/|apply\.py|scheme\.py|set-wallpaper\.sh)' <<< "$files" && reload+=(theme)
  # a new picture of you (~/.face linked into the repository, e.g. personal/face.png): the bar, the lock
  # and the login screen show it rendered round
  local face root
  root=$(readlink -f "$DRIFTLESS")
  face=$(readlink -f "$HOME/.face" 2> /dev/null) && [[ $face == "$root"/* ]] &&
    grep -qxF "${face#"$root"/}" <<< "$files" && reload+=(avatar)
  grep -qE '^home/\.config/hypr/' <<< "$files" && reload+=(hypr)
  # hypridle reads its file once (lock_cmd, the timeouts)
  grep -qE '^home/\.config/hypr/hypridle\.conf$' <<< "$files" && reload+=(hypridle)
  # who answers org.freedesktop.Notifications: D-Bus learns the new file, the shell takes the name again
  # (it could not while a retired mako still had it)
  grep -qE '^home/\.local/share/dbus-1/' <<< "$files" && reload+=(dbus shell)
  # the polkit agent registers once at the start: a new or changed one needs the shell restarted (after
  # a retired hyprpolkitagent let go of the session)
  grep -qE '^home/\.config/quickshell/polkit/' <<< "$files" && reload+=(shell)
  grep -qE '^home/\.config/systemd/' <<< "$files" && reload+=(systemd)
  # elephant keeps its menus from its start: a changed menu (e.g. a moved script) needs a restart
  grep -qE '^home/\.config/elephant/' <<< "$files" && reload+=(elephant)
  # both need root, one command does both: new system files, and system units new in the manifest
  local unit off=() sysmsg=""
  grep -qE '^system/' <<< "$files" && sysmsg="driftless-system changed"
  if grep -qE '^((personal/|hosts/[^/]+/)?manifest)$' <<< "$files"; then
    while read -r unit; do systemctl is-enabled -q "$unit" 2> /dev/null || off+=("$unit"); done < <(manifest unit)
  fi
  ((${#off[@]} == 0)) || sysmsg+="${sysmsg:+, }not enabled here yet: ${off[*]}"
  [[ -z $sysmsg ]] || notify_once system normal "System setup" "$sysmsg: run  driftless system  in a terminal"
  ((${#reload[@]} == 0)) || reload "${reload[@]}"
  # packages: cmd_sync's install_missing, after this
  return 0
}

# reload WHAT...: the running programs pick up what changed
reload() {
  local r
  # a new look or picture: the configs, the round picture, the desktop's colour, Hyprland, ghostty and
  # the login screen's copy (pkexec, no password for the active session), all in one run
  if [[ " $* " == *" theme "* || " $* " == *" avatar "* ]]; then
    "$HOME/.config/theme/set-wallpaper.sh" --current > /dev/null 2>&1 || warn "theme not rendered"
  fi
  for r in $(printf '%s\n' "$@" | sort -u); do
    case $r in
      systemd) systemctl --user daemon-reload 2> /dev/null || true ;;
      hypr) hyprctl reload > /dev/null 2>&1 || true ;;
      hypridle) systemctl --user try-restart hypridle.service 2> /dev/null || true ;;
      dbus) reload_dbus ;;
      shell) systemctl --user try-restart driftless-shell.service 2> /dev/null || true ;;
      elephant)
        # a menu that does not parse takes all of elephant (and walker's launcher) down: keep the old one
        if ! command -v luac > /dev/null || ! compgen -G "$HOME/.config/elephant/menus/*.lua" > /dev/null ||
          luac -p "$HOME"/.config/elephant/menus/*.lua 2> /dev/null; then
          systemctl --user try-restart elephant.service 2> /dev/null || true
        else
          warn "an elephant menu does not parse, elephant not restarted"
        fi
        ;;
    esac
  done
  return 0
}

# metered: NetworkManager thinks this connection is paid by the byte (a phone's hotspot)
metered() {
  local m
  m=$(busctl get-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager \
    org.freedesktop.NetworkManager Metered 2> /dev/null) || return 1
  [[ $m == "u 1" || $m == "u 3" ]] # NM_METERED_YES, NM_METERED_GUESS_YES
}

# install_missing: repo packages are offered, never installed in the background: a new set (or "sync
# now") brings the shell's review of new packages (bar/PackagesSection.qml, in the sync icon's popup)
# with what each one is and which machine listed it, and only its "Install" asks for the password.
# Flatpaks install without one (as often, not on a metered connection), AUR packages wait for a terminal.
install_missing() {
  local repo aur fp msg="" urgency=normal x offer=0
  if [[ $(cat "$STATE/installs" 2> /dev/null) == off ]]; then
    rm -f "$STATE/install-pending"
    return 0
  fi
  mapfile -t repo < <(missing repo)
  mapfile -t aur < <(missing aur)
  if ((${#repo[@]})) && { ((NOW)) || [[ "${repo[*]}" != "$(cat "$STATE/install-asked" 2> /dev/null)" ]]; }; then
    echo "${repo[*]}" > "$STATE/install-asked"
    if [[ ! -x ${DRIFTLESS_INSTALL_HELPER:-/usr/lib/driftless/install-packages} ]]; then
      msg="driftless-system is not installed here, so listed packages cannot be installed (driftless system)"
      urgency=critical
    else
      offer=1
    fi
  fi
  mapfile -t fp < <(missing flatpak)
  # without flatpak (a repo package that still waits) they wait too. A runtime can be a gigabyte:
  # longer than the sync unit may run, so the download gets a unit of its own, and when it is done
  # one more sync sets the pill right. What did not install waits in the pill, tried again by the
  # next new set or "sync now".
  if systemctl --user is-active -q driftless-flatpak-install.service 2> /dev/null; then
    fp=() # still downloading
  elif ((${#fp[@]})) && command -v flatpak > /dev/null && ! metered &&
    { ((NOW)) || [[ "${fp[*]}" != "$(cat "$STATE/flatpak-asked" 2> /dev/null)" ]]; }; then
    echo "${fp[*]}" > "$STATE/flatpak-asked"
    # shellcheck disable=SC2016 # expanded by the inner bash
    if systemd-run --user --quiet --collect --unit=driftless-flatpak-install -- bash -c \
      '"$1" packages install flatpak; systemctl --user start --no-block driftless-sync.service' _ "$DRIFTLESS/driftless" 2> /dev/null; then
      notify_once flatpak normal "Installing from Flathub" "${fp[*]}"
      fp=()
    fi
  fi
  {
    for x in "${repo[@]}"; do echo "repo $x"; done
    for x in "${fp[@]}"; do echo "flatpak $x"; done
    for x in "${aur[@]}"; do echo "aur $x"; done
  } > "$STATE/install-pending"
  if [[ -z $msg ]] && ((${#repo[@]} + ${#fp[@]} + ${#aur[@]})); then
    msg="Listed but not here: ${repo[*]} ${fp[*]} ${aur[*]} (sync icon)"
  fi
  if ((offer)); then
    offer_review
    # the offer named them: no second notification about the same packages
    echo "$msg" > "$STATE/install.notified"
  elif [[ -n $msg ]]; then
    notify_once install "$urgency" "New packages" "$msg"
  fi
  return 0
}

# offer_review: the shell's review of the packages that wait (scripts/install-review.py). After "sync
# now" you are there: it opens at once; otherwise a notification offers it. Its own unit, as the
# notification waits for its click longer than a sync may run.
offer_review() {
  local review=$HOME/.config/quickshell/scripts/install-review.py
  ((NOW)) && "$review" open > /dev/null 2>&1 && return 0
  systemd-run --user --quiet --collect -- "$review" announce 2> /dev/null ||
    notify normal "New packages" "Listed but not here: $(awk '{ print $2 }' "$STATE/install-pending" | paste -sd' ') (sync icon)"
}

# the optional git bundle (BUNDLE in personal/config): a full copy with history, e.g. for a USB stick
refresh_bundle() {
  [[ -n ${BUNDLE:-} ]] || return 0
  local head
  head=$(git_ rev-parse HEAD)
  [[ -f $BUNDLE && $(cat "$STATE/bundle.head" 2> /dev/null) == "$head" ]] && return 0
  mkdir -p "$(dirname "$BUNDLE")"
  # with HEAD, so "git clone FILE" checks main out
  git_ bundle create -q "$BUNDLE.tmp" HEAD main && mv -f "$BUNDLE.tmp" "$BUNDLE" && echo "$head" > "$STATE/bundle.head"
}

cmd_sync() {
  local adopt=0 old incoming
  NOW=0
  case ${1:-} in --adopt) adopt=1 ;; --now) NOW=1 ;; esac
  mkdir -p "$STATE"
  exec 9> "$STATE/lock"
  flock -n 9 || {
    echo "driftless: a sync is already running"
    return 0
  }
  RESULT=failed APPLIED=0
  trap write_status EXIT
  [[ -e $STATE/now ]] && NOW=1 && rm -f "$STATE/now"
  MODE=$(cat "$STATE/mode" 2> /dev/null || echo review)
  poke_bar
  if [[ $MODE == off ]] && ((! NOW && ! adopt)); then
    RESULT=paused
    return 0
  fi
  load_config
  git_ config user.name > /dev/null || git_ config user.name "driftless $HOST"
  git_ config user.email > /dev/null || git_ config user.email "driftless@$HOST.invalid"

  if ((adopt)); then
    git_net fetch -q origin main
    verify_incoming
    git_ reset -q --hard origin/main
    rm -f "$STATE/conflict"
    cmd_link
    setup_units
    apply_changes ""
    install_missing
  else
    commit_local
    old=$(git_ rev-parse HEAD)
    if git_net fetch -q origin main 2> /dev/null; then
      verify_incoming
      incoming=$(git_ rev-list --count HEAD..origin/main)
      if [[ $MODE == review ]] && ((incoming && ! NOW)); then
        RESULT=held
        notify_once held normal "Changes from your other machines" "$incoming change(s) wait until you take them over (sync icon)"
        return 0
      fi
      if ! update; then
        RESULT=conflict
        notify_once conflict critical "Sync conflict" "This machine and GitHub changed the same lines in: $(paste -sd' ' "$STATE/conflict"). Nothing changed. Merge by hand: cd $DRIFTLESS && git rebase origin/main"
        return 1
      fi
      rm -f "$STATE/conflict" "$STATE/conflict.notified"
      reload_code "$old"
    else
      RESULT=offline
    fi
    apply_changes "$old"
    retire_units
    [[ $RESULT == offline ]] || install_missing
  fi

  [[ $RESULT == offline ]] || RESULT=ok
  if [[ $RESULT == ok ]] && (($(git_ rev-list --count origin/main..HEAD 2> /dev/null || echo 0))); then
    git_net push -q origin HEAD:main || RESULT="push failed"
  fi
  refresh_bundle || warn "bundle not written"
  ((APPLIED)) && [[ -n $old ]] && notify normal "Taken over from GitHub" "$APPLIED file(s)"
  return 0
}
