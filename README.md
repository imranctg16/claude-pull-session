# pull-session

A [Claude Code](https://claude.com/claude-code) **plugin** that pulls a **summary of another session** into your current one.

You've got two Claude Code sessions open in two terminals. One figured something out — a plan, a decision, half a debug. You want the *other* one to know, without copy-pasting a wall of transcript. Install the plugin, then run:

```
/pull-session:pull-session
```

It lists the sessions for the current project. Pick one:

```
/pull-session:pull-session 5d8281d1-d0bc-49ac-a670-c698b3ee6a90
```

…and that session is asked (headlessly) to summarize itself — goal, decisions, files touched, current state, open threads — and the summary drops into your current session as context.

## Why this exists

Claude Code sessions are **independent by design**. `--resume` / `--continue` *switch to* a prior session; `--fork-session` *copies* the current one. There's no built-in "session A, absorb session B." This fills that gap with an on-demand, one-way **pull**.

## Install

This repo is a Claude Code marketplace containing the plugin. Inside any Claude Code session:

```
/plugin marketplace add imranctg16/claude-pull-session
/plugin install pull-session@imran-plugins
```

Then use `/pull-session:pull-session`. Requires the `claude` CLI, `bash`, and `jq` on your PATH.

## Usage

- `/pull-session:pull-session` — list this project's sessions (newest first, with a preview).
- `/pull-session:pull-session <session-id>` — pull that session's summary into the current one.

## How it works

- Sessions are transcripts at `${CLAUDE_CONFIG_DIR:-~/.claude}/projects/<cwd-with-non-alphanumerics-as-dashes>/<session-id>.jsonl`.
- With no argument, the bundled script lists those transcripts with a preview.
- With a session id, it runs `claude -p --resume <id> --output-format json "<summary prompt>"` — asking *that* session to summarize itself — and prints the result. The plugin command locates its bundled script via `${CLAUDE_PLUGIN_ROOT}` and tells Claude to absorb the output.
- It summarizes via `claude -p` rather than parsing the raw `.jsonl`, because the transcript's internal shape is undocumented and changes between Claude Code releases — so this keeps working across versions.

## Caveats (by design)

- **One-way, on-demand snapshot** — not a live two-way sync. Sessions can't truly merge mid-flight.
- **Costs one small summarization call** per pull (a headless `claude -p` turn).
- The pull runs a turn *inside* the target session, appending one "summarize yourself" exchange to its history. Harmless, but not zero-touch.
- Same-project only (sessions are scoped to the working directory).

## Repo layout

```
.claude-plugin/marketplace.json        # this repo as a one-plugin marketplace
plugins/pull-session/
├── .claude-plugin/plugin.json         # plugin manifest
├── commands/pull-session.md           # the /pull-session:pull-session command
└── scripts/pull-session.sh            # the helper (found at runtime via $CLAUDE_PLUGIN_ROOT)
```

## License

MIT — see [LICENSE](LICENSE).
