# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Claude Code plugin that speaks responses aloud using Kokoro TTS (local neural text-to-speech). No cloud APIs — everything runs on the user's machine.

## Testing

```bash
bash tests/run-all.sh          # all tests
bash tests/test-command-extraction.sh  # single test
```

Tests are plain bash scripts using an `assert_eq` pattern. Each test file is self-contained. New test files matching `tests/test-*.sh` are automatically picked up by `run-all.sh`.

## Architecture

```
Hook fires → speak.sh → FIFO pipe → speak-daemon.sh → speak-daemon.py → audio
```

- **Plugin hooks** (`hooks/hooks.json`) register for `Stop`, `PostToolUse`, and `Notification` events
- Hook scripts extract text and pipe it to `speak.sh`
- `speak.sh` is the central enqueuer: checks state, starts daemon if needed, writes to FIFO
- `speak-daemon.py` is a persistent Python process that keeps the Kokoro pipeline loaded in memory (~10s cold start, then <50ms per utterance)
- `kokoro-speak.py` is a standalone fallback for one-off speech

### State and runtime files

All stored under `~/.claude-code-narrator/`:
- `state` — enabled/disabled, voice, speed (file-based because hooks are subprocesses)
- `fifo` — named pipe for speech queue
- `daemon.pid` — written by Python daemon AFTER pipeline is loaded (signals readiness)
- `daemon.lock` — atomic mkdir lock to prevent concurrent daemon starts
- `last-spoken` — deduplication tracker for transcript-parsed text blocks

### Plugin structure

- `commands/` — slash command definitions (`/narrator:on`, `/narrator:off`, etc.) with step-by-step instructions for Claude to execute
- `skills/` — SKILL.md files that match user intent phrases (e.g. "change voice", "be quiet") and map to the same operations as commands
- `hooks/hooks.json` — declares which Claude Code events trigger which scripts
- `hooks/scripts/` — all executable scripts (bash + python)

### Hook scripts and what they handle

| Script | Hook event | Purpose |
|--------|-----------|---------|
| `speak-response.sh` | Stop | Speaks first ~1000 chars of final response |
| `speak-step.sh` | PostToolUse | Speaks tool description + intermediate text blocks |
| `speak-notification.sh` | Notification | Speaks notification title/message |
| `hush-on-input.sh` | UserPromptSubmit (user settings) | Silences speech when user types |

### Text-to-speech pipeline

`speak.sh` applies TTS-friendly replacements before enqueuing: dot expansion for filenames, arrow/operator symbols to words, markdown noise removal, abbreviation expansion. These replacements live in `speak.sh` around line 36-75.

`speak-step.sh` uses `extract-command.sh` (sourced function) to convert tool commands into short spoken descriptions (e.g. `git log --oneline -3` → "Running git log").

`speak-step.sh` also parses the Claude Code transcript JSONL (`$TRANSCRIPT_PATH`) to find and speak intermediate text blocks between tool calls that have no dedicated hook.

## Key Patterns

- **Never use `sed` to edit the state file** — commands/skills instruct Claude to use Read + Edit tools instead
- **`--force` flag** on `speak.sh` bypasses the enabled check (used by `/narrator:speak` for on-demand speech)
- **`$CLAUDE_PLUGIN_ROOT`** is set by Claude Code at runtime and points to the plugin cache, not this repo
- **Venv** for Kokoro lives at `~/.claude-narrator-venv` (separate from this repo)
- **Python 3.13 compatibility** requires installing kokoro/misaki from git with `--no-deps` and manually installing spacy deps with cp313 wheels (see `kokoro-speak.py` bootstrap)

## Development Workflow

Changes to hook scripts must be copied to the plugin cache (`~/.claude/plugins/cache/claude-code-narrator/narrator/<version>/`) for testing, since hooks run from the cache path, not the source repo. `/reload-plugins` does not refresh the cache unless the version changes.

The `UserPromptSubmit` hook for auto-hush is registered in `~/.claude/settings.json` (not in `hooks/hooks.json`) because it needs to persist across sessions and is managed by the `/narrator:on` and `/narrator:off` commands.
