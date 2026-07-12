---
description: Pull a summary of another Claude Code session (any instance / project) into this one
argument-hint: "[number|session-id] [--force]  (omit to list)"
allowed-tools: Bash(bash:*)
---

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/pull-session.sh" $ARGUMENTS`

Act on the output above:

- **A numbered list of sessions** → show it to me and ask which **number** (or session id) to pull. Call out the **● live** ones, and note that pulling a live session needs `--force` — and for a clean merge it's better to run `/compact` in that session's own terminal first.
- **A `⚠ … looks LIVE …` warning** → relay it and ask whether I want to `--force` it or compact it first. Do **not** re-run with `--force` without my go-ahead.
- **A `=== CONTEXT PULLED FROM SESSION … ===` block** → absorb that summary as background context for our current work, then give me a **one-line** confirmation of what you now know from that session. Don't echo the whole summary back.
- **An error** → relay it plainly and suggest running the command with no argument to list sessions.
