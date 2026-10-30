#!/usr/bin/env python3
"""The review of new packages (bar/PackagesSection.qml, in the sync icon's popup): what the sync found
in the lists but not on this machine (~/.local/state/driftless/install-pending), with what each package
is, what comes along, how big it is, and which machine put it in which list. Nothing is installed
without its "Install".

  install-review.py            the review's data as JSON
  install-review.py open       open the sync icon's popup, the packages unfolded (IPC)
  install-review.py announce   a notification that opens it (the sync, lib/sync.sh)
  install-review.py install    install what waits: repo packages through the password dialog, flatpaks
  install-review.py skip|unskip NAME   leave a package out on this machine, or take it back"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

from sync import LOG, REPO, STATE, ago, git, read, who

SHELL = Path.home() / ".config/quickshell"
DRIFTLESS = os.path.join(REPO, "driftless")
HELPER = "/usr/lib/driftless/install-packages"
LISTS = ("packages", "personal/packages")
ENV = dict(os.environ, LC_ALL="C")


def run(*args):
    proc = subprocess.run(args, capture_output=True, text=True, env=ENV)
    return proc.stdout if proc.returncode == 0 else ""


def size(n):
    for unit in ("B", "KiB", "MiB"):
        if n < 1024:
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} GiB"


def bytes_of(text):
    """'12.34 MiB' (pacman -Si) as bytes."""
    m = re.match(r"([\d.]+)\s*(B|KiB|MiB|GiB)", text or "")
    return int(float(m.group(1)) * 1024 ** ("B", "KiB", "MiB", "GiB").index(m.group(2))) if m else 0


def pending():
    """What waits, as [(kind, name)], without what is installed or skipped by now."""
    rows = [tuple(r.split()) for r in read("install-pending").splitlines() if len(r.split()) == 2]
    skip = set(read("skip").split())
    have = set(run("pacman", "-Qq").split())
    if any(kind == "flatpak" for kind, _ in rows):
        have |= set(run("flatpak", "list", "--app", "--columns=application").split())
    return [(kind, name) for kind, name in rows if name not in skip and name not in have]


def listed(name):
    """Where a package is listed: (kind, list file, its comment) from the first list line naming it."""
    for folder in LISTS:
        path = os.path.join(REPO, folder)
        for file in sorted(os.listdir(path)) if os.path.isdir(path) else []:
            if not file.endswith(".list"):
                continue
            for line in open(os.path.join(path, file)):
                m = re.match(r"^(aur:|flatpak:)?(\S+)\s*(?:#\s*(.*))?$", line.strip())
                if m and not line.startswith("#") and m.group(2) == name:
                    kind = (m.group(1) or "repo:").rstrip(":")
                    return kind, f"{folder}/{file}", (m.group(3) or "").strip()
    return "", "", ""


def origin(name, file):
    """Who listed it: the machine (or author), when and the commit's subject."""
    if not file:
        return {}
    pattern = rf"^(aur:|flatpak:)?{re.escape(name)}([[:space:]]|$)"
    entry = git("log", "-1", LOG, "-G", pattern, "--", file)
    if not entry:
        return {}
    timestamp, author, subject, host = (entry.split("\x1f") + [""])[:4]
    # a sync commit's subject starts with its machine, which "by" names already
    subject = re.sub(r"^\S+: ", "", subject) if host.strip() else subject
    return {"by": who(host, author), "when": ago(int(timestamp)), "subject": subject}


def repo_info(names):
    """pacman -Si for NAMES: {name: {description, download, installed}}."""
    info, cur = {}, {}
    for line in run("pacman", "-Si", "--", *names).splitlines() + [""]:
        if not line.strip():
            if "Name" in cur:
                info[cur["Name"]] = {
                    "description": cur.get("Description", ""),
                    "download": bytes_of(cur.get("Download Size")),
                    "installed": bytes_of(cur.get("Installed Size")),
                }
            cur = {}
        elif " : " in line:
            key, value = line.split(" : ", 1)
            cur[key.strip()] = value.strip()
    return info


def data():
    waiting = pending()
    repo = [n for k, n in waiting if k == "repo"]
    # everything pacman would install, dependencies included
    total = run("pacman", "-Sp", "--needed", "--print-format", "%n", "--", *repo).split() if repo else []
    deps = [n for n in total if n not in repo]
    info = repo_info(repo + deps) if repo else {}
    packages = []
    for kind, name in waiting:
        _, file, why = listed(name)
        entry = {"kind": kind, "name": name, "list": file, "why": why, **origin(name, file)}
        if kind == "repo":
            # what this one brings along by itself (another one of the set may share it)
            own = run("pacman", "-Sp", "--needed", "--print-format", "%n", "--", name).split()
            entry["description"] = info.get(name, {}).get("description", "")
            entry["size"] = size(info[name]["installed"]) if name in info else ""
            entry["deps"] = len([n for n in own if n != name])
            entry["download"] = size(sum(info.get(n, {}).get("download", 0) for n in own))
        packages.append(entry)
    download = sum(info.get(n, {}).get("download", 0) for n in total)
    disk = sum(info.get(n, {}).get("installed", 0) for n in total)
    return {
        "packages": packages,
        "deps": deps,
        "download": size(download) if download else "",
        "disk": size(disk) if disk else "",
        "skipped": sorted(set(read("skip").split())),
        "helper": os.access(HELPER, os.X_OK),
    }


def notify(title, text, urgency="normal", *actions):
    # no icon of its own: the shell shows the driftless mark for the app "driftless", so the title
    # says what it is about
    args = ["notify-send", "-a", "driftless", "-u", urgency]
    for action in actions:
        args += ["-A", action]
    proc = subprocess.run([*args, title, text], capture_output=True, text=True)
    return proc.stdout.strip()


def poke():
    subprocess.run([str(SHELL / "scripts/poke"), "sync"])


def open_card():
    proc = subprocess.run(
        ["quickshell", "ipc", "-p", str(SHELL), "call", "bar", "popup", "sync"], capture_output=True, text=True
    )
    # false: no bar with the sync icon (the shell not running, the icon left out of the bar)
    return proc.returncode == 0 and proc.stdout.strip() == "true"


def announce():
    names = [n for _, n in pending()]
    if not names:
        return
    shown = ", ".join(names[:6]) + (f" and {len(names) - 6} more" if len(names) > 6 else "")
    text = (
        f"Your other machines use {shown}. Have a look at what {'it is' if len(names) == 1 else 'they are'}"
        " before anything is installed here."
    )
    title = "1 new package" if len(names) == 1 else f"{len(names)} new packages"
    if notify(title, text, "normal", "default=Review", "review=Review …") in ("default", "review"):
        open_card()


def install():
    waiting = pending()
    repo = [n for k, n in waiting if k == "repo"]
    flatpaks = [n for k, n in waiting if k == "flatpak"]
    if not repo + flatpaks:
        # installed or skipped since the card opened (a sync, a terminal)
        notify("Nothing to install", "These packages are already here.")
        poke()
        return
    rc = 0
    if repo:
        rc = subprocess.run(["pkexec", HELPER, *repo]).returncode
    # 126: the password dialog was cancelled, 127: no polkit agent
    if flatpaks and rc not in (126, 127):
        subprocess.run([DRIFTLESS, "packages", "install", "flatpak"], stdin=subprocess.DEVNULL)
    left = pending()
    done = [n for k, n in waiting if (k, n) not in left and k != "aur"]
    # what still waits stays in the pill; AUR packages wait for the terminal anyway
    with open(os.path.join(STATE, "install-pending.new"), "w") as f:
        f.writelines(f"{kind} {name}\n" for kind, name in left)
    os.replace(os.path.join(STATE, "install-pending.new"), os.path.join(STATE, "install-pending"))
    failed = [n for k, n in left if k != "aur"]
    if rc in (126, 127) and not done:
        notify("Nothing installed", "The password dialog was closed. The packages wait at the sync icon.")
    elif failed:
        notify("Not installed", f"{', '.join(failed)} (maybe update first: sudo pacman -Syu)", "critical")
    if done:
        notify("Installed", ", ".join(done))
    poke()


def skip(sub, names):
    subprocess.run([DRIFTLESS, "packages", sub, *names], capture_output=True)
    if sub == "unskip":
        rows = read("install-pending").splitlines()
        for name in names:
            kind = listed(name)[0]
            if kind and f"{kind} {name}" not in rows:
                rows.append(f"{kind} {name}")
        with open(os.path.join(STATE, "install-pending"), "w") as f:
            f.writelines(row + "\n" for row in rows)
    poke()


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "json"
    if cmd == "json":
        print(json.dumps(data()))
    elif cmd == "open":
        sys.exit(0 if open_card() else 1)
    elif cmd == "announce":
        announce()
    elif cmd == "install":
        install()
    elif cmd in ("skip", "unskip") and len(sys.argv) > 2:
        skip(cmd, sys.argv[2:])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
