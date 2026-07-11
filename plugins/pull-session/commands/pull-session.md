---
description: Pull a summary of another Claude Code session into this one
argument-hint: "[session-id]  (omit to list sessions)"
allowed-tools: Bash(bash:*)
---

Run the pull-session helper:

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/pull-session.sh" $ARGUMENTS`

Now act on its output:

- If it printed a **list of sessions**, show me that list and ask which session id I want to pull. (The newest is usually this current session — I probably want a different one.)
- If it printed a block wrapped in **`=== CONTEXT PULLED FROM SESSION … ===`**, absorb that summary as background context for our current work, then give me a **one-line** confirmation of what you now know from the other session. Do not repeat the whole summary back to me.
- If it printed an **error**, relay it plainly and suggest running `/pull-session` with no argument to list sessions.
