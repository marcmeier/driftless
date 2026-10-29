------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto", -- Hyprland picks a fitting scale (HiDPI notebook panels)
})

-- Monitor rules of this machine: hosts/<host>/hyprland.lua, then the layout from the Monitors menu,
-- both loaded at the very end of this file (LOCAL LAYERS), so they win over the default above.

-- Laptop only / external only / extend / mirror: SUPER + SHIFT + P (display-mode.sh). If the last active
-- monitor goes away (external unplugged in "External only" mode), turn the laptop panel back on.
hl.on("monitor.removed", function(removed)
    local left = 0
    for _, m in ipairs(hl.get_monitors()) do
        if not removed or m.name ~= removed.name then left = left + 1 end
    end
    if left == 0 then
        hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1, disabled = false })
    end
end)


---------------------
---- MY PROGRAMS ----
---------------------

-- the accent and the look (dark/light) of the plain theme, rendered by theme/apply.py. Not rendered yet
-- (a fresh install whose theme step failed): the dark values keep the rest of this file working.
local themed, theme = pcall(dofile, os.getenv("HOME") .. "/.config/theme/colors.lua")
if not themed or type(theme) ~= "table" then
    theme = { scheme = "dark", primary = "7aa6d9", secondary = "7aa6d9", line = "3a3a3a", desk = "0e0e0e" }
end
local terminal = "ghostty"
local menu = "walker"
local fileManager = "nautilus"
local browser = "brave-origin --hide-crash-restore-bubble"
-- an area of the screen (slurp) to a file in ~/Pictures/Screenshots and the clipboard
local shotArea = 'mkdir -p ~/Pictures/Screenshots && f=~/Pictures/Screenshots/shot-$(date +%F_%H-%M-%S).png && grim -g "$(slurp)" - | tee "$f" | wl-copy'


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- The desktop shell (bar, notifications, lock screen, power menu, password dialog, Claude bubble), hypridle,
-- the clipboard history, the desktop colour (awww) and elephant are systemd user units that start with graphical-session.target (driftless setup
-- enables them), so they restart on a crash and "systemctl --user restart driftless-shell" works. That needs the session from
-- uwsm ("Hyprland (uwsm-managed)" at the login screen). Started any other way, start them here.
if not os.getenv("UWSM_FINALIZE_VARNAMES") then
    hl.on("hyprland.start", function ()
        for _, cmd in ipairs({
            "quickshell -p ~/.config/quickshell", "hypridle",
            "wl-paste --watch cliphist store", "elephant", "awww-daemon",
            "sleep 1 && awww img --transition-type none ~/.config/wall.png",
        }) do hl.exec_cmd(cmd) end
        hl.exec_cmd("notify-send 'Started without uwsm' 'Pick \"Hyprland (uwsm-managed)\" at the login screen'")
    end)
end


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- in ~/.config/uwsm/env, so the systemd units and apps started by uwsm get the same values


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 3,
        gaps_out = 6,

        border_size = 1,

        -- plain: the window with focus has the accent, the others a grey line
        col = {
            active_border   = "rgb(" .. theme.primary .. ")",
            inactive_border = "rgb(" .. (theme.line or "3a3a3a") .. ")",
        },

        -- see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/
        allow_tearing = true, -- only takes effect for windows with the "immediate" rule below

        layout = "dwindle",
    },

    decoration = {
        rounding = 0,

        -- plain: no shadow, no blur
        shadow = { enabled = false },
        blur   = { enabled = false },
    },

    -- plain: no animations, windows and workspaces are there at once
    animations = { enabled = false },
})


-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        -- the desktop's colour before awww shows wall.png (the same colour)
        background_color        = "rgb(" .. (theme.desk or "0e0e0e") .. ")",
        -- the lock screen is part of the shell: when the shell restarts while locked (a crash), the new one
        -- (or hyprlock from a TTY) takes the lock over; the screen stays locked in between
        allow_session_lock_restore = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout = "us", -- personal/hyprland.lua or hosts/<host>/hyprland.lua set yours

        follow_mouse = 1,

        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})



---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- See https://wiki.hypr.land/Configuring/Basics/Binds/
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal), { description = "Terminal (Ghostty)" })
hl.bind(mainMod .. " + W", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("quickshell ipc -p ~/.config/quickshell call power toggle"), { description = "Power menu: lock, log out, suspend, reboot, shut down" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("~/.config/quickshell/scripts/lock"), { description = "Lock the screen" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("quickshell ipc -p ~/.config/quickshell call bar popup notifications"), { description = "Notifications: the list" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("quickshell ipc -p ~/.config/quickshell call notifications dnd toggle"), { description = "Notifications: do not disturb on / off" })
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("~/.config/quickshell/scripts/widgets.py"), { description = "Bar widgets: show, hide, move" }) -- the bar's widget manager
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(browser), { description = "Browser" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { description = "File manager" })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Maximise window (fullscreen)" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("cliphist list | walker --dmenu | cliphist decode | wl-copy"), { description = "Clipboard history" })
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("~/.config/hypr/claude-launch.sh"), { description = "Claude Code" })
hl.bind("PRINT", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'), { description = "Screenshot: area to clipboard" })
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(shotArea), { description = "Screenshot: area to file and clipboard" })
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd('mkdir -p ~/Pictures/Screenshots && f=~/Pictures/Screenshots/shot-$(date +%F_%H-%M-%S).png && grim - | tee "$f" | wl-copy'), { description = "Screenshot: whole screen to file and clipboard" })
-- Color picker: click a pixel -> hex code in clipboard + notification (Esc cancels)
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("pidof hyprpicker || hyprpicker -a -n -q"), { description = "Colour picker: hex code to clipboard" })
-- Every keybinding, searchable (keybinds.py lists the descriptions of these binds)
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.exec_cmd("~/.config/hypr/keybinds.py"), { description = "Keybindings: search all shortcuts" })
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Float window (toggle)" })
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu), { description = "App launcher (walker): apps, calculator, web search" })
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("~/.config/hypr/emoji-picker.sh"), { description = "Emoji picker" })
-- Dictation (dictate.py): tap to start and again to stop, or hold and let go; with SHIFT without the LLM
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd("~/.config/hypr/dictate.py down"), { description = "Dictation, voice to text: tap to start and stop, hold to talk" })
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd("~/.config/hypr/dictate.py up"), { release = true })
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("~/.config/hypr/dictate.py down --raw"), { description = "Dictation, voice to text, without the LLM tidying up" })
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("~/.config/hypr/dictate.py up"), { release = true })
-- Ask Claude by voice (notch/notch.py): same keys as dictation, the answer appears in a bubble at the top and is spoken
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("~/.config/hypr/notch/notch.py down"), { description = "Ask Claude by voice: tap to start and stop, hold to talk" })
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("~/.config/hypr/notch/notch.py up"), { release = true })
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Pseudo-tile window" })
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/hypr/display-mode.sh"), { description = "Display mode: extend, mirror, one screen" })
hl.bind("XF86Display", hl.dsp.exec_cmd("~/.config/hypr/display-mode.sh"), { description = "Display mode: extend, mirror, one screen" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { description = "Toggle split direction" }) -- dwindle only

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }), { description = "Move focus" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Move focus" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }), { description = "Move focus" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }), { description = "Move focus" })

-- Swap active window with its neighbour with mainMod + SHIFT + arrow keys
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.swap({ direction = "left" }), { description = "Swap window with its neighbour" })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }), { description = "Swap window with its neighbour" })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.swap({ direction = "up" }), { description = "Swap window with its neighbour" })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.swap({ direction = "down" }), { description = "Swap window with its neighbour" })

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}), { description = "Go to workspace 1-10" })
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }), { description = "Move window to workspace 1-10" })
end

-- The scratchpad (special workspace)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"), { description = "Scratchpad (special workspace): show or hide" })
-- the screenshot keys of Windows, the same as SHIFT + PRINT
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(shotArea), { description = "Screenshot: area to file and clipboard" })
-- an area into satty, to draw on it; save and copy from there
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd('mkdir -p ~/Pictures/Screenshots && grim -g "$(slurp)" - | satty --filename - --output-filename ~/Pictures/Screenshots/shot-%Y-%m-%d_%H-%M-%S.png --copy-command wl-copy --early-exit'), { description = "Screenshot: area, annotate (satty)" })
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }), { description = "Move window to the scratchpad" })

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Move window (drag)" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window (drag)" })

-- Laptop multimedia keys for volume and LCD brightness (the shell's on-screen display shows the level)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true, description = "Mute speakers" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true, description = "Mute microphone" })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("~/.config/quickshell/scripts/brightness up"),    { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("~/.config/quickshell/scripts/brightness down"),  { locked = true, repeating = true, description = "Brightness down" })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Media: next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: play / pause" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: play / pause" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Media: previous track" })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.window_rule({
    -- apps do not maximise themselves
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- The shell's popups, tooltips, notifications, on-screen display, power menu and password dialog appear at
-- once, like everything in the plain look (no compositor fade either)
hl.layer_rule({
    name  = "shell-popups-no-anim",
    match = { namespace = "^(driftless-popup|driftless-tooltip|driftless-notifications|driftless-osd|driftless-power|driftless-polkit)$" },

    no_anim = true,
})

-- hyprpicker: no fade on the frozen overlay, so the picker appears/disappears instantly
hl.layer_rule({
    name  = "hyprpicker-no-anim",
    match = { namespace = "^hyprpicker$" },

    no_anim = true,
})

-- Gaming: allow tearing (lower input latency) for Steam/Proton, Battle.net/Diablo (Wine) and gamescope windows.
-- Requires general.allow_tearing = true above and vsync off in the game.
hl.window_rule({
    name  = "games-immediate",
    match = { class = "^(steam_app_.*|battle\\.net\\.exe|diablo iv\\.exe|gamescope)$" },

    immediate = true,
})

-- Browser extension popups (e.g. Bitwarden's unlock/popout in Brave, Chrome, Chromium, Vivaldi): they open as
-- toplevels without a parent, so Hyprland would tile them. Their first title is "_crx_<extension id>", which an
-- installed web app (same class pattern brave-<id>-Default) never has: floating, centered over the browser.
-- With a fixed size, because the browser draws the first frame at the tiled size and leaves white patches
-- when Hyprland resizes it afterwards. 480x760 fits Bitwarden; an extension that needs another size gets
-- its own rule below this one, matched by its id (initial_title = "^_crx_<id>$").
hl.window_rule({
    name  = "browser-extension-popups-float",
    match = { initial_title = "^_crx_[a-p]{32}$" },

    float  = true,
    center = true,
    size   = "480 760",
})

-- Picture-in-picture videos (Chromium browsers, Firefox): floating, on every workspace
hl.window_rule({
    name  = "picture-in-picture-float",
    match = { title = "^(Picture[- ]in[- ][Pp]icture|Bild[- ]im[- ]Bild)$" },

    float = true,
    pin   = true,
})

-- Calendar (ikhal, started from the calendar in the bar): floating, centered
hl.window_rule({
    name  = "calendar-float",
    match = { class = "^com\\.mitchellh\\.ghostty\\.calendar$" },

    float  = true,
    center = true,
    size   = "1000 720",
})


----------------------
---- LOCAL LAYERS ----
----------------------

-- In this order, each one winning over the ones before:
--   1. hosts/<host>/hyprland.lua   this machine in the repository (e.g. a monitor's refresh rate)
--   2. personal/hyprland.lua       yours on every machine (e.g. the keyboard layout)
--   3. the settings                Displays (nwg-displays) and Mouse & keyboard (quickshell/scripts/prefs.py),
--                                  saved in ~/.local/state/hypr, never in the repository: what you set
--                                  there is what you get
-- A missing file is fine (no layer, nothing saved yet); a broken one shows on screen, and the files
-- after it still load.
local function layer(path)
    local f = io.open(path)
    if not f then return end
    f:close()
    local ok, err = pcall(dofile, path)
    if not ok then
        hl.notification.create({ text = "hyprland.lua: " .. tostring(err), duration = 15000, color = "rgb(e06c75)" })
    end
end
layer(os.getenv("HOME") .. "/.config/driftless/host/hyprland.lua")
layer(os.getenv("HOME") .. "/.config/driftless/personal/hyprland.lua")
local layout_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/hypr/"
for _, file in ipairs({ "monitors.lua", "workspaces.lua", "input.lua" }) do
    layer(layout_dir .. file)
end
