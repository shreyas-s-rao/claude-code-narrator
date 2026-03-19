---
description: Speak text aloud on demand
allowed-tools: Bash
---

# On-Demand Speech

Speak text aloud on demand, regardless of whether narrator is currently enabled.

## Usage

If the user provides specific text to speak, pipe it directly:

```bash
echo "TEXT_TO_SPEAK" | bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/speak.sh" --force
```

If the user does not provide specific text, summarize the last action or response and speak that summary:

```bash
echo "SUMMARY_TEXT" | bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/speak.sh" --force
```

The `--force` flag bypasses the enabled check, allowing speech even when narrator is turned off.

## Important

- Always use `--force` for on-demand speak requests
- Keep spoken text concise -- summarize if the text is very long
- Ensure Kokoro is installed before attempting to speak (check with `python3 -c "import kokoro"`)
