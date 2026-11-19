#!/bin/bash
# Stops speech that is playing right now. Used by /speak-stop, by
# /toggle-speak when turning speech off, and by speak-say.sh before a new
# reply starts so two replies never talk over each other.
#
# Windows: kills the PowerShell speaker recorded in speaker.pid, but only if
# that pid still belongs to a powershell process (a reused pid is left alone).
# macOS / Linux: stops a running `say` / espeak started by this user.

PID_FILE="$HOME/.claude/claude-speak/speaker.pid"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    [ -s "$PID_FILE" ] || exit 0
    pid="$(tr -dc '0-9' < "$PID_FILE")"
    rm -f "$PID_FILE"
    [ -n "$pid" ] || exit 0
    powershell.exe -NoProfile -NonInteractive -Command \
      "Get-Process -Id $pid -ErrorAction SilentlyContinue | Where-Object { \$_.ProcessName -eq 'powershell' } | Stop-Process -Force" \
      >/dev/null 2>&1
    ;;
  Darwin)
    pkill -x say >/dev/null 2>&1
    ;;
  Linux)
    pkill -x espeak-ng >/dev/null 2>&1
    pkill -x espeak >/dev/null 2>&1
    ;;
esac
exit 0
