#!/bin/bash
# verify.sh — Superboost quick regression suite (~15s, deterministic).
# Deep animation capture lives in fxcap.py / ansi2json.py (run separately).
# Exit 0 = all pass.

HOOKS="$HOME/.claude/hooks"
TESTS="$HOME/.claude/tests"
SL="$HOOKS/superboost-statusline.sh"
FX="$HOOKS/superboost-fx.sh"
STATE="${SUPERBOOST_FX_DIR:-$HOME/.claude/fx}/state"
FAILS=0
t()  { if eval "$2" >/dev/null 2>&1; then echo "  ok   $1"; else echo "  FAIL $1"; FAILS=$((FAILS+1)); fi; }
say() { echo; echo "== $1 =="; }

say "hook syntax"
for f in "$HOOKS"/*.sh; do
  bash -n "$f" 2>/dev/null || { echo "  FAIL syntax: $f"; FAILS=$((FAILS+1)); }
done
echo "  ok   bash -n on all hooks"

say "settings bindings"
S="$HOME/.claude/settings.json"
t "settings.json valid JSON"      "python3 -c 'import json;json.load(open(\"$S\"))'"
for b in superboost-banner safety-guard resource-guard ram-monitor superboost-fx superboost-statusline "parallelism.sh --turn" "emit done" "superboost-fx.sh clear" \
         PostToolUseFailure "emit turn" "emit join" "superboost-fx.sh notify" "emit compact" '"refreshInterval"'; do
  t "binding: $b" "grep -qF -- '$b' '$S'"
done

say "banner self-test"
BANNER="$("$HOOKS/superboost-banner.sh" 2>/dev/null)"
LINE="$(printf '%s\n' "$BANNER" | head -1)"
# Accept BOTH banner branches: a WARN (e.g. intentional mid-edit hook drift) is
# the banner working correctly, not a regression. Only hard "FAIL:" self-test
# lines — a genuinely broken install — fail this check.
case "$LINE" in
  "HYVES CODE V5 ACTIVE"*)
    if printf '%s' "$BANNER" | grep -q 'FAIL:'; then
      echo "  FAIL banner self-test reports failures:"; printf '%s\n' "$BANNER" | grep 'FAIL:' | sed 's/^/         /'
      FAILS=$((FAILS+1))
    else
      echo "  ok   ${LINE%%. Open your*}"
      printf '%s' "$BANNER" | grep -q 'WARN:' && echo "       (warn-level issues present — benign for this check)"
    fi ;;
  *) echo "  FAIL banner: $LINE"; FAILS=$((FAILS+1)) ;;
esac
# v5.2.1: the hook must supply the two-line boot mark the model opens with
t "banner block present" "printf '%s' \"\$BANNER\" | grep -q '⬢ HYVES CODE V5' && printf '%s' \"\$BANNER\" | grep -q '⬢ boot '"

say "safety-guard matrix"
python3 "$TESTS/guard-test.py" | tail -1
python3 "$TESTS/guard-test.py" >/dev/null 2>&1 || FAILS=$((FAILS+1))

say "statusline width + behavior"
RICH='{"model":{"display_name":"Fable 5"},"cost":{"total_cost_usd":4.56,"total_lines_added":12,"total_lines_removed":3},"context_window":{"used_percentage":42.5},"rate_limits":{"five_hour":{"used_percentage":10}},"effort":{"level":"xhigh"},"workspace":{"current_dir":"/tmp/proj"}}'
for W in 200 160 140 120 60; do
  LEN=$(echo "$RICH" | COLUMNS=$W "$SL" | perl -pe 's/\e\[[0-9;]*m//g' | awk '{print length($0)}')
  if [ "$LEN" -le $((W-5)) ] && [ "$LEN" -ge 40 ]; then echo "  ok   COLUMNS=$W -> $LEN"; else echo "  FAIL COLUMNS=$W -> $LEN"; FAILS=$((FAILS+1)); fi
done
t "fractional ctx% renders green"  "echo '$RICH' | COLUMNS=160 '$SL' | grep -qF '38;2;34;197;94m ctx 42.5%'"
t "plain mode branded"             "echo '$RICH' | SUPERBOOST_STATUSLINE_PLAIN=1 '$SL' | grep -qF 'HYVES CODE V5 |'"
t "empty stdin no crash"           "echo '' | COLUMNS=120 '$SL'"
# v5.2.1: the FX canvas must be a real stage (>=18 cells) at common widths —
# measured before the fix: 9 cells at COLUMNS=150 turned scanner motion to mush.
# In plain text the canvas is the space-run just left of the label: >=20 incl.
# the cap chip's trailing + label's leading pad.
"$FX" emit fanout; CVOK=0
echo "$RICH" | COLUMNS=150 "$SL" | perl -pe 's/\e\[[0-9;]*m//g' | grep -Eq ' {20,}FAN-OUT' && CVOK=1
"$FX" clear
t "canvas floor >=18 at COLUMNS=150" "[ $CVOK = 1 ]"

say "fx classification"
fxcase() { echo "$2" | "$FX"; head -1 "$STATE" 2>/dev/null | grep -q "^$1|"; }
t "npm test ok -> pass"    "fxcase pass   '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"npm test\"},\"tool_response\":{\"exit_code\":0}}'"
t "pytest rc=1 -> fail"    "fxcase fail   '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pytest\"},\"tool_response\":{\"exit_code\":1}}'"
t "npm run deploy -> deploy" "fxcase deploy '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"npm run deploy\"},\"tool_response\":{\"exit_code\":0}}'"
t "git commit -> commit"   "fxcase commit '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m x\"}}'"
t "Agent -> fanout"        "fxcase fanout '{\"tool_name\":\"Agent\",\"tool_input\":{\"prompt\":\"x\"}}'"
"$FX" emit commit; BEFORE=$(cat "$STATE")
echo '{"tool_name":"Read","tool_input":{"file_path":"/tmp/x"}}' | "$FX"
t "Read leaves state alone" "[ \"\$(cat '$STATE')\" = '$BEFORE' ]"
# v5.2.1: emit time must be a FLOAT epoch (int truncation started sweep/scanner
# phases up to 1s late)
t "fx emits float epoch"    "awk -F'|' 'NR==1{exit (\$6 ~ /^[0-9]+\.[0-9]+$/) ? 0 : 1}' '$STATE'"
"$FX" clear

say "v5.3 lifecycle fx + grammar"
FXT=$(mktemp -d "${TMPDIR:-/tmp}/hyves-fxt.XXXXXX")
RICH53='{"session_id":"testsess-1234","model":{"display_name":"Fable 5"},"cost":{"total_cost_usd":3.5},"context_window":{"used_percentage":42.5},"rate_limits":{"five_hour":{"used_percentage":10}},"effort":{"level":"xhigh"},"workspace":{"current_dir":"/tmp/proj"}}'
J53='{"session_id":"testsess-1234","hook_event_name":"Stop"}'
fxs() { SUPERBOOST_FX_DIR="$FXT" "$FX" "$@"; }
sls() { SUPERBOOST_FX_DIR="$FXT" env COLUMNS=150 "$SL"; }
# session scoping: hook-context emits key state by session_id (sid8)
t "session-scoped emit"        "echo '$J53' | fxs emit done && [ -f '$FXT/state.testsess' ]"
# per-event ttl (turn=3, attn=45), field 7 of the state line
t "turn ttl=3"                 "echo '$J53' | fxs emit turn && awk -F'|' 'NR==1{exit(\$7==3)?0:1}' '$FXT/state.testsess'"
t "attn ttl=45"                "echo '$J53' | fxs emit attn && awk -F'|' 'NR==1{exit(\$7==45)?0:1}' '$FXT/state.testsess'"
# Notification mapping: waiting-on-user types -> attn; others ignored
t "notify permission -> attn"  "rm -f '$FXT/state.testsess'; echo '{\"session_id\":\"testsess-1234\",\"notification_type\":\"permission_prompt\"}' | fxs notify && grep -q '^attn|' '$FXT/state.testsess'"
t "notify auth_success ignored" "echo '{\"session_id\":\"testsess-1234\",\"notification_type\":\"auth_success\"}' | fxs notify && grep -q '^attn|' '$FXT/state.testsess'"
# PostToolUseFailure: test cmd -> fail, non-Bash tool -> error, benign Bash -> nothing
t "PTUF pytest -> fail"        "echo '{\"hook_event_name\":\"PostToolUseFailure\",\"session_id\":\"testsess-1234\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pytest\"}}' | fxs && grep -q '^fail|' '$FXT/state.testsess'"
t "PTUF Edit -> error"         "echo '{\"hook_event_name\":\"PostToolUseFailure\",\"session_id\":\"testsess-1234\",\"tool_name\":\"Edit\",\"tool_input\":{}}' | fxs && grep -q '^error|' '$FXT/state.testsess'"
t "PTUF grep -> no change"     "echo '{\"hook_event_name\":\"PostToolUseFailure\",\"session_id\":\"testsess-1234\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"grep -q x f\"}}' | fxs && grep -q '^error|' '$FXT/state.testsess'"
# hue-law recolors: search left violet (identity), think left teal (parallelism)
t "search recolored sky"       "echo '$J53' | fxs emit search && grep -q '|14|165|233|' '$FXT/state.testsess'"
t "think recolored blue"       "echo '$J53' | fxs emit think && grep -q '|37|99|235|' '$FXT/state.testsess'"
# newest record wins between session + global state
t "newest-wins session/global" "fxs emit deploy </dev/null && sleep 0.05 && echo '$J53' | fxs emit pass && echo '$RICH53' | sls | grep -q 'PASS'"
# SessionEnd clear removes ONLY this session's file
t "clear scoped to session"    "echo '$J53' | fxs clear && [ ! -f '$FXT/state.testsess' ] && [ -f '$FXT/state' ]"
# heartbeat: expired WORK event -> faint slate cells (48;2;32;36;46); done/attn -> none
HB_T=$(perl -MTime::HiRes=time -e 'printf "%.2f", time-10')
t "heartbeat after stale edit" "printf 'edit|EDIT|245|158|11|%s|7\n' '$HB_T' > '$FXT/state' && echo '$RICH53' | sls | grep -q '48;2;32;36;46m'"
t "no heartbeat after done"    "printf 'done|DONE|100|116|139|%s|7\n' '$HB_T' > '$FXT/state' && ! (echo '$RICH53' | sls | grep -q '48;2;32;36;46m')"
# ctx >= 85% escalates to a SOLID alert chip (same tier as 200K+)
t "ctx 90% solid alert chip"   "rm -f '$FXT/state'; echo '${RICH53}' | sed 's/42.5/90.2/' | sls | grep -q '48;2;127;29;29m'"
# grammar role order: identity -> workspace -> machine -> session -> activity
t "role order on the bar"      "echo '$RICH53' | sls | perl -pe 's/\e\[[0-9;]*m//g' | grep -Eq 'HYVES CODE V5 +Fable 5 xhigh +proj +RAM .*fanout~[0-9]+ +ctx 42.5% +5h 10% +.3.50'"
# width-law hardening: junk COLUMNS clamps to default, no crash/stderr
t "junk COLUMNS clamps"        "L=\$(echo '$RICH53' | SUPERBOOST_FX_DIR='$FXT' env COLUMNS=80x '$SL' 2>/dev/null | perl -pe 's/\e\[[0-9;]*m//g' | awk '{print length}'); [ \"\$L\" = 115 ]"
# empty display_name must not shift tab-separated fields
t "empty model name -> ?"      "echo '{\"model\":{\"display_name\":\"\"},\"cost\":{\"total_cost_usd\":3.5}}' | SUPERBOOST_FX_DIR='$FXT' env COLUMNS=140 '$SL' | perl -pe 's/\e\[[0-9;]*m//g' | grep -Eq '\? .*\\\$3.50'"
rm -rf "$FXT"

say "v5.4 radar: stash, budgets, pushes, ledger, cli"
P="$HOOKS/superboost-parallelism.sh"
FXR=$(mktemp -d "${TMPDIR:-/tmp}/hyves-fxr.XXXXXX")
RICH54='{"session_id":"radarsess-9","model":{"display_name":"Fable 5"},"cost":{"total_cost_usd":4.567},"context_window":{"used_percentage":85.3},"rate_limits":{"five_hour":{"used_percentage":82.4},"seven_day":{"used_percentage":75.1}},"effort":{"level":"xhigh"},"workspace":{"current_dir":"/tmp/radarproj"}}'
J54='{"session_id":"radarsess-9"}'
N54='{"session_id":"radarsess-9","notification_type":"permission_prompt","message":"needs your permission","cwd":"/tmp/radarproj"}'
slr() { SUPERBOOST_FX_DIR="$FXR" env COLUMNS=150 "$SL"; }
fxr() { SUPERBOOST_FX_DIR="$FXR" "$FX" "$@"; }
# statusline stashes live session stats (change-gated, per sid8)
t "stats stash written"        "echo '$RICH54' | slr >/dev/null && [ \"\$(cat '$FXR/stats.radarses')\" = '85.3|82.4|75.1|4.57|radarproj' ]"
# weekly chip: visible amber at 75, absent when healthy
t "7d chip amber at 75"        "echo '$RICH54' | slr | grep -q '38;2;245;158;11m 7d 75.1% '"
t "7d chip hidden at 30"       "! (echo '$RICH54' | sed 's/75.1/30.0/' | slr | perl -pe 's/\e\[[0-9;]*m//g' | grep -q '7d')"
# --turn budget warnings: once per crossing, silent repeat, hysteresis re-arm
SUPERBOOST_FX_DIR="$FXR" "$P" --line >/dev/null 2>&1
t "--turn warns rate+context"  "OUT54=\$(echo '$J54' | SUPERBOOST_FX_DIR='$FXR' '$P' --turn); printf '%s' \"\$OUT54\" | grep -q 'Rate-limit budget' && printf '%s' \"\$OUT54\" | grep -q 'Context budget' && grep -q 'rl80' '$FXR/warned.radarses' && grep -q 'ctx80' '$FXR/warned.radarses'"
t "--turn silent on repeat"    "[ -z \"\$(echo '$J54' | SUPERBOOST_FX_DIR='$FXR' '$P' --turn)\" ]"
t "--turn re-arms below 70"    "printf '30|55|20|1.00|radarproj\n' > '$FXR/stats.radarses' && echo '$J54' | SUPERBOOST_FX_DIR='$FXR' '$P' --turn >/dev/null && printf '85|82|75|1.10|radarproj\n' > '$FXR/stats.radarses' && echo '$J54' | SUPERBOOST_FX_DIR='$FXR' '$P' --turn | grep -q 'Rate-limit budget'"
# attention pushes (dryrun): fire once, rate-limited, opt-out
t "push on permission notify"  "echo '$N54' | SUPERBOOST_FX_DIR='$FXR' SUPERBOOST_PUSH_DRYRUN=1 '$FX' notify && grep -q 'Claude needs you - radarproj' '$FXR/push.dryrun'"
t "push rate-limited 90s"      "echo '$N54' | SUPERBOOST_FX_DIR='$FXR' SUPERBOOST_PUSH_DRYRUN=1 '$FX' notify && [ \"\$(wc -l < '$FXR/push.dryrun' | tr -d ' ')\" = 1 ]"
t "PUSH=0 kills pushes"        "rm -f '$FXR/push.dryrun' '$FXR/push.stamp'; echo '$N54' | SUPERBOOST_FX_DIR='$FXR' SUPERBOOST_PUSH_DRYRUN=1 SUPERBOOST_PUSH=0 '$FX' notify && [ ! -f '$FXR/push.dryrun' ]"
# long-turn push: turn stamp consumed by done; short turns stay silent
t "long turn pushes on done"   "echo '$J54' | fxr emit turn && python3 -c \"import time;open('$FXR/turnstart.radarses','w').write(str(int(time.time())-120))\" && echo '$J54' | SUPERBOOST_FX_DIR='$FXR' SUPERBOOST_PUSH_DRYRUN=1 '$FX' emit done && grep -q 'Turn ran 2m 0s' '$FXR/push.dryrun' && [ ! -f '$FXR/turnstart.radarses' ]"
t "short turn no push"         "rm -f '$FXR/push.dryrun' '$FXR/push.stamp'; echo '$J54' | fxr emit turn && echo '$J54' | SUPERBOOST_FX_DIR='$FXR' SUPERBOOST_PUSH_DRYRUN=1 '$FX' emit done && [ ! -f '$FXR/push.dryrun' ]"
# SessionEnd folds the stats snapshot into the cost ledger
t "clear folds cost ledger"    "printf '42|55|20|3.21|radarproj\n' > '$FXR/stats.radarses' && echo '$J54' | SUPERBOOST_FX_DIR='$FXR' SUPERBOOST_LEDGER='$FXR/ledger.tsv' '$FX' clear && grep -q 'radarproj	3.21' '$FXR/ledger.tsv' && [ ! -f '$FXR/stats.radarses' ]"
# hyves CLI
HY="$HOOKS/hyves.sh"
t "hyves version"              "'$HY' version | grep -q 'HYVES CODE v'"
t "hyves stats reads ledger"   "SUPERBOOST_LEDGER='$FXR/ledger.tsv' '$HY' stats 7 | grep -q 'radarproj'"
rm -rf "$FXR"

say "resource probe json"
t "resource-check valid JSON"  "'$HOOKS/resource-check.sh' --quiet | python3 -c 'import sys,json; json.load(sys.stdin)'"
t "available_gb leading digit" "'$HOOKS/resource-check.sh' --quiet | grep -Eq '\"available_gb\":[0-9]'"
t "dangling --min-agents exits" "perl -e 'alarm 5; exec @ARGV' '$HOOKS/resource-check.sh' --min-agents --quiet >/dev/null 2>&1"

say "live budget --turn gating"
P="$HOOKS/superboost-parallelism.sh"
"$P" --line >/dev/null 2>&1   # seed stash
t "--turn silent when unchanged" "[ -z \"\$('$P' --turn)\" ]"
echo solo > "${SUPERBOOST_FX_DIR:-$HOME/.claude/fx}/budget_mode"
t "--turn speaks on mode flip"   "'$P' --turn | grep -q 'CHANGED'"
t "--turn silent again"          "[ -z \"\$('$P' --turn)\" ]"

say "hyves-boot"
t "non-TTY plain fallback"  "'$HOOKS/hyves-boot.sh' | grep -q 'HYVES CODE V5'"
t "PTY run exits 0"         "HYVES_BOOT_FRAMES=6 script -q /dev/null '$HOOKS/hyves-boot.sh' >/dev/null"

echo
if [ "$FAILS" -eq 0 ]; then echo "VERIFY: ALL PASS"; else echo "VERIFY: $FAILS FAILURE(S)"; fi
exit $((FAILS > 0))
