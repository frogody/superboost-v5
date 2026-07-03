#!/bin/bash
# superboost-fx.sh — terminal visual-effect event emitter (HYVES CODE v5.3)
# Part of HYVES CODE by ISYNCSO (https://isyncso.com) — new in v5.0
#
# WHAT IT DOES:
#   Turns notable actions AND session lifecycle phases into short-lived COLORED
#   EFFECTS rendered by the statusline. Entry points:
#     1. PostToolUse / PostToolUseFailure hook (matcher *) — classifies the tool
#        that just ran. Success events emit fanout/search/edit/deploy/commit/pass;
#        failure events emit fail (test/build commands) or error (a tool itself
#        broke). Quiet tools (Read/Grep/Glob/plain Bash) write nothing.
#     2. Notification hook:  superboost-fx.sh notify
#        Maps waiting-on-user notification types (permission_prompt, idle_prompt,
#        agent_needs_input, elicitation_dialog) to the pink ATTN effect.
#     3. Manual:  superboost-fx.sh emit <effect> [label]
#        Lets a skill/slash-command/user/hook trigger an effect explicitly
#        (Stop -> done, UserPromptSubmit -> turn, SubagentStop -> join,
#         PreCompact -> compact).
#     4. superboost-fx.sh clear — SessionEnd hygiene: removes this session's
#        state (and prunes stale session files); a fade would be unseeable
#        because the TUI exits with the session, so hygiene wins.
#
# WHY A STATE FILE (not stdout): hook stdout can leak into model context or spam
#   the transcript. This writes a tiny state file and prints NOTHING; the
#   statusline reads it, renders a decaying wash, and the record self-expires.
#
# SESSION-SCOPED STATE (v5.3): every Claude Code hook receives session_id on
#   stdin, so effects write to $FX_DIR/state.<sid8> — two concurrent sessions no
#   longer clobber each other (one session's Stop/SessionEnd used to erase the
#   other's live effect). Manual emits without session context write the GLOBAL
#   $FX_DIR/state; the statusline shows whichever record is newest. Writes are
#   ATOMIC (tmp + rename): the old truncate-then-write let the statusline catch
#   a torn read in 15% of attempts during bursts.
#
# STATE FORMAT (one line, pipe-delimited):  effect|LABEL|R|G|B|emitted_epoch|ttl
#
# Effect vocabulary — hue families are LAW (one family = one meaning, §11):
#   cyan   PARALLELISM   fanout #22d3ee FAN-OUT      join   #67e8f9 JOINED
#   blue   INFO WORK     preflight #3b82f6 PREFLIGHT search #0ea5e9 SEARCH
#                        think  #2563eb THINK        turn   #93c5fd WORKING (ttl 3)
#   green  CONFIRMED     commit #22c55e COMMIT       pass   #4ade80 PASS
#   amber  CAUTION/CHANGE edit  #f59e0b EDIT         compact #fbbf24 COMPACT
#   red    FAILURE       blocked #ef4444 BLOCKED     fail   #f87171 FAIL
#                        error  #dc2626 ERROR
#   indigo SHIPPING      deploy #6366f1 DEPLOY
#   pink   NEEDS YOU     attn   #ec4899 NEEDS YOU (ttl 45 — waits are long)
#   slate  NEUTRAL       done   #64748b DONE
#   (search left the violet family in v5.3: violet/gold = identity, brand+model only;
#    think left teal: too close to parallelism cyan)

FX_DIR="${SUPERBOOST_FX_DIR:-$HOME/.claude/fx}"
FX_STATE="$FX_DIR/state"
mkdir -p "$FX_DIR" 2>/dev/null

# Resolve an effect name -> "LABEL|R|G|B|ttl". Unknown effects resolve empty (no-op).
fx_palette() {
  case "$1" in
    preflight) echo "PREFLIGHT|59|130|246|7" ;;
    fanout)    echo "FAN-OUT|34|211|238|7" ;;
    join)      echo "JOINED|103|232|249|7" ;;
    commit)    echo "COMMIT|34|197|94|7" ;;
    deploy)    echo "DEPLOY|99|102|241|7" ;;
    blocked)   echo "BLOCKED|239|68|68|7" ;;
    edit)      echo "EDIT|245|158|11|7" ;;
    search)    echo "SEARCH|14|165|233|7" ;;
    think)     echo "THINK|37|99|235|7" ;;
    turn)      echo "WORKING|147|197|253|3" ;;
    compact)   echo "COMPACT|251|191|36|7" ;;
    error)     echo "ERROR|220|38|38|7" ;;
    attn)      echo "NEEDS YOU|236|72|153|45" ;;
    done)      echo "DONE|100|116|139|7" ;;
    pass)      echo "PASS|74|222|128|7" ;;
    fail)      echo "FAIL|248|113|113|7" ;;
    *)         echo "" ;;
  esac
}

# session_id (first 8 chars) from a hook's stdin JSON via a real JSON parse —
# regex extraction can be fooled by tool payloads that merely CONTAIN the text.
sid_from_json() {  # $1=json -> sid8 on stdout (empty if none)
  [ -z "$1" ] && return 0
  FX_J="$1" python3 - <<'PY' 2>/dev/null
import json, os, re
try:
    d = json.loads(os.environ.get("FX_J", "") or "{}")
    sid = str(d.get("session_id", "") or "")
    print(re.sub(r"[^A-Za-z0-9-]", "", sid)[:8])
except Exception:
    pass
PY
}

state_path() {  # $1=sid8 -> path
  if [ -n "$1" ]; then printf '%s' "$FX_DIR/state.$1"; else printf '%s' "$FX_STATE"; fi
}

# ---------------------------------------------------------------- v5.4 pushes
# Native macOS notification when the terminal can't carry the signal itself:
# the pink attn wash is invisible when the window is occluded (App Nap pauses
# statusline renders), which is EXACTLY when the user needs the shoulder-tap.
# Gates, in order: SUPERBOOST_PUSH=0 kills all pushes; a 90s rate limit stops
# spam; SUPERBOOST_PUSH_DRYRUN=1 records intent to $FX_DIR/push.dryrun (tests);
# frontmost-terminal suppression (the TUI/wash already carries the signal when
# you are looking at a terminal) unless SUPERBOOST_PUSH=2 forces; macOS-only.
front_is_terminal() {
  command -v lsappinfo >/dev/null 2>&1 || return 1
  local name
  name="$(lsappinfo info -only name "$(lsappinfo front 2>/dev/null)" 2>/dev/null)"
  case "$name" in
    *Terminal*|*iTerm*|*Warp*|*kitty*|*Alacritty*|*WezTerm*|*Ghostty*|*Hyper*) return 0 ;;
    *) return 1 ;;
  esac
}

maybe_push() {  # $1=title  $2=body
  [ "${SUPERBOOST_PUSH:-1}" = "0" ] && return 0
  local now last stamp="$FX_DIR/push.stamp"
  now="$(date +%s 2>/dev/null)"; [ -z "$now" ] && return 0
  last="$(cat "$stamp" 2>/dev/null)"; case "$last" in ''|*[!0-9]*) last=0 ;; esac
  [ $(( now - last )) -lt "${SUPERBOOST_PUSH_MIN_GAP:-90}" ] && return 0
  # sanitize for AppleScript string context (and our own dryrun format)
  local title body
  title="$(printf '%s' "$1" | tr -d '"\\|' | cut -c1-60)"
  body="$(printf '%s' "$2" | tr -d '"\\|' | cut -c1-120)"
  if [ "${SUPERBOOST_PUSH_DRYRUN:-0}" = "1" ]; then
    printf '%s|%s|%s\n' "$now" "$title" "$body" >> "$FX_DIR/push.dryrun" 2>/dev/null
    printf '%s' "$now" > "$stamp" 2>/dev/null
    return 0
  fi
  [ "$(uname)" = "Darwin" ] || return 0
  command -v osascript >/dev/null 2>&1 || return 0
  if [ "${SUPERBOOST_PUSH:-1}" != "2" ] && front_is_terminal; then return 0; fi
  osascript -e "display notification \"$body\" with title \"$title\"" >/dev/null 2>&1
  printf '%s' "$now" > "$stamp" 2>/dev/null
}

write_fx() {  # $1=effect  $2=optional-label-override  $3=optional-sid8
  local eff="$1" label_override="$2" sid="$3"
  local spec label r g b ttl now dest tmp
  spec="$(fx_palette "$eff")"
  [ -z "$spec" ] && return 0
  label="${spec%%|*}"; rest="${spec#*|}"
  r="${rest%%|*}"; rest="${rest#*|}"
  g="${rest%%|*}"; rest="${rest#*|}"
  b="${rest%%|*}"; ttl="${rest#*|}"
  [ -n "$label_override" ] && label="$label_override"
  # per-event ttl (v5.3: turn=3, attn=45); an explicit SUPERBOOST_FX_TTL env
  # still overrides everything (demo/screenshot workflow)
  if [ -n "${SUPERBOOST_FX_TTL+x}" ]; then ttl="$SUPERBOOST_FX_TTL"; fi
  case "$ttl" in ''|*[!0-9]*) ttl=7 ;; esac
  # v5.2.1: FLOAT emit time — an integer-truncated epoch started every animation
  # phase up to 1s late. perl Time::HiRes ships on macOS; integer fallback.
  now="$(perl -MTime::HiRes=time -e 'printf "%.2f", time' 2>/dev/null)"
  if [ -z "$now" ]; then now="$(date +%s 2>/dev/null)"; [ -z "$now" ] && now=0; fi
  # ATOMIC write (v5.3): the statusline reads this file ~every 300ms from
  # another process; rename() is atomic on APFS/ext4, `>` is not.
  dest="$(state_path "$sid")"
  tmp="$dest.$$"
  printf '%s|%s|%s|%s|%s|%s|%s\n' "$eff" "$label" "$r" "$g" "$b" "$now" "$ttl" > "$tmp" 2>/dev/null \
    && mv -f "$tmp" "$dest" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
}

# Read hook stdin when present WITHOUT blocking an interactive terminal call:
# hooks pipe JSON in; a human running `emit` from a shell has a tty on stdin.
read_hook_stdin() {
  if [ ! -t 0 ]; then cat 2>/dev/null; fi
}

# --- Manual/hook entry point:  superboost-fx.sh emit <effect> [label] ---
if [ "$1" = "emit" ]; then
  [ -z "$2" ] && { echo "usage: superboost-fx.sh emit <effect> [label]" >&2; exit 1; }
  SID="${SUPERBOOST_FX_SID:-}"
  [ -z "$SID" ] && SID="$(sid_from_json "$(read_hook_stdin)")"
  # v5.4 long-turn tracking: `emit turn` (UserPromptSubmit) stamps the turn
  # start; `emit done` (Stop) reads it and pushes a notification when a turn
  # ran long — the moment a user has tabbed away and wants the shoulder-tap.
  TS_FILE="$FX_DIR/turnstart${SID:+.$SID}"
  if [ "$2" = "turn" ]; then
    date +%s > "$TS_FILE" 2>/dev/null
  elif [ "$2" = "done" ] && [ -f "$TS_FILE" ]; then
    T0="$(cat "$TS_FILE" 2>/dev/null)"; rm -f "$TS_FILE" 2>/dev/null
    case "$T0" in ''|*[!0-9]*) T0="" ;; esac
    if [ -n "$T0" ]; then
      DUR=$(( $(date +%s) - T0 ))
      if [ "$DUR" -ge "${SUPERBOOST_PUSH_LONG_TURN_SEC:-45}" ]; then
        maybe_push "Claude finished" "Turn ran $(( DUR / 60 ))m $(( DUR % 60 ))s - ready for you"
      fi
    fi
  fi
  write_fx "$2" "$3" "$SID"
  exit 0
fi

# --- SessionEnd hygiene: fold cost into the ledger; remove THIS session's
# state; prune stale siblings ---
# v5.4: the statusline stashes live session stats (ctx|5h|7d|cost|dir) per sid;
# on SessionEnd the final snapshot becomes a ledger row so `hyves stats` can
# answer "what did today / this project cost?". Stale stats from crashed
# sessions are folded (best effort) before pruning. Ledger rows are keyed by
# sid — cost is CUMULATIVE per session, so readers aggregate max-per-sid, which
# also makes duplicate folds harmless.
fold_stats() {  # $1=stats-file  $2=sid8
  local ledger="${SUPERBOOST_LEDGER:-$HOME/.claude/logs/cost-ledger.tsv}"
  [ -f "$1" ] || return 0
  local ctx rl5 rl7 cost dir
  IFS='|' read -r ctx rl5 rl7 cost dir < "$1" 2>/dev/null
  case "$cost" in ''|*[!0-9.]*) return 0 ;; esac
  mkdir -p "$(dirname "$ledger")" 2>/dev/null
  printf '%s\t%s\t%s\t%s\n' "$(date +%Y-%m-%d)" "${2:-global}" "${dir:--}" "$cost" >> "$ledger" 2>/dev/null
}

if [ "$1" = "clear" ]; then
  SID="${SUPERBOOST_FX_SID:-}"
  [ -z "$SID" ] && SID="$(sid_from_json "$(read_hook_stdin)")"
  if [ -n "$SID" ]; then
    fold_stats "$FX_DIR/stats.$SID" "$SID"
    rm -f "$FX_DIR/state.$SID" "$FX_DIR/stats.$SID" "$FX_DIR/turnstart.$SID" 2>/dev/null
  else
    rm -f "$FX_STATE" "$FX_DIR/turnstart" 2>/dev/null
  fi
  # crashed sessions never ran their own clear: fold, then prune
  for f in "$FX_DIR"/stats.*; do
    [ -f "$f" ] || continue
    if [ -n "$(find "$f" -mmin +240 2>/dev/null)" ]; then
      fold_stats "$f" "${f##*.}"
      rm -f "$f" 2>/dev/null
    fi
  done
  find "$FX_DIR" \( -name 'state.*' -o -name 'turnstart.*' \) -mmin +240 -delete 2>/dev/null
  exit 0
fi

# --- Notification hook: waiting-on-user types -> pink ATTN + push ---
if [ "$1" = "notify" ]; then
  NJSON="$(read_hook_stdin)"
  [ -z "$NJSON" ] && exit 0
  OUT="$(FX_J="$NJSON" python3 - <<'PY' 2>/dev/null
import json, os, re
try:
    d = json.loads(os.environ.get("FX_J", "") or "{}")
except Exception:
    raise SystemExit(0)
nt = str(d.get("notification_type", "") or "")
if nt in ("permission_prompt", "idle_prompt", "agent_needs_input", "elicitation_dialog"):
    sid = re.sub(r"[^A-Za-z0-9-]", "", str(d.get("session_id", "") or ""))[:8]
    cwd = str(d.get("cwd", "") or "").rstrip("/").rsplit("/", 1)[-1]
    msg = re.sub(r"[|\"\\\n]", " ", str(d.get("message", "") or ""))[:100]
    print(f"attn|{sid}|{cwd}|{msg}")
PY
)"
  if [ -n "$OUT" ]; then
    IFS='|' read -r N_EFF N_SID N_DIR N_MSG <<EOF
$OUT
EOF
    write_fx "$N_EFF" "" "$N_SID"
    maybe_push "Claude needs you${N_DIR:+ - $N_DIR}" "${N_MSG:-Waiting for your input}"
  fi
  exit 0
fi

# --- PostToolUse / PostToolUseFailure entry point: classify stdin JSON ---
TOOL_INPUT="$(cat 2>/dev/null)"
[ -z "$TOOL_INPUT" ] && exit 0

# v5.2 (P5): cheap bash gate — skip the python classifier entirely for quiet
# tools (Read/Grep/Glob/...). Over-matching is harmless: python then classifies
# to nothing; this only saves the ~30ms interpreter startup.
case "$TOOL_INPUT" in
  *PostToolUseFailure*|*Agent*|*TeamCreate*|*Task*|*Workflow*|*Write*|*Edit*|*NotebookEdit*|*WebSearch*|*WebFetch*|*Bash*) : ;;
  *) exit 0 ;;
esac

OUT="$(FX_INPUT="$TOOL_INPUT" python3 <<'PY' 2>/dev/null
import json, os, re
try:
    d = json.loads(os.environ.get("FX_INPUT", "") or "{}")
except Exception:
    raise SystemExit(0)

def out(effect):
    sid = re.sub(r"[^A-Za-z0-9-]", "", str(d.get("session_id", "") or ""))[:8]
    print(f"{effect}|{sid}")
    raise SystemExit(0)

tool = d.get("tool_name", d.get("name", "")) or ""
inp = d.get("tool_input", d.get("input", {})) or {}
cmd = (inp.get("command", "") or "") if isinstance(inp, dict) else ""
event = d.get("hook_event_name", "") or ""

TEST_CMD = (re.search(r"\b(npm|pnpm|yarn|bun)\s+(run\s+)?(test|build|lint|typecheck|check)\b", cmd)
            or re.search(r"\bmake\s+(test|build|lint|check)\b", cmd)
            or re.search(r"\b(pytest|vitest|jest|tsc|eslint)\b", cmd)
            or re.search(r"\bgo\s+(test|build|vet)\b", cmd)
            or re.search(r"\bcargo\s+(test|build|check|clippy)\b", cmd)) if cmd else None

# v5.3: current Claude Code fires PostToolUse ONLY on success; failures fire
# PostToolUseFailure (with tool_error). Branch on the event:
#   test/build command failed -> FAIL (soft red, an outcome verdict)
#   any non-Bash tool failed  -> ERROR (hard red, the machinery broke)
#   other Bash failures       -> nothing (grep exit 1 etc. is normal work)
if event == "PostToolUseFailure":
    if tool == "Bash":
        if TEST_CMD:
            out("fail")
        raise SystemExit(0)
    out("error")

# v5.2 (P4): older CC delivered failures on PostToolUse with a result payload —
# keep reading it (docs now call the field tool_output; runtime shipped
# tool_response) so PASS/FAIL still works there.
resp = d.get("tool_response", d.get("tool_output", d.get("response", {}))) or {}
def resp_failed():
    if not isinstance(resp, dict):
        return False
    if resp.get("is_error") is True or resp.get("isError") is True \
       or resp.get("interrupted") is True:
        return True
    for k in ("exit_code", "exitCode", "return_code", "returnCode", "code"):
        rc = resp.get(k)
        if isinstance(rc, int) and rc != 0:
            return True
    return False

# Spawns -> fan-out
if tool in ("Agent", "TeamCreate", "Task", "Workflow"):
    out("fanout")

# Web research -> search
if tool in ("WebSearch", "WebFetch"):
    out("search")

# File mutations -> edit
if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    out("edit")

# Bash: deploy / commit / test-outcome
if tool == "Bash" and cmd:
    if re.search(r"\bgit\s+push\b", cmd) \
       or re.search(r"\b(vercel|supabase|netlify|railway|flyctl|firebase|wrangler|gcloud|aws|az|cdk|kubectl|helm)\b[^\n]*\bdeploy\b", cmd) \
       or re.search(r"\b(npm|pnpm|yarn|bun)\s+(run\s+)?deploy\b", cmd) \
       or re.search(r"\bmake\s+deploy\b", cmd) \
       or re.search(r"(^|[;&|])\s*(\S*/)?deploy(\.\w+)?(\s|$)", cmd):
        out("deploy")
    if re.search(r"\bgit\s+commit\b", cmd):
        out("commit")
    if TEST_CMD:
        out("fail" if resp_failed() else "pass")

# Everything else -> no effect; let the prior one decay.
raise SystemExit(0)
PY
)"

if [ -n "$OUT" ]; then write_fx "${OUT%%|*}" "" "${OUT#*|}"; fi
exit 0
