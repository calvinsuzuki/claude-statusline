# claude-code-statusline

Custom one-line statusline for [Claude Code](https://claude.com/claude-code).

```
Caveman claude-sonnet-5 xhigh │ my-project/src │ ctx 42% │ 5h 61% 2h14m │ 1h29m +120/-34
```

Segments (most important first — the renderer truncates the tail on narrow terminals):

- **model** — display name, prefixed with `Caveman[:mode]` if caveman mode is active, plus effort level and `fast` flag
- **project** — project dir name, plus subpath if cwd is nested inside it
- **ctx** — context window used %, colored by severity (green/yellow/orange/red)
- **5h** — 5-hour rate limit used %, plus time until reset
- session tail — wall time this session, plus lines `+added/-removed`

## Requirements

- `bash` (uses `EPOCHSECONDS`, needs bash 4+; falls back to `date +%s` if unset)
- `jq`

## Install

One-liner (no clone needed):

```bash
curl -fsSL https://raw.githubusercontent.com/calvinsuzuki/claude-statusline/main/install.sh | bash
```

Or clone first:

```bash
git clone https://github.com/calvinsuzuki/claude-statusline.git
cd claude-statusline
./install.sh
```

Either way this copies `statusline.sh` to `~/.claude/statusline.sh` and merges a
`statusLine` block into `~/.claude/settings.json` (existing settings are
preserved — only the `statusLine` key is added/overwritten). Requires `jq`.

Set `CLAUDE_CONFIG_DIR` before running if your Claude config lives elsewhere:

```bash
CLAUDE_CONFIG_DIR=/path/to/.claude curl -fsSL https://raw.githubusercontent.com/calvinsuzuki/claude-statusline/main/install.sh | bash
```

## Manual install

Copy `statusline.sh` anywhere and add this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"/path/to/statusline.sh\"",
    "refreshInterval": 10
  }
}
```

## Notes

- The caveman badge reads `$CLAUDE_CONFIG_DIR/.caveman-active` if present; without
  it (or without the [caveman plugin](https://github.com/JuliusBrussee/caveman))
  that segment is simply skipped — no hard dependency.
- If `jq` is missing or the session JSON is malformed, the script exits silently
  rather than printing garbage.
