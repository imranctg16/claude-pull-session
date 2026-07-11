#!/usr/bin/env bash
# pull-session — pull a summary of ANOTHER Claude Code session into the current one.
#
# No args      -> lists the other sessions for THIS project (newest first, with a preview).
# <session-id> -> asks that session (headless) to summarize itself, and prints the summary
#                 so the calling session can absorb it as context.
#
# Sessions live at:  ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<cwd-with-nonalnum-as-dashes>/<id>.jsonl
# The summary is produced with `claude -p --resume <id>` (a supported, format-agnostic path),
# NOT by parsing the raw JSONL (whose internal shape is undocumented and changes between releases).
set -euo pipefail

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PROJ_DIR="$(pwd)"
HASH="$(printf '%s' "$PROJ_DIR" | sed 's/[^a-zA-Z0-9]/-/g')"
TDIR="$CFG/projects/$HASH"

if [ ! -d "$TDIR" ] || ! ls "$TDIR"/*.jsonl >/dev/null 2>&1; then
  echo "No Claude Code sessions found for this project."
  echo "  looked in: $TDIR"
  exit 1
fi

preview() {  # best-effort first-user-message snippet; never fails the run
  local f="$1" msg=""
  msg="$(grep -m1 '"type":"user"' "$f" 2>/dev/null \
        | jq -r 'try (.message.content) // empty' 2>/dev/null \
        | jq -r 'if type=="array" then (map(.text? // "") | join(" ")) else . end' 2>/dev/null \
        | tr '\n' ' ' | sed 's/  */ /g')"
  [ -z "$msg" ] && msg="$(grep -m1 -oE '"content":"[^"]{4,90}' "$f" 2>/dev/null | sed 's/"content":"//')"
  printf '%.90s' "${msg:-(no preview)}"
}

list_sessions() {
  echo "Claude Code sessions for this project:"
  echo "  $PROJ_DIR"
  echo
  local i=0
  while IFS= read -r f; do
    i=$((i + 1))
    local id ts
    id="$(basename "$f" .jsonl)"
    ts="$(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null || echo '????-??-?? ??:??')"
    printf '  %s  %s\n       ↳ %s…\n\n' "$ts" "$id" "$(preview "$f")"
  done < <(ls -t "$TDIR"/*.jsonl)
  echo "The newest is usually THIS session. To pull another in:"
  echo "  /pull-session:pull-session <session-id>"
}

summarize_session() {
  local id="$1"
  local f="$TDIR/$id.jsonl"
  if [ ! -f "$f" ]; then
    echo "Session '$id' not found in this project."
    echo "Run /pull-session:pull-session with no argument to list available sessions."
    exit 1
  fi
  local prompt='You are handing your context off to a DIFFERENT Claude Code session that cannot see your history. In 200-400 words, summarize: (1) the goal/task, (2) key decisions and the reasoning, (3) files created or changed, (4) the current state, (5) open threads / next steps. Be factual and concise. Output ONLY the summary, no preamble.'
  local out
  if ! out="$(claude -p --resume "$id" --output-format json "$prompt" 2>/dev/null)"; then
    echo "Could not query session '$id' (claude -p --resume failed). Is the session id correct and in this directory?"
    exit 1
  fi
  local summary
  summary="$(printf '%s' "$out" | jq -r 'try .result // empty' 2>/dev/null)"
  [ -z "$summary" ] && summary="$(printf '%s' "$out" | jq -r 'try .[-1].result // empty' 2>/dev/null)"
  if [ -z "$summary" ]; then
    echo "Queried session '$id' but got no summary text back."
    exit 1
  fi
  echo "=== CONTEXT PULLED FROM SESSION $id ==="
  echo "$summary"
  echo "=== END PULLED CONTEXT ==="
}

if [ "$#" -eq 0 ] || [ -z "${1:-}" ]; then
  list_sessions
else
  summarize_session "$1"
fi
