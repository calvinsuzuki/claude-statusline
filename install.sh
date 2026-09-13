#!/usr/bin/env bash
# Install this statusline into a Claude Code config dir.
# Usage (cloned repo):  ./install.sh
# Usage (one-liner):    curl -fsSL <raw-url>/install.sh | bash
# Env:   CLAUDE_CONFIG_DIR (default: $HOME/.claude)
set -euo pipefail

RAW_BASE="https://raw.githubusercontent.com/calvinsuzuki/claude-statusline/main"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Install it first (e.g. apt install jq / brew install jq)." >&2
  exit 1
fi

mkdir -p "$CFG"

if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/statusline.sh" ]; then
  cp "$SRC_DIR/statusline.sh" "$CFG/statusline.sh"
else
  # Running via curl | bash: no local file, pull it straight from GitHub.
  curl -fsSL "$RAW_BASE/statusline.sh" -o "$CFG/statusline.sh"
fi
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
