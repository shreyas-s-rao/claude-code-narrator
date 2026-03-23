# Narrator - Voice Output Plugin for Claude Code

![Claude Code Narrator](assets/banner.png)

A Claude Code plugin that speaks responses aloud using [Kokoro](https://github.com/hexgrad/kokoro) TTS, a local neural text-to-speech engine. No cloud APIs, no latency — everything runs on your machine.

## Prerequisites

- Python 3.9+ (tested on 3.13)
- macOS or Linux with audio output (speakers or headphones)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

## Installation

### From GitHub (recommended)

In Claude Code, run these slash commands:

1. Add the marketplace:
   ```
   /plugin marketplace add shreyas-s-rao/claude-code-narrator
   ```

2. Install the plugin:
   ```
   /plugin install narrator
   ```

3. Reload:
   ```
   /reload-plugins
   ```

> **Linux note:** If `/tmp` is a separate filesystem (tmpfs), plugin installation may fail with `EXDEV: cross-device link not permitted`. Fix by setting TMPDIR before launching Claude Code:
> ```bash
> mkdir -p ~/.cache/tmp && TMPDIR=~/.cache/tmp claude
> ```
> Then run the install commands above in that session. This is a [Claude Code platform limitation](https://github.com/anthropics/claude-code/issues/14799), not specific to this plugin.

### From local directory

If you've cloned the repo locally:

1. Add the marketplace:
   ```
   /plugin marketplace add /path/to/claude-code-narrator
   ```

2. Install and reload as above

### Direct plugin loading (development)

```bash
claude --plugin-dir /path/to/claude-code-narrator
```

## Getting Started

1. **Enable narrator**: Type `/narrator:on` in Claude Code
2. Kokoro TTS and all dependencies are **automatically installed** into a dedicated venv (`~/.claude-narrator-venv`) on first run. This takes a few minutes.
3. Once installed, the narrator speaks tool steps and responses aloud.
4. **Change voice**: `/narrator:cast af_bella` (or any voice from the table below)
5. **Silence**: `/narrator:hush` to stop current speech, `/narrator:off` to disable entirely

## Commands

| Command | Description |
|---------|-------------|
| `/narrator:on` | Enable voice output (auto-installs Kokoro on first run) |
| `/narrator:off` | Disable voice output |
| `/narrator:cast [voice]` | Change voice or list available voices |
| `/narrator:speed [value]` | Change speech speed (0.5–2.0, default 1.1) |
| `/narrator:speak [text]` | Speak on demand, even if narrator is off |
| `/narrator:hush` | Silence all current and queued speech |

All commands accept `--local` to apply settings to the current directory only (see [Per-Directory Config](#per-directory-config)).

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

## What Gets Spoken

| Event | What you hear |
|-------|---------------|
| Tool use (Read, Write, Bash, etc.) | Short description, e.g. "Reading file settings dot json" |
| Text between tool calls | The assistant's intermediate commentary |
| Final response | First ~1000 characters, ending at a sentence boundary |
| Notification | Title and message from Claude Code notifications |
| User input | Speech is automatically silenced when you type or click |

## Per-Directory Config

You can override narrator settings per directory, which is useful when running multiple Claude Code sessions with different voices.

```
/narrator:on --local          # enable narrator in this directory only
/narrator:cast --local am_adam  # use a different voice in this directory
/narrator:speed --local 1.5    # use a different speed in this directory
/narrator:off --local         # disable narrator in this directory only
```

Local settings are stored in `<cwd>/.claude-code-narrator/config`. Only the keys you set locally are overridden — missing keys fall back to the global config at `~/.claude-code-narrator/config`.

**Add the local config file to your `.gitignore`** so it's not committed:

```bash
echo .claude-code-narrator >> .gitignore
```

### Multi-Session Behavior

All sessions share a single daemon and FIFO (sequential playback, no overlap). Each session's utterances carry their own voice and speed settings, so if session A uses `am_adam` and session B uses `af_bella`, utterances interleave with the correct voices.

## Documentation

- [Architecture](docs/architecture.md) — pipeline diagram, state management, what gets spoken
- [Commands](docs/commands.md) — detailed reference for each command
- [Project Structure](docs/project-structure.md) — full directory tree with file descriptions

## Development

To work on the plugin locally, clone the repo and load it:

```bash
git clone https://github.com/shreyas-s-rao/claude-code-narrator
```

**Option 1:** Load directly (no install needed, good for quick iteration):

```bash
claude --plugin-dir /path/to/claude-code-narrator
```

**Option 2:** Install via local marketplace (persists across sessions):

1. In Claude Code, run `/plugin marketplace add /path/to/claude-code-narrator`
2. Run `/plugin install narrator` then `/reload-plugins`

Changes to hook scripts must be copied to the plugin cache (`~/.claude/plugins/cache/claude-code-narrator/narrator/<version>/`) for testing, since hooks run from the cache path, not the source repo. `/reload-plugins` does not refresh the cache unless the version changes.

Run tests with:

```bash
bash tests/run-all.sh
```

Tests are plain bash scripts using an `assert_eq` pattern. New test files matching `tests/test-*.sh` are automatically picked up by `run-all.sh`.

## Contributing

Narrator is a personal hobby project, built and tested on one machine (Apple Silicon, macOS Sequoia, Python 3.13). It almost certainly has rough edges — things may break on different hardware, OS versions, or Python setups.

Contributions are very welcome, including:

- **Bug reports** — open an issue describing your setup (OS, Python version, audio hardware) and what went wrong
- **Fixes** — PRs are welcome; keep changes small and focused
- **New pronunciation fixes** — uppercase/mixed-case words that Kokoro mispronounces (see `speak.sh`)
- **New voice support** — Kokoro supports more voices than the 8 listed; contributions to test and document them are welcome
- **Better text processing** — improvements to the TTS text replacement pipeline in `speak.sh`

### Things that are likely untested

- Linux audio (PortAudio/sounddevice should work, but not verified beyond install)
- Python versions below 3.11
- Intel Macs
- macOS versions before Sequoia
- Non-English Kokoro voices
- Running multiple daemons (only one daemon/FIFO is supported — all sessions share it)
- Very long responses (speech is truncated at ~1000 characters for final responses)

If something doesn't work, check whether the daemon is running (`cat ~/.claude-code-narrator/daemon.pid`) and try restarting it with `/narrator:hush` followed by any action that triggers speech.

## License

MIT License
