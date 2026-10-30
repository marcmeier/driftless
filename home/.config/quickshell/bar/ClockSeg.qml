import QtQuick
import Quickshell
import qs.services

// Time and date, then the next event within two days (khal, scripts/agenda.py; compact: only an accent
// dot). The tooltip carries the agenda. Click: the month with your events (sync and ikhal there too) ·
// right click: ikhal (add and edit events).
Seg {
    id: seg

    readonly property var cal: Feeds.calendar.value
    readonly property var next: cal ? cal.next : null
    readonly property bool failed: !!(cal && cal.error)
    readonly property string event: next ? (next.when ? next.when + " " : "") + next.title : ""

    padL: compact ? 10 : 12
    padR: compact ? 10 : 12
    spacing: compact ? 8 : 10

    SystemClock {
        id: clock
        precision: Prefs.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // ISO 8601 week
    function week(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
    }

    function agendaTip() {
        const lines = [Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy") + `<font color='${Theme.dim}'>  ·  week ${week(clock.date)}</font>`];
        if (!cal)
            return lines[0];
        lines.push("");
        if (cal.error)
            lines.push(`<font color='${Theme.warn}'>⚠ Sync failed: ${Apps.esc(cal.error)}</font>`, "");
        const days = (cal.agenda || []).slice(0, 3);
        if (!days.length)
            lines.push(`<font color='${Theme.dim}'>No events in the next days</font>`);
        for (const day of days) {
            lines.push(`<b>${day.label}</b> <font color='${Theme.dim}'>${day.sub}</font>`);
            for (const e of day.events) {
                const time = e.allDay ? "all day" : e.continued ? "until " + e.end : e.start;
                lines.push(`&nbsp;&nbsp;<font color='${Theme.dim}'>${time}</font>&nbsp;&nbsp;${Apps.esc(e.title)}`);
            }
        }
        lines.push("", `<font color='${Theme.dim}'>Click: month  ·  Right: ikhal</font>`);
        return lines.join("<br>");
    }
    tip: agendaTip()

    onClicked: button => {
        if (button === Qt.RightButton)
            Actions.script("ikhal.sh");
        else
            togglePopup();
    }

    popupKey: "calendar"
    popupComponent: Component {
        CalendarPopup {}
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        // 24 or 12 hours, seconds: the settings (Bar > Clock)
        text: Qt.formatDateTime(clock.date, (Prefs.clock24 ? "HH:mm" : "h:mm") + (Prefs.clockSeconds ? ":ss" : "")
                                + (Prefs.clock24 ? "" : " AP"))
        bold: true
        font.pixelSize: seg.compact ? 13 : 14
        font.letterSpacing: seg.compact ? 0.5 : 1
    }
    Label {
        visible: Prefs.clockDate
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        text: Qt.formatDateTime(clock.date, "ddd dd MMM")
        small: true
        dim: true
        font.weight: Font.Normal
    }

    // the next event: a dot in the accent (amber when the sync failed), then what and when
    Rectangle {
        visible: seg.event !== "" || seg.failed
        anchors.verticalCenter: parent.verticalCenter
        width: 5
        height: 5
        color: seg.failed ? Theme.warn : Theme.accent
    }
    Label {
        visible: !seg.compact && seg.event !== ""
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        width: Math.min(implicitWidth, 240)
        elide: Text.ElideRight
        text: seg.event
        small: true
        font.weight: Font.Normal
        color: Theme.text
    }
}
