#!/bin/bash
# install.sh — Superboost v5.2 "Hyves" installer / verifier
# Part of Claude Code Superboost by ISYNCSO (https://isyncso.com)
#
# Two modes, decided automatically:
#   IN-PLACE  — run from a checkout that IS ~/.claude (the normal layout):
#               verify prerequisites, chmod hooks, re-bless checksums, self-test.
#   COPY      — run from a checkout elsewhere: back up any existing ~/.claude
#               config files it would touch, copy hooks/ + CLAUDE.md +
#               settings.json + superboost-version.json in, then same as above.
#
# Ends with the HYVES CODE boot cinema (hooks/hyves-boot.sh) when stdout is a
# TTY; degrades to a plain status line when piped/CI. Idempotent — safe to
# re-run any time.

set -u

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"

say()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

say "Superboost v5.2 \"Hyves\" — install/verify"
say ""

# ─── 1. Prerequisites ────────────────────────────────────────
command -v python3 >/dev/null 2>&1 || fail "python3 is required (safety-guard, budget, bless)."
command -v git >/dev/null 2>&1 || say "  warn: git not found — checksum history and updates unavailable."
if command -v jq >/dev/null 2>&1; then
  say "  ok: jq present"
else
  say "  warn: jq not installed — statusline session fields (model/cost/ctx) will be blank."
  say "        install with: brew install jq"
fi
if command -v claude >/dev/null 2>&1; then
  CC_VER="$(claude --version 2>/dev/null | grep -o '[0-9][0-9.]*' | head -1)"
  say "  ok: Claude Code ${CC_VER:-?} (Fable 5 needs >= 2.1.170 — run 'claude update' if older)"
else
  say "  warn: 'claude' CLI not on PATH — install Claude Code first (https://claude.com/claude-code)."
fi

# ─── 2. Files into place (COPY mode only) ────────────────────
if [ "$SRC_DIR" = "$CLAUDE_DIR" ]; then
  say "  ok: running in-place from ~/.claude — no copying needed"
else
  say "  copy mode: installing from $SRC_DIR -> $CLAUDE_DIR"
  mkdir -p "$HOOKS_DIR"
  STAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$CLAUDE_DIR/superboost-backup-$STAMP"
  for f in CLAUDE.md settings.json superboost-version.json; do
    if [ -f "$CLAUDE_DIR/$f" ] && ! cmp -s "$SRC_DIR/$f" "$CLAUDE_DIR/$f"; then
      mkdir -p "$BACKUP_DIR"
      cp -p "$CLAUDE_DIR/$f" "$BACKUP_DIR/$f"
      say "  backed up existing $f -> ${BACKUP_DIR#$HOME/}/"
    fi
    [ -f "$SRC_DIR/$f" ] && cp -p "$SRC_DIR/$f" "$CLAUDE_DIR/$f"
  done
  cp -p "$SRC_DIR/hooks/"*.sh "$HOOKS_DIR/" 2>/dev/null || fail "hooks/ not found next to install.sh"
  [ -f "$SRC_DIR/README.md" ] && cp -p "$SRC_DIR/README.md" "$CLAUDE_DIR/README.md"
fi

# ─── 3. Permissions + checksums ──────────────────────────────
chmod +x "$HOOKS_DIR"/*.sh 2>/dev/null
if [ -x "$HOOKS_DIR/bless-hooks.sh" ]; then
  "$HOOKS_DIR/bless-hooks.sh" >/dev/null 2>&1 && say "  ok: hook checksums blessed" \
    || say "  warn: bless-hooks failed — run $HOOKS_DIR/bless-hooks.sh manually"
else
  fail "bless-hooks.sh missing or not executable in $HOOKS_DIR"
fi

# ─── 4. Self-test ────────────────────────────────────────────
BANNER_LINE="$("$HOOKS_DIR/superboost-banner.sh" 2>/dev/null | head -1)"
case "$BANNER_LINE" in
  *"boot OK"*)
    STATUS="${BANNER_LINE#*— }"; STATUS="${STATUS%%. Do NOT*}"
    say "  ok: self-test clean — ${STATUS}" ;;
  *)           say "  warn: self-test reported issues — run $HOOKS_DIR/superboost-banner.sh for details" ;;
esac

say ""
say "Installed. Start a fresh 'claude' session to activate all hooks."

# ─── 5. Finale: the HYVES CODE boot cinema (TTY only) ────────
if [ -t 1 ] && [ -x "$HOOKS_DIR/hyves-boot.sh" ]; then
  sleep 0.6
  "$HOOKS_DIR/hyves-boot.sh"
fi
exit 0
