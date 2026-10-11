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
