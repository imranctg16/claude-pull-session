#!/usr/bin/env bash
# pull-session v3 — discover Claude Code sessions across ALL local instances (config dirs)
# and ALL projects, label them by their real session NAME, flag which are live, and pull a
# chosen session's summary into the current one.
#
#   (no args)              -> list sessions (live first), numbered, by name, with a live flag
#   <number|session-id>    -> summarize that session and print it for the current session to absorb
#   <number|id> --force    -> pull even a LIVE session (see the live-session caveat below)
#
# Names & live status come from the app's OWN per-session metadata at <config-dir>/sessions/<pid>.json
# (fields: sessionId, name, nameSource, status, pid, cwd) — the same name shown at the top of the CLI.
# A session is:  ● busy = tracked, process alive, status "busy" · ○ open = tracked, process alive, idle
#   · recent = not tracked but written within $PULL_SESSION_LIVE_WINDOW · idle = otherwise.
# Sessions the app no longer tracks have only a transcript and no name — those fall back to a name
# derived from their first message.
#
# Discovery scans candidate config dirs (each contains projects/ and usually sessions/) —
#   $PULL_SESSION_DIRS (colon-separated, explicit override) · ${CLAUDE_CONFIG_DIR:-$HOME/.claude}
#   · ~/.claude, ~/.claude-*, and the same one level up (to catch HOME-swapped instances).
#
# Summaries use `claude -p --resume <id>` run under that session's OWN config dir (cross-instance),
# NOT raw-JSONL parsing. This APPENDS a summary turn to the target session — harmless when idle, but
# for a LIVE session it can interleave with the running instance, so live sessions require --force.
# Claude Code has no headless /compact, so to shrink a live session before merging, run /compact in
# ITS terminal first (this tool can't).
set -euo pipefail
shopt -s nullglob

for dep in claude jq; do
  command -v "$dep" >/dev/null 2>&1 || { echo "pull-session needs '$dep' on your PATH."; exit 1; }
done

LIVE_WINDOW="${PULL_SESSION_LIVE_WINDOW:-120}"
LIMIT="${PULL_SESSION_LIMIT:-25}"
NOW="$(date +%s)"

# portable across GNU (Linux) and BSD (macOS) coreutils
mtime()    { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }
fmtdate()  { LC_ALL=C date -d "@$1" '+%b%d %H:%M' 2>/dev/null || LC_ALL=C date -r "$1" '+%b%d %H:%M' 2>/dev/null || echo '?'; }
pid_alive() { [ -n "${1:-}" ] && [ "$1" != "null" ] && kill -0 "$1" 2>/dev/null; }

# ---- discover config-dir roots (dirs that contain a projects/ subdir) ----
ROOTS=()
add_root() {
  local d="$1"
  [ -n "$d" ] && [ -d "$d/projects" ] || return 0
  d="$(cd "$d" && pwd)"                       # normalize
  local r; for r in ${ROOTS[@]+"${ROOTS[@]}"}; do [ "$r" = "$d" ] && return 0; done
  ROOTS+=("$d")
}
if [ -n "${PULL_SESSION_DIRS:-}" ]; then
  IFS=':' read -ra _extra <<< "$PULL_SESSION_DIRS"
  for d in "${_extra[@]}"; do add_root "$d"; done
fi
add_root "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
_up="$(dirname "$HOME")"
for cand in "$HOME"/.claude "$HOME"/.claude-*/.claude "$HOME"/.claude-* \
            "$_up"/.claude "$_up"/.claude-*/.claude "$_up"/.claude-*; do
  add_root "$cand"
done
[ "${#ROOTS[@]}" -gt 0 ] || { echo "No Claude config dirs found (looked for */projects/)."; echo "Set PULL_SESSION_DIRS=/path/to/.claude:/another/.claude"; exit 1; }

# ---- index the app's own session metadata (name + live status), keyed by sessionId ----
# One line per tracked session:  sessionId<TAB>name<TAB>status<TAB>pid
SESS_INDEX=""
for root in "${ROOTS[@]}"; do
  for sf in "$root"/sessions/*.json; do
    [ -f "$sf" ] || continue
    line="$(jq -r '[.sessionId, (.name // ""), (.status // ""), (.pid // "")] | @tsv' "$sf" 2>/dev/null)" || continue
    [ -n "$line" ] && SESS_INDEX="$SESS_INDEX$line
"
  done
done
sess_meta() { # $1=sessionId -> "name\tstatus\tpid" (empty if the app isn't tracking it)
  [ -n "$SESS_INDEX" ] || return 0
  printf '%s' "$SESS_INDEX" | awk -F'\t' -v id="$1" '$1==id {print $2"\t"$3"\t"$4; exit}'
}

# ---- ground-truth liveness: a session is "open" if a live INTERACTIVE process is running for it ----
# The tracking files above are stale/incomplete, so the real signal is a running `claude` process
# (controlling TTY, NOT a child/subagent — CLAUDE_CODE_CHILD_SESSION=1). We map a process to a session
# two ways: (1) its CLAUDE_CODE_SESSION_ID when that matches a transcript, and — because that id often
# differs from the saved-transcript id — (2) by WORKING DIRECTORY: the newest transcript in the dir the
# process runs in is treated as its open session. Linux via /proc; macOS/BSD via `ps -E`.
LIVE_PROC_IDS=""
LIVE_CWDS=""
_add_live() { [ -n "${1:-}" ] && LIVE_PROC_IDS="$LIVE_PROC_IDS$1
"; }
_add_cwd()  { [ -n "${1:-}" ] && LIVE_CWDS="$LIVE_CWDS$1
"; }
if [ -d /proc ]; then
  for _pid in $(ps -eo pid= 2>/dev/null); do
    [ -r "/proc/$_pid/environ" ] || continue
    _env="$(tr '\0' '\n' < "/proc/$_pid/environ" 2>/dev/null)" || continue
    case "$_env" in *"CLAUDECODE=1"*) ;; *) continue ;; esac
    case "$_env" in *"CLAUDE_CODE_CHILD_SESSION=1"*) continue ;; esac
    _tty="$(ps -o tty= -p "$_pid" 2>/dev/null | tr -d ' ')"
    case "$_tty" in ''|'?'|'??'|'-') continue ;; esac        # must own a terminal
    _add_live "$(printf '%s\n' "$_env" | sed -n 's/^CLAUDE_CODE_SESSION_ID=//p' | head -1)"
    _add_cwd  "$(readlink "/proc/$_pid/cwd" 2>/dev/null)"
  done
else
  # macOS/BSD: `ps -E` appends the environment to the command column (no cwd without lsof, so id-only)
  while IFS= read -r _line; do
    case "$_line" in *"CLAUDECODE=1"*) ;; *) continue ;; esac
    case "$_line" in *"CLAUDE_CODE_CHILD_SESSION=1"*) continue ;; esac
    _add_live "$(printf '%s' "$_line" | sed -n 's/.*CLAUDE_CODE_SESSION_ID=\([0-9a-fA-F-]\{8,\}\).*/\1/p')"
  done < <(ps -E -o tty=,command= 2>/dev/null | grep -vE '^[[:space:]]*\?')
fi
# resolve each live working dir to the newest real transcript in it (the session that's open there)
if [ -n "$LIVE_CWDS" ]; then
  while IFS= read -r _lc; do
    [ -n "$_lc" ] || continue
    _dash="$(printf '%s' "$_lc" | sed 's#[^a-zA-Z0-9]#-#g')"
    _newest="$(
      for root in "${ROOTS[@]}"; do
        for f in "$root"/projects/"$_dash"/*.jsonl; do
          [ -f "$f" ] || continue
          case "$(basename "$f")" in agent-*) continue ;; esac
          printf '%s\t%s\n' "$(mtime "$f")" "$(basename "$f" .jsonl)"
        done
      done | sort -rn | head -1 | cut -f2
    )"
    _add_live "$_newest"
  done <<< "$(printf '%s' "$LIVE_CWDS" | sort -u)"
fi
proc_live() { case "$1" in "") return 1 ;; esac; case "$LIVE_PROC_IDS" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

# ---- collect sessions, live first (busy > open > tracked-dead > recent > idle), then newest ----
# Each RECORD line = mtime<TAB>root<TAB>file  (priority is used only for ordering, then stripped)
RECORDS=()
while IFS= read -r line; do RECORDS+=("$line"); done < <(
  for root in "${ROOTS[@]}"; do
    for f in "$root"/projects/*/*.jsonl; do
      [ -f "$f" ] || continue
      case "$(basename "$f")" in agent-*) continue ;; esac   # skip subagent transcripts
      sid="$(basename "$f" .jsonl)"
      meta="$(sess_meta "$sid")"; status=""; pid=""
      [ -n "$meta" ] && IFS=$'\t' read -r _nm status pid <<< "$meta"
      # "open" = this is the current session in a directory that has a live terminal (cwd-based,
      # via proc_live). We deliberately do NOT trust tracking-file PIDs — they go stale and lie.
      prio=4
      if proc_live "$sid" && [ "$status" = "busy" ]; then prio=0
      elif proc_live "$sid"; then prio=1; fi
      printf '%s\t%s\t%s\t%s\n' "$prio" "$(mtime "$f")" "$root" "$f"
    done
  done | sort -t$'\t' -k1,1n -k2,2nr | cut -f2-
)
[ "${#RECORDS[@]}" -gt 0 ] || { echo "No sessions found under: ${ROOTS[*]}"; exit 1; }

instance_label() { # short tag for a config dir root
  local r="$1"
  case "$r" in
    "$HOME/.claude") echo "default" ;;
    *) basename "$(dirname "$r")" | sed 's/^\.//' ;;   # e.g. .claude-user2 -> claude-user2
  esac
}
session_cwd()    { local f="$1" c; c="$(grep -m1 -oE '"cwd":"[^"]+"' "$f" 2>/dev/null | head -1 | sed 's/.*"cwd":"//;s/".*//')"; [ -n "$c" ] && printf '%s' "$c" || printf '(%s)' "$(basename "$(dirname "$f")")"; }
session_branch() { local b; b="$(grep -m1 -oE '"gitBranch":"[^"]*"' "$1" 2>/dev/null | head -1 | sed 's/.*"gitBranch":"//;s/".*//')"; printf '%s' "${b:-—}"; }
session_size()   { du -h "$1" 2>/dev/null | cut -f1 || echo '?'; }
preview() { # first REAL user message — skip command/caveat/system wrappers (lines starting with '<' etc.)
  local f="$1" msg=""
  msg="$(grep -m12 '"type":"user"' "$f" 2>/dev/null \
        | jq -r 'try (.message.content) // empty
                 | if type=="array" then (map(.text? // "")|join(" ")) else . end' 2>/dev/null \
        | sed 's/^[[:space:]]*//' \
        | grep -vE '^(<|Caveat|\[Request|$)' \
        | head -1 | tr '\n' ' ' | sed 's/  */ /g')"
  [ -z "$msg" ] && msg="$(grep -m1 -oE '"content":"[^"]{4,90}' "$f" 2>/dev/null | sed 's/"content":"//')"
  printf '%.78s' "${msg:-(no preview)}"
}
session_name() { # the app's own name, else a short label derived from the first message
  local meta nm
  meta="$(sess_meta "$(basename "$1" .jsonl)")"
  nm="$(printf '%s' "$meta" | cut -f1)"
  if [ -n "$nm" ]; then printf '%s' "$nm"
  else printf '%.42s (unnamed)' "$(preview "$1")"; fi
}
session_flag() { # live/idle token: busy (generating) > open (in a terminal) > recent > idle
  local sid meta status pid
  sid="$(basename "$1" .jsonl)"
  meta="$(sess_meta "$sid")"; status=""; pid=""
  [ -n "$meta" ] && IFS=$'\t' read -r _n status pid <<< "$meta"
  if proc_live "$sid" && [ "$status" = "busy" ]; then printf '● busy'; return; fi
  if proc_live "$sid"; then printf '○ open'; return; fi
  [ "$(( NOW - $(mtime "$1") ))" -le "$LIVE_WINDOW" ] && { printf '· recent'; return; }
  printf '  idle'
}
is_live() { [ "$(( NOW - $1 ))" -le "$LIVE_WINDOW" ]; }   # kept for the --force guard fallback

list_sessions() {
  echo "Claude Code sessions — all instances, all projects (live first):"
  echo
  local i=0 rec m root f shown=0
  for rec in "${RECORDS[@]}"; do
    i=$((i + 1))
    if [ "$shown" -ge "$LIMIT" ]; then continue; fi
    shown=$((shown + 1))
    IFS=$'\t' read -r m root f <<< "$rec"
    printf '  [%d] %-7s %s\n       %s · branch %s · %s · %s · id %s\n       ↳ %s…\n\n' \
      "$i" "$(session_flag "$f")" "$(session_name "$f")" \
      "$(session_cwd "$f")" "$(session_branch "$f")" "$(instance_label "$root")" \
      "$(session_size "$f")" "$(basename "$f" .jsonl | cut -c1-8)" "$(preview "$f")"
  done
  [ "${#RECORDS[@]}" -gt "$LIMIT" ] && echo "  … and $(( ${#RECORDS[@]} - LIMIT )) older sessions (raise with PULL_SESSION_LIMIT)."
  echo
  echo "Pull one in:  /pull-session:pull-session <number>   (or a session id)"
  echo "● busy = generating now · ○ open = running, idle · · recent = written <${LIVE_WINDOW}s ago."
  echo "Pulling a live one needs --force and won't compact it — run /compact in its own terminal first."
}

resolve() { # arg -> sets REC to the matching "mtime\troot\tfile"; supports index or (partial) id
  local a="$1" i=0 rec m root f
  if [[ "$a" =~ ^[0-9]+$ ]]; then
    for rec in "${RECORDS[@]}"; do i=$((i+1)); [ "$i" = "$a" ] && { REC="$rec"; return 0; }; done
    echo "No session numbered $a. Run with no argument to list."; exit 1
  fi
  for rec in "${RECORDS[@]}"; do
    IFS=$'\t' read -r m root f <<< "$rec"
    case "$(basename "$f" .jsonl)" in "$a"|"$a"*) REC="$rec"; return 0;; esac
  done
  echo "No session matching id '$a'. Run with no argument to list."; exit 1
}

summarize() {
  local force="${2:-}" m root f sid name
  resolve "$1"
  IFS=$'\t' read -r m root f <<< "$REC"
  sid="$(basename "$f" .jsonl)"
  name="$(session_name "$f")"
  local meta status pid; meta="$(sess_meta "$sid")"; status=""; pid=""
  [ -n "$meta" ] && IFS=$'\t' read -r _n status pid <<< "$meta"
  # LIVE = the current session in a folder with a live terminal, OR written very recently.
  # Resuming a session that's open in a terminal spins a second instance on it, so guard behind --force.
  if proc_live "$sid" || is_live "$m"; then
    if [ "$force" != "--force" ]; then
      echo "⚠ Session \"$name\" ($(instance_label "$root") · $sid) is OPEN in a terminal right now."
      echo "Summarizing it resumes it headlessly and appends a turn — it can interleave with the live instance."
      echo "For a clean merge, switch to that session and run /compact first (this tool can't compact it)."
      echo "To pull it anyway:  /pull-session:pull-session $1 --force"
      exit 0
    fi
  fi
  local prompt='You are handing your context off to a DIFFERENT Claude Code session that cannot see your history. In 200-400 words, summarize: (1) the goal/task, (2) key decisions and the reasoning, (3) files created or changed, (4) current state, (5) open threads / next steps. Be factual and concise. Output ONLY the summary.'
  local out
  if ! out="$(CLAUDE_CONFIG_DIR="$root" claude -p --resume "$sid" --output-format json "$prompt" 2>/dev/null)"; then
    echo "Could not query session \"$name\" ($sid) under $root (claude -p --resume failed)."; exit 1
  fi
  local summary
  summary="$(printf '%s' "$out" | jq -r 'try .result // empty' 2>/dev/null)"
  [ -z "$summary" ] && summary="$(printf '%s' "$out" | jq -r 'try (.[-1].result) // empty' 2>/dev/null)"
  [ -n "$summary" ] || { echo "Queried \"$name\" ($sid) but got no summary text back."; exit 1; }
  echo "=== CONTEXT PULLED FROM \"$name\" ($(instance_label "$root") · id $sid) ==="
  echo "$summary"
  echo "=== END PULLED CONTEXT ==="
}

pick_session() { # interactive arrow-key picker — TERMINAL ONLY (needs a TTY; can't run inside the slash command)
  command -v fzf >/dev/null 2>&1 || { echo "The 'pick' mode needs fzf — install it (brew install fzf / apt install fzf)."; exit 1; }
  local rec m root f sid menu choice cmd copied=""
  menu="$(
    for rec in "${RECORDS[@]}"; do
      IFS=$'\t' read -r m root f <<< "$rec"
      sid="$(basename "$f" .jsonl)"
      printf '%s\t%s  %s  %s · %s  |  %s  ↳ %s\n' \
        "$sid" "$(session_flag "$f")" "$(session_name "$f")" "$(instance_label "$root")" \
        "$(session_cwd "$f")" "$(session_size "$f")" "$(preview "$f")"
    done
  )"
  choice="$(printf '%s\n' "$menu" | fzf --delimiter=$'\t' --with-nth=2.. --nth=2.. \
              --prompt='pull-session ▶ ' --height=80% --reverse --no-hscroll \
              --header='↑/↓ move · Enter select · Esc cancel')" || { echo "cancelled."; exit 0; }
  sid="$(printf '%s' "$choice" | cut -f1)"
  [ -n "$sid" ] || { echo "no selection."; exit 0; }
  cmd="/pull-session:pull-session $sid"
  if   command -v pbcopy  >/dev/null 2>&1; then printf '%s' "$cmd" | pbcopy  && copied=" (copied to clipboard)"
  elif command -v wl-copy >/dev/null 2>&1; then printf '%s' "$cmd" | wl-copy && copied=" (copied to clipboard)"
  elif command -v xclip   >/dev/null 2>&1; then printf '%s' "$cmd" | xclip -selection clipboard 2>/dev/null && copied=" (copied to clipboard)"
  fi
  echo "Selected: $sid"
  echo "Paste into your Claude session:  $cmd${copied}"
}

case "${1:-}" in
  "")   list_sessions ;;
  pick) pick_session ;;
  *)    summarize "$1" "${2:-}" ;;
esac
