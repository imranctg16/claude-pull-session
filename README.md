# pull-session

A [Claude Code](https://claude.com/claude-code) **plugin** that finds your sessions **across every local instance and project** and pulls a chosen one's **summary** into your current session.

You run `claude`, `claude2`, `claude3` in different terminals (different config dirs), across different repos. One of them worked something out and you want *this* session to know — without copy-pasting a wall of transcript. Install the plugin, then:

```
/pull-session:pull-session
```

lists every session it can find — **by its real name** (the same label shown at the top of that CLI), **live sessions first**, tagged by **instance · project**, with a live flag:

```
[1] ● busy  blue-theme-logo-rebrand
      Youtube Channels · branch main · claude2 · id 5d8281d1
      ↳ yo, i want you to understand everything we have been doing…
[2] ○ open  job-portal-7e
      Job Portal · branch main · claude3 · id ea61ce67
      ↳ …
[3]   idle  campaign-cleanup (unnamed)
      CampaignFlow · branch main · default · id a1b2c3d4
      ↳ lets do a fun thing, separate from the project…
```

`● busy` = generating right now · `○ open` = running but idle · `idle` = closed. Names and live
status come from the app's own per-session metadata; older sessions the app no longer tracks fall
back to a name derived from their first message.

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

Then use `/pull-session:pull-session`. Prefer a shorter `/pull-session` (no prefix)? Plugin commands are always namespaced, but you can install the non-plugin copy in [`standalone/pull-session.md`](standalone/pull-session.md) into `<config-dir>/commands/` — see the notes at the top of that file.

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
- Session transcripts live at `<config-dir>/projects/<cwd-dashed>/<session-id>.jsonl`; the project shown comes from the transcript's `cwd`.
- **Live status** is taken from **running `claude` processes** — the reliable "is it open in a terminal" signal. A process counts if it owns a controlling TTY and isn't a child/subagent. Each is mapped to a session two ways: by its `CLAUDE_CODE_SESSION_ID`, and — because that id often differs from the saved-transcript id — by **working directory** (the newest transcript in the dir a live process runs in is its open session). `● busy` = generating now · `○ open` = a live terminal is on it · `· recent` = written within `$PULL_SESSION_LIVE_WINDOW`s (default 120) · `idle` = otherwise. On non-Linux without `/proc`, it uses `ps -E` (id-only) and falls back to the recent-write window.
- **Names** are the exact title shown in the CLI tab: the `aiTitle` record Claude writes into the transcript (e.g. *"Build dream resume comparison app with Laravel"*). If a session has no `aiTitle` yet, it falls back to the `sessions/<pid>.json` name slug, then to its first real message.
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
| `PULL_SESSION_LIVE_WINDOW` | `120` | Recent-write window (seconds) used as the liveness fallback for untracked sessions. |
| `PULL_SESSION_LIMIT` | `25` | Max sessions listed (live-first); the rest are summarized as "… and N older". |

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
