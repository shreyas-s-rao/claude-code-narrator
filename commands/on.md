---
description: Enable narrator voice output
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
---

# Enable Narrator Voice Output

To enable narrator voice output, perform the following steps in order:

## Step 1: Determine Scope

Check if the user specified `--local` (e.g., `/narrator:on --local`). If so, all state changes apply to a **local** config file in the current working directory instead of the global one.

- **Global** (default): `~/.claude-code-narrator/config`
- **Local** (`--local`): `<cwd>/.claude-code-narrator/config`

## Step 2: Enable Narrator State

### Global mode (no `--local`):

Read `~/.claude-code-narrator/config`. If the file exists, use the Edit tool to change the `enabled=` line to `enabled=true` (preserve the existing voice and speed settings). If the file does not exist, create it with the Write tool:

```
enabled=true
voice=af_heart
speed=1.1
```

### Local mode (`--local`):

Read `<cwd>/.claude-code-narrator/config`. If the file exists, use the Edit tool to change or add `enabled=true`. If the file does not exist, create the `<cwd>/.claude-code-narrator/` directory if needed, then create the `config` file with the Write tool containing just `enabled=true`. Do NOT include voice or speed unless the user specifies them — missing keys fall back to the global state.

IMPORTANT: Do NOT use `sed` to edit state files — use the Read and Edit tools instead.

## Step 3: Register Auto-Hush Hook

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

## Step 4: Confirm

For global mode, inform the user: "Narrator is now enabled. I will speak responses aloud using the af_heart voice."

For local mode, inform the user: "Narrator is now enabled for this directory. Voice and speed will fall back to global settings unless overridden locally with `/narrator:cast --local`."

Also remind the user to add the local config to their gitignore if they haven't already:

> Tip: Add the local config to your `.gitignore` so it's not committed:
> ```
> echo .claude-code-narrator >> .gitignore
> ```

Then speak a test confirmation. This will auto-install Kokoro TTS into a dedicated venv on first run (may take a few minutes):

```bash
echo "Narrator is now active." | bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/speak.sh" --force
```
