#!/usr/bin/env bash
# Install this statusline into a Claude Code config dir.
# Usage: ./install.sh
# Env:   CLAUDE_CONFIG_DIR (default: $HOME/.claude)
set -euo pipefail

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Install it first (e.g. apt install jq / brew install jq)." >&2
  exit 1
fi

mkdir -p "$CFG"
cp "$SRC_DIR/statusline.sh" "$CFG/statusline.sh"
chmod +x "$CFG/statusline.sh"

SETTINGS="$CFG/settings.json"
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

TMP=$(mktemp)
jq --arg cmd "bash \"$CFG/statusline.sh\"" '
  .statusLine = {
    "type": "command",
    "command": $cmd,
    "refreshInterval": 10
  }
' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"

echo "Installed statusline.sh to $CFG/statusline.sh"
echo "Updated $SETTINGS with the statusLine block."
echo "Restart Claude Code (or open a new session) to see it."
