#!/usr/bin/env bats
# home/.config/hypr/notch/tools.py: the parts that need no desktop (the tools Claude uses by voice)

setup() {
  cd "$BATS_TEST_DIRNAME/.." || exit 1
}

# py CODE: runs CODE with tools.py loaded as the module "t"
py() {
  python3 -I -c '
import importlib.util, sys
spec = importlib.util.spec_from_file_location("t", "home/.config/hypr/notch/tools.py")
t = importlib.util.module_from_spec(spec)
spec.loader.exec_module(t)
'"$1"
}

@test "durations: 10m, 1h30m, 90s, 1:30, a bare number is minutes" {
  run py 'assert [t.duration(x) for x in ("10m", "1h30m", "90s", "1:30", "25")] == [600, 5400, 90, 5400, 1500]'
  [ "$status" -eq 0 ]
}

@test "durations: the spelled-out units min, sek, sec and std work as well" {
  run py 'assert [t.duration(x) for x in ("10min", "5 min", "30sek", "30 sec", "2std", "1h 30m")] == [600, 300, 30, 30, 7200, 5400]'
  [ "$status" -eq 0 ]
}

@test "durations: nonsense is refused" {
  run py '
for bad in ("soon", "10x", "m10", ""):
    try:
        t.duration(bad)
    except ValueError:
        continue
    raise SystemExit(f"accepted: {bad!r}")'
  [ "$status" -eq 0 ]
}

@test "open: web addresses and files, nothing that runs something" {
  mkdir -p "$BATS_TEST_TMPDIR/d"
  : > "$BATS_TEST_TMPDIR/d/note.txt"
  : > "$BATS_TEST_TMPDIR/d/app.desktop"
  : > "$BATS_TEST_TMPDIR/d/run"
  chmod +x "$BATS_TEST_TMPDIR/d/run"
  D=$BATS_TEST_TMPDIR/d run py '
import os
d = os.environ["D"]
for ok in ("https://wiki.archlinux.org/title/PipeWire", "http://example.org/?q=a b".replace(" ", "+"), d, d + "/note.txt"):
    t.open_target(ok)
for bad in ("javascript:alert(1)", "mailto:a@b.c", "ftp://host/file", "data:text/html,x", "https://user:pw@host/",
            "https:///x", d + "/app.desktop", d + "/run", d + "/missing", "-n"):
    try:
        t.open_target(bad)
    except ValueError:
        continue
    raise SystemExit(f"opened: {bad!r}")'
  [ "$status" -eq 0 ]
}

# notch: the command line of `claude -p` (what the voice assistant may use)
notch() {
  HOME=$BATS_TEST_TMPDIR python3 -I -c '
import importlib.util, sys
spec = importlib.util.spec_from_file_location("n", "home/.config/hypr/notch/notch.py")
n = importlib.util.module_from_spec(spec)
spec.loader.exec_module(n)
cmd = n.claude_cmd("what time is it", None)
print(cmd[cmd.index("--tools") + 1])
print(" ".join(cmd[cmd.index("--allowedTools") + 1 :]))
'
}

@test "the voice assistant searches the web but does not fetch pages unless NOTCH_WEBFETCH=on" {
  run notch
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Bash,Read,WebSearch" ]
  [[ ${lines[1]} == *WebSearch* ]]
  [[ ${lines[1]} != *WebFetch* ]]
}

@test "NOTCH_WEBFETCH=on lets it fetch pages too" {
  NOTCH_WEBFETCH=on run notch
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Bash,Read,WebSearch,WebFetch" ]
  [[ ${lines[1]} == *WebFetch* ]]
}
