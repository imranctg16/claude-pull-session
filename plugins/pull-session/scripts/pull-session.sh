#!/usr/bin/env bash
# pull-session v2 — discover Claude Code sessions across ALL local instances (config dirs)
# and ALL projects, flag which are live, and pull a chosen session's summary into the current one.
#
#   (no args)              -> list every session found (newest first), numbered, with a ● live flag
#   <number|session-id>    -> summarize that session and print it for the current session to absorb
#   <number|id> --force    -> pull even a LIVE session (see the live-session caveat below)
#
# Discovery: scans candidate config dirs (each contains a projects/ dir) —
#   $PULL_SESSION_DIRS (colon-separated, explicit override) · ${CLAUDE_CONFIG_DIR:-$HOME/.claude}
#   · ~/.claude, ~/.claude-*, and the same one level up (to catch HOME-swapped instances).
# "Live" = transcript written within $PULL_SESSION_LIVE_WINDOW seconds (default 120). There are no
# lock/PID files in Claude Code, so recent-write is the only signal — treat it as a hint, not proof.
#
# Summaries use `claude -p --resume <id>` run under that session's OWN config dir (cross-instance),
# NOT raw-JSONL parsing (undocumented format + transcripts can be tens of MB). This APPENDS a
# summary turn to the target session — harmless when idle, but for a LIVE session it can interleave
# with the running instance, so live sessions require --force. Claude Code has no headless /compact,
# so to shrink a live session before merging, run /compact in ITS terminal first (this tool can't).
set -euo pipefail
shopt -s nullglob

LIVE_WINDOW="${PULL_SESSION_LIVE_WINDOW:-120}"
NOW="$(date +%s)"

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

# ---- collect all sessions, newest first: each line = mtime<TAB>root<TAB>file ----
RECORDS=()
while IFS= read -r line; do RECORDS+=("$line"); done < <(
  for root in "${ROOTS[@]}"; do
    for f in "$root"/projects/*/*.jsonl; do
      [ -f "$f" ] || continue
      printf '%s\t%s\t%s\n' "$(stat -c %Y "$f" 2>/dev/null || echo 0)" "$root" "$f"
    done
  done | sort -rn -t"$(printf '\t')" -k1
)
[ "${#RECORDS[@]}" -gt 0 ] || { echo "No sessions found under: ${ROOTS[*]}"; exit 1; }

instance_label() { # short tag for a config dir root
  local r="$1"
  case "$r" in
    "$HOME/.claude") echo "default" ;;
    *) basename "$(dirname "$r")" | sed 's/^\.//' ;;   # e.g. .claude-user2 -> claude-user2
  esac
}
project_label() { # accurate cwd from the transcript, fallback to the dashed hash
  local f="$1" cwd
  cwd="$(grep -m1 -oE '"cwd":"[^"]+"' "$f" 2>/dev/null | head -1 | sed 's/"cwd":"//;s/"$//')"
  [ -n "$cwd" ] && { basename "$cwd"; return; }
  basename "$(dirname "$f")"
}
preview() {
  local f="$1" msg=""
  msg="$(grep -m1 '"type":"user"' "$f" 2>/dev/null \
        | jq -r 'try (.message.content) // empty' 2>/dev/null \
        | jq -r 'if type=="array" then (map(.text? // "")|join(" ")) else . end' 2>/dev/null \
        | tr '\n' ' ' | sed 's/  */ /g')"
  [ -z "$msg" ] && msg="$(grep -m1 -oE '"content":"[^"]{4,90}' "$f" 2>/dev/null | sed 's/"content":"//')"
  printf '%.78s' "${msg:-(no preview)}"
}
is_live() { [ "$(( NOW - $1 ))" -le "$LIVE_WINDOW" ]; }

list_sessions() {
  echo "Claude Code sessions — all instances, all projects (newest first):"
  echo
  local i=0 rec m root f
  for rec in "${RECORDS[@]}"; do
    i=$((i + 1))
    IFS=$'\t' read -r m root f <<< "$rec"
    local flag ts
    if is_live "$m"; then flag="● live"; else flag="  idle"; fi
    ts="$(date -d "@$m" '+%b%d %H:%M' 2>/dev/null || echo '?')"
    printf '  [%d] %s  %s  %s · %s\n        ↳ %s…\n\n' \
      "$i" "$flag" "$ts" "$(instance_label "$root")" "$(project_label "$f")" "$(preview "$f")"
  done
  echo "Pull one in:  /pull-session:pull-session <number>   (or a session id)"
  echo "● live = written in the last ${LIVE_WINDOW}s. Pulling a live one needs --force,"
  echo "and won't compact it — for that, run /compact in that session's own terminal first."
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
  local force="${2:-}" m root f sid
  resolve "$1"
  IFS=$'\t' read -r m root f <<< "$REC"
  sid="$(basename "$f" .jsonl)"
  if is_live "$m" && [ "$force" != "--force" ]; then
    echo "⚠ Session $sid ($(instance_label "$root") · $(project_label "$f")) looks LIVE (written $(( NOW - m ))s ago)."
    echo "Summarizing it appends a turn to it and may interleave with the running instance."
    echo "For a clean merge, switch to that session and run /compact first (this tool can't compact it)."
    echo "To pull it anyway:  /pull-session:pull-session $1 --force"
    exit 0
  fi
  local prompt='You are handing your context off to a DIFFERENT Claude Code session that cannot see your history. In 200-400 words, summarize: (1) the goal/task, (2) key decisions and the reasoning, (3) files created or changed, (4) current state, (5) open threads / next steps. Be factual and concise. Output ONLY the summary.'
  local out
  if ! out="$(CLAUDE_CONFIG_DIR="$root" claude -p --resume "$sid" --output-format json "$prompt" 2>/dev/null)"; then
    echo "Could not query session $sid under $root (claude -p --resume failed)."; exit 1
  fi
  local summary
  summary="$(printf '%s' "$out" | jq -r 'try .result // empty' 2>/dev/null)"
  [ -z "$summary" ] && summary="$(printf '%s' "$out" | jq -r 'try (.[-1].result) // empty' 2>/dev/null)"
  [ -n "$summary" ] || { echo "Queried $sid but got no summary text back."; exit 1; }
  echo "=== CONTEXT PULLED FROM SESSION $sid ($(instance_label "$root") · $(project_label "$f")) ==="
  echo "$summary"
  echo "=== END PULLED CONTEXT ==="
}

if [ "$#" -eq 0 ] || [ -z "${1:-}" ]; then
  list_sessions
else
  summarize "$1" "${2:-}"
fi
