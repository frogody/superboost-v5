#!/bin/bash
# hyves.sh — the HYVES CODE command line (new in v5.4)
# Part of HYVES CODE by ISYNCSO (https://isyncso.com)
#
# One front door for the whole layer:
#   hyves [status]      two-line boot mark + live budgets + version
#   hyves doctor        full self-test (issues verbatim); --full also runs the suites
#   hyves stats [days]  session cost from the local ledger (default 14 days)
#   hyves demo          cycle the FX washes in this terminal's statusline
#   hyves update        git pull --ff-only + re-bless + self-test
#   hyves version       print the installed version
#
# Suggested alias:  alias hyves=~/.claude/hooks/hyves.sh

CLAUDE_DIR="$HOME/.claude"
HOOKS="$CLAUDE_DIR/hooks"
LEDGER="${SUPERBOOST_LEDGER:-$CLAUDE_DIR/logs/cost-ledger.tsv}"

hc_version() {
  python3 -c "import json;print(json.load(open('$CLAUDE_DIR/superboost-version.json'))['version'])" 2>/dev/null || echo "?"
}

case "${1:-status}" in

  status)
    BANNER="$("$HOOKS/superboost-banner.sh" 2>/dev/null)"
    printf '%s\n' "$BANNER" | grep '^⬢'
    "$HOOKS/superboost-parallelism.sh" --line 2>/dev/null
    echo "HYVES CODE v$(hc_version) · github.com/frogody/hyves-code"
    ;;

  doctor)
    BANNER="$("$HOOKS/superboost-banner.sh" 2>/dev/null)"
    printf '%s\n' "$BANNER" | grep '^⬢'
    if printf '%s' "$BANNER" | grep -qE 'FAIL:|WARN:'; then
      echo; echo "issues:"
      printf '%s\n' "$BANNER" | grep -E 'FAIL:|WARN:' | sed 's/^- */  /'
    else
      echo "  self-test clean"
    fi
    if [ "$2" = "--full" ]; then
      echo; echo "running quick suite (~15s)..."
      "$CLAUDE_DIR/tests/verify.sh" | tail -1
      echo "running deep animation suite (~30s)..."
      python3 "$CLAUDE_DIR/tests/deepcap.py" 2>/dev/null | tail -1
    fi
    ;;

  stats)
    DAYS="${2:-14}"
    case "$DAYS" in ''|*[!0-9]*) DAYS=14 ;; esac
    if [ ! -f "$LEDGER" ]; then
      echo "no ledger yet ($LEDGER) — it fills as sessions end."; exit 0
    fi
    HC_LEDGER="$LEDGER" HC_DAYS="$DAYS" python3 <<'PY'
import os, datetime, collections
ledger, days = os.environ["HC_LEDGER"], int(os.environ["HC_DAYS"])
cutoff = (datetime.date.today() - datetime.timedelta(days=days - 1)).isoformat()
# cost is CUMULATIVE per session -> keep max per (date, sid); dup folds are harmless
best = {}
with open(ledger) as f:
    for line in f:
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 4:
            continue
        date, sid, wdir, cost = parts
        if date < cutoff:
            continue
        try:
            cost = float(cost)
        except ValueError:
            continue
        k = (date, sid)
        if cost > best.get(k, (0.0, wdir))[0]:
            best[k] = (cost, wdir)
if not best:
    print(f"no sessions in the last {days} day(s).")
    raise SystemExit(0)
by_day = collections.defaultdict(float)
by_dir = collections.defaultdict(float)
for (date, _sid), (cost, wdir) in best.items():
    by_day[date] += cost
    by_dir[wdir] += cost
total = sum(by_day.values())
print(f"HYVES CODE — session cost, last {days} day(s)   total ${total:.2f} across {len(best)} session(s)")
print()
width = 30
peak = max(by_day.values()) or 1
for date in sorted(by_day):
    bar = "#" * max(1, round(by_day[date] / peak * width))
    print(f"  {date}  ${by_day[date]:>8.2f}  {bar}")
print()
print("  by project:")
for wdir, cost in sorted(by_dir.items(), key=lambda kv: -kv[1])[:10]:
    print(f"    {wdir:<20} ${cost:>8.2f}")
PY
    ;;

  demo)
    echo "cycling FX washes — watch the statusline (Ctrl-C to stop)"
    for e in preflight search think fanout join edit compact commit pass fail error deploy attn done; do
      "$HOOKS/superboost-fx.sh" emit "$e" </dev/null
      printf '  %s\n' "$e"
      sleep 2
    done
    "$HOOKS/superboost-fx.sh" clear </dev/null
    ;;

  update)
    echo "HYVES CODE update (git pull --ff-only)..."
    git -C "$CLAUDE_DIR" pull --ff-only || { echo "pull failed — resolve manually in ~/.claude" >&2; exit 1; }
    "$HOOKS/bless-hooks.sh" >/dev/null 2>&1 && echo "  checksums re-blessed"
    "$HOOKS/superboost-banner.sh" 2>/dev/null | grep '^⬢'
    ;;

  version) echo "HYVES CODE v$(hc_version)" ;;

  *)
    sed -n '5,12p' "$0" | sed 's/^# //;s/^#//'
    ;;
esac
exit 0
