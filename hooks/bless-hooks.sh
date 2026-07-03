#!/bin/bash
# bless-hooks.sh — Seed/update Superboost hook checksums in version.json
# Part of Claude Code Superboost V4 by ISYNCSO (https://isyncso.com)
#
# Run after intentional edits to any hook in ~/.claude/hooks/ to re-bless
# the checksums. The SessionStart banner warns on drift; this quiets it.
#
# Usage: ~/.claude/hooks/bless-hooks.sh

set -e

HOOKS_DIR="$HOME/.claude/hooks"
VERSION_FILE="$HOME/.claude/superboost-version.json"
TRACKED=(resource-check.sh ram-monitor.sh resource-guard.sh superboost-banner.sh superboost-statusline.sh bless-hooks.sh safety-guard.sh gitnexus-refresh.sh superboost-secrets.sh superboost-fx.sh superboost-parallelism.sh hyves-boot.sh hyves.sh)

if [ ! -f "$VERSION_FILE" ]; then
  echo "ERROR: $VERSION_FILE not found" >&2
  exit 1
fi

# Build JSON object of {script: sha256, ...} via python on a null-delimited list
export BLESS_HOOKS_DIR="$HOOKS_DIR"
export BLESS_VERSION_FILE="$VERSION_FILE"
export BLESS_TRACKED=$(printf '%s\n' "${TRACKED[@]}")

python3 <<'PY'
import datetime, hashlib, json, os

hooks_dir = os.environ["BLESS_HOOKS_DIR"]
version_file = os.environ["BLESS_VERSION_FILE"]
tracked = [s for s in os.environ["BLESS_TRACKED"].splitlines() if s]

scripts = {}
for name in tracked:
    path = os.path.join(hooks_dir, name)
    if not os.path.exists(path):
        continue
    with open(path, "rb") as f:
        scripts[name] = hashlib.sha256(f.read()).hexdigest()

with open(version_file) as f:
    vj = json.load(f)
vj["scripts"] = scripts
vj["blessed_at"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
with open(version_file, "w") as f:
    json.dump(vj, f, indent=2)
    f.write("\n")

print(f"Blessed {len(scripts)} hook(s) at {vj['blessed_at']}")
for name, sha in scripts.items():
    print(f"  {name}: {sha[:16]}...")
PY
