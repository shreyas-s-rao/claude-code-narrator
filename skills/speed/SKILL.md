---
name: speed
description: This skill should be used when the user asks to "change speed", "set speed", "talk faster", "talk slower", "speed up", "slow down", "narrator speed", or wants to change the text-to-speech speech rate used by narrator.
---

# Change Narrator Speech Speed

## Step 1: Determine Scope

Check if the user said "locally", "for this directory", "for this project", or similar. If so, changes apply to the **local** config file in the current working directory.

- **Global** (default): `~/.claude-code-narrator/config`
- **Local**: `<cwd>/.claude-code-narrator/config`

## Step 2: Get the Speed Value

If the user specifies a speed value (e.g., "set speed to 1.5"), use that value. Valid range is **0.5 to 2.0**. Default is **1.1**.

If the user says "faster" or "speed up", read the current speed and increase it by 0.2 (capped at 2.0).
If the user says "slower" or "slow down", read the current speed and decrease it by 0.2 (minimum 0.5).

If the value is outside the valid range, tell the user the valid range and ask them to pick a value.

If no specific value or direction is given, read the current speed from the appropriate config file (local if it exists and has a speed key, otherwise global) and show it to the user. Then ask what speed they would like using AskUserQuestion with these options:

- **0.7** — Slow, deliberate
- **1.0** — Natural pace
- **1.1** — Default
- **1.5** — Brisk

The user can also type a custom value.

## Step 3: Set the Speed

### Global mode (default):

Read `~/.claude-code-narrator/config` and use the Edit tool to change the `speed=` line to the new value.

### Local mode:

Read `<cwd>/.claude-code-narrator/config`. If the file exists, use the Edit tool to change or add the `speed=` line. If the file does not exist, create the `<cwd>/.claude-code-narrator/` directory if needed, then create the `config` file with the Write tool containing just `speed=<value>`.

IMPORTANT: Do NOT use `sed` to edit state files — use the Read and Edit tools instead.

## Step 4: Confirm

Tell the user the new speed value, then speak a test sentence so they can hear the difference:

```bash
echo "This is how I sound at the new speed." | bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/speak.sh" --force
```
