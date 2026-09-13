#!/usr/bin/env bash
# Install this statusline into a Claude Code config dir.
# Usage (cloned repo):  ./install.sh
# Usage (one-liner):    curl -fsSL <raw-url>/install.sh | bash
# Env:   CLAUDE_CONFIG_DIR (default: $HOME/.claude)
set -euo pipefail

RAW_BASE="https://raw.githubusercontent.com/calvinsuzuki/claude-statusline/main"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || true)"

install_jq() {
  local sudo=""
  [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && sudo="sudo"
  if command -v brew >/dev/null 2>&1; then brew install jq
  elif command -v apt-get >/dev/null 2>&1; then $sudo apt-get update -qq && $sudo apt-get install -y jq
  elif command -v dnf >/dev/null 2>&1; then $sudo dnf install -y jq
  elif command -v yum >/dev/null 2>&1; then $sudo yum install -y jq
  elif command -v pacman >/dev/null 2>&1; then $sudo pacman -Sy --noconfirm jq
  elif command -v apk >/dev/null 2>&1; then $sudo apk add jq
  elif command -v zypper >/dev/null 2>&1; then $sudo zypper install -y jq
  else return 1
  fi
}

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found, installing..." >&2
  if ! install_jq || ! command -v jq >/dev/null 2>&1; then
    echo "Could not auto-install jq. Install it yourself (e.g. apt install jq / brew install jq) and re-run." >&2
    exit 1
  fi
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
