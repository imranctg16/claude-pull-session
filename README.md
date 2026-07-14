# pull-session

**You've got three Claude Code chats open. One already figured this out — the one you're in has no idea.** Pull what it knows into this session, instead of copy-pasting a wall of transcript.

A [Claude Code](https://claude.com/claude-code) plugin for working across multiple sessions.

## Install

In a running Claude Code session, run:

```
/plugin marketplace add imranctg16/claude-pull-session
/plugin install pull-session@imran-plugins
```

Needs `claude`, `bash`, and `jq` on PATH. Works on Linux, macOS, and Windows (via WSL or Git Bash).

## Use

```
/pull-session:pull-session
```

Lists your sessions — by their real **tab title**, **live ones first**, with directory, last-used, message count, and size — as a keyboard-selectable menu:

```
[1] ● busy  Build dream resume comparison app with Laravel
      ~/Workspace/Personal · last used just now · 61 msgs · 332K
[2] ○ open  Design SEO-friendly job board architecture with scraper
      ~/Workspace/Job Portal · last used 9m ago · 1015 msgs · 5.8M
[3]   idle  Review Trello board progress
      ~/Workspace/uno · last used 2h ago · 497 msgs · 2.4M
```

Pick one and its summary (goal, decisions, files touched, current state, open threads) drops into your current session.

`● busy` = generating now · `○ open` = open in a terminal · `idle` = closed. Pulling is **append-only and safe** — only a session generating *right now* asks for `--force`.

Want the shorter `/pull-session` (no prefix)? See [`standalone/pull-session.md`](standalone/pull-session.md).

## How it works

Scans each Claude config dir (`~/.claude`, `~/.claude-*`) for session transcripts, reads live status from running `claude` processes, and pulls a summary via `claude -p --resume` under the target session's own config dir. **CLI sessions only** — not the Desktop app's chat.

## Notes

- One-way, on-demand snapshot; costs one small summarization call per pull.
- Env vars (all optional): `PULL_SESSION_DIRS` (extra config dirs), `PULL_SESSION_LIMIT` (default 25), `PULL_SESSION_LIVE_WINDOW`, `PULL_SESSION_BUSY_WINDOW`.

## License

MIT — see [LICENSE](LICENSE).
