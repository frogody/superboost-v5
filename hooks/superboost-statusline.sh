#!/bin/bash
# superboost-statusline.sh — full-width colorized HUD for Claude Code Superboost (v5.1)
# Part of Claude Code Superboost by ISYNCSO (https://isyncso.com)
#
# v5.1 — "use the whole bar": the statusline now claims the entire terminal width
# (COLUMNS is provided in the hook environment) and paints with truecolor
# BACKGROUNDS, not just letter colors:
#   - Chip layout: brand / model+effort chips with solid bg, stats on a dark base
#     strip that spans the full width.
#   - RAM bar: wide, bg-colored cell gradient (green->amber->red positionally),
#     filled cells bright / unfilled a dark ghost of the same gradient.
#   - FX washes: when superboost-fx.sh records an event, the flexible canvas
#     region floods with a QUANTIZED BLOCKY background wash in the effect color —
#     chunky 3-cell "pixels" whose brightness falls off with distance from the
#     label, dithered per-second so it shimmers, pulsed by the 4-frame table,
#     and decayed to nothing over the TTL. The base strip also tints faintly
#     toward the effect color so the whole bar "breathes" with the event.
#   - New data chips from the session JSON: ctx used%, effort level, 5h rate use.
#
# WIDTH SAFETY (v4's hard-won lesson, still law): every VISIBLE glyph is plain
# ASCII (letters digits % ~ $ # - [ ] | space). All color — fg AND bg — is ANSI
# SGR only (38;2 / 48;2), which is zero display-width. Backgrounds are painted
# on SPACES, never on block glyphs (U+2591-3 are East-Asian-ambiguous width and
# can desync the TUI). Escape hatch: SUPERBOOST_STATUSLINE_PLAIN=1 -> pure ASCII.
#
# Reads session JSON on stdin; outputs a single status-bar line.

INPUT=$(cat)

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
IFS=$'\t' read -r MODEL COST CTX RLIM EFFORT ADDED REMOVED CWD BIG <<EOF
$(echo "$INPUT" | jq -r '[
  (.model.display_name // "?"),
  (.cost.total_cost_usd // 0),
  (try (((.context_window.used_percentage * 10) | round) / 10) catch "-"),
  (try (((.rate_limits.five_hour.used_percentage * 10) | round) / 10) catch "-"),
  (.effort.level // "-"),
  (.cost.total_lines_added // 0),
  (.cost.total_lines_removed // 0),
  ((((.workspace.current_dir // .cwd // "") | tostring | split("/") | last) // "")
    | if . == "" then "-" else . end),
  (if .exceeds_200k_tokens == true then "1" else "0" end)
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
CWD=$(printf '%s' "$CWD" | LC_ALL=C tr -cd '\40-\176' | cut -c1-16)
case "$ADDED" in ''|*[!0-9]*) ADDED=0 ;; esac
case "$REMOVED" in ''|*[!0-9]*) REMOVED=0 ;; esac
[ "$BIG" = "1" ] || BIG=0
CTX_INT="${CTX%%.*}"; case "$CTX_INT" in ''|*[!0-9]*) CTX_INT="" ;; esac

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
if   [ "$MAX_AGENTS" -ge 8 ]; then CAP="fanout~${MAX_AGENTS}"; CAP_R=34;  CAP_G=211; CAP_B=238
elif [ "$MAX_AGENTS" -ge 3 ]; then CAP="fanout~${MAX_AGENTS}"; CAP_R=245; CAP_G=158; CAP_B=11
elif [ "$MAX_AGENTS" -ge 1 ]; then CAP="tight~${MAX_AGENTS}";  CAP_R=245; CAP_G=158; CAP_B=11
else                               CAP="solo";                 CAP_R=239; CAP_G=68;  CAP_B=68; fi

# --- FX state (effect color + freshness) ---
FX_STATE="${SUPERBOOST_FX_DIR:-$HOME/.claude/fx}/state"
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
  if [ -n "$_t_i" ] && [ -n "$FX_TTL" ]; then
    FX_AGE=$(( NOW - _t_i ))
    [ "$FX_AGE" -ge 0 ] && [ "$FX_AGE" -lt "$FX_TTL" ] && FX_ON=1
  fi
fi
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
if [ "$FX_ON" = "1" ]; then
  _tint=$(( 14 * DECAY * PULSE / 10000 ))   # 0..14% toward effect color
  B0_R=$(( B0_R + (FX_R - B0_R) * _tint / 100 ))
  B0_G=$(( B0_G + (FX_G - B0_G) * _tint / 100 ))
  B0_B=$(( B0_B + (FX_B - B0_B) * _tint / 100 ))
fi
BG0="$(b "$B0_R" "$B0_G" "$B0_B")"

# --- Width ---
W=$(( ${COLUMNS:-$(tput cols 2>/dev/null || echo 120)} - 5 ))
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
        + ${#CTX_TXT} + ${#CAP_TXT} + ${#FXL_TXT} + ${#RL_TXT} + ${#COST_TXT} \
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

# --- RAM bar: bg-colored cell gradient; filled bright, unfilled dark ghost ---
RAMBAR=$(awk -v n="$RB" -v used="$USED_PCT" 'BEGIN{
  e=sprintf("%c",27); fill=int(n*used/100+0.5); out=""
  for(i=0;i<n;i++){
    t=i/(n-1)
    if(t<0.55){u=t/0.55; r=34+int((245-34)*u);  g=197+int((158-197)*u); bl=94+int((11-94)*u)}
    else      {u=(t-0.55)/0.45; r=245+int((239-245)*u); g=158+int((68-158)*u); bl=11+int((68-11)*u)}
    if(i>=fill){r=int(r*22/100)+14; g=int(g*22/100)+14; bl=int(bl*22/100)+14}
    out=out e "[48;2;" r ";" g ";" bl "m "
  }
  printf "%s", out
}')

# --- FX canvas: quantized blocky wash (3-cell pixels), dithered + pulsed + decayed.
# v5.2: 1D plasma shimmer within the effect color, plus event-typed motion —
# fanout/deploy get a Larson scanner, commit a one-shot L->R sweep. All positions
# are pure functions of wall-clock, so a paused frame is a valid still. ---
if [ "$FX_ON" = "1" ] && [ "$CANVAS" -gt 0 ]; then
  WASH=$(awk -v n="$CANVAS" -v now="$NOW" -v t="${_t:-0}" -v nowf="$NOW_F" \
             -v dec="$DECAY" -v pul="$PULSE" \
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
      al=(lvl==0)?0:(lvl==1)?20:(lvl==2)?40:(lvl==3)?62:82   # alpha % (v5.2.2: punchier)
      r=br+int((fr-br)*al/100); gg=bg+int((fg-bg)*al/100); bl=bb+int((fb-bb)*al/100)
      out=out e "[48;2;" r ";" gg ";" bl "m "
    }
    printf "%s", out
  }')
else
  WASH="$(printf "${BG0}%*s" "$CANVAS" "")"
fi

# --- Chips ---
BRAND="$(b 124 58 237)$(c 255 255 255)${BOLD}${BRAND_TXT}${RST}"
case "$MODEL" in
  *[Ff]able*) MODEL_CHIP="$(b 250 204 21)$(c 40 28 0)${BOLD}${MODEL_TXT}${RST}" ;;
  *[Oo]pus*)  MODEL_CHIP="$(b 124 58 237)$(c 255 255 255)${BOLD}${MODEL_TXT}${RST}" ;;
  *)          MODEL_CHIP="$(b 71 85 105)$(c 255 255 255)${BOLD}${MODEL_TXT}${RST}" ;;
esac
if   [ "$USED_PCT" -lt 50 ]; then ST_R=34;  ST_G=197; ST_B=94
elif [ "$USED_PCT" -lt 75 ]; then ST_R=245; ST_G=158; ST_B=11
else                              ST_R=239; ST_G=68;  ST_B=68; fi
STATS="${BG0}$(c "$ST_R" "$ST_G" "$ST_B")${STATS_TXT}${RST}"
RAML="${BG0}$(c 148 163 184)${RAM_LBL}${RST}"
CTXP=""
if [ -n "$CTX_TXT" ]; then
  # B3 fix: compare the integer part — a fractional used_percentage (e.g. 42.5)
  # made both integer tests error out and fall through to red
  if   [ "${CTX_INT:-0}" -lt 60 ]; then CX_R=34;  CX_G=197; CX_B=94
  elif [ "${CTX_INT:-0}" -lt 85 ]; then CX_R=245; CX_G=158; CX_B=11
  else                                  CX_R=239; CX_G=68;  CX_B=68; fi
  CTXP="${BG0}$(c "$CX_R" "$CX_G" "$CX_B")${CTX_TXT}${RST}"
fi
CAPP="${BG0}$(c "$CAP_R" "$CAP_G" "$CAP_B")${CAP_TXT}${RST}"
RLP=""
[ -n "$RL_TXT" ] && RLP="${BG0}$(c 100 116 139)${RL_TXT}${RST}"
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
[ -n "$CHURN_TXT" ] && CHURNP="${BG0}$(c 134 239 172) +${ADDED}$(c 252 165 165) -${REMOVED} ${RST}"
BIGP=""
[ -n "$BIG_TXT" ] && BIGP="$(b 127 29 29)$(c 254 202 202)${BOLD}${BIG_TXT}${RST}"

printf '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n' \
  "$BRAND" "$MODEL_CHIP" "$DIRP" "$RAML" "$RAMBAR" "$RST" "$STATS" "$CTXP" "$BIGP" \
  "$CAPP" "$WASH" "$FXLP" "$RLP" "$CHURNP" "$COSTP"
