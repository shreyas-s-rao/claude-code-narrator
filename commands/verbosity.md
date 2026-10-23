---
description: Choose what the narrator speaks
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
---

# Change Narrator Verbosity

## Step 1: Determine Scope

Check if the user specified `--local` (e.g., `/narrator:verbosity final --local`). If so, changes apply to the **local** config file in the current working directory.

- **Global** (default): `~/.claude-code-narrator/config`
- **Local** (`--local`): `<cwd>/.claude-code-narrator/config`

## Step 2: Get the Level

Valid levels:

- **minimal** — Tool descriptions only ("Reading file settings dot json.")
- **normal** — Tool descriptions + final response
- **verbose** — Tool descriptions + text between tool calls + final response + notifications (default)
- **final** — Final response only

If the user provides a level (e.g., `/narrator:verbosity normal`), use it. If it is not one of the four, tell the user the valid levels and ask them to pick one.

If no level is provided, read the current `verbosity=` value from the appropriate config file (local if it exists and has a verbosity key, otherwise global; `verbose` if neither has one) and show it to the user. Then ask which level they would like using AskUserQuestion with the four options above.

## Step 3: Set the Level

### Global mode (no `--local`):

Read `~/.claude-code-narrator/config`. Use the Edit tool to change the `verbosity=` line to the new level, or add a `verbosity=<level>` line if there is none.

### Local mode (`--local`):

Read `<cwd>/.claude-code-narrator/config`. If the file exists, use the Edit tool to change or add the `verbosity=` line. If the file does not exist, create the `<cwd>/.claude-code-narrator/` directory if needed, then create the `config` file with the Write tool containing just `verbosity=<level>`.

IMPORTANT: Do NOT use `sed` to edit state files — use the Read and Edit tools instead.

## Step 4: Confirm

Tell the user the new level and what they will hear at it. The change applies from the next hook that fires; no restart is needed.
