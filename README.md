# Superboost v5.0 "Fable"

A personal operating layer for [Claude Code](https://claude.com/claude-code) by ISYNCSO — a colorized RAM/model/FX HUD, real safety guardrails, RAM-scaled parallelism, and lean agent-orchestration guidance, **tuned for Claude Fable 5** and wired into `~/.claude`.

> **v5 in one line:** everything v4 was — *enforce with hooks, don't narrate; lean on the native harness* — retuned for Fable 5, plus RAM-scaled fan-out and a colored terminal-FX layer.

## What's new in v5

- **Tuned for Claude Fable 5.** Default model is `fable[1m]` with an `availableModels` allowlist (`fable`/`opus`/`sonnet`) so a blocked default degrades to Opus 4.8 with a warning, not a hard fail. Model tiering is now `fable` (orchestrator/synthesizer/judge) · `sonnet` (worker) · `haiku` (explorer).
- **Fable-5 doctrine** (`CLAUDE.md` §9): dependable async sub-agents (delegate + keep working), state-the-objective + the *Why*, grounded progress claims, no-tidying at high effort, effort awareness, memory surface, and refusal/fallback awareness (Fable 5's cyber/bio classifier + Claude Code's built-in Opus 4.8 fallback).
- **RAM → parallelism budget** (`superboost-parallelism.sh`): turns the RAM probe into an actionable fan-out posture — `wide` / `balanced` / `narrow` / `solo` with a concrete `concurrent_agents` and `workflow_width`. Emitted into context at SessionStart and shown live in the statusline. When RAM is ample, fan out wide and async — the win plain Fable-5-on-Claude-Code doesn't offer.
- **Colored terminal FX** (`superboost-fx.sh` + statusline): notable actions light up as a decaying, pulsing colored segment (fan-out=cyan, commit=green, deploy=indigo, edit=amber, research=violet, block=red) — plus a manual `emit` so any skill/step can trigger an effect (e.g. `emit preflight`). Writes state only, prints nothing → zero context pollution.
- **Colorized statusline** with a RAM gradient bar and colored model/capacity/cost — using **ANSI SGR only, no wide glyphs**, so the TUI width calc stays exact (v4's hard-won lesson). `SUPERBOOST_STATUSLINE_PLAIN=1` reverts to pure ASCII.

## Fable 5 quick reference (verified — see `superboost-expertise-report.md`)

- **Needs Claude Code ≥ v2.1.170** (`claude update`), is **never an account default**, and is **not available under ZDR**. Select via the `model` setting, `/model fable`, or the `best` alias (Fable where available, else latest Opus).
- **Always-on adaptive thinking** — no manual budget; depth is the **effort** knob (`low…max`, default `high`). `MAX_THINKING_TOKENS`, `alwaysThinkingEnabled`, `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` have no effect on Fable 5.
- **Refusals** = normal HTTP 200 `stop_reason:"refusal"` (categories `cyber`/`bio`/`reasoning_extraction`/`frontier_llm`/`null`); Claude Code auto-re-runs flagged cyber/bio on Opus 4.8 (Opus 4.7 on AWS).
- **Keys:** `Meta+T` thinking · `Meta+P` model picker · `Meta+O` fast mode; in the picker `←/→` = effort, `s` = this session only.

The full cited brief — architecture, safety machinery, prompting guidance, and how each finding maps to a v5 change — is in [`superboost-expertise-report.md`](./superboost-expertise-report.md) (25/25 claims verified 3-0 against first-party Anthropic docs).

## What's in here

| File | Role |
|------|------|
| `CLAUDE.md` | Global behavior: Auto-Router (RAM-aware), Fable-first Model Tiering, Fable-5 doctrine, parallelism budget, terminal FX, safety. Loaded into every session. |
| `settings.json` | Hook bindings, plugins, `model: fable[1m]` + `availableModels` allowlist, `defaultMode: auto` (made safe by `safety-guard.sh`). |
| `hooks/superboost-banner.sh` | SessionStart install self-test + parallelism-budget emit. **Silent on success**; surfaces only problems. |
| `hooks/superboost-statusline.sh` | Colorized HUD (RAM gradient bar, capacity, model, cost, live FX). ANSI SGR only; `SUPERBOOST_STATUSLINE_PLAIN=1` for pure ASCII. |
| `hooks/superboost-parallelism.sh` | RAM probe → actionable fan-out budget (`--budget` JSON, `--line`, human). **New in v5.** |
| `hooks/superboost-fx.sh` | Terminal FX event emitter — PostToolUse classifier + manual `emit <effect>`. Writes state, prints nothing. **New in v5.** |
| `hooks/safety-guard.sh` | **PreToolUse deny hook** (Bash/Write/Edit): blocks `rm -rf /`~, disk format, fork bombs, `git push --force`, secret exfil, and edits to calculator-locked files. |
| `hooks/resource-guard.sh` | PreToolUse spawn guard — blocks agent/team/workflow spawns only when RAM is genuinely too low. Exit 2 = block. |
| `hooks/resource-check.sh` | RAM/CPU/pressure probe → JSON. |
| `hooks/ram-monitor.sh` | PostToolUse RAM logger — sampled + rotated. |
| `hooks/gitnexus-refresh.sh` | SessionStart index-freshness report — cwd-guarded, no auto-exec. |
| `hooks/superboost-secrets.sh` | Keychain-backed credential manager + first-boot provisioning. |
| `hooks/bless-hooks.sh` | Re-seed sha256 checksums in `superboost-version.json` after editing a hook. |
| `superboost-version.json` | Version + target-model spec + alias-only model tiers + tracked-hook checksums + changelog. |

## Design principles

1. **Safety is enforced, not narrated.** `defaultMode: auto` is safe because `safety-guard.sh` blocks the catastrophic cases in a PreToolUse hook — deliberately conservative (ordinary `git push`, deploys, SQL allowed).
2. **Scale to the machine.** The RAM probe isn't just a HUD number — it's a fan-out budget the orchestrator acts on. Wide when RAM is ample, solo when tight.
3. **Defer orchestration to the harness.** Native Workflow tool (concurrency cap, shared token budget, resume, `/workflows` UI) over hand-rolled waves/zones.
4. **No stale model pins.** Model tiers are alias-only (`fable`/`opus`/`sonnet`/`haiku`).
5. **Observable and pleasant, not noisy.** A colorized HUD + short colored action effects — but color via zero-width SGR only, never wide glyphs, so the TUI never desyncs.

## Operating

```bash
# After editing any hook, re-seed checksums (silences the drift warning):
~/.claude/hooks/bless-hooks.sh

# Manual resource + parallelism reads:
~/.claude/hooks/resource-check.sh --quiet          # JSON resource probe
~/.claude/hooks/superboost-parallelism.sh          # fan-out budget (human)
~/.claude/hooks/superboost-parallelism.sh --budget # fan-out budget (JSON)

# Trigger a terminal effect manually:
~/.claude/hooks/superboost-fx.sh emit preflight     # blue; also fanout|commit|deploy|blocked|edit|search

# Run the install self-test on demand:
~/.claude/hooks/superboost-banner.sh
```

## Secrets

No secrets live in this repo. Store credentials in the macOS keychain and reference them by name:

```bash
~/.claude/hooks/superboost-secrets.sh set supabase-mgmt-token   # hidden prompt; value -> keychain
~/.claude/hooks/superboost-secrets.sh get supabase-mgmt-token   # retrieve for use in a command
```

The `.gitignore` uses a **whitelist** model: everything is ignored except the authored config, so session transcripts, logs, caches, `.env`, and `settings.local.json` can never be committed.

---
*ISYNCSO · github.com/frogody/superboost-v4*
