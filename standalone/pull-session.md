---
description: Pull a summary of another Claude Code session (any instance / project) into this one
argument-hint: "[number|session-id] [--force]  (omit to list)"
allowed-tools: Bash(bash:*)
---

<!-- Standalone (non-plugin) copy of the pull-session command so it is invokable as `/pull-session`
     with no plugin prefix. Install into <config-dir>/commands/pull-session.md. Uses an absolute
     path to the script (the plugin's ${CLAUDE_PLUGIN_ROOT} isn't set outside the plugin). -->

!`bash "/home/imran/Workspace/Personal/claude-pull-session/plugins/pull-session/scripts/pull-session.sh" $ARGUMENTS`

Act on the output above:

- **A numbered list of sessions** → **ALWAYS present them as a keyboard-selectable menu** (your interactive option picker). **Never ask me to type a session number or id** — selection is always by picking from the menu. Put the **open (live) sessions first**; if there are more than the picker can hold, show the live ones and the most-recent, and let the auto **Other** entry cover the rest (that's the only fallback — still a pick, not a typed id). **Label each option with the session's name** — the script resolves each to its real name (the label at the top of that CLI, e.g. `blue-theme-logo-rebrand`); use it verbatim, NOT the id or number. Put `project` and the live tag (`● busy` / `○ open` / `idle`) in the description. Keep each session's id internally (don't show it) to run the pull once I pick: `bash "/home/imran/Workspace/Personal/claude-pull-session/plugins/pull-session/scripts/pull-session.sh" <that session's id>`, then handle the output below. Pulling is append-only and safe, so open/idle sessions pull directly; only a session that's **generating right now** returns a BUSY warning that needs `--force`.
- **A `⚠ … looks LIVE …` warning** → relay it and ask whether I want to `--force` it or compact it first. Do **not** re-run with `--force` without my go-ahead.
- **A `=== CONTEXT PULLED FROM SESSION … ===` block** → absorb that summary as background context for our current work, then give me a **one-line** confirmation of what you now know from that session. Don't echo the whole summary back.
- **An error** → relay it plainly and suggest running the command with no argument to list sessions.
