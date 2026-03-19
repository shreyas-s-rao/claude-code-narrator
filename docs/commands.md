# Commands

## `/narrator:on`

Enable narrator voice output. Hooks will automatically speak responses, tool actions, and notifications.

On first run, Kokoro TTS and all dependencies are auto-installed into a dedicated venv (`~/.claude-narrator-venv`). This may take a few minutes.

**What it does:**
1. Writes `enabled=true` to the state file (`~/.claude-code-narrator/state`), preserving existing voice and speed settings
2. Speaks a test confirmation ("Narrator is now active") to verify audio is working

**Example:**
```
/narrator:on
```

---

## `/narrator:off`

Disable narrator voice output. Hooks will no longer trigger speech.

**What it does:**
1. Sets `enabled=false` in the state file
2. Does not attempt to speak a confirmation (narrator is off)

**Example:**
```
/narrator:off
```

---

## `/narrator:cast`

Change the narrator voice or speech speed.

**Usage:**
```
/narrator:cast [voice_name]
```

If no voice name is given, the available voices are listed and you're asked to pick one.

**Available voices:**

| Voice | Gender | Description |
|-------|--------|-------------|
| `af_heart` | Female | Warm, expressive (default) |
| `af_bella` | Female | Clear, professional |
| `af_nicole` | Female | Soft, gentle |
| `af_sarah` | Female | Bright, energetic |
| `af_sky` | Female | Calm, composed |
| `am_adam` | Male | Deep, authoritative |
| `am_michael` | Male | Warm, friendly |
| `am_fenrir` | Male | Bold, commanding |

After switching, a test sentence is spoken in the new voice.

**Speed:** You can also ask to change speed (valid range: 0.5–2.0, default: 1.1).

**Examples:**
```
/narrator:cast am_adam
/narrator:cast                # lists voices and prompts for selection
```

---

## `/narrator:speak`

Speak text aloud on demand, regardless of whether narrator is currently enabled.

**Usage:**
```
/narrator:speak [text]
```

If no text is provided, a summary of the last action or response is spoken. The `--force` flag is used internally to bypass the enabled check.

**Examples:**
```
/narrator:speak
/narrator:speak Hello, world!
```

---

## `/narrator:hush`

Immediately stop all current and queued speech. The daemon is killed and the FIFO is removed.

Narrator stays enabled after hushing — only the current playback is silenced. New speech will resume on the next hook-triggered action. The daemon restarts automatically.

To disable narrator entirely, use `/narrator:off` instead.

**Example:**
```
/narrator:hush
```
