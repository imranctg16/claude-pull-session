# pull-session

A [Claude Code](https://claude.com/claude-code) **plugin** that finds your sessions **across every local instance and project** and pulls a chosen one's **summary** into your current session.

You run `claude`, `claude2`, `claude3` in different terminals (different config dirs), across different repos. One of them worked something out and you want *this* session to know — without copy-pasting a wall of transcript. Install the plugin, then:

```
/pull-session:pull-session
```

lists every session it can find — newest first, tagged by **instance · project**, with a **● live** flag for ones active right now:

```
[1] ● live  Jul12 13:22  default · Youtube Channels
      ↳ we have a conversation exported here, i need you to load it…
[2] ● live  Jul12 13:22  work    · Job Portal
      ↳ …
[3]   idle  Jul10 17:32  claude3 · CampaignFlow
      ↳ lets do a fun thing, separate from the project…
```

Pull one in by number (or id):

```
/pull-session:pull-session 3
```

…and that session is asked (headlessly, under **its own** config dir) to summarize itself — goal, decisions, files touched, current state, open threads — and the summary drops into your current session as context.

## Why this exists

Claude Code sessions are **independent by design** and each instance has its **own config dir**. `--resume`/`--continue` only *switch to* a prior session **in the current instance**; nothing merges or imports across sessions — let alone across instances or projects. This fills that gap with an on-demand, cross-instance **pull**.

## Install

This repo is a Claude Code marketplace containing the plugin. In any Claude Code session:

```
/plugin marketplace add imranctg16/claude-pull-session
/plugin install pull-session@imran-plugins
```

Then use `/pull-session:pull-session`.

### Requirements & scope

Needs the **`claude` CLI**, plus **`bash`** and **`jq`** on PATH.

- **Linux / macOS** — works out of the box (`brew install jq` on macOS if needed).
- **Windows** — works under **WSL** or with **Git for Windows** installed (the slash command runs a `bash` step; without Git Bash, Claude Code falls back to PowerShell and this plugin can't run).
- Discovers **Claude Code CLI** sessions (the `<config-dir>/projects/*.jsonl` transcripts). It does **not** reach conversations created in the **Claude Desktop app's chat** — those are a separate session store the CLI can't resume. Running the plugin *inside* Desktop's Code tab is fine; it'll still see your CLI sessions.

## Usage

- `/pull-session:pull-session` — list all sessions (all instances, all projects), numbered, with ● live flags.
- `/pull-session:pull-session <number|id>` — pull that session's summary into the current one.
- `/pull-session:pull-session <number|id> --force` — pull a **live** session anyway (see caveats).

Don't want to eyeball a number? After the list, just **tell Claude which one** ("pull the Job Portal one", "the live one") — it'll run the pull.

### Arrow-key picker (terminal)

Arrow-key selection can't run *inside* the slash command — Claude Code owns the keyboard during a `!` step. For a real fzf picker, run the bundled script in your **own terminal**:

```bash
bash /path/to/claude-pull-session/plugins/pull-session/scripts/pull-session.sh pick
# handy: alias pspick='bash /path/to/.../pull-session.sh pick'
```

Arrow to a session, hit **Enter**, and it copies `/pull-session:pull-session <id>` to your clipboard — paste that into your Claude session to pull it. Requires `fzf` (optional; only for `pick`; uses `pbcopy`/`wl-copy`/`xclip` if present).

## How it discovers sessions

- Scans config dirs that contain a `projects/` dir: `$PULL_SESSION_DIRS` (colon-separated override) · `${CLAUDE_CONFIG_DIR:-~/.claude}` · `~/.claude`, `~/.claude-*`, and the same one level up (to catch HOME-swapped instances). There's no registry of instances in Claude Code, so scanning is the intended approach.
- Session transcripts live at `<config-dir>/projects/<cwd-dashed>/<session-id>.jsonl`; the project name shown comes from the transcript's `cwd`.
- **● live** = written within `$PULL_SESSION_LIVE_WINDOW` seconds (default 120). Claude Code has **no session lock/PID files**, so recent-write is the only signal — treat it as a hint, not proof.
- Summaries use `claude -p --resume <id>` run under that session's own `CLAUDE_CONFIG_DIR`, not raw-`.jsonl` parsing (the format is undocumented and transcripts can be tens of MB).

## Caveats (by design / by platform limits)

- **One-way, on-demand snapshot** — not a live two-way sync.
- **Costs one small summarization call** per pull.
- Pulling **appends a summary turn** to the target session. Harmless when idle; for a **live** session it can interleave with the running instance, so live sessions need `--force`.
- **No pre-merge compaction from outside.** Claude Code's `/compact` is interactive-only — there's no headless way to compact a session you're not in. To shrink a live session before merging, run `/compact` in *its* terminal first; this tool will remind you.
- Cross-instance labels reflect the config dirs as seen from the running instance.
- **CLI sessions only.** The Claude Desktop app keeps its chat sessions in a separate store that `claude -p --resume` can't address, so Desktop conversations won't appear in the list (see *Requirements & scope*).

## Config (env vars)

| Var | Default | Purpose |
|---|---|---|
| `PULL_SESSION_DIRS` | — | Colon-separated extra config dirs to scan (for non-standard layouts). |
| `PULL_SESSION_LIVE_WINDOW` | `120` | Seconds since last write to still count as ● live. |

## Repo layout

```
.claude-plugin/marketplace.json        # this repo as a one-plugin marketplace
plugins/pull-session/
├── .claude-plugin/plugin.json         # plugin manifest
├── commands/pull-session.md           # the /pull-session:pull-session command
└── scripts/pull-session.sh            # discovery + summarize (found via $CLAUDE_PLUGIN_ROOT)
```

## License

MIT — see [LICENSE](LICENSE).
