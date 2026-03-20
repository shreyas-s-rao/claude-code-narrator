# Architecture

## Pipeline Overview

```
Hook fires → speak.sh → FIFO pipe → speak-daemon.sh → speak-daemon.py → audio
                              (sequential, no overlap)
```

The speech daemon keeps the Kokoro TTS pipeline loaded in memory. After a ~10s cold start, each utterance synthesizes in under 50ms.

## How It Works

1. **Hooks** fire on Claude Code events (response complete, tool used, notification)
2. **Hook scripts** extract relevant text and the session's `cwd` from the hook JSON, then pipe text to `speak.sh` with `NARRATOR_CWD` set
3. **speak.sh** resolves enabled/voice/speed by checking the local state file (`<cwd>/.claude-code-narrator`) then the global one (`~/.claude-code-narrator/state`), starts the daemon if needed, and writes a JSON message to the FIFO queue
4. **speak-daemon.sh** launches `speak-daemon.py`, the persistent Python daemon
5. **speak-daemon.py** keeps the Kokoro pipeline loaded in memory, reads JSON lines from the FIFO, uses the embedded voice/speed for each utterance, and plays audio through your speakers
6. **kokoro-speak.py** is a standalone fallback TTS script (used for one-off speech when the daemon isn't running)

## State Management

### Global state

Narrator state is stored in `~/.claude-code-narrator/config`:

```
enabled=true
voice=af_heart
speed=1.1
```

### Per-directory (local) state

A local config can be placed in any directory at `<cwd>/.claude-code-narrator/config`:

```
enabled=true
voice=am_adam
speed=1.0
```

The local file can contain any subset of keys. Missing keys fall back to the global state.

### State resolution order

For each setting (`enabled`, `voice`, `speed`):
1. **Local** `<cwd>/.claude-code-narrator/config` — if the key is present, use it
2. **Global** `~/.claude-code-narrator/config` — fallback

This allows per-project voice/speed without duplicating all settings.

Skills and commands modify config files; hook scripts read them. This file-based approach is necessary because hooks run as subprocesses and cannot set environment variables in the parent process.

## FIFO Protocol

Messages on the FIFO are newline-delimited JSON:

```json
{"text":"Hello world","voice":"af_heart","speed":1.1}
```

The daemon detects the format by checking if the line starts with `{`. Plain text lines are treated as a backward-compatible fallback (voice/speed read from global state).

The special message `__QUIT__` shuts down the daemon cleanly.

## Multi-Session Behavior

- All sessions share one daemon and one FIFO (sequential playback, no overlap)
- Each session's utterances carry their own voice/speed in the JSON message
- If session A uses `am_adam` and session B uses `af_bella`, utterances interleave with correct voices
- Hush (SIGUSR1) affects all sessions (acceptable — only one speaker at a time)

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
- **Pronunciation fixes** — uppercase/mixed-case words that Kokoro mispronounces are replaced with phonetic equivalents (longer variants before shorter to avoid partial matches):
  - Words → phonetic: `README` → "read me", `JSON` → "jason", `JSONL` → "jason L", `YAML` → "yammel", `TOML` → "tommel", `FIFO` → "fye foe", `SQL` → "sequel", `UUID` → "you you I D", `REPL` → "repple", `OAuth` → "oh auth", `CORS` → "cores", `echo` → "ekko"
  - Spelled out: `API` → "A P I", `CLI` → "C L I", `URL` → "U R L", `HTTP` → "H T T P", `HTTPS` → "H T T P S", `NPM` → "N P M", `CSRF` → "C S R F", `CI/CD` → "C I C D", `PyPI` → "pie P I"
  - Normalized case: `ENV` → "env", `STDIN` → "standard in", `WASM` → "wasm", `POSIX` → "posix"
- **Markdown noise** — backticks, bold markers (`**`), and heading markers (`#`) are stripped
- **Ellipsis** — `...` collapsed to a single space (avoids TTS stutter)
- **Pipes** — freestanding `|` replaced with comma for a natural pause
- **Command stripping** — Tool use descriptions have CLI flags and arguments stripped so only the program and subcommand are spoken (e.g. `git log --oneline -5` → "Running git log."), with a trailing period to prevent Kokoro from clipping the last word
