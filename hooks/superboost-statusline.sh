#!/bin/bash
# superboost-statusline.sh — full-width colorized HUD for HYVES CODE (v5.3)
# Part of HYVES CODE by ISYNCSO (https://isyncso.com)
#
# v5.3 — ONE VISUAL GRAMMAR (documented in CLAUDE.md §11; the code must match):
#
#   ROLE ORDER (left -> right):
#     IDENTITY   brand chip, model+effort chip (solid bg)
#     WORKSPACE  dir basename (dim), diff churn +N/-N
#     MACHINE    RAM label + gradient bar + stats, fan-out budget (fanout~N)
#     SESSION    ctx used% (solid alert >=85%), 200K+ flag, 5h rate, cost
#     ACTIVITY   FX wash canvas + effect label pinned at the right edge
#
#   QUIET BY DEFAULT (v5.4.1, the first law of the grammar): a HEALTHY value
#   renders NEUTRAL slate — hue appears only when a state needs attention
#   (amber/red thresholds) or an event fires (FX wash/label). The steady-state
#   bar is calm; color is the exception that carries the signal.
#
#   HUE FAMILIES (one family = one meaning, everywhere):
#     violet+gold IDENTITY (brand + model as bold TEXT on the base strip;
#                 v5.4.3: no solid identity slabs) — never status
#     green       CONFIRMED EVENTS (commit, pass; churn + is desaturated data)
#     amber       CAUTION/CHANGE   (RAM>=75, ctx>=60, tight budget, 7d>=70,
#                                   edit, compact)
#     red         CRITICAL/FAILED  (RAM>=85, ctx>=85 solid, 200K+, solo,
#                                   blocked, fail, error)
#     cyan        PARALLELISM EVENTS (fanout, join washes; the fanout~N
#                 readout is neutral until the budget constrains you)
#     blue        INFORMATION WORK (preflight, search, think, turn/WORKING)
#     indigo      SHIPPING         (deploy)
#     pink        NEEDS YOU        (attn — the only pink anywhere on the bar)
#     slate       NEUTRAL/HEALTHY  (all readouts at rest, dir, 5h, cost, done,
#                                   RAM bar fill, idle heartbeat)
#
#   EMPHASIS TIERS (exactly three): SOLID chip (bg+bold: urgent alerts + FX
#   label ONLY — solid means "act now") > TINTED text on the base strip
#   (identity bold, readouts regular) > DIM context (dir). Every chip pads
#   one space each side.
#
#   LIFECYCLE: the ACTIVITY canvas always says what the process is doing —
#   an event wash while fresh, a faint drifting slate heartbeat while a turn
#   works past its last event (never after done/attn), black when idle.
#
# WIDTH SAFETY (v4's hard-won lesson, still law): every VISIBLE glyph is plain
# ASCII (letters digits % ~ $ # - [ ] | space). All color — fg AND bg — is ANSI
# SGR only (38;2 / 48;2), which is zero display-width. Backgrounds are painted
# on SPACES, never on block glyphs (U+2591-3 are East-Asian-ambiguous width and
# can desync the TUI). Escape hatch: SUPERBOOST_STATUSLINE_PLAIN=1 -> pure ASCII.
#
# Reads session JSON on stdin; outputs a single status-bar line.

INPUT=$(cat)

# Deterministic text handling everywhere (v5.3): comma-decimal locales make
# bash printf reject "4.56" ("invalid number") and can slip commas into awk
# output; C locale also makes ${#var} count BYTES, which equals display width
# only because every visible string below is sanitized to printable ASCII.
export LC_ALL=C

PLAIN="${SUPERBOOST_STATUSLINE_PLAIN:-0}"
esc=$'\033'
RST=""; BOLD=""; DIM=""
c() { :; }; b() { :; }
if [ "$PLAIN" != "1" ]; then
  RST="${esc}[0m"; BOLD="${esc}[1m"; DIM="${esc}[2m"
  c() { printf '%s[38;2;%s;%s;%sm' "$esc" "$1" "$2" "$3"; }   # fg
  b() { printf '%s[48;2;%s;%s;%sm' "$esc" "$1" "$2" "$3"; }   # bg
fi

# --- Session JSON -> fields (single jq pass; tab-separated) ---
# v5.2.2: percentages rounded to 1 decimal in jq — the harness can emit float
# noise like 7.000000000000001, which rendered verbatim in the 5h chip; a
# missing/non-numeric value still yields the "-" sentinel via try/catch
IFS=$'\t' read -r MODEL COST CTX RLIM EFFORT ADDED REMOVED CWD BIG SID R7 <<EOF
$(echo "$INPUT" | jq -r '[
  ((.model.display_name // "?") | tostring | if . == "" then "?" else . end),
  (.cost.total_cost_usd // 0),
  (try (((.context_window.used_percentage * 10) | round) / 10) catch "-"),
  (try (((.rate_limits.five_hour.used_percentage * 10) | round) / 10) catch "-"),
  ((.effort.level // "-") | tostring | if . == "" then "-" else . end),
  (.cost.total_lines_added // 0),
  (.cost.total_lines_removed // 0),
  ((((.workspace.current_dir // .cwd // "") | tostring | split("/") | last) // "")
    | if . == "" then "-" else . end),
  (if .exceeds_200k_tokens == true then "1" else "0" end),
  ((.session_id // "-") | tostring | if . == "" then "-" else . end),
  (try (((.rate_limits.seven_day.used_percentage * 10) | round) / 10) catch "-")
] | @tsv' 2>/dev/null)
EOF
# tab-IFS read collapses EMPTY tsv fields (they'd shift right-hand fields left),
# hence the "-" placeholder for cwd above and these defaults for a failed jq pass
[ -z "$MODEL" ] && MODEL="?"
[ -z "$COST" ] && COST=0
[ -z "$CTX" ] && CTX="-"
[ -z "$RLIM" ] && RLIM="-"
[ -z "$EFFORT" ] && EFFORT="-"
[ "$CWD" = "-" ] && CWD=""
# v5.2 hygiene: dir basename must obey the ASCII width law (strip + truncate);
# churn fields must be integers; ctx% may arrive fractional (B3) -> integer part
# v5.3: MODEL/EFFORT get the same treatment — an emoji or CJK glyph in a model
# display_name made the visible line 1 cell wider than the width law allows
# (verified: "🚀 Fable 5" rendered 116 cells at COLUMNS=120)
CWD=$(printf '%s' "$CWD" | tr -cd '\40-\176' | cut -c1-16)
MODEL=$(printf '%s' "$MODEL" | tr -cd '\40-\176' | cut -c1-24)
EFFORT=$(printf '%s' "$EFFORT" | tr -cd '\40-\176' | cut -c1-8)
[ -z "$MODEL" ] && MODEL="?"
[ -z "$EFFORT" ] && EFFORT="-"
case "$ADDED" in ''|*[!0-9]*) ADDED=0 ;; esac
case "$REMOVED" in ''|*[!0-9]*) REMOVED=0 ;; esac
[ "$BIG" = "1" ] || BIG=0
CTX_INT="${CTX%%.*}"; case "$CTX_INT" in ''|*[!0-9]*) CTX_INT="" ;; esac
# v5.3: session id (first 8 chars) keys this session's FX state file
[ "$SID" = "-" ] && SID=""
SID8=$(printf '%s' "$SID" | LC_ALL=C tr -cd 'A-Za-z0-9-' | cut -c1-8)
[ -z "$R7" ] && R7="-"
R7_INT="${R7%%.*}"; case "$R7_INT" in ''|*[!0-9]*) R7_INT="" ;; esac

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

USED_PCT=$(( 100 - (AVAIL_MB * 100 / TOTAL_MB) ))
[ "$USED_PCT" -lt 0 ] && USED_PCT=0; [ "$USED_PCT" -gt 100 ] && USED_PCT=100

# --- Parallelism budget ---
SAFETY_MB=$(( TOTAL_MB * 15 / 100 )); [ "$SAFETY_MB" -lt 4096 ] && SAFETY_MB=4096
PER_AGENT_MB="${RESOURCE_PER_AGENT_MB:-1000}"
MAX_AGENTS=$(( (AVAIL_MB - SAFETY_MB) / PER_AGENT_MB )); [ "$MAX_AGENTS" -lt 0 ] && MAX_AGENTS=0
MAX_AGENT_CAP="${RESOURCE_MAX_AGENT_CAP:-20}"
[ "$MAX_AGENTS" -gt "$MAX_AGENT_CAP" ] && MAX_AGENTS="$MAX_AGENT_CAP"
# v5.4.1 quiet: capacity reads neutral while healthy — a permanently glowing
# cyan chip was noise; hue appears only when the budget CONSTRAINS you
if   [ "$MAX_AGENTS" -ge 3 ]; then CAP="fanout~${MAX_AGENTS}"; CAP_R=148; CAP_G=163; CAP_B=184
elif [ "$MAX_AGENTS" -ge 1 ]; then CAP="tight~${MAX_AGENTS}";  CAP_R=245; CAP_G=158; CAP_B=11
else                               CAP="solo";                 CAP_R=239; CAP_G=68;  CAP_B=68; fi

# --- FX state (effect color + freshness) ---
# v5.3 session scoping: hooks write to state.<sid8>; manual emits (no session
# context) write the global state. Render whichever record is NEWEST, so this
# session's own lifecycle wins but demo/manual emits still show everywhere.
FX_DIR_P="${SUPERBOOST_FX_DIR:-$HOME/.claude/fx}"
FX_STATE="$FX_DIR_P/state"
# v5.4 stats stash: latest ctx|5h|7d|cost|dir snapshot per session, written
# only when a value CHANGES (renders run at 1Hz when idle — no write churn).
# Consumers: `--turn` budget warnings (rate/context thresholds) and the
# SessionEnd ledger fold (`hyves stats`). Atomic like the FX state.
if [ -n "$SID8" ]; then
  STATS_F="$FX_DIR_P/stats.$SID8"
  COST2="$(printf '%.2f' "$COST" 2>/dev/null)"; [ -z "$COST2" ] && COST2="0.00"
  STATS_LINE="${CTX}|${RLIM}|${R7}|${COST2}|${CWD:--}"
  if [ "$STATS_LINE" != "$(cat "$STATS_F" 2>/dev/null)" ]; then
    printf '%s\n' "$STATS_LINE" > "$STATS_F.tmp.$$" 2>/dev/null \
      && mv -f "$STATS_F.tmp.$$" "$STATS_F" 2>/dev/null
    rm -f "$STATS_F.tmp.$$" 2>/dev/null
  fi
fi
if [ -n "$SID8" ] && [ -f "$FX_DIR_P/state.$SID8" ]; then
  if [ -f "$FX_STATE" ]; then
    _tg=$(IFS='|' read -r _ _ _ _ _ tg _ < "$FX_STATE" 2>/dev/null; printf '%s' "${tg%%.*}")
    _ts=$(IFS='|' read -r _ _ _ _ _ ts _ < "$FX_DIR_P/state.$SID8" 2>/dev/null; printf '%s' "${ts%%.*}")
    case "$_tg" in ''|*[!0-9]*) _tg=0 ;; esac
    case "$_ts" in ''|*[!0-9]*) _ts=0 ;; esac
    [ "$_ts" -ge "$_tg" ] && FX_STATE="$FX_DIR_P/state.$SID8"
  else
    FX_STATE="$FX_DIR_P/state.$SID8"
  fi
fi
NOW=$(date +%s 2>/dev/null); [ -z "$NOW" ] && NOW=0
# v5.2.1: FLOAT clock for animation phases. The statusline re-renders ~every
# 300ms, but keying motion off integer seconds froze it to 1 fps and made the
# scanner teleport (2.2 rad/integer-step ~ 126 deg jumps). BSD date has no %N;
# perl's Time::HiRes is on every macOS. Falls back to integer seconds.
NOW_F=$(perl -MTime::HiRes=time -e 'printf "%.2f", time' 2>/dev/null)
[ -z "$NOW_F" ] && NOW_F=$NOW
FX_ON=0; FX_EVENT=""; FX_LABEL=""; FX_R=0; FX_G=0; FX_B=0; FX_AGE=0; FX_TTL=7
if [ -f "$FX_STATE" ]; then
  IFS='|' read -r FX_EVENT FX_LABEL FX_R FX_G FX_B _t FX_TTL < "$FX_STATE" 2>/dev/null
  # v5.2.1: fx.sh now emits a FLOAT epoch (sweep/scanner phases start on time);
  # bash's integer arithmetic gates on the whole-second part, awk gets the float.
  _t_i="${_t%%.*}"
  case "$_t_i" in ''|*[!0-9]*) _t_i="" ;; esac
  # a malformed/extra-field state line lands junk in FX_TTL (the last read var
  # swallows the rest of the line), and non-numeric R/G/B blow up every later
  # $(( )) -> integer tests spewed stderr ~3x/sec; treat ANY bad field as no FX
  case "$FX_TTL" in ''|*[!0-9]*) FX_TTL=""; _t_i="" ;; esac
  case "$FX_R" in ''|*[!0-9]*) _t_i="" ;; esac
  case "$FX_G" in ''|*[!0-9]*) _t_i="" ;; esac
  case "$FX_B" in ''|*[!0-9]*) _t_i="" ;; esac
  if [ -n "$_t_i" ] && [ -n "$FX_TTL" ]; then
    FX_AGE=$(( NOW - _t_i ))
    [ "$FX_AGE" -ge 0 ] && [ "$FX_AGE" -lt "$FX_TTL" ] && FX_ON=1
  fi
fi
# v5.3 long-turn heartbeat: an expired effect whose last event was WORK (not
# done/attn) means the turn is still running with nothing new to report — show
# a faint drifting slate shimmer so an active turn is visibly alive instead of
# a dead-black canvas. Capped at 15 min so a crashed session can't pulse forever.
HEART=0
if [ "$FX_ON" = "0" ] && [ -n "$_t_i" ] && [ -n "$FX_TTL" ]; then
  case "$FX_EVENT" in
    done|attn) : ;;
    *) [ "$FX_AGE" -ge "$FX_TTL" ] && [ "$FX_AGE" -lt 900 ] && HEART=1 ;;
  esac
fi
# v5.4.2 intensity dial: SUPERBOOST_FX_INTENSITY = normal (v5.2.2 punchy
# levels) | low (same full-canvas coverage, ~half the luminance) | off (no
# canvas wash/heartbeat at all — the label chip still names the event).
FXI="${SUPERBOOST_FX_INTENSITY:-normal}"
case "$FXI" in low|off|normal) : ;; *) FXI="normal" ;; esac
if [ "$FXI" = "low" ]; then A1=10; A2=18; A3=28; A4=38; TINT_MAX=7; HB_AL=8
else                        A1=20; A2=40; A3=62; A4=82; TINT_MAX=14; HB_AL=14; fi

# v5.2: smoothstep ease-out decay + gentle sine pulse (~0.4 Hz, <10% luminance
# swing — WCAG 2.3.1-safe; replaces linear decay + the 4-frame table). Scales 0-100.
# v5.2.1: phases run on the float clock so decay/pulse glide between renders.
# v5.2.2: HOLD-then-ease — the pure smoothstep was near-black by mid-life while
# the label chip stayed lit to TTL, so a glance a few seconds after the event
# saw "label, no confirmation" (user screenshot-verified). Full strength for the
# first 35% of TTL, then smoothstep to 0 at TTL — still strictly falling to ~0.
read -r DECAY PULSE <<<"$(awk -v t="${_t:-0}" -v ttl="$FX_TTL" -v nowf="$NOW_F" 'BEGIN{
  agef=nowf-t; u=(ttl>0)?agef/ttl:1; if(u<0)u=0; if(u>1)u=1
  if(u<0.35){a=1}else{a=(1-u)/0.65; a=a*a*(3-2*a)}
  p=0.90+0.10*sin(nowf*2.6)
  printf "%d %d", a*100+0.5, p*100+0.5 }')"
: "${PULSE:=100}"; : "${DECAY:=0}"
[ "$FX_ON" = "1" ] || DECAY=0

# --- Base strip color: dark slate, tinted faintly toward an active effect ---
B0_R=22; B0_G=24; B0_B=31
if [ "$FX_ON" = "1" ] && [ "$FXI" != "off" ]; then
  _tint=$(( TINT_MAX * DECAY * PULSE / 10000 ))   # 0..TINT_MAX% toward effect color
  B0_R=$(( B0_R + (FX_R - B0_R) * _tint / 100 ))
  B0_G=$(( B0_G + (FX_G - B0_G) * _tint / 100 ))
  B0_B=$(( B0_B + (FX_B - B0_B) * _tint / 100 ))
fi
BG0="$(b "$B0_R" "$B0_G" "$B0_B")"

# --- Width ---
# COLUMNS must be validated BEFORE the arithmetic: a value like "80x" makes
# $(( )) itself error, leaving W empty so even the <40 clamp then errors
_COLS="${COLUMNS:-$(tput cols 2>/dev/null)}"
case "$_COLS" in ''|*[!0-9]*) _COLS=120 ;; esac
W=$(( _COLS - 5 ))
[ "$W" -lt 40 ] && W=40

# ============================ PLAIN / NARROW FALLBACK =========================
plain_line() {
  printf 'HYVES CODE V5 | RAM %s%% | %sGB free | %s | %s $%.2f\n' \
    "$USED_PCT" "$AVAIL_GB" "$CAP" "$MODEL" "$COST"
}
if [ "$PLAIN" = "1" ]; then plain_line; exit 0; fi

# ============================ FULL-WIDTH RENDER ===============================
# Fixed-text pieces (visible lengths tracked exactly; ASCII only)
BRAND_TXT=" HYVES CODE V5 "
MODEL_TXT=" ${MODEL}"
[ "$EFFORT" != "-" ] && MODEL_TXT="${MODEL_TXT} ${EFFORT}"
MODEL_TXT="${MODEL_TXT} "
RAM_LBL=" RAM "
STATS_TXT=" ${USED_PCT}% ${AVAIL_GB}GB free "
CTX_TXT=""
[ "$CTX" != "-" ] && CTX_TXT=" ctx ${CTX}% "
CAP_TXT=" ${CAP} "
RL_TXT=""
[ "$RLIM" != "-" ] && RL_TXT=" 5h ${RLIM}% "
# v5.4: weekly quota joins the session-budget group ONLY when it matters
# (>=70%) — a healthy week earns no pixels
R7_TXT=""
[ "${R7_INT:-0}" -ge 70 ] && R7_TXT=" 7d ${R7}% "
COST_TXT="$(printf ' $%.2f ' "$COST")"
FXL_TXT=""
[ "$FX_ON" = "1" ] && FXL_TXT=" ${FX_LABEL} "
# v5.2 density chips: workspace dir, diff churn, past-200k flag (all ASCII)
DIR_TXT=""
[ -n "$CWD" ] && DIR_TXT=" ${CWD} "
CHURN_TXT=""
[ $(( ADDED + REMOVED )) -gt 0 ] && CHURN_TXT=" +${ADDED} -${REMOVED} "
BIG_TXT=""
[ "$BIG" = "1" ] && BIG_TXT=" 200K+ "

# RAM bar width scales with the terminal (~12% of W, min 10)
RB=$(( W * 12 / 100 )); [ "$RB" -lt 10 ] && RB=10

FIXED=$(( ${#BRAND_TXT} + ${#MODEL_TXT} + ${#RAM_LBL} + RB + ${#STATS_TXT} \
        + ${#CTX_TXT} + ${#CAP_TXT} + ${#FXL_TXT} + ${#RL_TXT} + ${#R7_TXT} + ${#COST_TXT} \
        + ${#DIR_TXT} + ${#CHURN_TXT} + ${#BIG_TXT} ))
CANVAS=$(( W - FIXED ))
# v5.2.1: the canvas is the STAGE for washes/scanner/sweep — below ~18 cells the
# Gaussian head (sigma clamped >= 2) is as wide as the whole stage and motion
# reads as mush (measured: a 9-cell canvas at COLUMNS=150 pinned the scanner
# argmax to the label-side glow in 15/17 frames). Guarantee a minimum stage
# STATICALLY — independent of FX state, so the layout never shifts mid-effect:
# shrink the RAM bar first, then shed churn, then dir.
MIN_CANVAS=18
if [ "$CANVAS" -lt "$MIN_CANVAS" ] && [ "$RB" -gt 10 ]; then
  FIXED=$(( FIXED - RB + 10 )); RB=10; CANVAS=$(( W - FIXED ))
fi
if [ "$CANVAS" -lt "$MIN_CANVAS" ] && [ -n "$CHURN_TXT" ]; then
  FIXED=$(( FIXED - ${#CHURN_TXT} )); CHURN_TXT=""; CANVAS=$(( W - FIXED ))
fi
if [ "$CANVAS" -lt "$MIN_CANVAS" ] && [ -n "$DIR_TXT" ]; then
  FIXED=$(( FIXED - ${#DIR_TXT} )); DIR_TXT=""; CANVAS=$(( W - FIXED ))
fi
# too narrow for the full layout: compact line, hard-truncated so it can't wrap
if [ "$CANVAS" -lt 0 ]; then plain_line | cut -c1-"$W"; exit 0; fi

# --- RAM bar (v5.4.1 "quiet"): SINGLE-hue fill chosen by state, dark ghost
# for the rest. The old positional green->amber->red gradient painted a rainbow
# even on an idle machine — the loudest steady-state element on the bar. Now:
# neutral slate while healthy, amber >=75% used, red >=85%; hue change IS the
# signal, exactly once, when it matters. ---
if   [ "$USED_PCT" -ge 85 ]; then RB_R=239; RB_G=68;  RB_B=68
elif [ "$USED_PCT" -ge 75 ]; then RB_R=245; RB_G=158; RB_B=11
else                              RB_R=100; RB_G=116; RB_B=139; fi
RAMBAR=$(awk -v n="$RB" -v used="$USED_PCT" \
             -v fr="$RB_R" -v fg="$RB_G" -v fb="$RB_B" 'BEGIN{
  e=sprintf("%c",27); fill=int(n*used/100+0.5); out=""
  for(i=0;i<n;i++){
    if(i<fill){r=fr; g=fg; bl=fb}
    else      {r=34; g=37; bl=45}
    out=out e "[48;2;" r ";" g ";" bl "m "
  }
  printf "%s", out
}')

# --- FX canvas: quantized blocky wash (3-cell pixels), dithered + pulsed + decayed.
# v5.2: 1D plasma shimmer within the effect color, plus event-typed motion —
# fanout/deploy get a Larson scanner, commit a one-shot L->R sweep. All positions
# are pure functions of wall-clock, so a paused frame is a valid still. ---
if [ "$FX_ON" = "1" ] && [ "$CANVAS" -gt 0 ] && [ "$FXI" != "off" ]; then
  WASH=$(awk -v n="$CANVAS" -v now="$NOW" -v t="${_t:-0}" -v nowf="$NOW_F" \
             -v dec="$DECAY" -v pul="$PULSE" \
             -v a1="$A1" -v a2="$A2" -v a3="$A3" -v a4="$A4" \
             -v ev="$FX_EVENT" \
             -v fr="$FX_R" -v fg="$FX_G" -v fb="$FX_B" \
             -v br="$B0_R" -v bg="$B0_G" -v bb="$B0_B" 'BEGIN{
    e=sprintf("%c",27); nb=int((n+2)/3); out=""
    agef=nowf-t; if(agef<0)agef=0
    scan=-1; sweep=-1
    # v5.2.1: phases on the float clock -> the head GLIDES between renders.
    # Scanner bounce period ~3.5s (1.8 rad/s); sweep crosses in 3s.
    if(ev=="fanout"||ev=="deploy"){ scan=(n-1)*(0.5+0.5*sin(nowf*1.8)) }
    else if(ev=="commit" && agef<3){ sweep=n*agef/3.0 }
    for(i=0;i<n;i++){
      j=int(i/3)
      g=(nb<=1)?1:(j/(nb-1))              # 0 far-left .. 1 at the label (right)
      # v5.2.2: FLOORED falloff — pure g^1.5 left the far half of a wide
      # canvas black even at full strength (user screenshot-verified at ~250
      # cols); every cell now participates, still brightest at the label
      base=0.35+0.65*g*sqrt(g)
      s=0.5+0.5*sin(i*0.35+nowf*2.0)       # 1D plasma shimmer (slow, subtle)
      base*=0.72+0.28*s
      if(scan>=0 || sweep>=0) base*=0.35   # dim the glow so the moving head reads
      a=base*(dec/100.0)*(pul/100.0)
      if(scan>=0){ d=i-scan; sig=n/10.0; if(sig<2)sig=2; a+=0.9*exp(-d*d/(2*sig*sig))*(dec/100.0) }
      if(sweep>=0){ d=i-sweep; sig=n/14.0; if(sig<2)sig=2; a+=0.8*exp(-d*d/(2*sig*sig)) }
      lvl=int(a*4+0.5)
      d2=(j*73+now*13)%4                   # per-second dither -> shimmering pixels
      if(d2==0 && lvl>0) lvl--
      if(d2==3 && lvl<4 && lvl>0) lvl++
      if(lvl<0)lvl=0; if(lvl>4)lvl=4
      al=(lvl==0)?0:(lvl==1)?a1:(lvl==2)?a2:(lvl==3)?a3:a4   # alpha % per intensity dial
      r=br+int((fr-br)*al/100); gg=bg+int((fg-bg)*al/100); bl=bb+int((fb-bb)*al/100)
      out=out e "[48;2;" r ";" gg ";" bl "m "
    }
    printf "%s", out
  }')
elif [ "$HEART" = "1" ] && [ "$CANVAS" -gt 0 ] && [ "$FXI" != "off" ]; then
  # heartbeat: sparse slate cells drifting slowly right (~0.9 rad/s phase), a
  # pure function of wall-clock. Quiet by design — "alive", not "an event".
  WASH=$(awk -v n="$CANVAS" -v nowf="$NOW_F" -v hal="$HB_AL" \
             -v br="$B0_R" -v bg="$B0_G" -v bb="$B0_B" 'BEGIN{
    e=sprintf("%c",27); out=""
    for(i=0;i<n;i++){
      s=sin(i*0.35 - nowf*0.9)
      al=(s>0.60)?hal:0
      r=br+int((100-br)*al/100); g=bg+int((116-bg)*al/100); bl=bb+int((139-bb)*al/100)
      out=out e "[48;2;" r ";" g ";" bl "m "
    }
    printf "%s", out
  }')
else
  WASH="$(printf "${BG0}%*s" "$CANVAS" "")"
fi

# --- Chips ---
# v5.4.3 (user screenshot): identity had the last two solid slabs on an
# otherwise seamless strip and read as out of style. Identity is now TEXT on
# the shared base strip — violet brand, gold Fable / violet Opus — bold is its
# only emphasis. SOLID backgrounds are reserved for exactly two things:
# urgent alerts (200K+, ctx>=85) and the FX label. Solid = "act now".
BRAND="${BG0}$(c 196 181 253)${BOLD}${BRAND_TXT}${RST}"
case "$MODEL" in
  *[Ff]able*) MODEL_CHIP="${BG0}$(c 250 204 21)${BOLD}${MODEL_TXT}${RST}" ;;
  *[Oo]pus*)  MODEL_CHIP="${BG0}$(c 167 139 250)${BOLD}${MODEL_TXT}${RST}" ;;
  *)          MODEL_CHIP="${BG0}$(c 226 232 240)${BOLD}${MODEL_TXT}${RST}" ;;
esac
# readouts are neutral while healthy; amber/red only under pressure
if   [ "$USED_PCT" -ge 85 ]; then ST_R=239; ST_G=68;  ST_B=68
elif [ "$USED_PCT" -ge 75 ]; then ST_R=245; ST_G=158; ST_B=11
else                              ST_R=148; ST_G=163; ST_B=184; fi
STATS="${BG0}$(c "$ST_R" "$ST_G" "$ST_B")${STATS_TXT}${RST}"
RAML="${BG0}$(c 148 163 184)${RAM_LBL}${RST}"
CTXP=""
if [ -n "$CTX_TXT" ]; then
  # B3 fix: compare the integer part — a fractional used_percentage (e.g. 42.5)
  # made both integer tests error out and fall through to red
  # v5.3: >=85% escalates from a tinted readout to a SOLID alert chip (same
  # emphasis tier as 200K+) — context pressure is the alert users miss most.
  if [ "${CTX_INT:-0}" -ge 85 ]; then
    CTXP="$(b 127 29 29)$(c 254 202 202)${BOLD}${CTX_TXT}${RST}"
  else
    if [ "${CTX_INT:-0}" -lt 60 ]; then CX_R=148; CX_G=163; CX_B=184
    else                                CX_R=245; CX_G=158; CX_B=11; fi
    CTXP="${BG0}$(c "$CX_R" "$CX_G" "$CX_B")${CTX_TXT}${RST}"
  fi
fi
CAPP="${BG0}$(c "$CAP_R" "$CAP_G" "$CAP_B")${CAP_TXT}${RST}"
RLP=""
[ -n "$RL_TXT" ] && RLP="${BG0}$(c 100 116 139)${RL_TXT}${RST}"
R7P=""
if [ -n "$R7_TXT" ]; then
  # visible only under pressure -> status hues: amber <90, red >=90
  if [ "${R7_INT:-0}" -ge 90 ]; then R7P="${BG0}$(c 239 68 68)${R7_TXT}${RST}"
  else                               R7P="${BG0}$(c 245 158 11)${R7_TXT}${RST}"; fi
fi
COSTP="${BG0}$(c 148 163 184)${COST_TXT}${RST}"
FXLP=""
if [ "$FX_ON" = "1" ]; then
  # label chip pulses with the same sine; bright effect bg, dark text
  LR=$(( FX_R * PULSE / 100 )); LG=$(( FX_G * PULSE / 100 )); LB=$(( FX_B * PULSE / 100 ))
  FXLP="$(b "$LR" "$LG" "$LB")$(c 15 15 20)${BOLD}${FXL_TXT}${RST}"
fi
# v5.2 density chips
DIRP=""
[ -n "$DIR_TXT" ] && DIRP="${BG0}$(c 148 163 184)${DIM}${DIR_TXT}${RST}"
CHURNP=""
# churn is passive data, not status — desaturated diff hues, not neon
[ -n "$CHURN_TXT" ] && CHURNP="${BG0}$(c 110 160 130) +${ADDED}$(c 180 130 130) -${REMOVED} ${RST}"
BIGP=""
[ -n "$BIG_TXT" ] && BIGP="$(b 127 29 29)$(c 254 202 202)${BOLD}${BIG_TXT}${RST}"

# v5.3 role ordering (the grammar, left -> right): IDENTITY (brand, model) ->
# WORKSPACE (dir, churn) -> MACHINE (RAM bar+stats, fan-out budget) ->
# SESSION BUDGET (ctx, 200K+, 5h rate, cost) -> ACTIVITY (wash canvas + FX
# label pinned to the right edge, where the eye checks "what is it doing now").
printf '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n' \
  "$BRAND" "$MODEL_CHIP" "$DIRP" "$CHURNP" "$RAML" "$RAMBAR" "$RST" "$STATS" \
  "$CAPP" "$CTXP" "$BIGP" "$RLP" "$R7P" "$COSTP" "$WASH" "$FXLP"
