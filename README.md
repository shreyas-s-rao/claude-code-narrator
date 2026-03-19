# Narrator - Voice Output Plugin for Claude Code

A Claude Code plugin that speaks responses aloud using [Kokoro](https://github.com/hexgrad/kokoro) TTS, a local neural text-to-speech engine. No cloud APIs, no latency -- everything runs on your machine.

## Installation

### Prerequisites

- Python 3.8+
- macOS with audio output (speakers or headphones)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

### Install Kokoro TTS

```bash
pip3 install kokoro sounddevice numpy
```

### Load the Plugin

```bash
claude --plugin-dir /path/to/claude-code-narrator
```

Or add to your Claude Code settings for permanent use.

## Usage

### Enable Narrator

```
/narrator:on
```

This checks that Kokoro is installed, enables voice output, and speaks a test confirmation.

### Disable Narrator

```
/narrator:off
```

Turns off automatic voice output. Hooks will no longer trigger speech.

### Change Voice

```
/narrator:voice am_adam
```

Or just `/narrator:voice` to see available voices and pick one.

### Speak On-Demand

```
/narrator:speak
```

Speaks a summary of the last action, even if narrator is currently off. You can also provide text: `/narrator:speak Hello world`.

### Silence Immediately

```
/narrator:hush
```

Kills all current and queued speech instantly. Narrator stays enabled -- it will resume speaking on the next action.

## Available Voices

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

## Architecture

```
Hook fires → speak.sh → FIFO pipe → speak-daemon.sh → kokoro-speak.py → audio
                              (sequential, no overlap)
```

### How It Works

1. **Hooks** fire on Claude Code events (response complete, tool used, notification)
2. **Hook scripts** extract relevant text and pipe it to `speak.sh`
3. **speak.sh** checks if narrator is enabled, starts the daemon if needed, and writes text to a FIFO queue
4. **speak-daemon.sh** reads from the FIFO sequentially, ensuring utterances never overlap
5. **kokoro-speak.py** synthesizes speech using Kokoro TTS and plays it through your speakers

### State Management

Narrator state is stored in `/tmp/claude-narrator-state`:

```
enabled=true
voice=af_heart
speed=1.1
```

Skills modify this file; hook scripts read it. This file-based approach is necessary because hooks run as subprocesses and cannot set environment variables in the parent process.

### What Gets Spoken

| Event | What's spoken |
|-------|--------------|
| **Response complete** | First ~300 characters of the assistant's reply (sentence-aligned) |
| **Tool use** | Short description: "Reading file X", "Running: npm test", etc. |
| **Notification** | The notification title and message |

## Project Structure

```
narrator/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── hooks/
│   ├── hooks.json            # Hook registrations
│   └── scripts/
│       ├── kokoro-speak.py   # Core TTS engine
│       ├── speak-daemon.sh   # Background speech queue
│       ├── speak.sh          # Speech enqueuer (entry point)
│       ├── speak-response.sh # Stop hook (speaks responses)
│       ├── speak-step.sh     # PostToolUse hook (speaks tool actions)
│       └── speak-notification.sh  # Notification hook
├── skills/
│   ├── on/SKILL.md           # Enable narrator
│   ├── off/SKILL.md          # Disable narrator
│   ├── voice/SKILL.md        # Change voice
│   ├── speak/SKILL.md        # On-demand speech
│   └── hush/SKILL.md         # Silence immediately
├── LICENSE
└── README.md
```

## License

Apache License 2.0
