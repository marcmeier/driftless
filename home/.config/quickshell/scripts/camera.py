#!/usr/bin/env python3
"""The bar: which programs have a camera (/dev/video*) open right now, for the privacy indicator.
Runs for as long as the shell does and prints one JSON line whenever that changes: {"apps": [...]}.
Woken by inotify when a camera is opened or closed (or one comes or goes), so it costs nothing while
idle. PipeWire and WirePlumber are left out: an app that records through PipeWire shows up there as a
stream, and the shell sees it itself (services/Privacy.qml)."""

import ctypes
import json
import os
import select
import signal
import sys
import time

IN_CLOSE_WRITE = 0x08
IN_CLOSE_NOWRITE = 0x10
IN_OPEN = 0x20
IN_CREATE = 0x100
IN_DELETE = 0x200
PR_SET_PDEATHSIG = 1
SKIP = {"pipewire", "wireplumber"}

libc = ctypes.CDLL(None, use_errno=True)


def cameras():
    return sorted("/dev/" + f for f in os.listdir("/dev") if f.startswith("video"))


def holders():
    """The programs that hold a camera open, by the name of their executable (comm as a fallback)."""
    apps = set()
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            fds = os.scandir(f"/proc/{pid}/fd")
        except OSError:
            continue
        with fds:
            for fd in fds:
                try:
                    if not os.readlink(fd.path).startswith("/dev/video"):
                        continue
                except OSError:
                    continue
                try:
                    name = os.path.basename(os.readlink(f"/proc/{pid}/exe"))
                except OSError:
                    with open(f"/proc/{pid}/comm") as f:
                        name = f.read().strip()
                if name not in SKIP:
                    apps.add(name)
                break
    return sorted(apps)


def main():
    # go with the shell: it only reads us, and a pipe nobody reads is not noticed until the next change
    parent = os.getppid()
    libc.prctl(PR_SET_PDEATHSIG, signal.SIGTERM)
    if os.getppid() != parent:
        sys.exit(0)
    fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
    if fd < 0:
        sys.exit("inotify_init1 failed")
    libc.inotify_add_watch(fd, b"/dev", IN_CREATE | IN_DELETE)
    watched = set()
    last = None
    while True:
        for cam in cameras():
            if (
                cam not in watched
                and libc.inotify_add_watch(fd, cam.encode(), IN_OPEN | IN_CLOSE_WRITE | IN_CLOSE_NOWRITE) >= 0
            ):
                watched.add(cam)
        watched &= set(cameras())
        apps = holders()
        if apps != last:
            print(json.dumps({"apps": apps}), flush=True)
            last = apps
        # wait for the next open or close (a minute at most, in case one slipped by), then let a
        # burst of them settle before looking again
        select.select([fd], [], [], 60)
        time.sleep(0.3)
        try:
            while os.read(fd, 65536):
                pass
        except BlockingIOError:
            pass


if __name__ == "__main__":
    main()
