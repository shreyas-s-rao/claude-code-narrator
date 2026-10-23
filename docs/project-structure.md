# Project Structure

```
claude-code-narrator/
├── .claude-plugin/
│   ├── marketplace.json      # Marketplace distribution config
│   └── plugin.json           # Plugin manifest (name, version, license)
├── .claude/
│   └── settings.local.json   # Local dev permissions
├── commands/
│   ├── cast.md               # /narrator:cast — change voice or speed
│   ├── hush.md               # /narrator:hush — silence speech
│   ├── length.md             # /narrator:length — summary or full final response
│   ├── off.md                # /narrator:off — disable narrator
│   ├── on.md                 # /narrator:on — enable narrator
│   ├── speak.md              # /narrator:speak — on-demand speech
│   └── verbosity.md          # /narrator:verbosity — choose what gets spoken
├── hooks/
│   ├── hooks.json             # Hook registrations (Stop, PostToolUse, Notification)
│   └── scripts/
│       ├── extract-command.sh     # Shared helper: Bash command → short spoken description
│       ├── hush-on-input.sh       # UserPromptSubmit hook (auto-silence on input)
│       ├── kokoro-speak.py        # Standalone TTS with auto-venv bootstrap
│       ├── narrator-state.sh      # Shared helper: local→global config lookup, verbosity, length
│       ├── speak-daemon.py        # Persistent Python daemon (keeps pipeline loaded)
│       ├── speak-daemon.sh        # Bash wrapper to launch Python daemon
│       ├── speak-notification.sh  # Notification hook
│       ├── speak-response.sh      # Stop hook (speaks responses)
│       ├── speak-step.sh          # PostToolUse hook (speaks tool actions + intermediate text)
│       └── speak.sh               # Speech enqueuer (entry point, TTS text replacements)
├── skills/
│   ├── cast/SKILL.md          # Intent matching for voice/speed changes
│   ├── hush/SKILL.md          # Intent matching for silencing
│   ├── length/SKILL.md        # Intent matching for response length
│   ├── off/SKILL.md           # Intent matching for disabling
│   ├── on/SKILL.md            # Intent matching for enabling
│   ├── speak/SKILL.md         # Intent matching for on-demand speech
│   └── verbosity/SKILL.md     # Intent matching for verbosity
├── tests/
│   ├── run-all.sh                 # Run all test suites
│   ├── test-command-extraction.sh # Tests for tool use command stripping
│   ├── test-dot-replacement.sh    # Tests for filename dot pronunciation
│   └── test-verbosity.sh          # Tests for the verbosity and length settings
├── docs/
│   ├── architecture.md        # Architecture, state management, speech processing
│   ├── commands.md            # Detailed command reference
│   └── project-structure.md   # This file
├── .gitignore
├── CLAUDE.md                  # Guidance for Claude Code
├── LICENSE
└── README.md
```
