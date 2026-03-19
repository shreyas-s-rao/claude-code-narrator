---
name: cast
description: This skill should be used when the user asks to "change narrator voice", "set voice", "list voices", "narrator cast", "switch voice", "cast voice", or wants to change the text-to-speech voice used by narrator.
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

## Changing the Voice

If the user specifies a voice name (e.g., `/narrator:cast am_adam`), read `~/.claude-code-narrator/state` and use the Edit tool to change the `voice=` line to the requested voice.

IMPORTANT: Do NOT use `sed` to edit the state file — use the Read and Edit tools instead.

If the user does not specify a voice, present the list above and ask which voice they would like to use.

After changing the voice, speak a test sentence to confirm:

```bash
echo "This is how I sound with the new voice." | bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/speak.sh" --force
```

## Changing Speed

If the user asks to change speed, read `~/.claude-code-narrator/state` and use the Edit tool to change the `speed=` line to the new value.

IMPORTANT: Do NOT use `sed` to edit the state file — use the Read and Edit tools instead.

Valid speed range: 0.5 to 2.0. Default is 1.1.
