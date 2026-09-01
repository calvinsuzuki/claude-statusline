#!/usr/bin/env bash
# Claude Code statusline - one line.
#
#   model (caveman-prefixed) . effort . project . context % . 5h % + reset . session
#
# Segments run most-important first: the renderer truncates the tail on a narrow
# terminal, so the session counters go before the usage numbers do.
#
# Reads the session JSON on stdin (code.claude.com/docs/en/statusline).
# Wire it up in ~/.claude/settings.json:
#   "statusLine": { "type": "command",
#                   "command": "bash \"$HOME/.claude/statusline.sh\"",
#                   "refreshInterval": 10 }
# refreshInterval is what makes the reset countdowns tick without keystrokes.

input=$(cat)
[ -z "$input" ] && exit 0

now=${EPOCHSECONDS:-$(date +%s)}
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# ---------------------------------------------------------------- palette ---
Z=$'\033[0m'
GRN=$'\033[38;5;42m'  ; YEL=$'\033[38;5;178m'
ORG=$'\033[38;5;208m' ; RED=$'\033[38;5;196m'
PUR=$'\033[38;5;141m' ; CYN=$'\033[38;5;80m'
DIM=$'\033[38;5;240m' ; LBL=$'\033[38;5;245m'
BLD=$'\033[1m'
SEP=" ${DIM}│${Z} "

# sev <pct> -> $_sev : green under 50, yellow under 75, orange under 90, red above.
sev() {
  if   (( $1 >= 90 )); then _sev=$RED
  elif (( $1 >= 75 )); then _sev=$ORG
  elif (( $1 >= 50 )); then _sev=$YEL
  else                      _sev=$GRN
  fi
}

# fmt_dur <seconds> -> $_d : 2d04h / 1h29m / 47m / now
fmt_dur() {
  local s=$1
  if   (( s <= 0 ));     then _d='now'
  elif (( s >= 86400 )); then printf -v _d '%dd%02dh' $((s/86400)) $(((s%86400)/3600))
  elif (( s >= 3600 ));  then printf -v _d '%dh%02dm' $((s/3600))  $(((s%3600)/60))
  else                        printf -v _d '%dm' $(((s+59)/60))
  fi
}

# ------------------------------------------------------------ session JSON ---
# One jq pass, one value per line so empty fields survive the split.
mapfile -t F < <(printf '%s' "$input" | jq -r '[
  (.model.display_name // "?"),
  (.effort.level // ""),
  (if .fast_mode then 1 else 0 end),
  (.workspace.project_dir // ""),
  (.workspace.current_dir // ""),
  (.context_window.used_percentage // 0 | floor),
  (.rate_limits.five_hour.used_percentage // -1 | floor),
  (.rate_limits.five_hour.resets_at // 0),
  (.cost.total_duration_ms // 0 | floor),
  (.cost.total_lines_added // 0),
  (.cost.total_lines_removed // 0)
] | map(tostring) | .[]' 2>/dev/null)

# jq missing or payload malformed: stay silent rather than print garbage.
(( ${#F[@]} < 11 )) && exit 0

model=${F[0]}    effort=${F[1]}  fast=${F[2]}
proj_dir=${F[3]} cur_dir=${F[4]} ctx_pct=${F[5]}
p5=${F[6]}       r5=${F[7]}
dur_ms=${F[8]}   ladd=${F[9]}    ldel=${F[10]}

# ------------------------------------------------------------------ segments ---
# Caveman mode rides on the model name: "Caveman Opus 5". Read the flag file
# directly rather than shelling out to the plugin badge script - its path carries
# a version hash that moves on every plugin update.
CAVE=""
FLAG="$CFG/.caveman-active"
if [ -f "$FLAG" ] && [ ! -L "$FLAG" ]; then
  # Cap the read and strip to [a-z0-9-]: the flag is world-writable territory and
  # its bytes land in the terminal, so no escape sequences get through.
  mode=$(head -c 64 "$FLAG" 2>/dev/null | tr -d '\n\r' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
  case $mode in
    ''|full)                                        CAVE="Caveman" ;;
    lite|ultra|wenyan|wenyan-lite|wenyan-full|\
    wenyan-ultra|commit|review|compress)            CAVE="Caveman:$mode" ;;
    *)                                              CAVE="" ;;
  esac
fi

id_seg=""
[ -n "$CAVE" ] && id_seg="${ORG}${CAVE}${Z} "
id_seg+="${BLD}${PUR}${model}${Z}"
[ -n "$effort" ] && id_seg+=" ${DIM}${effort}${Z}"
(( fast ))  && id_seg+=" ${ORG}fast${Z}"

# Project label, plus the path inside it when the cwd sits deeper.
loc=""
if [ -n "$proj_dir" ]; then
  loc="${proj_dir##*/}"
  if [ -n "$cur_dir" ] && [ "$cur_dir" != "$proj_dir" ] && [[ $cur_dir == "$proj_dir"/* ]]; then
    loc+="/${cur_dir#"$proj_dir"/}"
  fi
elif [ -n "$cur_dir" ]; then
  loc="${cur_dir##*/}"
fi
loc_seg=""
[ -n "$loc" ] && loc_seg="${CYN}${loc}${Z}"

# Session so far: wall time, and how much code actually moved.
fmt_dur $(( dur_ms / 1000 )); sess=$_d
[ "$sess" = now ] && sess='0m'
tail_seg="${DIM}${sess}${Z}"
if (( ladd || ldel )); then
  tail_seg+=" ${GRN}+${ladd}${Z}${DIM}/${Z}${RED}-${ldel}${Z}"
fi

sev "$ctx_pct"
ctx_seg="${LBL}ctx${Z} ${_sev}${ctx_pct}%${Z}"

# limit_seg <label> <pct> <resets_at> -> $_seg : percentage plus time left.
limit_seg() {
  local lb=$1 p=$2 reset=$3
  if (( p < 0 )); then _seg=""; return; fi
  sev "$p"
  _seg="${LBL}${lb}${Z} ${_sev}${p}%${Z}"
  if (( reset > 0 )); then
    fmt_dur $(( reset - now ))
    _seg+=" ${DIM}${_d}${Z}"
  fi
}

limit_seg 5h "$p5" "$r5"; five_seg=$_seg

out=""
for s in "$id_seg" "$loc_seg" "$ctx_seg" "$five_seg" "$tail_seg"; do
  [ -z "$s" ] && continue
  if [ -z "$out" ]; then out="$s"; else out+="$SEP$s"; fi
done

printf '%s' "$out"
