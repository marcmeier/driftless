#!/usr/bin/env python3
"""The settings of this machine beyond the look and the bar, for the settings popup (bar/SettingsPopup.qml):
the clock, the night light, notifications, when the screen locks and turns off, mouse, touchpad and
keyboard.

settings.json holds only what was changed (~/.local/state/driftless-shell, per machine, outside the
repository); a setting that is not in it is whatever the configuration says. From it come
  the shell        reads settings.json itself (services/Prefs.qml): clock, night light, notifications
  input.lua        ~/.local/state/hypr, loaded by hyprland.lua after the host and personal layers
  idle.conf        ~/.local/state/hypr, sourced by hypr/hypridle.conf (the times as $variables)
A change reaches Hyprland at once (hyprctl eval) and hypridle with a restart.
Usage: prefs.py set KEY VALUE    store one ("default" forgets it) and apply it
       prefs.py input            the input options in effect now, as JSON (hyprctl)
       prefs.py render           write input.lua and idle.conf again from settings.json
       prefs.py about            this machine for the settings (System > About), as JSON"""

import json
import os
import platform
import re
import socket
import subprocess
import sys

STATE_DIR = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
SETTINGS = f"{STATE_DIR}/driftless-shell/settings.json"
INPUT_LUA = f"{STATE_DIR}/hypr/input.lua"
# hypridle.conf sources it by this path (hyprlang knows no XDG_STATE_HOME)
IDLE_CONF = os.path.expanduser("~/.local/state/hypr/idle.conf")
NEVER = 604800  # "never" for hypridle: a week (its timeouts end at about 49 days)


def boolean(v):
    if v not in ("true", "false"):
        raise ValueError(v)
    return v == "true"


def seconds(v):
    n = int(v)
    if n != 0 and not 60 <= n <= 86400:
        raise ValueError(v)
    return n


def speed(v):
    return round(max(-1.0, min(1.0, float(v))), 2)


def one_of(*values):
    def check(v):
        n = int(v)
        if n not in values:
            raise ValueError(v)
        return n

    return check


def word(*values):
    def check(v):
        if v not in values:
            raise ValueError(v)
        return v

    return check


def names(v):
    """A list of names, comma-separated (empty: none)."""
    return [n for n in v.split(",") if n]


# key: (parse, where it goes, the Hyprland option)
KEYS = {
    "clock24": (boolean, "shell", None),
    "clockSeconds": (boolean, "shell", None),
    "clockDate": (boolean, "shell", None),
    "holdInFullscreen": (boolean, "shell", None),
    "nightLight": (word("off", "sun", "on"), "shell", None),
    "nightTemp": (one_of(3000, 3500, 4000, 4500), "shell", None),
    "trayPinned": (names, "shell", None),
    "lockAfter": (seconds, "idle", "lock_after"),
    "screenOffAfter": (seconds, "idle", "screen_off_after"),
    "pointerSpeed": (speed, "input", "sensitivity"),
    "followMouse": (boolean, "input", "follow_mouse"),
    "naturalScroll": (boolean, "input", "touchpad.natural_scroll"),
    "tapToClick": (boolean, "input", "touchpad.tap_to_click"),
    "disableWhileTyping": (boolean, "input", "touchpad.disable_while_typing"),
    "repeatDelay": (one_of(250, 400, 600), "input", "repeat_delay"),
    "repeatRate": (one_of(25, 35, 50), "input", "repeat_rate"),
}


def load():
    try:
        with open(SETTINGS) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".new", "w") as f:
        f.write(text)
    os.replace(path + ".new", path)


def lua_value(key, value):
    if key == "followMouse":
        return "1" if value else "0"
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


# {input = {sensitivity = 0.3, touchpad = {tap_to_click = false}}} from the input keys in data
def input_table(data):
    top, touchpad = [], []
    for key, (_, target, option) in KEYS.items():
        if target != "input" or key not in data:
            continue
        name = option.removeprefix("touchpad.")
        (touchpad if option.startswith("touchpad.") else top).append(f"{name} = {lua_value(key, data[key])}")
    if touchpad:
        top.append("touchpad = { " + ", ".join(touchpad) + " }")
    return "{ input = { " + ", ".join(top) + " } }" if top else ""


def render_input(data):
    table = input_table(data)
    write(
        INPUT_LUA,
        "-- Written by the settings (quickshell/scripts/prefs.py) from settings.json. Do not edit.\n"
        + (f"hl.config({table})\n" if table else ""),
    )


def render_idle(data):
    lines = ["# Written by the settings (quickshell/scripts/prefs.py) from settings.json. Do not edit."]
    for key in ("lockAfter", "screenOffAfter"):
        if key in data:
            lines.append(f"${KEYS[key][2]} = {data[key] or NEVER}")
    write(IDLE_CONF, "\n".join(lines) + "\n")


def run(*cmd):
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


def apply(key, data):
    target = KEYS[key][1]
    if target == "input":
        render_input(data)
        # one option back to the configuration's value needs the whole configuration again
        if key in data:
            run("hyprctl", "eval", f"hl.config({input_table({key: data[key]})})")
        else:
            run("hyprctl", "reload")
    elif target == "idle":
        render_idle(data)
        run("systemctl", "--user", "try-restart", "hypridle.service")


def option(name):
    try:
        out = subprocess.run(["hyprctl", "-j", "getoption", name], capture_output=True, text=True, check=True)
        got = json.loads(out.stdout)
    except (OSError, subprocess.CalledProcessError, ValueError):
        return None
    for kind in ("int", "float", "bool"):
        if kind in got:
            return got[kind]
    return None


def current_input():
    result = {}
    for key, (_, target, opt) in KEYS.items():
        if target == "input":
            value = option("input:" + opt.replace(".", ":"))
            if value is not None:
                result[key] = bool(value) if key == "followMouse" else value
    try:
        out = subprocess.run(["hyprctl", "-j", "devices"], capture_output=True, text=True, check=True)
        mice = json.loads(out.stdout).get("mice", [])
    except (OSError, subprocess.CalledProcessError, ValueError):
        mice = []
    result["touchpad"] = any("touchpad" in m.get("name", "") for m in mice)
    return result


def first_match(path, pattern):
    try:
        with open(path) as f:
            m = re.search(pattern, f.read(), re.M)
        return m.group(1).strip() if m else ""
    except OSError:
        return ""


def about():
    repo = os.path.dirname(os.path.realpath(os.path.expanduser("~/.local/bin/driftless")))
    try:
        out = subprocess.run(["hyprctl", "-j", "version"], capture_output=True, text=True, check=True)
        hyprland = json.loads(out.stdout).get("tag", "").lstrip("v")
    except (OSError, subprocess.CalledProcessError, ValueError):
        hyprland = ""
    memory = first_match("/proc/meminfo", r"^MemTotal:\s+(\d+)")
    return {
        "version": first_match(f"{repo}/CHANGELOG.md", r"^## v(\S+)"),
        "host": socket.gethostname(),
        "os": first_match("/etc/os-release", r'^PRETTY_NAME="?([^"\n]*)'),
        "kernel": platform.release(),
        "hyprland": hyprland,
        "cpu": re.sub(r"\s+", " ", first_match("/proc/cpuinfo", r"^model name\s*:\s*(.*)$")),
        "memory": f"{round(int(memory) / 1048576)} GB" if memory else "",
    }


def main(argv):
    if argv[:1] == ["set"] and len(argv) == 3 and argv[1] in KEYS:
        key, raw = argv[1], argv[2]
        data = load()
        if raw == "default":
            data.pop(key, None)
        else:
            try:
                data[key] = KEYS[key][0](raw)
            except ValueError:
                print(f"prefs.py: not a value for {key}: {raw}", file=sys.stderr)
                return 2
        write(SETTINGS, json.dumps(data, indent=2, sort_keys=True) + "\n")
        apply(key, data)
        return 0
    if argv == ["input"]:
        print(json.dumps(current_input()))
        return 0
    if argv == ["about"]:
        print(json.dumps(about()))
        return 0
    if argv == ["render"]:
        data = load()
        render_input(data)
        render_idle(data)
        return 0
    print("usage: " + __doc__.split("Usage: ")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
