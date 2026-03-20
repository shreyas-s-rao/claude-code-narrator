---
description: Change narrator speech speed
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
---

# Change Narrator Speech Speed

## Step 1: Determine Scope

Check if the user specified `--local` (e.g., `/narrator:speed 1.5 --local`). If so, changes apply to the **local** config file in the current working directory.

- **Global** (default): `~/.claude-code-narrator/config`
- **Local** (`--local`): `<cwd>/.claude-code-narrator/config`

## Step 2: Get the Speed Value

If the user provides a speed value (e.g., `/narrator:speed 1.5`), use that value. Valid range is **0.5 to 2.0**. Default is **1.1**.

If the value is outside the valid range, tell the user the valid range and ask them to pick a value.

If no value is provided, read the current speed from the appropriate config file (local if it exists and has a speed key, otherwise global) and show it to the user. Then ask what speed they would like using AskUserQuestion with these options:

- **0.7** — Slow, deliberate
- **1.0** — Natural pace
- **1.1** — Default
- **1.5** — Brisk

The user can also type a custom value.

## Step 3: Set the Speed

### Global mode (no `--local`):

Read `~/.claude-code-narrator/config` and use the Edit tool to change the `speed=` line to the new value.

### Local mode (`--local`):

Read `<cwd>/.claude-code-narrator/config`. If the file exists, use the Edit tool to change or add the `speed=` line. If the file does not exist, create the `<cwd>/.claude-code-narrator/` directory if needed, then create the `config` file with the Write tool containing just `speed=<value>`.

IMPORTANT: Do NOT use `sed` to edit state files — use the Read and Edit tools instead.

## Step 4: Confirm

Tell the user the new speed value, then speak a test sentence so they can hear the difference:

```bash
echo "This is how I sound at the new speed." | bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/speak.sh" --force
```
