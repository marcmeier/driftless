# shellcheck shell=bash
# Test sandbox: a bare repository as "GitHub" and machines with their own home, all under
# $BATS_TEST_TMPDIR. System tools (pacman, systemctl, notify-send, ...) are stubs; git and the SSH
# signing are real.

SRC=$(cd "$BATS_TEST_DIRNAME/.." && pwd)

setup_sandbox() {
  T=$BATS_TEST_TMPDIR
  mkdir -p "$T/bin" "$T/hw/proc" "$T/hw/sys"
  local c
  for c in notify-send hyprctl pkill walker dbus-run-session; do
    printf '#!/bin/sh\nexit 0\n' > "$T/bin/$c"
  done
  # systemd-run: records what it was asked to start, a --unit=NAME is active from then on
  # shellcheck disable=SC2016 # expanded by the stub
  printf '#!/bin/sh\necho "$*" >> "%s/systemd-run.log"\nfor a; do case $a in --unit=*) mkdir -p "%s/active"; touch "%s/active/${a#--unit=}.service" ;; esac; done\nexit 0\n' "$T" "$T" "$T" > "$T/bin/systemd-run"
  # busctl: NetworkManager's "Metered" is $NM_METERED (1 = yes), else no NetworkManager
  # shellcheck disable=SC2016 # expanded by the stub
  printf '#!/bin/sh\n[ -n "$NM_METERED" ] || exit 1\necho "u $NM_METERED"\n' > "$T/bin/busctl"
  # no user manager in the sandbox (as during bootstrap): every --user call fails, system calls succeed;
  # a unit that systemd-run started counts as active until the test removes $T/active/UNIT; system
  # units named in $SYSTEMCTL_DISABLED are not enabled
  # shellcheck disable=SC2016 # expanded by the stub
  printf '#!/bin/sh\ncase "$*" in *--user*is-active*) for u; do :; done; test -e "%s/active/$u"; exit ;;\n  *--user*) exit 1 ;;\n  *is-enabled*) for u; do :; done; case " $SYSTEMCTL_DISABLED " in *" $u "*) exit 1 ;; esac ;;\nesac\nexit 0\n' "$T" > "$T/bin/systemctl"
  # pkexec: records what it was asked to run
  printf '#!/bin/sh\necho "$*" >> "%s/pkexec.log"\nexit 0\n' "$T" > "$T/bin/pkexec"
  # pacman: installed = $PACMAN_PKGS (repo) and $PACMAN_AUR, all explicitly installed
  cat > "$T/bin/pacman" << 'STUB'
#!/bin/sh
case "$1" in
  -Qq | -Qqe) printf '%s\n' ${PACMAN_PKGS-base git} ${PACMAN_AUR-} ;;
  -Qqm) printf '%s\n' ${PACMAN_AUR-} ;;
esac
exit 0
STUB
  # flatpak: installed apps = $FLATPAK_APPS; install records what it was asked for
  cat > "$T/bin/flatpak" << STUB
#!/bin/sh
case "\$1" in
  list) printf '%s\\n' \${FLATPAK_APPS-} ;;
  install) echo "\$*" >> "$T/flatpak.log" ;;
esac
exit 0
STUB
  cat > "$T/bin/dconf" << 'STUB'
#!/bin/sh
case "$1" in
  dump) cat "$HOME/dconf.live" 2> /dev/null ;;
  load) cat > "$HOME/dconf.live" ;;
esac
STUB
  chmod +x "$T"/bin/*
  export PATH="$T/bin:$PATH"
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  # the same hardware on every machine: an AMD CPU, nothing else
  echo "vendor_id	: AuthenticAMD" > "$T/hw/proc/cpuinfo"
  export HW_PROC=$T/hw/proc HW_SYS=$T/hw/sys HW_VIRT_OVERRIDE=""

  # "GitHub", seeded with the working tree (committed or not, so tests see the current code)
  git init -q --bare -b main "$T/origin.git"
  mkdir "$T/seed"
  (cd "$SRC" && git ls-files -co --exclude-standard -z | xargs -0 cp --parents -a -t "$T/seed")
  [[ ! -f $T/seed/personal/config ]] || sed -i 's#^BUNDLE=.*#BUNDLE=""#' "$T/seed/personal/config"
  rm -f "$T/seed/signers/"*.pub
  git -C "$T/seed" init -q -b main
  git -C "$T/seed" -c user.name=seed -c user.email=seed@example.com add -A
  git -C "$T/seed" -c user.name=seed -c user.email=seed@example.com commit -q -m seed
  git -C "$T/seed" push -q "$T/origin.git" main
}

home() { echo "$T/$1/home"; }
repo() { echo "$T/$1/home/.local/share/driftless"; }

# dl MACHINE ARGS...: the driftless command on MACHINE
dl() {
  local m=$1
  shift
  HOME="$T/$m/home" XDG_STATE_HOME="$T/$m/state" DRIFTLESS_HOST="$m" \
    DRIFTLESS_SIGNING_KEY="$T/$m/home/.ssh/driftless-signing" "$(repo "$m")/driftless" "$@"
}

# machine NAME: a home with the repository cloned, linked and signing set up
machine() {
  local m=$1
  mkdir -p "$(home "$m")/.local/share"
  git clone -q "$T/origin.git" "$(repo "$m")"
  git -C "$(repo "$m")" config user.name "$m"
  git -C "$(repo "$m")" config user.email "$m@example.com"
  dl "$m" link > /dev/null
  dl "$m" signing setup > /dev/null
}

# trust_all: every machine trusts every other one (what "Trust new machine" does)
trust_all() {
  local m other
  for m in "$@"; do
    for other in "$@"; do
      [[ $m == "$other" ]] && continue
      echo "$other namespaces=\"git\" $(awk '{ print $1, $2 }' "$(home "$other")/.ssh/driftless-signing.pub")" >> "$T/$m/state/driftless/allowed_signers"
    done
  done
}

state() { cat "$T/$1/state/driftless/$2" 2> /dev/null; }
result() { state "$1" status | sed -n 's/^result=//p'; }
on_github() { git -C "$T/origin.git" cat-file -e "main:$1" 2> /dev/null; }
github_has() { git -C "$T/origin.git" show "main:$1" | grep -qF -- "$2"; }
# refute CMD...: fails when CMD succeeds (a plain "! CMD" never fails a bats test)
refute() { if "$@"; then return 1; fi; }
