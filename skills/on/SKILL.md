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

## Step 2: Register Auto-Hush Hook

Read `~/.claude/settings.json`. If it does not have a `UserPromptSubmit` hook that runs `hush-on-input.sh`, add one. This hook silences speech when the user provides input.

Use the Edit tool to add the following to the `hooks` object in `~/.claude/settings.json` (create the `hooks` key if it doesn't exist, and merge with any existing hooks):

```json
"UserPromptSubmit": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/hush-on-input.sh",
        "timeout": 3
      }
    ]
  }
]
```

IMPORTANT: Do NOT replace existing hooks — merge with them. Read the file first.

## Step 3: Confirm

Inform the user: "Narrator is now enabled. I will speak responses aloud using the af_heart voice."

Then speak a test confirmation. This will auto-install Kokoro TTS into a dedicated venv on first run (may take a few minutes):

```bash
echo "Narrator is now active." | bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/speak.sh" --force
```
