<a href="README.md"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/brand/logo-on-dark.svg"><img src="docs/brand/logo-on-light.svg" alt="driftless" width="44" align="right"></picture></a>

# Changelog

Versions follow the [releases](../../releases), which have the full notes.

## v2.19.0 (2026-10-29): privacy indicator and folded tray

### Added
- **Privacy indicator** in the bar, first on the right and only while it matters: an amber capsule
  with a symbol each for the microphone, the camera and the screen while an app records, films or
  shares it (red while the screen is shared); it pulses when something new starts. Hover: which apps;
  click: mute the microphone, wheel: its level. It sees PipeWire streams, programs that open
  `/dev/video*` themselves (`scripts/camera.py`, woken by inotify) and screen recorders that copy
  straight from Hyprland.

### Changed
- **The tray is folded away** behind an arrow: a small box under it holds every app's own icon (click:
  the app; right click: its menu below the icons, which stay usable). The pin on an icon keeps it in
  the bar next to the arrow, per machine (`trayPinned` in the settings); the arrow lights up while a
  folded app asks for attention.

### Removed
- The permanent microphone switch in the status pill (`pulseaudio#mic`): the privacy indicator mutes
  while an app listens, the volume popup lists the microphones, and the mute key works as before.

## v2.18.0 (2026-10-29): printing

### Added
- **Printing without drivers**: a new package group `printing` (CUPS, cups-filters, avahi, nss-mdns,
  system-config-printer) with `cups.socket` and `avahi-daemon.service` enabled. Network printers that
  speak IPP Everywhere or AirPrint (most from the last ten years) show up in every print dialog;
  `system-config-printer` sets one up for good.
- driftless-system adds `mdns_minimal` to the `hosts` line of `/etc/nsswitch.conf` once, so printers
  that announce themselves as `NAME.local` resolve. On a machine that is already set up, run
  `driftless system` after the sync has installed the group.

## v2.17.1 (2026-10-29): Hyprland 0.57.0

### Fixed
- **SUPER+F maximises again under Hyprland 0.57.0**: the fullscreen dispatcher now takes a table
  (`hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })`); the old two-argument call
  failed to load the bind and showed a config error after login. The new form works on 0.56 too.

## v2.17.0 (2026-10-28): floating extension popups

### Changed
- **Browser extension popups float**: Bitwarden's unlock and popout and every other extension window
  of a Chromium browser (Brave, Chrome, Chromium, Vivaldi) open centered at 480×760 instead of tiled.
  They are told apart from installed web apps, which share their class pattern, by their first title
  `_crx_<extension id>`. The fixed size keeps the browser from leaving white patches when Hyprland
  resized the first frame; an extension that needs another size gets its own rule by its id.
- **Picture-in-picture videos float** and stay on every workspace.

## v2.16.0 (2026-10-27): night light

### Added
- **Night light** under Displays in the settings: off, from sunset to sunrise (today's times from the
  weather, as for the auto look) or always, in four warmths (4500 to 3000 K). hyprsunset runs only
  while it is on (`services/NightLight.qml`), so the screens get their colours back when it ends; a
  new warmth reaches it at once. The choice is per machine like the other settings.
- `hyprsunset` in the desktop packages.

## v2.15.0 (2026-10-27): more in the settings

### Added
- **Notifications** page: do not disturb, whether a fullscreen window (a game, a video) holds them
  back, clearing the list.
- **Mouse & keyboard** page: pointer speed, focus follows the mouse; on a notebook natural scrolling,
  tap to click and the touchpad off while typing; how soon and how fast a held key repeats; the
  keybindings (moved here from System). Hyprland follows at once (`hyprctl eval`).
- **Power** page: lock the screen and turn it off after 5, 10, 15, 30 minutes or never; keep awake;
  the power profile on a notebook; the power menu.
- **Clock** under Bar: 24 or 12 hours, seconds, the date next to the time.
- **About** under System: the machine, the driftless version, kernel, Hyprland, processor and memory.

### Changed
- The new choices are per machine like the others: `scripts/prefs.py` keeps only what was changed in
  `~/.local/state/driftless-shell/settings.json` and writes `~/.local/state/hypr/input.lua` (loaded by
  `hyprland.lua` after the host and personal layers) and `~/.local/state/hypr/idle.conf`, whose times
  `hypridle.conf` reads as variables; a drop-in for `hypridle.service` creates that file empty first.

## v2.14.0 (2026-10-27): settings like a settings app

### Changed
- **The settings popup is laid out like a settings app**: the pages on the left (Appearance, Bar,
  Displays, System), on the right grouped rows, what a setting is on the left and its control on the
  right, in place of one page of buttons.
- Dark, light or auto, the bar size and the sync mode are segmented controls (`bar/PSegmented.qml`);
  the palettes a grid of tiles with their colours under Appearance.
- The widgets are a list of switches in place of a cloud of chips; a group that is off greys out its
  members. "Arrange …" still orders them in the widget manager.

### Added
- The sync mode (automatic, review first, off) and "Sync now" right in the settings, under System;
  "Open …" leads to the rest of the sync menu.

## v2.13.0 (2026-10-27): palettes

### Added
- **Palettes** next to the plain greys, softer and well known, each dark and light so auto works with
  all of them: Catppuccin (Mocha, Latte), Dracula (Dracula, Alucard), Everforest, Gruvbox, Nord (Polar
  Night, Snow Storm), Rosé Pine (Rosé Pine, Dawn), Solarized and Tokyo Night (Night, Day). They bring
  their own background, text, accent and terminal colours; what a scheme has no colour for (the steps
  between background and text, bevels, selection) is mixed from its background and text. The form
  stays the plain look's: opaque, square, one accent. Shell, Ghostty, GTK, Qt, walker, btop, starship,
  VS Code and Hyprland follow.
- In the settings: a row of tiles under Appearance, each with a few of its colours; in walker as
  "Palette: …"; on the command line `theme/apply.py --palette NAME` (`--palettes` lists them). The
  choice is per machine (`~/.local/state/theme/palette`), plain stays the default.

### Changed
- The lock and the login screen stay dark, now in the palette's dark look; a palette chosen in the
  settings hands the login screen its files at once.
- The named palettes keep their originals' contrast (Solarized and Tokyo Night Day are softer):
  `tests/theme.bats` asks AA for their text, the plain look keeps its stricter checks.

## v2.12.0 (2026-10-27): Crafting Apps instead of LibreOffice

### Changed
- **Office is now the Crafting Apps** by storytold/ArtCraft: WordCraft, GridCraft and DeckCraft
  (`aur:wordcraft-bin`, `aur:gridcraft-bin`, `aur:deckcraft-bin` in `packages/apps.list`). The `-bin`
  packages install the official release binaries (their checksums match upstream's `SHA256SUMS.txt`),
  so an update is a download, not a Rust build; they update with the rest of the AUR in the update
  pill. Flatpak is no option yet: the apps only ship bundles in their GitHub releases, without a
  repository flatpak could update them from.
- `mimeapps.list` opens Word, ODT and RTF files in WordCraft, Excel, ODS and CSV in GridCraft and
  PowerPoint (`.pptx`) in DeckCraft; the bar names their windows with their own glyphs.

### Removed
- **LibreOffice** (`libreoffice-fresh`, `libreoffice-fresh-de`) and the hyphenation and thesaurus
  packages only it used (`hyphen-de`, `hyphen-en`, `mythes-de`, `mythes-en`). The sync never uninstalls:
  on a machine that has them, `driftless packages` lists them as installed but in no list, to remove
  with `sudo pacman -Rns`. DeckCraft opens no `.ppt` or `.odp` yet.

## v2.11.0 (2026-10-27): a calmer right side

### Changed
- **The bar's right side follows one rule**: from what comes and goes (next to the clock) to what
  always stays (at the edge), one kind of thing per pill: media · tray · pending · voice and Claude ·
  status · session. A pill that appears or grows now only pushes the passing things aside.
  - **Pending** (`group/pending`, new): updates and the sync, only while something waits. They used to
    sit in the pill at the edge and shift everything left of it when they came and went.
  - **Session** (`group/session`, replaces `group/system`): notifications, keep awake, power, always in
    the same place.
  - **Tray** moves inward next to the media, so the apps' coloured icons no longer split the
    monochrome status and session pills.
- A saved layout follows on its own (the new pills go next to their neighbours); a `group/system`
  hidden in the widget manager has to be hidden again as Session. The widget manager calls the idle
  inhibitor "Keep awake".

## v2.10.0 (2026-10-26): SSH agent

### Added
- **An SSH agent in every session**: `ssh-agent.socket` (from openssh) in the manifest and
  `SSH_AUTH_SOCK` in `~/.config/uwsm/env`. A key with a passphrase is then asked for once per session
  (with `AddKeysToAgent yes` in `~/.ssh/config`), instead of on every connection. Takes effect at the
  next login.

## v2.9.0 (2026-10-26): Tailscale

### Added
- **Tailscale on every machine**: a group `packages/tailscale.list` (`tailscale` and Trayscale from
  the AUR), `tailscaled.service` in the manifest, and Trayscale in the XDG autostart, hidden, so it
  is just its icon in the bar's tray. Logging in and the operator stay one step per machine
  (`tailscale up --operator=$USER`); `verify` says when one is missing.

## v2.8.0 (2026-10-25): the plain look

### Added
- **Flatpaks in the package lists**: `flatpak:APP_ID` in any list, and an empty group
  `packages/flatpak.list` for them (`driftless packages add ID flatpak`). They go into the system
  installation, next to the flathub remote Arch's flatpak package brings: one copy of each runtime,
  none of it in the home's snapshots and backups. Flatpak's polkit rule lets a wheel user of the
  active session install without a password, so the sync does it on its own, in a unit of its own (a
  runtime can take longer than a sync may run), with a notification, and not on a metered
  connection. `driftless packages` and `verify` show missing flatpaks and those in no list.
  `flatpak` itself is in `apps.list` now.
- The update pill counts flatpak updates (apps and runtimes) and its click runs `flatpak update`
  after `yay -Syu`, then removes runtimes nothing uses any more.
- **SSH on every machine**: `openssh` in `base.list`, `sshd.service` in the manifest, and a firewall
  rule with a rate limit (`ufw limit 22/tcp`, added once by driftless-system, removed with it). Keys
  only: no password login and no root login (`/etc/ssh/sshd_config.d/40-driftless.conf`). The keys
  that may log in stay in each machine's `~/.ssh/authorized_keys`, written by hand; `verify` says
  when there are none.
- `driftless system` also enables the system units the manifest gained since a machine was set up,
  and the sync says when an update brought one.

### Changed
- **The plain look** replaces the theme from the wallpaper: neutral greys and one accent (blue), dark,
  light or auto as before, a desktop of one colour, everything opaque, square and framed by a 1 px
  line, no blur, shadows, gradients, rounded corners or animations, in the shell and in Hyprland
  (`theme/scheme.py` has the two palettes). The bar is one strip along the top edge with its popups
  hanging from its line; the lock and login screen are the clock, the date, your name and the
  password on one dark colour; the power menu is a list; the Claude bubble a plain box without the
  face. walker, Ghostty, GTK, Qt, btop, starship, VS Code, hyprlock and ReGreet follow.
- Gone with the wallpaper images: picking, thumbnails and the walker wallpaper menu, the daily
  `driftless-wallpaper-rotate.timer` (a retired unit now), `palette.py`, `thumbs.py`,
  `WALLPAPER_DIR` and the assistant's "new wallpaper". `set-wallpaper --current` stays and renders the
  look again; `wall.png` and `login.png` are files of one colour, so awww, ReGreet and
  `greeter-update` work as before.
- Calendar sync: after a changed vdirsyncer config it runs `vdirsyncer discover` by itself, and the
  warning in the calendar pill tells a missing password by vdirsyncer's own error (its
  `password.fetch` command failed), whatever the config reads the password from.

### Fixed
- A package list with nothing but comments made `driftless` lose every group after it (`grep`
  without a line is an error under `set -e`): their packages were neither installed nor checked.
- The voice bubble's face moves with the spoken answer again, and the bubble stays open while it is
  read out. `speak.py` addressed the shell by a folder that has had no shell in it since the bubble
  became part of the bar's shell, so its calls failed without a word. A test now checks every
  `quickshell ipc` call.
- Timers by voice take `min`, `sek` and `sec` as units; the shorter `m` and `s` matched first.
- The pills fed by scripts (Claude usage, sync, weather, calendar, updates) are hidden until their
  script has answered. The feed's `data` property took the feed's Process and Timer children in, so a
  pill saw an object instead of nothing and showed "today 0" for a script that failed.
- A notification body cannot load pictures through `<img>` any more (Qt fetches them from any
  address), and an icon or image given as a web address is not fetched.
- A program's replaced folder is only removed from the home after it was copied into the repository
  completely (`driftless link` ran the removal even when the copy failed).
- The sync gives its calls to GitHub five minutes and the unit fifteen: a connection that died while a
  notebook slept blocked every later run. The lock's file descriptor is not handed to them.
- `driftless packages add` aborted for a list without a header line. `driftless help` and
  `install-base.sh --help` printed two lines of code at the end, and the installer checks for root
  before it removes or copies anything.
- Hyprland keeps its keys and rules when `theme/colors.lua` is missing (a theme step that failed).
- The screenshots show no real host name and no folder name of the author; `driftless publish` says
  when `personal/forbidden` has no terms to check.

### Security
- The voice assistant no longer fetches web pages (`WebFetch`) unless `NOTCH_WEBFETCH=on`. Text from a
  page, the screen or the clipboard can carry instructions, and the address of a fetch is a way to send
  out what the assistant has seen. Web search stays. The prompt also says that such text is data.
- "Open ..." by voice starts web addresses (http, https, no login in them) and files that are not
  programs; `javascript:`, `mailto:`, launchers and scripts are refused.
- `install-base.sh` refuses a disk that has mounted partitions (the live medium, a data disk) instead
  of wiping it after one typed confirmation.
- `bootstrap.sh` no longer runs `pacman -Sy` together with other packages (a partial upgrade): the
  keyring first, then the whole system, then reflector.

## v2.7.0 (2026-10-03): a light look

### Added
- A logo and a wordmark. The README, the other pages and the repository's social preview carry
  them; the files and how to use them are in [docs/brand](docs/brand/README.md).
- Light mode beside the dark one, chosen in the settings (Appearance: dark, light, auto) with three
  previews of your desktop in miniature. Light is paper and slate tinted by the wallpaper's hue, with
  deeper versions of its accents; auto is light from sunrise to sunset (`weather.py` notes them in
  `~/.cache/theme/sun.json`). The shell blends into the new look; GTK/libadwaita/Electron (gsettings),
  Qt, Ghostty, walker, btop, starship, VS Code and Hyprland follow. Lock and login screen stay dark.
- `theme/scheme.py`: both looks as named colours (`fg`, `bg`, `dim`, `line`, `red`, ...) that every
  template uses; `apply.py --appearance dark|light|auto`, `--follow-sun`. The choice is per machine
  (`~/.local/state/theme/appearance`).

### Changed
- `color-scheme` and `gtk-theme` left `dconf.ini` (each machine's look; `dconf capture` skips them).
- Ghostty's colours all come from the rendered `theme/ghostty-colors`.

### Fixed
- Keep awake (the coffee cup in the bar) did nothing: the screen still locked and went off. Hyprland
  ignores idle inhibitors on the bar, and the bar read QtQuick's own `State` instead of the shell's
  switch. It now holds an idle lock with logind (`systemd-inhibit`), which hypridle honours.

## v2.6.0 (2026-10-02): your picture, placed by you

### Added
- Your picture in the settings: a click on it (or "Picture …") picks an image, an editor in the
  shell's look places it behind a round mask (drag, wheel or slider to zoom; portraits start at the
  face's usual height). It goes to `~/.face` and the bar, the lock and the login screen follow at
  once. A picture linked into the repository (`personal/face.png`) reaches your other machines with
  the sync, which renders it there too.

## v2.5.0 (2026-10-02): the login screen in the lock screen's look

### Added
- A login screen drawn by Quickshell, in the lock screen's look: the same card with your picture and
  the password over the same blurred wallpaper, the machine, the session and reboot and shut down
  below. It puts the uwsm session first, offers the account that set the wallpaper, and talks to
  greetd directly. ReGreet stays as its fallback when it does not start
  ([why](ARCHITECTURE.md#9-notifications-login-and-lock-screen-power-menu-and-password-dialog-are-the-shell-too)).

### Changed
- `greeter-update` also hands the login screen the colours (`colors.json`) and the caller's login name.
- FEATURES: the wallpaper is chosen in the settings popup; the walker menu's screenshot is gone. A new
  screenshot of the login screen in README and FEATURES.

## v2.4.1 (2026-10-02): a face for Claude by voice

### Changed
- The voice bubble has a little bot instead of the orb: a screen for a face, rimmed in the
  wallpaper's accents, with an antenna. It listens with wide eyes, looks up and around while Claude
  thinks, reads along as the answer comes in, talks with the voice, smiles when done, glances at the
  pointer and shakes its head on an error. The answer stands right of it, in line with the question.
- New screenshots of the bubble in FEATURES.

## v2.4.0 (2026-10-01): the whole desktop in one shell

The Quickshell shell takes over what mako, hyprlock, wlogout and hyprpolkitagent did, and the settings
move into it, all in the bar's look:
[FEATURES.md](FEATURES.md#notifications-login-and-lock-screen-power-menu-and-password-dialog), [why](ARCHITECTURE.md#9-notifications-login-and-lock-screen-power-menu-and-password-dialog-are-the-shell-too).

### Added
- Notifications drawn by the shell: cards below the bar with the app's icon, progress, buttons and a
  line that runs out; a list behind the bell, grouped by app, with do not disturb and clear
  (`SUPER + N`, `SUPER + SHIFT + N`). Critical ones come through do not disturb.
- An on-screen display for volume, mute, the microphone, a new output device and the brightness keys.
- A lock screen in the login screen's look (`SUPER + L`, hypridle, before sleep); it counts what came in
  meanwhile and shows the cards after you unlock. hyprlock stays as the fallback.
- A power menu (`SUPER + SHIFT + M`, the power button; right click: lock) with keys for every card;
  suspend locks first.
- A password dialog: the shell is the polkit agent (hyprpolkitagent before), in the lock screen's look.
- Bluetooth in the bar: your devices with their battery, the ones nearby to pair, on/off. blueman's
  tray icon stays out while the bar shows Bluetooth.
- Quiet in fullscreen: only critical notifications pop up while a fullscreen window is on the
  workspace you look at; afterwards one card says how many came in.
- The settings as a popup of the bar (the avatar): wallpaper thumbnails, bar size, widgets on and off
  with one click, monitors, sync, keys. The walker menus stay for moving widgets and browsing the
  wallpaper folder.
- The notification list outlives a restart and a new login (seven days, this machine only, a folder
  only you can read).

### Changed
- The bell: click opens the list (was: do not disturb), right click is do not disturb, middle clear
  all. It reads the notifications directly instead of asking mako every five seconds.
- Voice commands for do not disturb and locking go to the shell.

### Removed
- mako (its unit is retired; a D-Bus activation file hands notifications to the shell), wlogout and
  their theme files; hyprpolkitagent (retired). The packages stay installed until you remove them
  (`driftless packages` lists them).

### Fixed
- The network pill's tooltip logged an error on a machine with only a cable.
- Moving over from the old kit in a session without uwsm started mako and the polkit agent next to the
  shell.


## v2.3.3 (2026-10-01): the ultrawide screenshot

### Changed
- The first screenshot in README and in FEATURES (the spacious bar on a 3440x1440 ultrawide) shows the
  Quickshell bar now; v2.3.2 still had the Waybar one there.

### Fixed
- The bar follows a monitor that is plugged in at once (its active workspace showed only after the
  next workspace change).

## v2.3.2 (2026-10-01): new screenshots

Every screenshot shows the setup as it is now, and two fixes for the bar.

### Changed
- New screenshots in README and FEATURES: the Quickshell bar, its popups, the ask button with the
  bubble growing out of it, dictation, the tiled desktop, walker, mako, wlogout and the menus.

### Fixed
- The bar missed the first workspace change after the shell started (the new workspace did not show
  up, the old window stayed in the window pill): it asks Hyprland for the state on workspace events.
- The sound popup names apps by their name instead of their app id (`Celluloid`, not
  `io.github.celluloid_player.Celluloid`).

## v2.3.1 (2026-10-01): an ask button

Ask Claude from the bar without knowing `SUPER + A`, and the bar's right side grouped by topic:
[FEATURES.md](FEATURES.md#the-bar).

### Added
- An ask button (✨) in the bar: ask Claude by voice without knowing `SUPER + A` (click: talk, click
  again: send, right click: stop). The bubble grows out of it, also for `SUPER + A`, and the button
  shows what Claude does (red while it listens, breathing while it thinks).

### Changed
- The right side of the bar in groups by topic: media · voice and Claude (ask button, dictation,
  usage) · status · tray (the apps' own icons, apart from the kit's monochrome ones) · system
  (updates, sync, keep awake, notifications, power) · you. Saved widget layouts follow by themselves.

### Fixed
- The wallpaper menu in walker called the settings menu at its old place (`~/.config/waybar`) after
  the update to v2.3.0: elephant keeps its menus from its start. The sync restarts elephant now when a
  menu changes (not when one does not parse). After updating to v2.3.0 once:
  `systemctl --user restart elephant.service` (or log in again).
- The active workspace's gradient stayed dimmed on the focused screen (Quickshell does not keep a
  monitor's focus up to date; the bar compares with the focused monitor now).
- The window pill showed the last window on an empty workspace, and the sound popup listed no apps.

## v2.3.0 (2026-10-01): the Quickshell bar and Claude by voice

The bar is drawn by Quickshell now, with popups for everything behind its pills, and Claude answers
by voice: [FEATURES.md](FEATURES.md#the-bar), [FEATURES.md](FEATURES.md#asking-claude).

### Added
- Ask Claude by voice (`SUPER + A`, tap or hold like dictation): whisper.cpp transcribes, `claude -p`
  answers, and the answer streams into a bubble at the top of the screen while Piper reads it out
  sentence by sentence. Timers and reminders (a gentle alarm that rings until a click or `SUPER + A`),
  calendar (read and add), weather, the screen (Claude looks at a screenshot), clipboard and typing
  into the active window, notes, media, volume, brightness, battery and system, updates, Bluetooth,
  do not disturb, lock, suspend, wallpaper, finding files, apps and web search. Claude may use only
  `notch/tools.py`, the screenshot and web search, and runs without your Claude Code settings. A
  question within two minutes continues the conversation; a click or a new question stops it. The
  bubble is part of the desktop shell and takes the wallpaper's colours. `home/.config/hypr/notch/`
  (the voice side) and `home/.config/quickshell/notch/` (the bubble); Piper and the voice install
  themselves into `~/.local/share` on first use. Settings: `NOTCH_*` in `personal/config`.
- Popups in the bar: the month with your events (click a day for its events), the weather of the next
  hours and days, media with cover, progress and every player, sound with outputs, microphones and a
  level per app, Wi-Fi networks, the battery with power profiles, Claude usage in detail, and tray menus
  in the bar's style. They open below the pill, slide from one to the next and close on a click
  elsewhere or `Esc`; `quickshell ipc -p ~/.config/quickshell call bar popup NAME` opens one from a key.
- `user-unit-retired` in the manifest: a user unit the kit dropped is switched off on every machine
  (at every sync run, also when its unit file is gone already).

### Changed
- The bar is a Quickshell shell now instead of Waybar
  ([ARCHITECTURE.md](ARCHITECTURE.md#8-the-bar-is-a-quickshell-shell)): one process
  (`driftless-shell.service`, `home/.config/quickshell`) draws the bars, their tooltips and popups and
  the Claude bubble, in one theme. Same pills, same order, same clicks; workspaces, window, sound,
  media, battery, network and tray come from Quickshell's services, so `feeds.py` and
  `driftless-bar.service` are gone. Theme, widget layout and bar size apply live, without a restart.
  The scripts moved from `~/.config/waybar` to `~/.config/quickshell/scripts` and print plain JSON;
  they tell the bar about changes with `scripts/poke NAME` instead of signals. `host/waybar.json` is
  `host/bar.json` now (the old name is still read).

### Fixed
- An update that changes driftless itself is applied by the new code: the sync reads `lib/` again
  after the update. Before, the code that started the run applied it and knew nothing of what came in
  (a new manifest kind, a new reload rule).

### Upgrading
- The sync does it: it links `~/.config/quickshell`, starts `driftless-shell.service` and switches
  Waybar and `driftless-bar.service` off (a sync still running v2.2.0's code finishes that on its next
  run; a drop-in keeps Waybar from starting in between). Your widget layout moves from
  `~/.local/state/waybar` to `~/.local/state/driftless-shell` by itself.
- `quickshell` is in the `desktop` group: the sync offers it in its password dialog.
- Waybar is in no list any more: `sudo pacman -Rns waybar` if you like.

## v2.2.0 (2026-09-30): the wallpaper menu

Pick a wallpaper from thumbnails with a large preview, get a new one every day, and see the colours
reach btop, VS Code and the terminal tools: [FEATURES.md](FEATURES.md#theme-from-the-wallpaper).

### Added
- The wallpaper menu (settings menu, *Wallpaper and colours*): the wallpaper folder with thumbnails
  and a large preview, plus a random, the previous or any other image. An elephant-menus menu
  (`elephant/menus/wallpapers.lua`) in a wider walker theme; the thumbnails come from
  `theme/thumbs.py` (cached in `~/.cache/theme/thumbs`). Without elephant-menus the plain list stays.
- `WALLPAPER_DIR` in `personal/config`: the wallpaper folder, e.g. one your cloud client syncs, to have
  the same wallpapers on every machine.
- A new wallpaper every day: `driftless-wallpaper-rotate.timer` runs `set-wallpaper --random` (an image
  from the folder, not the current one); a day the machine was off catches up after the next login.
- btop and VS Code in the wallpaper's colours: `apply.py` renders a btop theme and the VS Code theme
  "driftless" (2026 Dark with the accents, installed as a local `.vsix`). fastfetch (in Ghostty with
  your avatar as the logo), bat and fzf use Ghostty's accent slots.
- `ruff` in the `dev` group: `tests/lint.sh` needs it.
- Tests for `greeter-update` (`tests/greeter-update.bats`): links, oversized files and bad caller ids
  are refused, and the files are read with the caller's rights.

### Changed
- The wallpaper runs on awww (the successor of swww) instead of swaybg: a new image grows in as a
  circle from the mouse pointer while the colours change.
- The login screen follows a new wallpaper without a password prompt. `greeter-update` now reads the
  theme files with the caller's rights, which makes that safe
  ([ARCHITECTURE.md](ARCHITECTURE.md#4-system-files-are-a-package)).
- Screenshots are saved to `~/Pictures/Screenshots` instead of `~/Pictures`.
- CI lints with shellcheck 0.11.0, shfmt 3.14.1 and ruff 0.16.9, the versions Arch ships, so
  `tests/lint.sh` agrees locally.

### Upgrading
- The sync offers `awww` in its password dialog (or `driftless packages install`). `elephant-menus`
  is an AUR package: `driftless packages install` in a terminal.
- `driftless system`, which the sync reminds you of: the new `greeter-update` and its polkit rule.
- Then once: `systemctl --user restart driftless-wallpaper.service elephant.service` (or log in again)
  and `set-wallpaper --current`, which renders the btop, VS Code and walker themes.
- swaybg is in no list any more: `sudo pacman -Rs swaybg` if you like.

## v2.1.0 (2026-09-27): dictation and keybindings

Speak into any window, look up any key, and a tour of everything: [FEATURES.md](FEATURES.md).

### Added
- Dictation into the active window (`SUPER + D`, `hypr/dictate.py`, package group `dictation`):
  whisper.cpp and a small LLM from Ollama (`gemma3:4b`), both on the GPU through Vulkan. Tap to start
  and stop, or hold and let go; with `SHIFT` without the LLM. A pill next to the microphone shows the
  state. Settings `DICTATE_*` in `personal/config`.
- Keybindings in the settings menu and on `SUPER + SHIFT + K` (`hypr/keybinds.py`): every bind of the
  running Hyprland with its description, searchable in walker. Every bind in `hyprland.lua` has one now.
- Bar size in the settings menu: automatic (compact on notebook panels), always full or always
  compact, per machine.
- `FEATURES.md`: everything driftless sets up in one page, with the keys and screenshots; the README's
  list is shorter and points there.

### Changed
- The Monitors menu wins over the host file: a layout saved there overrides `hosts/<host>/hyprland.lua`.
- Waybar: the spacious bar has the pills and order of the compact one; one icon size and one gap in
  the icon pills.

### Upgrading
- Update first (`sudo pacman -Syu`): the sync installs the new group `dictation` with `pacman -S` only
  and never upgrades the system, which fails on an outdated package database.
- Then once: `sudo systemctl enable --now ollama`. The models (about 4 GB) download on the first
  dictation, or ahead of it with `ollama pull gemma3:4b`.

## v2.0.0 (2026-09-25): driftless

The kit is rebuilt around links instead of copies and renamed to driftless. The reasons, decision by
decision: [ARCHITECTURE.md](ARCHITECTURE.md). Moving a running v1 machine over:
[README](README.md#moving-over-from-arch-hyprland-kit-v1).

### Changed
- The home links into the repository (`~/.config/hypr` is `home/.config/hypr`). `snapshot.sh`, the
  deletion guessing, the per machine file list and the backup folders of the sync are gone.
- The sync commits only files the repository tracks, stops on changes that look like credentials,
  rebases instead of merging, and heals links that programs replaced by files.
- One manifest (`manifest`, `personal/manifest`, `hosts/<host>/manifest`) says what a machine gets:
  links, package groups, system and user units, chosen by hardware facts.
- Package lists are written by hand, in groups (`packages/*.list`); nothing is recorded from what a
  machine has. `driftless packages` shows what is installed but in no list.
- System files are the package `driftless-system`, all as drop-ins. greetd and smartd get their
  configuration through service drop-ins; no file of another package is edited with `sed`.
- The session runs under uwsm: Waybar, mako, hypridle, the polkit agent (now hyprpolkitagent),
  cliphist, the wallpaper and elephant are systemd user units.
- Waybar: one bar per output from Waybar's own `output` rules, so no watcher process. The workspace
  buttons, the window title and the media pill come from one process (`feeds.py`) instead of eleven.
- Personal values live in `personal/` and `hosts/`; publishing is leaving them out.

### Added
- `install-base.sh --encrypt`: LUKS2. New installs boot unified kernel images (`docs/boot.md`).
- `install/switch-to-uki.sh`, `install/migrate-from-rebuild.sh`, `install/migrate-system.sh`.
- `driftless verify` warns about a notebook without disk encryption.

## v1.6.0 (2026-09-25)

### Added
- Settings menu: a click on the avatar or the name in Waybar (or *Desktop Settings* in the app launcher) opens a walker menu for Waybar widgets, wallpaper, monitors and the kit sync (`waybar/settings-menu.sh`).
- Waybar widget manager (also `SUPER + SHIFT + B`, `waybar/widgets.py`): show and hide widgets, also single members of a group, and move them along the bar, with a separate order for the spacious and the compact bar. Stored per machine in `~/.local/state/waybar/layout.json`.
- Wallpaper menu: pick from `~/Pictures/Wallpapers`, choose any other image, or go back to the previous one.
- Monitor layout with nwg-displays, per machine in `~/.local/state/hypr/`. `hyprland.lua` loads it after its own rules.

### Changed
- The wallpaper and its colours are per machine now. The wallpaper and every file `theme/apply.py` renders from it are listed as `MACHINE_LOCAL` in `lib/lists.sh`: `snapshot.sh` never records them and the sync never applies them. A changed template or `apply.py` is rendered on each machine with its own colours. `restore.sh` renders the theme anew on a new install.
- The sync restarts `waybar/density-watch.py` when it changed. Before, the old renderer kept running until the next login.

### Fixed
- nwg-displays had no effect: it writes `monitors.lua`, which the Lua config never loaded. The unused `hypr/monitors.conf`, `monitors.lua` and `workspaces.conf` are gone from the kit.

## v1.5.1 (2026-09-24)

Found by installing the template in a fresh VM, following the README.

### Fixed
- On a fresh install the sync never recorded anything: git had no identity, so every commit failed. The kit now gives its own repository a machine identity (`rebuild-kit <host>`, an address ending in `.invalid`) when none is set. Machines with a git identity are unchanged.
- `restore.sh` asked for the password three times instead of once: makepkg runs `sudo -k`, which ignores the ticket, so bootstrapping yay asked twice more. If nobody was there to answer, the AUR step failed.
- In a VM without CPU microcode or GPU packages, `restore.sh` tried to install an empty package name and reported "hardware packages" as failed.
- `verify.sh` reported the user timers as not enabled when `restore.sh` ran it, since there is no user session then. It now checks the timer symlink. The calendar timer is only a hint, since the calendar is optional.
- The template no longer starts the Nextcloud client at login.

### Docs
- The live ISO has no git: the Quick start now installs it first.
- `restore.sh` turns on the firewall: when installing over SSH, allow SSH first.
- While the AUR step keeps the sudo ticket, a build script could use it as well (the same trade-off as `yay --sudoloop`); `--review-aur` shows every PKGBUILD first.

## v1.5.0 (2026-09-24)

### Fixed
- Since v1.4.0 the sync failed on every run in a kit without a notes folder, which is the default in this template. The new deletion check in `snapshot.sh` looked at `files/docs`, which does not exist then. The new tests found it.

### Added
- Tests (`tests/`, bats): the shared-list and deletion rules, `rebuild-install`'s argument check, and the sync itself, run with two simulated machines and a bare repository in a sandbox.
- CI on every push: shellcheck, shfmt, ruff and the tests.

### Changed
- All shell scripts are formatted with shfmt and all Python files with ruff. shellcheck and ruff report nothing. The formatting was checked to change no behaviour (`shfmt --minify` and the Python AST are identical before and after).
- `snapshot.sh` no longer stops on a machine without AUR packages.
- `restore.sh` and `install-base.sh` pass package lists as arrays instead of relying on word splitting.

## v1.4.1 (2026-09-24)

### Security
- `restore.sh` no longer writes a temporary `NOPASSWD: ALL` sudoers rule for the AUR step. If the script was killed at the wrong moment, that rule stayed and made the user root without a password. Now it asks for the user's password once at the start and keeps that sudo ticket alive until the AUR step is done; the keepalive stops at the latest a minute after the script ends. A leftover rule from an interrupted older run is removed, and `verify.sh` names it.

### Added
- `restore.sh --review-aur`: yay shows every PKGBUILD and asks before building. Without it, `restore.sh` says up front that the AUR packages are built without review.

### Fixed
- `restore.sh` reset `ufw` on every run, which deleted your own firewall rules. It now only sets the defaults while the firewall is not enabled yet.

## v1.4.0 (2026-09-24)

Changes after feedback on r/hyprland.

### Fixed
- A config file that one machine never had was deleted on all other machines. `snapshot.sh` rebuilt `files/home` from the machine's live files, so a folder missing there looked like a deletion, and the sync applied it everywhere. Now a missing file only counts as deleted if that machine had it before (`guard_deletions` in `lib/lists.sh`).
- `install-base.sh --help` printed two lines of code.

### Changed
- The default sync mode is now *review first*: a machine shows incoming changes and applies them only after *Sync now*. Machines that already have a mode keep it.
- Merge conflicts stop the sync. Before, the sync merged with `-X theirs`, so GitHub's side replaced local changes to the same lines without telling you. Now nothing is applied or pushed, and the sync pill and a notification name the files.
- `files/dconf.ini` leaves out window sizes and positions. They differ per screen and caused most of the noise and conflicts.
- Resuming a paused sync restores the previous mode instead of *automatic*.
- The README now says what the project is and isn't, compares it with alternatives and lists known limitations. Script comments are shorter.

### Added
- Before the sync replaces or deletes a file, it copies it to `~/.local/state/rebuild/backup/<time>/`. The last 10 runs are kept.

### Upgrade
Existing machines keep their current mode. To switch one to *review first*: sync pill menu → *Mode: review GitHub changes first*.

## v1.3.0 (2026-09-23)

### Security
- The sync only takes over commits signed by one of your machines (`lib/signing.sh`). A stolen GitHub token or login can still push, but nothing it pushes is applied. A compromised machine of yours is not covered, since its key signs.

## v1.2.0 (2026-09-23)

### Security
- The sync no longer runs pacman without a password. Missing packages come up in a polkit dialog (`pkexec rebuild-install`, package names only). The old sudoers rule let every process of the user run pacman as root.
- AUR packages are never built unattended; they wait until you install them in a terminal.

### Added
- Colour picker on `SUPER + K`.

## v1.1.2 (2026-09-23)

### Fixed
- The sync's pacman rule was overridden by the wheel rule, and the sync's failed sudo attempts could lock the account via pam_faillock.

## v1.1.1 (2026-09-23)

### Fixed
- After the sync restarted Waybar, every later run stopped with "already running": Waybar had inherited the sync's lock.

## v1.1.0 (2026-09-23)

### Added
- Sync pill in Waybar: state, incoming changes and new packages per machine; modes *automatic*, *review first* and *off*; a menu to control it.

## v1.0.2 (2026-09-23)

### Fixed
- The notifications module broke after the sync restarted Waybar (the sync's `LC_ALL=C` was inherited).

## v1.0.1 (2026-09-23)

### Fixed
- Waybar was killed when the sync restarted it, because it stayed in the sync service's cgroup.

## v1.0.0 (2026-09-23)

First public release: installer (`install-base.sh`, `restore.sh`, `verify.sh`), hourly sync between machines, hardware detection, Hyprland desktop with a wallpaper-based theme.

At that point the sync ran pacman without a password and built AUR packages unattended, so anyone who could push to the repository was root on every machine. v1.2.0 and v1.3.0 changed that.
