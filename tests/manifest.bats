#!/usr/bin/env bats
# lib/common.sh (manifest, facts) and lib/packages.sh (groups)

setup() {
  load helpers
  setup_sandbox
  mkdir -p "$(home A)/.local/share"
  git clone -q "$T/origin.git" "$(repo A)"
  R=$(repo A)
  cat > "$R/manifest" << 'M'
# comment
link .a
link .b some/where   # trailing comment
link .c hosts/{host}/c
group one
group two if=laptop
group three if=!laptop
group four if=host:A
unit x.service if=cpu-amd
M
  printf '# header\nfoo\naur:bar  # built from the AUR\n' > "$R/packages/one.list"
  printf 'three\n' > "$R/packages/three.list"
  printf 'laptop-only\n' > "$R/packages/two.list"
  printf 'four\n' > "$R/packages/four.list"
  rm -rf "$R/personal"
}

lib() { HOME=$(home A) DRIFTLESS_HOST=A bash -c "DRIFTLESS=$(repo A); source $(repo A)/lib/common.sh; source $(repo A)/lib/packages.sh; $1"; }

@test "manifest: kinds, default sources, {host} and comments" {
  run lib "manifest link"
  [ "${lines[0]}" = ".a" ]
  [ "${lines[1]}" = ".b some/where" ]
  [ "${lines[2]}" = ".c hosts/A/c" ]
}

@test "manifest: if= picks by fact, negation and host" {
  run lib "manifest group"
  [ "$output" = "$(printf 'one\nthree\nfour')" ]
  run lib "manifest unit"
  [ "$output" = x.service ]
}

@test "manifest: a laptop gets its group" {
  mkdir -p "$T/hw/sys/class/power_supply/BAT0"
  run lib "manifest group"
  [[ $output == *two* ]]
  [[ $output != *three* ]]
}

@test "manifest: the personal and host layers add lines" {
  mkdir -p "$(repo A)/personal" "$(repo A)/hosts/A"
  echo "group p" > "$(repo A)/personal/manifest"
  echo "group h" > "$(repo A)/hosts/A/manifest"
  run lib "manifest group"
  [[ $output == *p* && $output == *h* ]]
}

@test "wanted: repo and AUR packages of the machine's groups, comments dropped" {
  run lib wanted
  [ "$output" = "$(printf 'aur bar\nrepo foo\nrepo four\nrepo three')" ]
}

@test "missing and unlisted" {
  PACMAN_PKGS="foo extra" run lib "missing repo"
  [ "$output" = "$(printf 'four\nthree')" ]
  PACMAN_PKGS="foo extra" run lib unlisted
  [ "$output" = extra ]
}

@test "wanted: a group of comments only does not lose the groups after it (set -e)" {
  printf '# nothing yet\n' > "$R/packages/one.list"
  run lib "set -euo pipefail; wanted"
  [ "$output" = "$(printf 'repo four\nrepo three')" ]
}

@test "flatpaks: wanted, missing and unlisted next to the pacman packages" {
  printf 'three\nflatpak:org.example.App\n' > "$R/packages/three.list"
  FLATPAK_APPS="org.example.Tryout" run lib "missing flatpak"
  [ "$output" = org.example.App ]
  FLATPAK_APPS="org.example.App org.example.Tryout" run lib unlisted_flatpak
  [ "$output" = org.example.Tryout ]
  PACMAN_PKGS="foo four three" PACMAN_AUR="bar" run lib unlisted
  [ -z "$output" ]
}

@test "packages install flatpak: system installation, app ids only, no options from a list" {
  printf 'three\nflatpak:org.example.App\nflatpak:--from=https://example.com/x\n' > "$R/packages/three.list"
  run lib "cmd_packages install flatpak"
  [ "$status" -eq 0 ]
  grep -qx "install --system --noninteractive -- flathub org.example.App" "$T/flatpak.log"
  [[ $output == *"not a Flathub app id, skipped: --from="* ]]
}

@test "packages add ID flatpak takes an app that is not installed yet, and only an app id" {
  printf '# apps\n' > "$R/packages/flatpak.list"
  run lib "cmd_packages add org.example.New flatpak"
  [ "$status" -eq 0 ]
  grep -qx "flatpak:org.example.New" "$R/packages/flatpak.list"
  run lib "cmd_packages add no-app-id flatpak"
  [ "$status" -ne 0 ]
  refute grep -q no-app-id "$R/packages/flatpak.list"
}

@test "packages add marks an installed flatpak, remove takes it out again" {
  FLATPAK_APPS="org.example.App" run lib "cmd_packages add org.example.App one"
  [ "$status" -eq 0 ]
  grep -qx "flatpak:org.example.App" "$R/packages/one.list"
  run lib "cmd_packages remove org.example.App"
  refute grep -q org.example.App "$R/packages/one.list"
}

@test "unlisted leaves out the AUR helper and driftless-system" {
  PACMAN_PKGS="foo four three yay-bin driftless-system" PACMAN_AUR="bar" run lib unlisted
  [ -z "$output" ]
}

@test "packages add keeps the header and the order, marks AUR packages" {
  PACMAN_AUR="newaur" run lib "cmd_packages add newaur one"
  [ "$status" -eq 0 ]
  [ "$(head -1 "$(repo A)/packages/one.list")" = "# header" ]
  grep -qx 'aur:newaur' "$(repo A)/packages/one.list"
}

@test "packages add also works for a list without a header (the command runs with errexit)" {
  run dl A packages add extra three
  [ "$status" -eq 0 ]
  # (the pacman stub calls every package foreign, hence the optional aur: prefix)
  grep -qxE '(aur:)?extra' "$(repo A)/packages/three.list"
  grep -qx three "$(repo A)/packages/three.list"
  [ ! -e "$(repo A)/packages/three.list.new" ]
}

@test "packages remove takes a package out of every list" {
  lib "cmd_packages remove foo"
  refute grep -qx foo "$(repo A)/packages/one.list"
}
