#!/usr/bin/env bash
# Sync Nextcloud calendars. On failure: one desktop notification (per failure streak) and a
# state file that makes the calendar in the bar show a warning. On success the state is cleared.
STATE="${XDG_CACHE_HOME:-$HOME/.cache}/calendar-sync-failed"
VDIR="${VDIRSYNCER:-vdirsyncer}"

SYNC_ID="string:x-canonical-private-synchronous:calendar-sync"
# keep vdirsyncer's messages for the journal, and to tell a missing password from other errors
sync() { out=$("$VDIR" sync 2>&1) && out+=$'\n'$("$VDIR" metasync 2>&1); }
sync
ok=$?
# the config came changed with the repository: vdirsyncer refuses until discover ran again
if ((ok)) && grep -q 'Detected change in config file' <<< "$out"; then
  out=$(yes | "$VDIR" discover 2>&1) && sync
  ok=$?
fi
[[ -n $out ]] && printf '%s\n' "$out" >&2
if ((ok == 0)); then
  # recovered: replace the sticky failure notification by a short-lived one
  [[ -e $STATE ]] && notify-send -h "$SYNC_ID" -u normal -t 4000 "Calendar sync restored" "<small>$(date +%H:%M)</small>" 2> /dev/null
  rm -f "$STATE"
else
  # password.fetch failed: the command that reads the keyring did not start, or it failed
  if grep -qE "Failed to execute command|Command '\[.*\]' returned non-zero" <<< "$out"; then
    reason="Keyring locked or app password missing (log in again or run calendar-login)"
  else
    reason="vdirsyncer sync failed (run: vdirsyncer sync)"
  fi
  if [[ ! -e $STATE ]]; then
    notify-send -h "$SYNC_ID" -u critical "Calendar sync failed" "$reason"$'\n'"<small>$(date +%H:%M)</small>" 2> /dev/null || true
  fi
  printf '%s\n' "$reason" > "$STATE"
fi
"$(dirname "$(readlink -f "$0")")/poke" calendar
[[ ! -e $STATE ]]
