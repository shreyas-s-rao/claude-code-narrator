---
name: verbosity
description: This skill should be used when the user asks to "only read the final response", "stop narrating tool calls", "only narrate tool calls", "narrate everything", "less verbose", "more verbose", "change verbosity", or wants to control which events narrator speaks.
---

# Change Narrator Verbosity

## Step 1: Determine Scope

Check if the user said "locally", "for this directory", "for this project", or similar. If so, changes apply to the **local** config file in the current working directory.

- **Global** (default): `~/.claude-code-narrator/config`
- **Local**: `<cwd>/.claude-code-narrator/config`

## Step 2: Get the Level

Valid levels:

- **minimal** — Tool descriptions only ("Reading file settings dot json.")
- **normal** — Tool descriptions + final response
- **verbose** — Tool descriptions + text between tool calls + final response + notifications (default)
- **final** — Final response only

If the user names a level or describes one (e.g., "only the final response" → final, "just tool calls" → minimal), use it. If it is not one of the four, tell the user the valid levels and ask them to pick one.

If no level is given, read the current `verbosity=` value from the appropriate config file (local if it exists and has a verbosity key, otherwise global; `verbose` if neither has one) and show it to the user. Then ask which level they would like using AskUserQuestion with the four options above.

## Step 3: Set the Level

### Global mode (default):

Read `~/.claude-code-narrator/config`. Use the Edit tool to change the `verbosity=` line to the new level, or add a `verbosity=<level>` line if there is none.

### Local mode:

Read `<cwd>/.claude-code-narrator/config`. If the file exists, use the Edit tool to change or add the `verbosity=` line. If the file does not exist, create the `<cwd>/.claude-code-narrator/` directory if needed, then create the `config` file with the Write tool containing just `verbosity=<level>`.

IMPORTANT: Do NOT use `sed` to edit state files — use the Read and Edit tools instead.

## Step 4: Confirm

Tell the user the new level and what they will hear at it. The change applies from the next hook that fires; no restart is needed.
