---
name: on
description: This skill should be used when the user asks to "enable narrator", "turn on voice", "start narrator", "enable voice output", "narrator on", or wants to activate text-to-speech output for Claude Code responses.
---

# Enable Narrator Voice Output

To enable narrator voice output, perform the following steps in order:

## Step 1: Enable Narrator State

Read `/tmp/claude-narrator-state`. If the file exists, use the Edit tool to change the `enabled=` line to `enabled=true` (preserve the existing voice and speed settings). If the file does not exist, create it with the Write tool:

```
enabled=true
voice=af_heart
speed=1.1
```

IMPORTANT: Do NOT use `sed` to edit the state file — use the Read and Edit tools instead.

## Step 2: Confirm

Inform the user: "Narrator is now enabled. I will speak responses aloud using the af_heart voice."

Then speak a test confirmation. This will auto-install Kokoro TTS into a dedicated venv on first run (may take a few minutes):

```bash
echo "Narrator is now active." | bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/speak.sh" --force
```
