pragma Singleton

import Quickshell
import QtQuick

// A glyph and a short name per app (by its window class / app id); first match wins.
Singleton {
    readonly property var table: [
        [/ghostty/i, "\u{F018D}", "Ghostty"],
        [/brave/i, "\u{F059F}", "Brave"],
        [/steam/i, "\u{F04D3}", "Steam"],
        [/discord/i, "\u{F066F}", "Discord"],
        [/^(code|code-oss|vscodium)/i, "\u{F0A1E}", "VS Code"],
        [/lutris/i, "\u{F0297}", "Lutris"],
        [/battle\.net|diablo/i, "\u{F0297}", "Battle.net"],
        [/pwvucontrol|pavucontrol/i, "\u{F057E}", "Volume"],
        [/spotify/i, "\u{F04C7}", "Spotify"],
        [/firefox/i, "\u{F0239}", "Firefox"],
        [/thunar|nautilus|dolphin|pcmanfm/i, "\u{F024B}", "Files"],
        [/obsidian/i, "\u{F082E}", "Obsidian"],
        [/nextcloud/i, "\u{F0163}", "Nextcloud"],
        [/libreoffice/i, "\u{F0219}", "LibreOffice"],
        [/loupe|eog|imv/i, "\u{F02E9}", "Images"],
        [/evince|zathura|okular/i, "\u{F0226}", "Documents"],
    ]

    function lookup(cls) {
        for (const [rx, glyph, name] of table)
            if (rx.test(cls))
                return { glyph: glyph, name: name };
        const name = (cls.split(".").pop() || "").replace(/[-_]/g, " ").trim()
                     .replace(/\b\w/g, c => c.toUpperCase());
        return { glyph: "\u{F05B2}", name: name || "Window" };
    }

    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // A notification body is shown as StyledText, and Qt loads an <img> from any address: a tracking
    // pixel, or a request to a device in the local network. The tag goes, the text stays.
    function safeMarkup(s) {
        return String(s).replace(/<\s*img\b[^>]*(?:>|$)/gi, "");
    }

    // only pictures from this machine (a file, or one the shell itself provides): a web address given
    // as a notification's icon or image would make the shell fetch it
    function localUrl(u) {
        return !u || !u.includes("://") || /^(file|image):\/\//.test(u) ? u : "";
    }
}
