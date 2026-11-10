#!/usr/bin/env bats
# lib/publish.sh: the public template leaves the personal layer out

setup() {
  load helpers
  setup_sandbox
  mkdir -p "$(home A)/.local/share"
  git clone -q "$T/origin.git" "$(repo A)"
  git init -q -b main "$T/public"
}

@test "personal/, signers/ and real hosts stay out, hosts/example goes in" {
  run dl A publish "$T/public"
  [ "$status" -eq 0 ]
  [ -f "$T/public/driftless" ]
  [ -f "$T/public/hosts/example/hyprland.lua" ]
  [ ! -e "$T/public/personal" ]
  [ "$(ls "$T/public/hosts")" = example ]
  [ ! -e "$T/public/signers" ]
}

@test "a personal term in a published file aborts the export" {
  [[ -s $(repo A)/personal/forbidden ]] || skip "no personal layer (public template)"
  # one of the personal terms, taken from the list so this file stays publishable itself
  term=$(grep -v '^\s*\(#\|$\)' "$(repo A)/personal/forbidden" | grep -m1 '^[a-z-]*$')
  echo "# $term was here" >> "$(repo A)/home/.bashrc"
  git -C "$(repo A)" -c user.name=t -c user.email=t@t commit -qam leak
  run dl A publish "$T/public"
  [ "$status" -ne 0 ]
  [[ $output == *"personal terms"* ]]
  [ -z "$(git -C "$T/public" log --oneline 2> /dev/null)" ]
}

@test "a forbidden list without terms still exports, and says nothing was checked" {
  mkdir -p "$(repo A)/personal"
  printf '# no terms yet\n' > "$(repo A)/personal/forbidden"
  git -C "$(repo A)" add -A
  git -C "$(repo A)" -c user.name=t -c user.email=t@t commit -qm "no terms"
  run dl A publish "$T/public"
  [ "$status" -eq 0 ]
  [[ $output == *"not checked for personal words"* ]]
  [ -f "$T/public/driftless" ]
}

@test "the public template itself contains no personal term" {
  [[ -s $(repo A)/personal/forbidden ]] || skip "no personal layer (public template)"
  dl A publish "$T/public"
  run grep -rnIE -f <(grep -v '^\s*\(#\|$\)' "$(repo A)/personal/forbidden") "$T/public" --exclude-dir=.git
  [ "$status" -eq 1 ]
}

@test "--push signs the commit and --tag a tag; release-signers lists the keys without host names" {
  dl A signing setup > /dev/null
  git init -q --bare -b main "$T/public.git"
  git clone -q "$T/public.git" "$T/pub" 2> /dev/null
  git -C "$T/pub" config user.name t
  git -C "$T/pub" config user.email t@t
  run dl A publish "$T/pub" --push --tag v9.9.9
  [ "$status" -eq 0 ]
  [[ $output == *"signed tag v9.9.9"* ]]
  signers=$T/pub/docs/release-signers
  grep -q "^driftless-release namespaces=\"git\" ssh-ed25519 " "$signers"
  ! grep -q " A$\|driftless A" "$signers"
  git -C "$T/pub" -c gpg.ssh.allowedSignersFile="$signers" verify-commit HEAD
  git -C "$T/pub" -c gpg.ssh.allowedSignersFile="$signers" verify-tag v9.9.9
  [ "$(git -C "$T/public.git" rev-parse v9.9.9^{commit})" = "$(git -C "$T/pub" rev-parse HEAD)" ]
}

@test "a tag needs --push, and an existing tag is not replaced" {
  run dl A publish "$T/public" --tag v9.9.9
  [ "$status" -ne 0 ]
  [[ $output == *"--tag needs --push"* ]]
  dl A signing setup > /dev/null
  git -C "$T/public" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git -C "$T/public" tag v9.9.9
  run dl A publish "$T/public" --push --tag v9.9.9
  [ "$status" -ne 0 ]
  [[ $output == *"already has a tag v9.9.9"* ]]
}
