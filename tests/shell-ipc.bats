#!/usr/bin/env bats
# Calls into the running desktop shell (quickshell ipc) have to name its config folder, ~/.config/quickshell:
# with another path the call finds no instance and fails without a word (speak.py once did that).

setup() {
  cd "$BATS_TEST_DIRNAME/.." || exit 1
}

@test "every quickshell ipc call names the shell's config folder" {
  run bash -c 'git ls-files -co --exclude-standard home lib | xargs grep -nE "quickshell.*ipc|\"ipc\", \"-p\"" |
    grep -vE "\.config/quickshell|str\(SHELL\)"'
  [ -z "$output" ]
}

@test "a Python script that sends str(SHELL) defines it as the shell's config folder" {
  for f in $(git ls-files -co --exclude-standard 'home/*.py' | xargs grep -l 'str(SHELL)'); do
    grep -q '^SHELL = Path.home() / ".config/quickshell"' "$f" || {
      echo "$f"
      return 1
    }
  done
}
