# Architecture

## Pipeline Overview

```
Hook fires → speak.sh → FIFO pipe → speak-daemon.sh → speak-daemon.py → audio
                              (sequential, no overlap)
```

The speech daemon keeps the Kokoro TTS pipeline loaded in memory. After a ~10s cold start, each utterance synthesizes in under 50ms.

## How It Works

1. **Hooks** fire on Claude Code events (response complete, tool used, notification)
2. **Hook scripts** extract relevant text and pipe it to `speak.sh`
3. **speak.sh** checks if narrator is enabled, starts the daemon if needed, and writes text to a FIFO queue
4. **speak-daemon.sh** launches `speak-daemon.py`, the persistent Python daemon
5. **speak-daemon.py** keeps the Kokoro pipeline loaded in memory, reads utterances from the FIFO sequentially (no overlap), and plays audio through your speakers
6. **kokoro-speak.py** is a standalone fallback TTS script (used for one-off speech when the daemon isn't running)

## State Management

Narrator state is stored in `~/.claude-code-narrator/state`:

```
enabled=true
voice=af_heart
speed=1.1
```

Skills modify this file; hook scripts read it. This file-based approach is necessary because hooks run as subprocesses and cannot set environment variables in the parent process.

## What Gets Spoken

| Event | What's spoken |
|-------|--------------|
| **Response complete** | First ~1000 characters of the assistant's reply (sentence-aligned) |
| **Tool use** | Short description: "Reading file X", "Running git log", etc. |
| **Notification** | The notification title and message |
| **User input** | Speech is automatically silenced (daemon killed, FIFO cleared) |

## Speech Text Processing

Before text is sent to the TTS engine, `speak.sh` applies several transformations to make spoken output sound natural:

- **Abbreviations** — `e.g.` → "for example", `i.e.` → "that is" (applied before dot replacement)
- **Filename dots** — `settings.json` → "settings dot json", with chained extension support (`types.d.ts` → "types dot d dot ts")
- **Arrows and operators** — `→` → "to", `=>` / `->` → "arrow", `!=` → "not equal", `==` → "equals", `<=` / `>=` → "less/greater or equal"
- **Logical operators** — `&&` → "and", `||` → "or"
- **Paths and env vars** — `~/` → "home slash", `$HOME` → "home", `/dev/null` → "dev null"
- **Shorthand** — `w/o` → "without", `w/` → "with"
- **Technical terms** — `stderr` → "standard error", `stdout` → "standard output"
- **Markdown noise** — backticks, bold markers (`**`), and heading markers (`#`) are stripped
- **Ellipsis** — `...` collapsed to a single space (avoids TTS stutter)
- **Pipes** — freestanding `|` replaced with comma for a natural pause
- **Command stripping** — Tool use descriptions have CLI flags and arguments stripped so only the program and subcommand are spoken (e.g. `git log --oneline -5` → "Running git log")
