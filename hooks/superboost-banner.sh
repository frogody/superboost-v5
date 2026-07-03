#!/bin/bash
# superboost-banner.sh — SessionStart hook for HYVES CODE V5 (formerly Superboost;
# scripts keep the historical superboost- filename prefix so settings.json wiring
# and env vars stay stable across the rebrand)
# Part of HYVES CODE by ISYNCSO (https://isyncso.com)
#
# On every session start:
#   1. Runs a self-test to verify all HYVES CODE components are intact
#   2. Collects live system stats
#   3. Emits the HYVES CODE banner block for Claude to open its first reply with
# Save to: ~/.claude/hooks/superboost-banner.sh

SUPERBOOST_VERSION="5.4.0"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

# ─── Self-Test ───────────────────────────────────────────────
PASS=0
FAIL=0
WARN=0
ISSUES=""

check_pass() { PASS=$((PASS + 1)); }
check_fail() { FAIL=$((FAIL + 1)); ISSUES="${ISSUES}FAIL: $1\n"; }
check_warn() { WARN=$((WARN + 1)); ISSUES="${ISSUES}WARN: $1\n"; }

# 1. Hook scripts exist and are executable
for script in resource-check.sh ram-monitor.sh resource-guard.sh superboost-banner.sh superboost-statusline.sh safety-guard.sh gitnexus-refresh.sh bless-hooks.sh superboost-secrets.sh superboost-fx.sh superboost-parallelism.sh hyves-boot.sh hyves.sh; do
  if [ -x "$HOOKS_DIR/$script" ]; then
    check_pass
  else
    check_fail "$script missing or not executable"
  fi
done

# 2. settings.json exists and has required hook bindings
if [ -f "$SETTINGS" ]; then
  check_pass
  # Check each binding using grep (fast, no python dependency for basic checks)
  grep -q '"SessionStart"' "$SETTINGS" 2>/dev/null && check_pass || check_fail "SessionStart hook not configured in settings.json"
  grep -q 'superboost-banner' "$SETTINGS" 2>/dev/null && check_pass || check_fail "superboost-banner not bound in settings.json"
  grep -q 'resource-check\|resource-guard' "$SETTINGS" 2>/dev/null && check_pass || check_fail "PreToolUse resource guard not configured"
  grep -q 'safety-guard' "$SETTINGS" 2>/dev/null && check_pass || check_fail "PreToolUse safety-guard not configured"
  grep -q 'superboost-secrets' "$SETTINGS" 2>/dev/null && check_pass || check_fail "SessionStart superboost-secrets (first-boot creds) not configured"
  grep -q 'ram-monitor' "$SETTINGS" 2>/dev/null && check_pass || check_fail "PostToolUse ram-monitor not configured"
  grep -q 'superboost-statusline' "$SETTINGS" 2>/dev/null && check_pass || check_fail "statusLine not configured"
  # v5.2: the two bindings the v5.1 self-test missed, plus the live-budget hook
  grep -q 'superboost-fx' "$SETTINGS" 2>/dev/null && check_pass || check_warn "PostToolUse superboost-fx not bound — statusline FX will never fire"
  grep -q 'parallelism.sh --turn' "$SETTINGS" 2>/dev/null && check_pass || check_warn "UserPromptSubmit live-budget hook not bound — budget is SessionStart-only"
  # v5.3: lifecycle FX wiring (user-approved 2026-07-03)
  grep -q 'PostToolUseFailure' "$SETTINGS" 2>/dev/null && check_pass || check_warn "PostToolUseFailure not bound — FAIL/ERROR washes will not fire on current Claude Code"
  grep -q 'emit turn' "$SETTINGS" 2>/dev/null && check_pass || check_warn "UserPromptSubmit 'emit turn' not bound — no turn-start flash"
  grep -q 'emit join' "$SETTINGS" 2>/dev/null && check_pass || check_warn "SubagentStop 'emit join' not bound — sub-agent completion invisible"
  grep -q 'superboost-fx.sh notify' "$SETTINGS" 2>/dev/null && check_pass || check_warn "Notification hook not bound — waiting-on-you (attn) wash will not fire"
  grep -q 'emit compact' "$SETTINGS" 2>/dev/null && check_pass || check_warn "PreCompact 'emit compact' not bound — no compaction warning"
  grep -q '"refreshInterval"' "$SETTINGS" 2>/dev/null && check_pass || check_warn "statusLine refreshInterval missing — FX freeze while the session idles"
else
  check_fail "settings.json not found at $SETTINGS"
fi

# 3. CLAUDE.md exists and contains HYVES CODE V5 content
if [ -f "$CLAUDE_MD" ]; then
  check_pass
  grep -q "HYVES CODE V5" "$CLAUDE_MD" 2>/dev/null && check_pass || check_warn "CLAUDE.md doesn't reference HYVES CODE V5"
  grep -q "Auto-Router" "$CLAUDE_MD" 2>/dev/null && check_pass || check_warn "CLAUDE.md missing Auto-Router"
  grep -q "Model Tiering" "$CLAUDE_MD" 2>/dev/null && check_pass || check_warn "CLAUDE.md missing Model Tiering"
  grep -q "safety-guard" "$CLAUDE_MD" 2>/dev/null && check_pass || check_warn "CLAUDE.md missing safety-guard reference"
else
  check_fail "CLAUDE.md not found at $CLAUDE_MD"
fi

# 3b. jq present — the statusline's session-JSON parse hard-depends on it (v5.2)
if command -v jq >/dev/null 2>&1; then
  check_pass
else
  check_warn "jq not installed — statusline model/cost/ctx/rate fields will be blank"
fi

# 4. resource-check.sh runs and returns valid JSON
RC_JSON=$("$HOOKS_DIR/resource-check.sh" --quiet 2>/dev/null)
RC_EXIT=$?
if [ $RC_EXIT -le 2 ] && echo "$RC_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  check_pass
else
  check_fail "resource-check.sh returned invalid output (exit=$RC_EXIT)"
fi

# 5. Hook checksum drift detection (v3) — WARN on mismatch; bless-hooks.sh to re-seed
VERSION_FILE="$HOME/.claude/superboost-version.json"
if [ -f "$VERSION_FILE" ] && command -v python3 >/dev/null 2>&1; then
  DRIFT=$(HOOKS_DIR="$HOOKS_DIR" VERSION_FILE="$VERSION_FILE" python3 <<'PY' 2>/dev/null
import hashlib, json, os, sys
try:
    with open(os.environ["VERSION_FILE"]) as f:
        vj = json.load(f)
    hooks_dir = os.environ["HOOKS_DIR"]
    drifted = []
    for name, expected in vj.get("scripts", {}).items():
        if not (isinstance(expected, str) and len(expected) == 64 and all(c in "0123456789abcdef" for c in expected)):
            continue
        path = os.path.join(hooks_dir, name)
        if not os.path.exists(path):
            drifted.append(name + "(missing)")
            continue
        with open(path, "rb") as f:
            actual = hashlib.sha256(f.read()).hexdigest()
        if actual != expected:
            drifted.append(name)
    if drifted:
        print(",".join(drifted))
except Exception:
    pass
PY
)
  if [ -z "$DRIFT" ]; then
    check_pass
  else
    check_warn "hook drift: $DRIFT — run ~/.claude/hooks/bless-hooks.sh if intentional"
  fi
else
  check_warn "checksum validation skipped (version.json or python3 missing)"
fi

# 6. Compute self-test verdict
TOTAL=$((PASS + FAIL + WARN))
if [ $FAIL -eq 0 ] && [ $WARN -eq 0 ]; then
  SELFTEST_VERDICT="ALL SYSTEMS GO"
  SELFTEST_ICON="✅"
elif [ $FAIL -eq 0 ]; then
  SELFTEST_VERDICT="OPERATIONAL (${WARN} warning(s))"
  SELFTEST_ICON="⚠️"
else
  SELFTEST_VERDICT="DEGRADED (${FAIL} failure(s), ${WARN} warning(s))"
  SELFTEST_ICON="❌"
fi

# ─── System Stats ────────────────────────────────────────────
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
case "$AVAIL_MB" in ''|*[!0-9]*) AVAIL_MB=0 ;; esac
case "$TOTAL_MB" in ''|*[!0-9]*) TOTAL_MB=0 ;; esac

AVAIL_GB=$(awk "BEGIN {printf \"%.1f\", $AVAIL_MB / 1024}")

# --- Calculate max agents ---
SAFETY_MB=$(( TOTAL_MB * 15 / 100 ))
[ "$SAFETY_MB" -lt 4096 ] && SAFETY_MB=4096
PER_AGENT_MB="${RESOURCE_PER_AGENT_MB:-1000}"
MAX_AGENTS=$(( (AVAIL_MB - SAFETY_MB) / PER_AGENT_MB ))
[ "$MAX_AGENTS" -lt 0 ] && MAX_AGENTS=0
[ "$MAX_AGENTS" -gt "${RESOURCE_MAX_AGENT_CAP:-20}" ] && MAX_AGENTS="${RESOURCE_MAX_AGENT_CAP:-20}"

# --- Pick status ---
if [ "$AVAIL_MB" -gt 8192 ]; then
  STATUS="HEALTHY"
elif [ "$AVAIL_MB" -gt 4096 ]; then
  STATUS="MODERATE"
else
  STATUS="LOW"
fi

# ─── Build Issue Report (only if there are issues) ───────────
ISSUE_BLOCK=""
if [ $FAIL -gt 0 ] || [ $WARN -gt 0 ]; then
  # Format issues as markdown list
  ISSUE_LIST=$(echo -e "$ISSUES" | sed '/^$/d' | sed 's/^/- /')
  ISSUE_BLOCK="
> **Issues detected:**
${ISSUE_LIST}
"
fi

# ─── Parallelism budget (v5): RAM -> actionable fan-out posture ───
# Emitted into context so the orchestrator sizes fan-out to free memory up front.
PARA_LINE="$("$HOOKS_DIR/superboost-parallelism.sh" --line 2>/dev/null)"
[ -z "$PARA_LINE" ] && PARA_LINE="Parallelism budget: (unavailable)"

# ─── Banner block (v5.2.1, user-requested): Claude OPENS its first reply with
# this exact two-liner in a fenced code block — the visible HYVES CODE boot mark.
# (The hyves-boot.sh cinema stays installer-only: hook stdout is model context,
# so a hook can never paint the terminal itself — the model renders the banner.)
FANOUT_MODE=$(printf '%s' "$PARA_LINE" | sed -n 's/.*mode=\([a-z]*\).*/\1/p')
[ -z "$FANOUT_MODE" ] && FANOUT_MODE="?"
BANNER_L1="⬢ HYVES CODE V5 — Holistic Yield & Validation Engines · ISYNCSO"
BANNER_L2="⬢ boot ${PASS}/${TOTAL} · RAM ${AVAIL_GB} GB free · ${STATUS} · fan-out ${FANOUT_MODE}~${MAX_AGENTS}"

# ─── Output ───
# v3.0 forced a full marketing banner; v4/v5 went silent-on-success; v5.2.1
# reinstates a DELIBERATE, compact boot mark (two lines) by user request —
# the self-test itself still reports detail only when something is wrong.
if [ $FAIL -gt 0 ] || [ $WARN -gt 0 ]; then
cat <<EOF
HYVES CODE V5 ACTIVE (tuned for Claude Fable 5) — the boot self-test found issues. Open your FIRST reply with this exact banner in a fenced code block:

${BANNER_L1}
${BANNER_L2}

then surface these issues to the user so they can repair the install, and proceed with their request:
${ISSUE_BLOCK}
${PARA_LINE}
(HYVES CODE v${SUPERBOOST_VERSION} | ${SELFTEST_ICON} ${PASS}/${TOTAL} checks | RAM ${AVAIL_GB} GB free | ${STATUS})
EOF
else
cat <<EOF
HYVES CODE V5 ACTIVE (tuned for Claude Fable 5) — boot OK (${PASS}/${TOTAL} checks), RAM ${AVAIL_GB} GB free, ${STATUS}. Open your FIRST reply in this session with the exact two-line banner below in a fenced code block (verbatim, no other preamble before it), then proceed directly with the user's request:

${BANNER_L1}
${BANNER_L2}

${PARA_LINE}  ->  Size sub-agent/Workflow fan-out to this budget (wide when RAM is ample, solo when tight). Fable 5's async sub-agents are dependable: when the budget says "wide", prefer delegate-and-keep-working over spawn-and-block.
EOF
fi

exit 0
