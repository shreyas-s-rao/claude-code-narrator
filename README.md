# Narrator - Voice Output Plugin for Claude Code

A Claude Code plugin that speaks responses aloud using [Kokoro](https://github.com/hexgrad/kokoro) TTS, a local neural text-to-speech engine. No cloud APIs, no latency — everything runs on your machine.

## Installation

### Prerequisites

- Python 3.9+ (tested on 3.13)
- macOS with audio output (speakers or headphones)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

### Load the Plugin

```bash
claude --plugin-dir /path/to/claude-code-narrator
```

Or add to your Claude Code settings for permanent use:

```json
{
  "plugins": ["/path/to/claude-code-narrator"]
}
```

Kokoro TTS and all its dependencies are **automatically installed** into a dedicated venv (`~/.claude-narrator-venv`) the first time you run `/narrator:on`. No manual setup required.

## Usage

| Command | Description |
|---------|-------------|
| `/narrator:on` | Enable voice output (auto-installs Kokoro on first run) |
| `/narrator:off` | Disable voice output |
| `/narrator:cast [voice]` | Change voice or list available voices |
| `/narrator:speak [text]` | Speak on demand, even if narrator is off |
| `/narrator:hush` | Silence all current and queued speech |

See [docs/commands.md](docs/commands.md) for detailed usage and examples.

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

## Testing

```bash
bash tests/run-all.sh
```

Or run individual test suites:

```bash
bash tests/test-dot-replacement.sh     # Filename dots spoken as "dot" (e.g. "settings dot json")
bash tests/test-command-extraction.sh   # Tool use speaks only program + subcommand
```

## Documentation

- [Architecture](docs/architecture.md) — pipeline diagram, state management, what gets spoken
- [Commands](docs/commands.md) — detailed reference for each skill
- [Project Structure](docs/project-structure.md) — full directory tree with file descriptions

## License

Apache License 2.0
