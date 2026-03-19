---
description: Disable narrator voice output
allowed-tools: Bash, Read, Edit, Write
---

# Disable Narrator Voice Output

To disable narrator voice output:

## Step 1: Update State File

Read `/tmp/claude-narrator-state`. If the file exists, use the Edit tool to change the `enabled=` line to `enabled=false`. If the file does not exist, create it with the Write tool containing just `enabled=false`.

IMPORTANT: Do NOT use `sed` to edit the state file — use the Read and Edit tools instead.

## Step 2: Remove Auto-Hush Hook

Read `~/.claude/settings.json`. If it has a `UserPromptSubmit` hook that runs `hush-on-input.sh`, remove that entire `UserPromptSubmit` entry from the `hooks` object. Preserve all other hooks.

IMPORTANT: Do NOT remove other hooks — only remove the narrator `UserPromptSubmit` hook. Read the file first.

## Step 3: Confirm

Inform the user: "Narrator is now disabled. Voice output is off."

Do NOT attempt to speak this confirmation (narrator is now off).
