---
description: Change narrator voice or speed
allowed-tools: Bash, Read, Edit, AskUserQuestion
---

# Change Narrator Voice

## Available Voices

Kokoro provides these voices:

**Female voices:**
- `af_heart` (default) - warm, expressive
- `af_bella` - clear, professional
- `af_nicole` - soft, gentle
- `af_sarah` - bright, energetic
- `af_sky` - calm, composed

**Male voices:**
- `am_adam` - deep, authoritative
- `am_michael` - warm, friendly
- `am_fenrir` - bold, commanding

## Determine Scope

Check if the user specified `--local` (e.g., `/narrator:cast --local am_adam`). If so, changes apply to the **local** config file in the current working directory.

- **Global** (default): `~/.claude-code-narrator/config`
- **Local** (`--local`): `<cwd>/.claude-code-narrator/config`

## Changing the Voice

If the user specifies a voice name (e.g., `/narrator:cast am_adam`), read the appropriate state file and use the Edit tool to change or add the `voice=` line to the requested voice.

### Global mode (no `--local`):

Read `~/.claude-code-narrator/config` and use the Edit tool to change the `voice=` line.

### Local mode (`--local`):

Read `<cwd>/.claude-code-narrator/config`. If the file exists, use the Edit tool to change or add the `voice=` line. If the file does not exist, create the `<cwd>/.claude-code-narrator/` directory if needed, then create the `config` file with the Write tool containing just `voice=<requested_voice>`.

IMPORTANT: Do NOT use `sed` to edit state files — use the Read and Edit tools instead.

If the user does not specify a voice, present the list above and ask which voice they would like to use.

After changing the voice, speak a test sentence to confirm:

```bash
echo "This is how I sound with the new voice." | bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/speak.sh" --force
```

## Changing Speed

If the user asks to change speed, read the appropriate state file and use the Edit tool to change or add the `speed=` line to the new value.

For local mode, if the file does not exist, create the `<cwd>/.claude-code-narrator/` directory if needed, then create the `config` file with the Write tool containing just `speed=<value>`.

IMPORTANT: Do NOT use `sed` to edit state files — use the Read and Edit tools instead.

Valid speed range: 0.5 to 2.0. Default is 1.1.
