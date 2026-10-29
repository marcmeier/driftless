#!/usr/bin/env python3
"""The bar: this machine as one JSON object, for "About this machine" (bar/AboutPopup.qml, a click on
your name). The model, the system and its versions, the driftless release running here, the last full
upgrade, memory and the root file system. Anything that cannot be read is left out."""

import datetime as dt
import json
import os
import re
import shutil
import subprocess

# the running clone: where the driftless command links to
DRIFTLESS = os.path.dirname(os.path.realpath(os.path.expanduser("~/.local/bin/driftless")))


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return ""


def run(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def os_name():
    for line in read("/etc/os-release").splitlines():
        if line.startswith("PRETTY_NAME="):
            return line.split("=", 1)[1].strip('"')
    return ""


def model():
    vendor = read("/sys/class/dmi/id/sys_vendor")
    name = read("/sys/class/dmi/id/product_name")
    if not name or name.lower().startswith(("to be filled", "system product", "default string")):
        name = read("/sys/class/dmi/id/board_name")
    return " ".join(x for x in (vendor, name) if x and not name.startswith(vendor)) or name


def cpu():
    for line in read("/proc/cpuinfo").splitlines():
        if line.startswith("model name"):
            name = line.split(":", 1)[1]
            # "13th Gen Intel(R) Core(TM) i5-1345U" -> "13th Gen Intel Core i5-1345U"
            return re.sub(r"\s+", " ", re.sub(r"\((R|TM)\)|CPU|@.*", "", name)).strip()
    return ""


def hyprland():
    try:
        return json.loads(run("hyprctl", "version", "-j")).get("version", "")
    except ValueError:
        return ""


def quickshell():
    m = re.search(r"(\d+\.\d+(?:\.\d+)?)", run("quickshell", "--version"))
    return m.group(1) if m else ""


def driftless():
    """The release the running clone is on (the newest heading of its changelog), and its commit."""
    version = ""
    for line in read(f"{DRIFTLESS}/CHANGELOG.md").splitlines():
        m = re.match(r"## (v\d+\.\d+\.\d+)", line)
        if m:
            version = m.group(1)
            break
    commit = run("git", "-C", DRIFTLESS, "rev-parse", "--short", "HEAD")
    return {"version": version, "commit": commit}


def last_upgrade():
    """When pacman last ran a full system upgrade, as a Unix time (0: never seen)."""
    last = ""
    try:
        with open("/var/log/pacman.log", errors="replace") as f:
            for line in f:
                if "starting full system upgrade" in line:
                    last = line
    except OSError:
        return 0
    m = re.match(r"\[([^\]]+)\]", last)
    if not m:
        return 0
    try:
        return int(dt.datetime.fromisoformat(m.group(1)).timestamp())
    except ValueError:
        return 0


def memory():
    info = {}
    for line in read("/proc/meminfo").splitlines():
        key, _, rest = line.partition(":")
        info[key] = int(rest.split()[0]) * 1024 if rest.split() else 0
    total = info.get("MemTotal", 0)
    return {"used": total - info.get("MemAvailable", 0), "total": total}


def disk():
    try:
        d = shutil.disk_usage("/")
    except OSError:
        return {"used": 0, "total": 0}
    return {"used": d.total - d.free, "total": d.total}


def main():
    uptime = read("/proc/uptime").split()
    print(
        json.dumps(
            {
                "host": read("/etc/hostname") or os.uname().nodename,
                "model": model(),
                "cpu": cpu(),
                "os": os_name(),
                "kernel": os.uname().release,
                "hyprland": hyprland(),
                "quickshell": quickshell(),
                "driftless": driftless(),
                "uptime": int(float(uptime[0])) if uptime else 0,
                "upgraded": last_upgrade(),
                "memory": memory(),
                "disk": disk(),
            }
        )
    )


if __name__ == "__main__":
    main()
