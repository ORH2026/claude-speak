#!/bin/bash
# Turns automatic speech on or off. Usage: toggle-speak.sh [on|off|toggle|status]
# (default: toggle). Speech is ON while ~/.claude/claude-speak/enabled exists.
# Turning it off also stops anything being spoken right now.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$HOME/.claude/claude-speak"
FLAG="$STATE_DIR/enabled"
mkdir -p "$STATE_DIR"

action="${1:-toggle}"
if [ "$action" = "toggle" ]; then
  if [ -f "$FLAG" ]; then action="off"; else action="on"; fi
fi

case "$action" in
  on)
    touch "$FLAG"
    echo "toggle-speak: ON"
    ;;
  off)
    rm -f "$FLAG"
    "$DIR/speak-stop.sh"
    echo "toggle-speak: OFF"
    ;;
  status)
    if [ -f "$FLAG" ]; then echo "toggle-speak: ON"; else echo "toggle-speak: OFF"; fi
    ;;
  *)
    echo "usage: toggle-speak.sh [on|off|toggle|status]" >&2
    exit 2
    ;;
esac
