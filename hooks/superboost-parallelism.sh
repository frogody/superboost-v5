#!/bin/bash
# superboost-parallelism.sh — turn the RAM probe into an actionable fan-out budget
# Part of Claude Code Superboost v5 by ISYNCSO (https://isyncso.com) — new in v5.0
#
# WHY THIS EXISTS (v5):
#   Fable 5 on Claude Code already fans out sub-agents. What plain Claude Code does
#   NOT do is size that fan-out to the machine. This script reads the live RAM/CPU
#   probe and converts it into a concrete budget the orchestrator can act on:
#     - concurrent_agents : how many agents can run SIMULTANEOUSLY without thrashing
#     - workflow_width    : recommended Workflow concurrency cap (min of the above and
#                           the harness cap of 16)
#     - mode              : wide | balanced | narrow | solo — a one-word fan-out posture
#   The SessionStart banner emits this into context so the model plans fan-out width
#   up front; the statusline shows it as a capacity hint; and the model can re-query
#   it on demand before a big fan-out.
#
# Fable 5's sub-agents are dependable and its turns are long, so when RAM is ample the
# right move is to delegate WIDE and asynchronously (spawn, keep working) rather than
# spawn-and-block. When RAM is tight, stay solo. This script draws that line for you.
#
# Usage:
#   superboost-parallelism.sh                 # human summary
#   superboost-parallelism.sh --budget        # JSON: {concurrent_agents,workflow_width,mode,...}
#   superboost-parallelism.sh --line          # single terse line for context/banner
#   superboost-parallelism.sh --turn          # UserPromptSubmit hook (v5.2): prints the
#                                             # line ONLY when the mode changed since the
#                                             # last turn — live budget, zero ceremony
#
# Tunables (env): RESOURCE_PER_AGENT_MB (default 1000), WORKFLOW_MAX_WIDTH (default 16).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="human"
case "$1" in
  --budget|-b) OUT="json" ;;
  --line|-l)   OUT="line" ;;
  --turn|-t)   OUT="turn" ;;
esac

CHECK_JSON="$("${SCRIPT_DIR}/resource-check.sh" --quiet 2>/dev/null)"

RESULT="$(CHECK_JSON="$CHECK_JSON" \
WORKFLOW_MAX_WIDTH="${WORKFLOW_MAX_WIDTH:-16}" \
OUT="$OUT" \
python3 <<'PY' 2>/dev/null
import json, os

try:
    d = json.loads(os.environ.get("CHECK_JSON", "") or "{}")
except Exception:
    d = {}

wf_max = int(os.environ.get("WORKFLOW_MAX_WIDTH", "16") or 16)
out = os.environ.get("OUT", "human")

can = bool(d.get("can_spawn", False))
avail_gb = d.get("available_gb", "?")
try:
    max_new = int(d.get("max_new_agents"))
except Exception:
    max_new = 0

concurrent = max_new if can else 0
workflow_width = max(1, min(concurrent, wf_max)) if concurrent >= 1 else 1

if concurrent >= 8:
    mode = "wide"
    hint = (f"RAM is ample - delegate WIDE and async. Fan out up to ~{concurrent} agents; "
            f"size Workflow width to {workflow_width}.")
elif concurrent >= 3:
    mode = "balanced"
    hint = (f"Moderate RAM - fan out for genuinely independent streams (~{concurrent} agents, "
            f"Workflow width {workflow_width}); keep sequential work solo.")
elif concurrent >= 1:
    mode = "narrow"
    hint = f"RAM is tight - at most ~{concurrent} concurrent agent(s). Prefer solo or a single helper."
else:
    mode = "solo"
    hint = "RAM too low to spawn safely - work SOLO until memory frees up."

budget = {
    "concurrent_agents": concurrent,
    "workflow_width": workflow_width,
    "mode": mode,
    "available_gb": avail_gb,
    "can_spawn": can,
    "hint": hint,
}

if out == "json":
    print(json.dumps(budget))
elif out in ("line", "turn"):
    print(f"Parallelism budget: mode={mode} | ~{concurrent} concurrent agents | "
          f"Workflow width {workflow_width} | {avail_gb}GB free")
else:
    print("=== Superboost Parallelism Budget ===")
    print(f"Mode:              {mode}")
    print(f"Concurrent agents: ~{concurrent}")
    print(f"Workflow width:    {workflow_width}")
    print(f"Available RAM:     {avail_gb} GB")
    print("")
    print(hint)
PY
)"

# v5.4 "three budgets": RAM was the only budget with a feedback LOOP (probe ->
# context -> guard). --turn now also watches the session's rate-limit and
# context-window budgets via the statusline's stats stash (stats.<sid8>:
# ctx|5h|7d|cost|dir) and injects ONE actionable line per threshold crossing —
# hysteresis via warned.<sid8> (warn at >=80, re-arm below 70), silent otherwise.
BUDGET_WARNINGS=""
if [ "$OUT" = "turn" ] && [ ! -t 0 ]; then
  TURN_JSON="$(cat 2>/dev/null)"
  SID="$(PB_J="$TURN_JSON" python3 -c '
import json, os, re
try:
    d = json.loads(os.environ.get("PB_J", "") or "{}")
    print(re.sub(r"[^A-Za-z0-9-]", "", str(d.get("session_id", "") or ""))[:8])
except Exception:
    pass
' 2>/dev/null)"
  if [ -n "$SID" ]; then
    SDIR="${SUPERBOOST_FX_DIR:-$HOME/.claude/fx}"
    STATS_F="$SDIR/stats.$SID"
    WARNED_F="$SDIR/warned.$SID"
    if [ -f "$STATS_F" ]; then
      IFS='|' read -r S_CTX S_RL5 S_R7 S_COST S_DIR < "$STATS_F" 2>/dev/null
      CTX_I="${S_CTX%%.*}"; case "$CTX_I" in ''|*[!0-9]*) CTX_I="" ;; esac
      RL5_I="${S_RL5%%.*}"; case "$RL5_I" in ''|*[!0-9]*) RL5_I="" ;; esac
      WARNED="$(cat "$WARNED_F" 2>/dev/null)"
      NEW_WARNED="$WARNED"
      if [ -n "$RL5_I" ]; then
        if [ "$RL5_I" -ge 80 ]; then
          case "$NEW_WARNED" in *rl80*) : ;; *)
            BUDGET_WARNINGS="${BUDGET_WARNINGS}Rate-limit budget: the 5h window is at ${S_RL5}% — tier down NOW: sonnet/haiku for sub-agents, narrow fan-out, batch related work. A hard rate stop mid-task costs more than slower models do.\n"
            NEW_WARNED="${NEW_WARNED}rl80 " ;;
          esac
        elif [ "$RL5_I" -lt 70 ]; then
          NEW_WARNED="$(printf '%s' "$NEW_WARNED" | sed 's/rl80 //')"
        fi
      fi
      if [ -n "$CTX_I" ]; then
        if [ "$CTX_I" -ge 80 ]; then
          case "$NEW_WARNED" in *ctx80*) : ;; *)
            BUDGET_WARNINGS="${BUDGET_WARNINGS}Context budget: the window is at ${S_CTX}% used — checkpoint durable state to memory files, delegate exploration to sub-agents (their context is separate), and finish or /compact at the next natural boundary.\n"
            NEW_WARNED="${NEW_WARNED}ctx80 " ;;
          esac
        elif [ "$CTX_I" -lt 70 ]; then
          NEW_WARNED="$(printf '%s' "$NEW_WARNED" | sed 's/ctx80 //')"
        fi
      fi
      if [ "$NEW_WARNED" != "$WARNED" ]; then
        printf '%s' "$NEW_WARNED" > "$WARNED_F" 2>/dev/null
      fi
    fi
  fi
fi

if [ -z "$RESULT" ]; then
  # per-turn probe failure stays SILENT (no context noise); explicit calls
  # report it. Budget warnings are independent of the probe — still deliver.
  if [ "$OUT" = "turn" ]; then
    [ -n "$BUDGET_WARNINGS" ] && printf '%b' "$BUDGET_WARNINGS"
    exit 0
  fi
  echo "Parallelism budget unavailable (resource probe failed)."
  exit 0
fi

# v5.2: stash the mode so --turn can detect changes. --line (SessionStart) seeds it.
if [ "$OUT" = "line" ] || [ "$OUT" = "turn" ]; then
  STASH_DIR="${SUPERBOOST_FX_DIR:-$HOME/.claude/fx}"
  STASH="$STASH_DIR/budget_mode"
  MODE="$(printf '%s' "$RESULT" | sed -n 's/.*mode=\([a-z][a-z]*\).*/\1/p')"
  LAST="$(cat "$STASH" 2>/dev/null)"
  mkdir -p "$STASH_DIR" 2>/dev/null
  [ -n "$MODE" ] && printf '%s' "$MODE" > "$STASH" 2>/dev/null
  if [ "$OUT" = "turn" ]; then
    # speak ONLY when something changed: posture flip and/or a budget
    # threshold crossing; a silent turn means "all budgets unchanged"
    if [ -n "$MODE" ] && [ -n "$LAST" ] && [ "$MODE" != "$LAST" ]; then
      printf '%s\n' "${RESULT}  ->  Fan-out posture CHANGED (was ${LAST}). Re-size any planned agent/Workflow fan-out to this budget."
    fi
    [ -n "$BUDGET_WARNINGS" ] && printf '%b' "$BUDGET_WARNINGS"
    exit 0
  fi
fi

printf '%s\n' "$RESULT"
exit 0
