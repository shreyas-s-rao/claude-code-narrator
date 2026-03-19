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

If the user specifies a voice name (e.g., `/narrator:cast am_adam`), update the state file:

```bash
sed -i'' 's/^voice=.*/voice=VOICE_NAME/' /tmp/claude-narrator-state
```

Replace `VOICE_NAME` with the requested voice identifier.

If the user does not specify a voice, present the list above and ask which voice they would like to use.

After changing the voice, speak a test sentence to confirm:

```bash
echo "This is how I sound with the new voice." | bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/speak.sh" --force
```

## Changing Speed

If the user asks to change speed, update the speed value in the state file:

```bash
sed -i'' 's/^speed=.*/speed=NEW_SPEED/' /tmp/claude-narrator-state
```

Valid speed range: 0.5 to 2.0. Default is 1.1.
