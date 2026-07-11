#!/usr/bin/env bash
# Install the /pull-session command into your Claude Code config.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

mkdir -p "$CFG/commands"
install -m 0755 "$HERE/pull-session.sh" "$CFG/commands/pull-session.sh"
install -m 0644 "$HERE/commands/pull-session.md" "$CFG/commands/pull-session.md"

echo "Installed:"
echo "  $CFG/commands/pull-session.sh"
echo "  $CFG/commands/pull-session.md"
echo
echo "Open a Claude Code session and run:  /pull-session"
echo "(Installs globally for all projects. For one project only, copy the two files into"
echo " that project's .claude/commands/ instead.)"
