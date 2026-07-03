#!/bin/bash
# safety-guard.sh — PreToolUse deny hook for catastrophic / exfil actions + locked files
# Part of Claude Code Superboost by ISYNCSO (https://isyncso.com)  — new in v4.0
#
# Purpose: replace the prose "Auto-Mode Safety Checklist" (which nothing enforced)
# with a REAL guardrail. Because defaultMode=auto + skipAutoPermissionPrompt=true
# suppress permission prompts, this is the only thing standing between a model
# mistake / prompt-injection and an irreversible action.
#
# Design principle: CONSERVATIVE. It blocks only actions that are essentially never
# intended (rm -rf of home/root, disk formatting, fork bombs, force-push, secret
# exfiltration) plus edits to calculator-locked files. It deliberately does NOT block
# ordinary `git push`, `supabase/vercel deploy`, or SQL — those are part of the normal
# workflow. Tune the patterns below to taste.
#
# Bind to PreToolUse matchers: Bash, Write, Edit, MultiEdit.
# Claude Code blocks a tool on exit code 2 (stderr is fed back to the model).

TOOL_INPUT=$(cat)

SG_INPUT="$TOOL_INPUT" python3 <<'PY'
import os, json, re, sys

raw = os.environ.get("SG_INPUT", "")
try:
    d = json.loads(raw)
except Exception:
    sys.exit(0)  # fail-open: unparseable input must not brick the session

tool = d.get("tool_name", d.get("name", "")) or ""
inp = d.get("tool_input", d.get("input", {})) or {}

def block(msg):
    sys.stderr.write("BLOCKED by Superboost safety-guard: " + msg + "\n")
    sys.exit(2)

if tool == "Bash":
    cmd = inp.get("command", "") or ""

    # fork bomb  ":(){ :|:& };:"  — check the space-collapsed definition (quote-safe)
    if ":(){" in cmd.replace(" ", ""):
        block("fork bomb pattern.")

    # rm -rf targeting / or home (not ordinary subdirectories)
    m = re.search(r"\brm\b(.*)", cmd, re.S)
    if m:
        tail = m.group(1)
        has_rf = bool(re.search(r"-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r", tail)
                      or (re.search(r"-r\b", tail) and re.search(r"-f\b", tail)))
        targets_root = bool(
            re.search(r"\s(/|~|\$HOME|\$\{HOME\}|/\*|~/\*|\*)\s*($|;|&&|\|)", tail)
            or re.search(r"\s(/|~|\$HOME|\$\{HOME\})\s*$", tail)
        )
        if has_rf and targets_root:
            block("rm -rf targeting / or $HOME. Refusing; run it manually if truly intended.")

    # raw disk write / format
    if re.search(r"\bmkfs\b", cmd) or re.search(r"\bdd\b[^\n]*of=/dev/", cmd) \
       or re.search(r">\s*/dev/(sd|disk|nvme|hd)", cmd):
        block("raw disk write / format.")

    # recursive chmod 777 on / or home
    if re.search(r"\bchmod\s+-R\s+0?777\s+(/|~|\$HOME)", cmd):
        block("recursive chmod 777 on / or home.")

    # git force-push (rewrites remote history)
    if re.search(r"\bgit\s+push\b[^\n]*(--force\b|--force-with-lease\b|\s-f\b)", cmd):
        block("git force-push rewrites remote history. Push normally or run manually.")

    # secret exfiltration over the network
    if re.search(r"\b(curl|wget|nc|ncat|scp|rsync)\b", cmd) \
       and re.search(r"(\.env\b|id_rsa|\.pem\b|\.aws/credentials|\.ssh/id_|\.npmrc|\bsecret\b|token=)", cmd, re.I) \
       and re.search(r"https?://|@[\w.-]+:", cmd):
        block("possible secret exfiltration over the network.")

    sys.exit(0)

if tool in ("Write", "Edit", "MultiEdit"):
    fp = inp.get("file_path", inp.get("path", "")) or ""
    base = fp.rsplit("/", 1)[-1]

    # Calculator lock — real enforcement (v3.0 was prose-only with a plaintext password)
    if base in {"formulas.ts", "useCalculations.ts", "woningvorming.ts"}:
        block(f"'{base}' is a calculator-locked file. Editing calc logic requires a deliberate, "
              f"explicit unlock — temporarily disable this hook (see project CLAUDE.md).")

    # Never write to credential paths
    if re.search(r"/\.(ssh|aws|gnupg)/", fp) or base == ".env" or re.search(r"\.(pem|key)$", fp):
        block(f"writing to a credential path ({fp}).")

    sys.exit(0)

sys.exit(0)
PY
rc=$?
# On a block (exit 2), auto-fire the red BLOCKED effect in the statusline.
# PostToolUse never runs for a denied call, so this is the only place it can fire.
# (Added with explicit user authorization, 2026-07-03.)
if [ "$rc" -eq 2 ]; then
  "$HOME/.claude/hooks/superboost-fx.sh" emit blocked 2>/dev/null
fi
exit "$rc"
