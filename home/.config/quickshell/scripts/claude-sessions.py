#!/usr/bin/env python3
"""The bar: how many Claude Code sessions are running, waiting for an answer or recently done, as JSON.
Reads ~/.local/state/claude-status/*.json. A Claude Code hook writes these files (status, pid, seit =
time of the last change); without that hook there are none and the bar shows nothing. Files of
sessions that died without saying goodbye are removed."""

import glob
import json
import os
import time

STATE = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
DONE_SHOWN = 15 * 60  # seconds a finished session stays in the bar


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def main():
    counts = {"running": 0, "waiting": 0, "done": 0}
    now = time.time()
    for path in glob.glob(STATE + "/claude-status/*.json"):
        try:
            with open(path) as f:
                session = json.load(f)
            if not alive(int(session["pid"])):
                os.unlink(path)
                continue
            status = session["status"]
            if status == "done" and now - float(session["seit"]) > DONE_SHOWN:
                continue
            counts[status] += 1
        except (OSError, ValueError, KeyError, TypeError):
            continue
    print(json.dumps(counts))


main()
