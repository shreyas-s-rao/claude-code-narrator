# Project Structure

```
claude-code-narrator/
├── .claude-plugin/
│   └── plugin.json            # Plugin manifest
├── hooks/
│   ├── hooks.json             # Hook registrations
│   └── scripts/
│       ├── kokoro-speak.py    # Core TTS engine (with auto-venv bootstrap)
│       ├── speak-daemon.py    # Persistent Python daemon (keeps pipeline loaded)
│       ├── speak-daemon.sh    # Bash wrapper to launch Python daemon
│       ├── speak.sh           # Speech enqueuer (entry point)
│       ├── speak-response.sh  # Stop hook (speaks responses)
│       ├── speak-step.sh      # PostToolUse hook (speaks tool actions)
│       └── speak-notification.sh  # Notification hook
├── skills/
│   ├── on/SKILL.md            # /narrator:on — enable narrator
│   ├── off/SKILL.md           # /narrator:off — disable narrator
│   ├── cast/SKILL.md          # /narrator:cast — change voice
│   ├── speak/SKILL.md         # /narrator:speak — on-demand speech
│   └── hush/SKILL.md          # /narrator:hush — silence immediately
├── tests/
│   ├── run-all.sh                 # Run all test suites
│   ├── test-dot-replacement.sh    # Tests for filename dot pronunciation
│   └── test-command-extraction.sh # Tests for tool use command stripping
├── docs/
│   ├── architecture.md        # Architecture, state management, speech processing
│   ├── commands.md            # Detailed command reference
│   └── project-structure.md   # This file
├── .gitignore
├── LICENSE
└── README.md
```
