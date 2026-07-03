#!/bin/bash
# superboost-banner.sh — SessionStart hook for Claude Code Superboost V4
# Part of Claude Code Superboost by ISYNCSO (https://isyncso.com)
#
# On every session start:
#   1. Runs a self-test to verify all Superboost components are intact
#   2. Collects live system stats
#   3. Outputs banner + health report for Claude to display
# Save to: ~/.claude/hooks/superboost-banner.sh

SUPERBOOST_VERSION="5.0"
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
for script in resource-check.sh ram-monitor.sh resource-guard.sh superboost-banner.sh superboost-statusline.sh safety-guard.sh gitnexus-refresh.sh bless-hooks.sh superboost-secrets.sh superboost-fx.sh superboost-parallelism.sh; do
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
else
  check_fail "settings.json not found at $SETTINGS"
fi

# 3. CLAUDE.md exists and contains Superboost v4 content
if [ -f "$CLAUDE_MD" ]; then
  check_pass
  grep -q "Superboost v5" "$CLAUDE_MD" 2>/dev/null && check_pass || check_warn "CLAUDE.md doesn't reference Superboost v5"
  grep -q "Auto-Router" "$CLAUDE_MD" 2>/dev/null && check_pass || check_warn "CLAUDE.md missing Auto-Router"
  grep -q "Model Tiering" "$CLAUDE_MD" 2>/dev/null && check_pass || check_warn "CLAUDE.md missing Model Tiering"
  grep -q "safety-guard" "$CLAUDE_MD" 2>/dev/null && check_pass || check_warn "CLAUDE.md missing safety-guard reference"
else
  check_fail "CLAUDE.md not found at $CLAUDE_MD"
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
  LOAD_AVG=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')
else
  AVAIL_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
  TOTAL_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
  LOAD_AVG=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0)
fi

AVAIL_GB=$(awk "BEGIN {printf \"%.1f\", $AVAIL_MB / 1024}")
TOTAL_GB=$(awk "BEGIN {printf \"%.0f\", $TOTAL_MB / 1024}")

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

# ─── Output (v4+: silent on success; surface ONLY problems) ───
# v3.0 forced Claude to render a full marketing banner as its first output every
# session. v4/v5 run the self-test silently and only speak up when something is wrong.
if [ $FAIL -gt 0 ] || [ $WARN -gt 0 ]; then
cat <<EOF
SUPERBOOST V5 ACTIVE (tuned for Claude Fable 5) — the boot self-test found issues. Surface these to the user so they can repair the install, then proceed with their request:
${ISSUE_BLOCK}
${PARA_LINE}
(Superboost v${SUPERBOOST_VERSION} | ${SELFTEST_ICON} ${PASS}/${TOTAL} checks | RAM ${AVAIL_GB} GB free | ${STATUS})
EOF
else
cat <<EOF
SUPERBOOST V5 ACTIVE (tuned for Claude Fable 5) — boot OK (${PASS}/${TOTAL} checks), RAM ${AVAIL_GB} GB free, ${STATUS}. Do NOT render a banner; proceed directly with the user's request.
${PARA_LINE}  ->  Size sub-agent/Workflow fan-out to this budget (wide when RAM is ample, solo when tight). Fable 5's async sub-agents are dependable: when the budget says "wide", prefer delegate-and-keep-working over spawn-and-block.
EOF
fi

exit 0
