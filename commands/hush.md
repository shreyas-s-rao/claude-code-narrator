---
description: Silence all current and queued speech
allowed-tools: Bash
---

# Silence Narrator Immediately

Stop all current and queued speech output immediately.

## Steps

Run the following commands to kill all speech processes and clean up:

```bash
# Kill the speak daemon if running
if [ -f /tmp/claude-speak-daemon.pid ]; then
    kill $(cat /tmp/claude-speak-daemon.pid) 2>/dev/null || true
    rm -f /tmp/claude-speak-daemon.pid
fi

# Kill any running kokoro-speak.py processes
pkill -f kokoro-speak.py 2>/dev/null || true

# Remove the FIFO to clear any queued messages
rm -f /tmp/claude-speak-fifo
```

## After Hushing

Narrator remains enabled after hushing -- only the current and queued speech is stopped. New hook-triggered speech will resume when Claude's next action fires a hook. The daemon will be restarted automatically by speak.sh when the next speech is enqueued.

If the user wants to disable narrator entirely (not just silence current speech), suggest using `/narrator:off` instead.

Inform the user: "Silenced. Narrator is still enabled and will speak on the next action."
