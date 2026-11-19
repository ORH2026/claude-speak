---
description: Choose the speech engine on Windows (system voice or Fish Audio), set the Fish voice, or set the Fish daily cap
argument-hint: [fish|system|status|voice <id>|voice reset|cap <chars>]
---

Based on the argument, do exactly one of the following via Bash, then report the result in one short sentence:

- **No argument or `status`**: run `cat ~/.claude/claude-speak/engine 2>/dev/null || echo system; cat ~/.claude/claude-speak/fish-voice 2>/dev/null; cat ~/.claude/claude-speak/fish-daily-cap 2>/dev/null || echo 20000; cat ~/.claude/claude-speak/fish-usage-$(date +%Y%m%d).txt 2>/dev/null || echo 0; cat ~/.claude/claude-speak/last-engine.txt 2>/dev/null` and report: engine, Fish voice (or "Fish default"), daily cap, characters used today, and which engine spoke last. Never print the API key.
- **`fish`**: `mkdir -p ~/.claude/claude-speak && echo fish > ~/.claude/claude-speak/engine`. Then check the key exists without printing it: `powershell.exe -NoProfile -Command "if ([Environment]::GetEnvironmentVariable('FISH_API_KEY','User')) {'key found'} else {'key missing'}"`. If missing, say Fish will fall back to the system voice until FISH_API_KEY is set.
- **`system`**: `rm -f ~/.claude/claude-speak/engine`
- **`voice <id>`**: the id is a Fish voice model id (from the voice's page on fish.audio). Only letters, digits and dashes are allowed; otherwise refuse. `mkdir -p ~/.claude/claude-speak && echo "<id>" > ~/.claude/claude-speak/fish-voice`
- **`voice reset`**: `rm -f ~/.claude/claude-speak/fish-voice`
- **`cap <chars>`**: a positive whole number only. `mkdir -p ~/.claude/claude-speak && echo <chars> > ~/.claude/claude-speak/fish-daily-cap`
- **Anything else**: write nothing and list the accepted forms.

Fish is used only on Windows. If Fish fails, is over the daily cap, or has no key, that reply is spoken with the system voice instead. There are no retries.
