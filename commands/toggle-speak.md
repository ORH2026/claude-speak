---
description: Turn automatic speaking of every response on or off (no argument flips it)
argument-hint: [on|off|status]
---

Run this exact command via Bash, passing the argument the user gave (`on`, `off` or `status`; leave it out to flip the current setting), and report the result to the user in one short sentence:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/toggle-speak.sh" $ARGUMENTS
```

Do not do anything else — just run the command and relay whether it is now ON or OFF. Turning it OFF also stops anything being spoken right now.
