---
description: Pull a summary of another Claude Code session (any instance / project) into this one
argument-hint: "[number|session-id] [--force]  (omit to list)"
allowed-tools: Bash(bash:*)
---

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/pull-session.sh" $ARGUMENTS`

Act on the output above:

- **A numbered list of sessions** → present them to me as a **keyboard-selectable menu** (use your interactive option picker), **live sessions first, then most-recent**. Label each option `instance · project`; put the directory, a snippet, and a ● live tag in its description. The picker shows up to ~4 options, so choose the most relevant and rely on the auto **Other** entry for me to type a number or id for anything not shown. When I pick one, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pull-session.sh" <that session's id>` and handle its output as below. A **live** pick needs `--force`; a clean merge is better after `/compact` in that session's own terminal.
- **A `⚠ … looks LIVE …` warning** → relay it and ask whether I want to `--force` it or compact it first. Do **not** re-run with `--force` without my go-ahead.
- **A `=== CONTEXT PULLED FROM SESSION … ===` block** → absorb that summary as background context for our current work, then give me a **one-line** confirmation of what you now know from that session. Don't echo the whole summary back.
- **An error** → relay it plainly and suggest running the command with no argument to list sessions.
