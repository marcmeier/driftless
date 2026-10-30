#!/usr/bin/env python3
"""The bar: state of the driftless sync (driftless sync), next to the package updates, as one JSON object.
Text: icon, plus what waits (incoming GitHub commits, unpushed local ones). Tooltip (Qt rich text): mode, last run,
who wrote to GitHub last, what the incoming commits would change (files, new packages) and the last
change seen from every machine. Only local reads (git refs, ~/.local/state/driftless); the network is
touched by the sync run or by "Check GitHub" in sync-menu.sh. Refreshed by "poke sync"."""

import fcntl
import json
import os
import re
import subprocess
import time
from html import escape

HOME = os.path.expanduser("~")
# the repository: where ~/.local/bin/driftless points (driftless setup links it)
REPO = os.path.dirname(os.path.realpath(HOME + "/.local/bin/driftless"))
STATE = os.environ.get("XDG_STATE_HOME", HOME + "/.local/state") + "/driftless"
# GitHub logo, so it never reads as the "recheck updates" arrows next to it; the state shows as
# colour plus a small mark behind it (pause while off, alert after a failed run)
ICON = "\U000f02a4"  # 󰊤
MARK = {"off": " \U000f03e4", "error": " \U000f0026"}  # 󰏤 󰀦
MODE_NAME = {"auto": "automatic", "review": "review first", "off": "off"}
RESULT_NAME = {
    "ok": "ok",
    "offline": "GitHub not reachable",
    "held": "held back for review",
    "paused": "switched off",
    "conflict": "merge conflict, fix by hand",
    "push failed": "push failed",
    "failed": "failed, see the log",
    "joining": "a new machine waits for your trust",
    "untrusted": "GitHub has commits none of your machines signed",
    "secret": "a change looks like a secret, nothing committed",
}
LOG = "--format=%ct%x1f%an%x1f%s%x1f%(trailers:key=Driftless-Host,valueonly,separator=)"


def git(*args):
    proc = subprocess.run(["git", "-C", REPO, *args], capture_output=True, text=True)
    return proc.stdout.strip() if proc.returncode == 0 else ""


def read(name, default=""):
    try:
        return open(f"{STATE}/{name}").read().strip() or default
    except OSError:
        return default


def ago(timestamp):
    secs = max(int(time.time() - timestamp), 0)
    if secs < 60:
        return "just now"
    if secs < 3600:
        return f"{secs // 60}m ago"
    if secs < 86400:
        return f"{secs // 3600}h ago"
    return f"{secs // 86400}d ago"


def pending():
    """The packages that wait for a review: install-pending without what is here or skipped by now (an
    "Install", a terminal); install-review.py has the same filter."""
    rows = [row.split() for row in read("install-pending").splitlines() if len(row.split()) == 2]
    if not rows:
        return []
    have = set(subprocess.run(["pacman", "-Qq"], capture_output=True, text=True).stdout.split())
    if any(kind == "flatpak" for kind, _ in rows):
        apps = ["flatpak", "list", "--app", "--columns=application"]
        have |= set(subprocess.run(apps, capture_output=True, text=True).stdout.split())
    have |= set(read("skip").split())
    return [name for _, name in rows if name not in have]


def running():
    try:
        with open(STATE + "/lock") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return False
    except BlockingIOError:
        return True
    except OSError:
        return False


def who(host, author):
    """The machine a sync commit came from (its Driftless-Host trailer), else the author."""
    return host.strip() or f"{author} (by hand)"


def incoming_data(incoming):
    """The commits on GitHub this machine has not taken over yet: who, when, what, and in all."""
    commits = []
    for entry in git("log", "-6", LOG, "HEAD..origin/main").splitlines():
        timestamp, author, subject, host = (entry.split("\x1f") + [""])[:4]
        short = re.sub(r"^\S+: ", "", subject) if host.strip() else subject
        commits.append({"by": who(host, author), "ago": ago(int(timestamp)), "subject": short[:70]})
    files = git("diff", "--name-only", "HEAD...origin/main").splitlines()
    areas = sorted({re.sub(r"^(home|personal/home)/(\.config/)?", "", path).split("/")[0] for path in files})
    diff = git("diff", "--no-color", "-U0", "HEAD...origin/main", "--", "packages", "personal/packages")
    new_packages = [
        row[1:].removeprefix("aur:")
        for row in diff.splitlines()
        if row.startswith("+") and not row.startswith("+++") and not row.startswith("+#")
    ]
    return {
        "count": incoming,
        "commits": commits,
        "more": max(incoming - 6, 0),
        "files": len(files),
        "areas": areas[:8] + (["…"] if len(areas) > 8 else []),
        "packages": new_packages[:10] + (["…"] if len(new_packages) > 10 else []),
    }


def last_change_per_machine(has_origin):
    """When each machine last sent a change, newest first."""
    last_seen = {}
    for entry in git("log", "-300", LOG, "origin/main" if has_origin else "HEAD").splitlines():
        timestamp, _, _, host = (entry.split("\x1f") + [""])[:4]
        host = host.strip()
        if host and host not in last_seen:
            last_seen[host] = int(timestamp)
    return [{"host": host, "ago": ago(ts)} for host, ts in sorted(last_seen.items(), key=lambda item: -item[1])]


def main():
    if not os.path.isdir(REPO + "/.git"):
        print('{"text":"","class":"none","tooltip":false}')
        return
    mode = read("mode", "review")
    installs = read("installs", "on")
    status = dict(line.split("=", 1) for line in read("status").splitlines() if "=" in line)
    has_origin = bool(git("rev-parse", "-q", "--verify", "origin/main"))
    incoming = int(git("rev-list", "--count", "HEAD..origin/main") or 0) if has_origin else 0
    outgoing = int(git("rev-list", "--count", "origin/main..HEAD") or 0) if has_origin else 0
    result, busy = status.get("result", ""), running()
    waiting = pending()
    untrusted = [row.split() for row in read("untrusted").splitlines() if len(row.split()) == 4]
    conflict = read("conflict").split() if result == "conflict" else []
    signing = os.path.exists(STATE + "/allowed_signers")
    # each entry: commit, signature status (%G?), key fingerprint, host from signers/ ("-" if none)
    joining = sorted({(host, fp) for _, sig, fp, host in untrusted if sig == "U" and host != "-"})
    foreign = len([e for e in untrusted if e[1] != "U" or e[3] == "-"])

    if busy:
        state = "running"
    elif result in ("conflict", "failed", "push failed", "untrusted", "secret"):
        state = "error"
    elif mode == "off":
        state = "off"
    elif (incoming and mode == "review") or waiting or result == "joining":
        state = "pending"
    else:
        state = "ok"
    # what waits for you, as one number at the icon: packages to look at, changes to take over, machines to trust
    needs = len(waiting) + (incoming if mode != "auto" else 0) + len(joining)

    last = None
    if "time" in status:
        last = {
            "ago": ago(int(status["time"])),
            "result": RESULT_NAME.get(result, result),
            "ok": result in ("ok", "held", "paused", "offline"),
            "applied": int(status.get("applied", "0") or 0),
        }
    writer = git("log", "-1", LOG, "origin/main").split("\x1f") if has_origin else []
    github = ""
    if len(writer) >= 3:
        timestamp, author, _, host = (writer + [""])[:4]
        github = f"{who(host, author)}, {ago(int(timestamp))}"
    details = {
        "mode": mode,
        "modeName": MODE_NAME.get(mode, mode),
        "installs": installs == "on",
        "running": busy,
        "last": last,
        "github": github,
        "incoming": incoming_data(incoming) if incoming else None,
        "outgoing": outgoing,
        "packages": len(waiting),
        "joining": [{"host": host, "fp": fp} for host, fp in joining],
        "foreign": foreign,
        "conflict": conflict,
        "signing": signing,
        "machines": last_change_per_machine(has_origin),
        "repo": REPO,
    }

    # the tooltip: in short, the popup has the rest
    tooltip = [f"<b>driftless sync</b>  ·  {escape(details['modeName'])}"]
    if busy:
        tooltip.append("Running right now …")
    elif last:
        tooltip.append(f"Last run {last['ago']}: {escape(last['result'])}")
    if waiting:
        tooltip.append(f"<font color='#ffb454'>{len(waiting)} listed package(s) to look at</font>")
    if incoming and mode != "auto":
        tooltip.append(f"<font color='#ffb454'>{incoming} change(s) on GitHub wait for you</font>")
    if joining:
        tooltip.append(f"<font color='#ffb454'>New machine: {escape(', '.join(h for h, _ in joining))}</font>")
    if conflict or foreign:
        tooltip.append("<font color='#ff6b6b'>Needs a look: open the details</font>")
    tooltip += ["", "Click: details  ·  Right: sync now  ·  Middle: pause / resume"]

    print(
        json.dumps(
            {
                "text": ICON + MARK.get(state, "") + (f" {needs}" if needs else ""),
                "mark": MARK.get(state, "").strip(),
                "count": needs,
                "class": state,
                "tooltip": "\n".join(tooltip),
                "details": details,
            }
        )
    )


if __name__ == "__main__":
    main()
