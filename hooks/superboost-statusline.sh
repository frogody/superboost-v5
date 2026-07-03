#!/bin/bash
# superboost-statusline.sh — colorized RAM/model/FX HUD for Claude Code Superboost (v5.0)
# Part of Claude Code Superboost by ISYNCSO (https://isyncso.com)
#
# v5.0 vs v4.0 — this is the "make the bottom bar great" change:
#   - COLOR IS BACK, done safely. v4 stripped ALL color because v3 emitted raw ANSI
#     *plus* a wide 'lightning' emoji, and the wide glyph corrupted the TUI width calc.
#     The fix is not "no color" — it's "no WIDE glyphs". This version emits ONLY ANSI
#     SGR sequences (38;2;r;g;b truecolor + reset), which are zero display-width and
#     stripped by the width calc, and keeps every VISIBLE glyph ASCII (# - [ ] | space).
#     Correct width => no mouse-coordinate desync, no SGR leak into the input line.
#   - RAM bar is a green->amber->red gradient keyed to used%.
#   - New live FX segment: reads ~/.claude/fx/state (written by superboost-fx.sh) and
#     renders a decaying, pulsing colored [LABEL] for a few seconds after an action
#     (preflight, fan-out, commit, deploy, blocked, edit, search...).
#   - Capacity hint is now the v5 parallelism budget ("fanout~N").
#   - ESCAPE HATCH: set SUPERBOOST_STATUSLINE_PLAIN=1 to fall back to pure ASCII, no
#     color — identical safety profile to v4 if any terminal miscounts SGR width.
#
# Reads session JSON on stdin; outputs a single plain-text status-bar line.

INPUT=$(cat)
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "?"' 2>/dev/null)
COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)

PLAIN="${SUPERBOOST_STATUSLINE_PLAIN:-0}"

# --- Color helpers (truecolor SGR; all zero-width). Disabled in PLAIN mode. ---
esc=$'\033'
RST=""; c() { :; }        # defaults for PLAIN mode
if [ "$PLAIN" != "1" ]; then
  RST="${esc}[0m"
  c() { printf '%s[38;2;%s;%s;%sm' "$esc" "$1" "$2" "$3"; }   # c R G B -> fg color
fi
BOLD=""; DIM=""
if [ "$PLAIN" != "1" ]; then BOLD="${esc}[1m"; DIM="${esc}[2m"; fi

# --- Live RAM stats ---
if [ "$(uname)" = "Darwin" ]; then
  PAGE_SIZE=$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)
  VM=$(vm_stat 2>/dev/null)
  FREE_P=$(echo "$VM" | awk '/^Pages free:/ {gsub(/[^0-9]/,"",$3); print $3+0}')
  INACT_P=$(echo "$VM" | awk '/^Pages inactive:/ {gsub(/[^0-9]/,"",$3); print $3+0}')
  PURG_P=$(echo "$VM" | awk '/^Pages purgeable:/ {gsub(/[^0-9]/,"",$3); print $3+0}')
  SPEC_P=$(echo "$VM" | awk '/^Pages speculative:/ {gsub(/[^0-9]/,"",$3); print $3+0}')
  AVAIL_MB=$(( (FREE_P + INACT_P + PURG_P + SPEC_P) * PAGE_SIZE / 1024 / 1024 ))
  TOTAL_MB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 ))
else
  AVAIL_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
  TOTAL_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
fi
[ "${TOTAL_MB:-0}" -lt 1 ] && TOTAL_MB=1

AVAIL_GB=$(awk "BEGIN {printf \"%.1f\", $AVAIL_MB / 1024}")

# --- Parallelism budget (RAM-scaled fan-out capacity) ---
SAFETY_MB=$(( TOTAL_MB * 15 / 100 )); [ "$SAFETY_MB" -lt 4096 ] && SAFETY_MB=4096
PER_AGENT_MB="${RESOURCE_PER_AGENT_MB:-1000}"
MAX_AGENTS=$(( (AVAIL_MB - SAFETY_MB) / PER_AGENT_MB )); [ "$MAX_AGENTS" -lt 0 ] && MAX_AGENTS=0
MAX_AGENT_CAP="${RESOURCE_MAX_AGENT_CAP:-20}"
[ "$MAX_AGENTS" -gt "$MAX_AGENT_CAP" ] && MAX_AGENTS="$MAX_AGENT_CAP"

# --- ASCII RAM bar (10 cells), colored per-cell by pressure (gradient) ---
USED_PCT=$(( 100 - (AVAIL_MB * 100 / TOTAL_MB) ))
[ "$USED_PCT" -lt 0 ] && USED_PCT=0; [ "$USED_PCT" -gt 100 ] && USED_PCT=100
FILLED=$(( USED_PCT / 10 )); EMPTY=$(( 10 - FILLED ))

# whole-bar color by pressure band (green / amber / red)
if [ "$USED_PCT" -lt 50 ]; then BAR_R=34; BAR_G=197; BAR_B=94
elif [ "$USED_PCT" -lt 75 ]; then BAR_R=245; BAR_G=158; BAR_B=11
else BAR_R=239; BAR_G=68; BAR_B=68; fi

BAR="$(c "$BAR_R" "$BAR_G" "$BAR_B")"
for ((i=0; i<FILLED; i++)); do BAR="${BAR}#"; done
if [ "$PLAIN" != "1" ]; then BAR="${BAR}${DIM}"; fi
for ((i=0; i<EMPTY; i++)); do BAR="${BAR}-"; done
BAR="${BAR}${RST}"

# capacity color: green when wide, amber when moderate, red when solo
if [ "$MAX_AGENTS" -ge 8 ]; then CAP_COL="$(c 34 211 238)"; CAP="fanout~${MAX_AGENTS}"
elif [ "$MAX_AGENTS" -ge 3 ]; then CAP_COL="$(c 245 158 11)"; CAP="fanout~${MAX_AGENTS}"
elif [ "$MAX_AGENTS" -ge 1 ]; then CAP_COL="$(c 245 158 11)"; CAP="tight~${MAX_AGENTS}"
else CAP_COL="$(c 239 68 68)"; CAP="solo"; fi

# GB-free color mirrors the pressure band
if [ "$USED_PCT" -lt 50 ]; then GB_COL="$(c 34 197 94)"
elif [ "$USED_PCT" -lt 75 ]; then GB_COL="$(c 245 158 11)"
else GB_COL="$(c 239 68 68)"; fi

# --- Model segment: gold for Fable, violet otherwise ---
case "$MODEL" in
  *[Ff]able*) MODEL_COL="$(c 250 204 21)" ;;   # gold — Fable 5
  *[Oo]pus*)  MODEL_COL="$(c 168 85 247)" ;;   # violet — Opus
  *)          MODEL_COL="$(c 148 163 184)" ;;  # slate — other
esac

# --- Cost segment ---
COST_PART=""
if [ "$(echo "$COST > 0" | bc 2>/dev/null)" = "1" ]; then
  COST_PART=" ${DIM}$(printf '$%.2f' "$COST")${RST}"
fi

# --- FX segment: decaying, pulsing colored [LABEL] from superboost-fx.sh ---
FX_STATE="${SUPERBOOST_FX_DIR:-$HOME/.claude/fx}/state"
FX_PART=""
if [ "$PLAIN" != "1" ] && [ -f "$FX_STATE" ]; then
  IFS='|' read -r _fx_eff _fx_label _fx_r _fx_g _fx_b _fx_t _fx_ttl < "$FX_STATE" 2>/dev/null
  NOW=$(date +%s 2>/dev/null); [ -z "$NOW" ] && NOW=0
  if [ -n "$_fx_t" ] && [ -n "$_fx_ttl" ]; then
    AGE=$(( NOW - _fx_t ))
    if [ "$AGE" -ge 0 ] && [ "$AGE" -lt "$_fx_ttl" ]; then
      # pulse: 4-frame brightness table keyed to wall-clock second
      frames=(10 8 6 8); f=${frames[$(( NOW % 4 ))]}
      pr=$(( _fx_r * f / 10 )); pg=$(( _fx_g * f / 10 )); pb=$(( _fx_b * f / 10 ))
      FX_PART=" ${BOLD}$(c "$pr" "$pg" "$pb")[${_fx_label}]${RST}"
    fi
  fi
fi

# --- Assemble (single line, ASCII glyphs only; color via zero-width SGR) ---
BRAND="$(c 168 85 247)${BOLD}SUPERBOOST${RST}"
SEP="${DIM}|${RST}"

printf '%s %s RAM [%s] %s%s%%%s %s %s%sGB free%s %s %s%s%s %s%s%s%s\n' \
  "$BRAND" "$SEP" \
  "$BAR" "$GB_COL" "$USED_PCT" "$RST" \
  "$SEP" "$GB_COL" "$AVAIL_GB" "$RST" \
  "$SEP" "$CAP_COL" "$CAP" "$RST" \
  "$MODEL_COL$BOLD" "$MODEL" "$RST" "$COST_PART$FX_PART"
