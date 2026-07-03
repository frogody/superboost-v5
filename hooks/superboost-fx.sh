#!/bin/bash
# superboost-fx.sh — terminal visual-effect event emitter (Superboost v5.0)
# Part of Claude Code Superboost by ISYNCSO (https://isyncso.com) — new in v5.0
#
# WHAT IT DOES:
#   Turns notable actions into a short-lived COLORED EFFECT rendered by the statusline.
#   Two entry points:
#     1. PostToolUse hook (matcher *) — classifies the tool that just ran and, for
#        NOTABLE actions only (spawns, commits, deploys, edits, web research), writes
#        an effect record. Common/quiet tools (Read/Grep/Glob/plain Bash) write nothing
#        and the previous effect simply decays.
#     2. Manual:  superboost-fx.sh emit <effect> [label]
#        Lets a skill/slash-command/user trigger an effect explicitly. Example: when
#        preflight mode starts ->  superboost-fx.sh emit preflight
#
# WHY A STATE FILE (not stdout): hook stdout can leak into model context or spam the
#   transcript. This writes a single tiny state file ($FX_STATE) and prints NOTHING,
#   so effects are purely cosmetic and never touch the conversation. The statusline
#   reads the file, renders a decaying colored segment, and the file self-expires.
#
# STATE FORMAT (one line, pipe-delimited):  effect|LABEL|R|G|B|emitted_epoch|ttl_seconds
#
# Effect vocabulary + truecolor palette (extend freely):
#   preflight  #3b82f6  PREFLIGHT   (blue)     fanout    #22d3ee  FAN-OUT   (cyan)
#   commit     #22c55e  COMMIT      (green)    deploy    #6366f1  DEPLOY    (indigo)
#   blocked    #ef4444  BLOCKED     (red)      edit      #f59e0b  EDIT      (amber)
#   search     #a855f7  SEARCH      (violet)   think     #14b8a6  THINK     (teal)
#   done       #64748b  DONE        (slate)

FX_DIR="${SUPERBOOST_FX_DIR:-$HOME/.claude/fx}"
FX_STATE="$FX_DIR/state"
FX_TTL="${SUPERBOOST_FX_TTL:-7}"
mkdir -p "$FX_DIR" 2>/dev/null

# Resolve an effect name -> "LABEL|R|G|B". Unknown effects fall back to a neutral slate.
fx_palette() {
  case "$1" in
    preflight) echo "PREFLIGHT|59|130|246" ;;
    fanout)    echo "FAN-OUT|34|211|238" ;;
    commit)    echo "COMMIT|34|197|94" ;;
    deploy)    echo "DEPLOY|99|102|241" ;;
    blocked)   echo "BLOCKED|239|68|68" ;;
    edit)      echo "EDIT|245|158|11" ;;
    search)    echo "SEARCH|168|85|247" ;;
    think)     echo "THINK|20|184|166" ;;
    done)      echo "DONE|100|116|139" ;;
    *)         echo "" ;;
  esac
}

write_fx() {  # $1=effect  $2=optional-label-override
  local eff="$1" label_override="$2"
  local spec label r g b now
  spec="$(fx_palette "$eff")"
  [ -z "$spec" ] && return 0
  label="${spec%%|*}"; rest="${spec#*|}"
  r="${rest%%|*}"; rest="${rest#*|}"
  g="${rest%%|*}"; b="${rest#*|}"
  [ -n "$label_override" ] && label="$label_override"
  now="$(date +%s 2>/dev/null)"; [ -z "$now" ] && now=0
  printf '%s|%s|%s|%s|%s|%s|%s\n' "$eff" "$label" "$r" "$g" "$b" "$now" "$FX_TTL" > "$FX_STATE" 2>/dev/null
}

# --- Manual entry point:  superboost-fx.sh emit <effect> [label] ---
if [ "$1" = "emit" ]; then
  [ -z "$2" ] && { echo "usage: superboost-fx.sh emit <effect> [label]" >&2; exit 1; }
  write_fx "$2" "$3"
  exit 0
fi

if [ "$1" = "clear" ]; then
  rm -f "$FX_STATE" 2>/dev/null
  exit 0
fi

# --- PostToolUse entry point: classify the tool from stdin JSON ---
TOOL_INPUT="$(cat 2>/dev/null)"
[ -z "$TOOL_INPUT" ] && exit 0

EFFECT="$(FX_INPUT="$TOOL_INPUT" python3 <<'PY' 2>/dev/null
import json, os, re
try:
    d = json.loads(os.environ.get("FX_INPUT", "") or "{}")
except Exception:
    raise SystemExit(0)

tool = d.get("tool_name", d.get("name", "")) or ""
inp = d.get("tool_input", d.get("input", {})) or {}
cmd = (inp.get("command", "") or "") if isinstance(inp, dict) else ""

# Spawns -> fan-out
if tool in ("Agent", "TeamCreate", "Task", "Workflow"):
    print("fanout"); raise SystemExit(0)

# Web research -> search (this is the "preflight-ish" research effect)
if tool in ("WebSearch", "WebFetch"):
    print("search"); raise SystemExit(0)

# File mutations -> edit
if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    print("edit"); raise SystemExit(0)

# Bash: distinguish deploy / push vs commit vs nothing
if tool == "Bash" and cmd:
    if re.search(r"\bgit\s+push\b", cmd) or re.search(r"\b(vercel|supabase)\b.*\bdeploy\b", cmd) or re.search(r"\bdeploy\b", cmd):
        print("deploy"); raise SystemExit(0)
    if re.search(r"\bgit\s+commit\b", cmd):
        print("commit"); raise SystemExit(0)

# Everything else (Read, Grep, Glob, plain Bash, etc.) -> no effect; let the prior decay.
raise SystemExit(0)
PY
)"

[ -n "$EFFECT" ] && write_fx "$EFFECT"
exit 0
