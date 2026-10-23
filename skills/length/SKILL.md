---
name: length
description: This skill should be used when the user asks to "read the whole response", "read long responses in full", "don't cut off responses", "only read a summary", "change response length", or wants to control how much of the final response narrator speaks.
---

# Change Narrator Response Length

## Step 1: Determine Scope

Check if the user said "locally", "for this directory", "for this project", or similar. If so, changes apply to the **local** config file in the current working directory.

- **Global** (default): `~/.claude-code-narrator/config`
- **Local**: `<cwd>/.claude-code-narrator/config`

## Step 2: Get the Value

Valid values:

- **summary** — The first ~1000 characters of the final response, ending at a sentence boundary (default)
- **full** — The whole final response

If the user names a value or describes one (e.g., "read it all" → full), use it. If it is not one of the two, tell the user the valid values and ask them to pick one.

If no value is given, read the current `length=` value from the appropriate config file (local if it exists and has a length key, otherwise global; `summary` if neither has one) and show it to the user. Then ask which they would like using AskUserQuestion with the two options above.

## Step 3: Set the Value

### Global mode (default):

Read `~/.claude-code-narrator/config`. Use the Edit tool to change the `length=` line to the new value, or add a `length=<value>` line if there is none.

### Local mode:

Read `<cwd>/.claude-code-narrator/config`. If the file exists, use the Edit tool to change or add the `length=` line. If the file does not exist, create the `<cwd>/.claude-code-narrator/` directory if needed, then create the `config` file with the Write tool containing just `length=<value>`.

IMPORTANT: Do NOT use `sed` to edit state files — use the Read and Edit tools instead.

## Step 4: Confirm

Tell the user the new value. For `full`, mention that `/narrator:hush` stops a long response at any point. Plan-mode responses are always spoken in full, whatever this setting.
