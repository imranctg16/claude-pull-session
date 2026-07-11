# /pull-session

A tiny [Claude Code](https://claude.com/claude-code) slash command that pulls a **summary of another session** into your current one.

You've got two Claude Code sessions open in two terminals. One of them figured something out — a plan, a decision, half a debug. You want the *other* one to know about it, without copy-pasting a wall of transcript. Run:

```
/pull-session
```

It lists the sessions for the current project. Pick one:

```
/pull-session 5d8281d1-d0bc-49ac-a670-c698b3ee6a90
```

…and that session is asked (headlessly) to summarize itself — goal, decisions, files touched, current state, open threads — and the summary drops into your current session as context.

## Why this exists

Claude Code sessions are **independent by design**. `--resume` / `--continue` *switch to* a prior session; `--fork-session` *copies* the current one. There is no built-in "session A, absorb session B." This fills that gap with an on-demand, one-way **pull**.

## Install

```bash
git clone https://github.com/<you>/claude-pull-session
cd claude-pull-session
./install.sh
```

That copies the command into `${CLAUDE_CONFIG_DIR:-~/.claude}/commands/` (global, all projects). Restart Claude Code (or start a new session) and `/pull-session` is available. For a single project instead, drop `pull-session.sh` and `commands/pull-session.md` into that repo's `.claude/commands/`.

Requires: `claude` CLI, `bash`, `jq`.

## How it works

- Sessions are transcripts at `${CLAUDE_CONFIG_DIR:-~/.claude}/projects/<cwd-with-non-alphanumerics-as-dashes>/<session-id>.jsonl`.
- With no argument, the script lists those transcripts (newest first) with a preview.
- With a session id, it runs `claude -p --resume <id> --output-format json "<summary prompt>"` — i.e. it asks *that* session to summarize itself — and prints the result. The slash command tells Claude to absorb it.
- It summarizes via `claude -p` rather than parsing the raw `.jsonl`, because the transcript's internal shape is undocumented and changes between Claude Code releases. This way it keeps working across versions.

## Caveats (by design)

- **One-way, on-demand snapshot** — not a live two-way sync. Sessions can't truly merge mid-flight.
- **Costs one small summarization call** per pull (a headless `claude -p` turn).
- The pull runs a turn *inside* the target session, so it appends one "summarize yourself" exchange to that session's history. Harmless, but not zero-touch.
- Same-project only (sessions are scoped to the working directory).

## License

MIT — see [LICENSE](LICENSE).
