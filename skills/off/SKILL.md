---
name: off
description: This skill should be used when the user asks to "disable narrator", "turn off voice", "stop narrator", "disable voice output", "narrator off", "mute narrator", or wants to deactivate text-to-speech output.
---

# Disable Narrator Voice Output

To disable narrator voice output:

## Step 1: Update State File

Modify the state file to disable narrator:

```bash
sed -i '' 's/^enabled=.*/enabled=false/' /tmp/claude-narrator-state 2>/dev/null || echo "enabled=false" > /tmp/claude-narrator-state
```

If the state file does not exist, create it with `enabled=false`:

```bash
echo "enabled=false" > /tmp/claude-narrator-state
```

## Step 2: Confirm

Inform the user: "Narrator is now disabled. Voice output is off."

Do NOT attempt to speak this confirmation (narrator is now off).
