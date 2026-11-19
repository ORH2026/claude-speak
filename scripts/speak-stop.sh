#!/bin/bash
# Stops speech that is playing right now. Used by /speak-stop, by
# /toggle-speak when turning speech off, and by speak-say.sh before a new
# reply starts so two replies never talk over each other.
#
# Windows only: kills the PowerShell speaker recorded in speaker.pid, and
# only if that process's command line is still windows-say.ps1, so a reused
# pid (for example the user's own PowerShell window) is never touched.
# macOS / Linux: no-op, so it never kills speech started by anything else.

PID_FILE="$HOME/.claude/claude-speak/speaker.pid"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    [ -s "$PID_FILE" ] || exit 0
    pid="$(tr -dc '0-9' < "$PID_FILE")"
    rm -f "$PID_FILE"
    [ -n "$pid" ] || exit 0
    powershell.exe -NoProfile -NonInteractive -Command \
      "Get-CimInstance Win32_Process -Filter 'ProcessId=$pid' | Where-Object { \$_.CommandLine -like '*windows-say.ps1*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" \
      >/dev/null 2>&1
    ;;
esac
exit 0
