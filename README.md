# Superboost v5.2 "Hyves"

![version](https://img.shields.io/badge/version-5.2%20%22Hyves%22-a855f7)
![Claude Code](https://img.shields.io/badge/Claude%20Code-%E2%89%A5%202.1.170-22d3ee)
![tuned for](https://img.shields.io/badge/tuned%20for-Claude%20Fable%205-facc15)
![safety](https://img.shields.io/badge/auto--mode-guarded-22c55e)

**Superboost is an operating layer for [Claude Code](https://claude.com/claude-code) that makes Claude Fable 5 in your terminal faster, safer, cheaper, and far nicer to use — without changing how you work.** You drop it into `~/.claude`, and every session boots with real safety guardrails, agents that scale to your machine's RAM, smart model tiering, and a colorized heads‑up display that reacts to what Claude is doing. It's the difference between *running* Fable 5 and *getting the most out of it*.

Built by [ISYNCSO](https://isyncso.com). Zero dependencies, zero lock‑in — it's shell hooks and a `CLAUDE.md`, all in one folder you already have.

---

## Why it exists

Claude Fable 5 is a phenomenal model: a 1M‑token context, always‑on adaptive reasoning, dependable parallel sub‑agents, and turns that can run productively for minutes on hard, ambiguous work. But out of the box, Claude Code doesn't know anything about **your machine, your budget, or your safety posture** — and it leaves Fable's best traits half‑used:

- It will fan out sub‑agents, but it won't size that fan‑out to the RAM you actually have.
- Auto‑mode suppresses permission prompts for speed — but nothing is stopping a genuinely destructive command.
- Fable costs ~2× Opus, yet mechanical "find‑this‑file" work runs on the expensive model.
- Fable's safety classifier can decline benign security work; if you don't know that, a normal refusal looks like a bug.
- The terminal is a wall of monochrome text with no sense of what's happening.

Superboost closes every one of those gaps. **It's the config layer that turns "Fable 5 in Claude Code" into a tuned cockpit.**

---

## What you get

### Tuned for Fable 5 — the model, done right
The default model is set to `fable[1m]` with a graceful‑degradation allowlist (if your org lacks Fable access, it falls back to Opus with a warning instead of failing). On top of that, a **Fable‑5 doctrine** baked into `CLAUDE.md` teaches Claude how to actually behave like Fable 5: state the *outcome and the why* instead of step‑by‑step scripts, delegate to async sub‑agents and keep working, don't over‑refactor at high effort, ground every progress claim in real tool output, and treat the safety‑classifier refusal (auto‑routed to Opus) as a known mode — not a failure. Every point is backed by a **verified deep‑research brief** ([`superboost-expertise-report.md`](./superboost-expertise-report.md), 25/25 claims confirmed against first‑party Anthropic docs).

### Agents that scale to your machine — the standout feature
Superboost reads your live RAM and converts it into an **actionable fan‑out budget**: how many agents can run at once, what Workflow width to use, and a one‑word posture (`wide` / `balanced` / `narrow` / `solo`). It's emitted into context at session start and shown live in the status bar as `fanout~N`. When you have headroom, Superboost tells the orchestrator to **delegate wide and async** — exactly what Fable 5's dependable sub‑agents are built for. When RAM is tight, it says stay solo, and a guard hook physically blocks spawns that would thrash the machine. **This is the benefit plain Fable‑on‑Claude‑Code simply doesn't offer: parallelism that's matched to your hardware, automatically.**

### Safety that's actually enforced — not a checklist
Auto‑mode (no permission prompts) is fast but risky. Superboost makes it safe with a real `PreToolUse` **deny hook** that blocks the catastrophic cases — `rm -rf` of `/` or `$HOME`, disk formatting, fork bombs, `git push --force`, secret exfiltration over the network, and edits to files you've locked — while deliberately allowing ordinary `git push`, deploys, and SQL. It's a guardrail the model *cannot* talk its way past, so you get the speed of auto‑mode without the exposure.

### A terminal you enjoy looking at
The status bar is a **full‑width HUD painted with truecolor backgrounds** (new in 5.1): a violet brand chip, the model + effort level on a gold chip when you're on Fable, a wide green→amber→red RAM gradient bar, context‑window use, your fan‑out capacity, 5‑hour rate use, and session cost — edge to edge. Notable actions **flood the bar** with a quantized, dithered background wash in the action's color that pulses and decays — fan‑out is cyan, commits green, deploys indigo, edits amber, web research violet, and safety blocks fire red *from the guard itself*, so even a denied action is visible. Washes last `SUPERBOOST_FX_TTL` seconds (default 7). It's all done with zero‑width ANSI color on plain‑ASCII glyphs, so it never corrupts the terminal layout (a hard‑won lesson), and `SUPERBOOST_STATUSLINE_PLAIN=1` reverts to pure ASCII if you ever want it. (One macOS quirk: if the terminal window is fully covered, App Nap pauses redraws, so short‑lived washes can pass unseen — they resume the moment the window is visible.)

### Smart model tiering — pay for judgment, not grep
Superboost's guidance tiers work across models: `fable` for orchestration, synthesis, and judgment; `sonnet` for implementation; `haiku` for cheap read‑only exploration. Cheap explorers + Sonnet workers + one Fable synthesizer gets you near‑frontier quality at a fraction of an all‑Fable bill — and it keeps the expensive model off mechanical work.

---

## Why it's special

1. **Enforce with hooks, don't narrate with ceremony.** Superboost doesn't ask the model to *remember* to be safe or efficient — it wires those behaviors into the harness where they can't be skipped, and keeps the model focused on your task instead of on rituals.
2. **It scales to *your* machine.** The RAM number isn't just a HUD stat — it's a budget the orchestrator acts on. More parallelism when you can afford it, none when you can't.
3. **It's grounded in verified facts, not vibes.** The Fable‑5 tuning comes from a fact‑checked research pass against Anthropic's own docs, shipped alongside the config so you can audit every claim.
4. **It's transparent and recoverable.** Everything is plain shell + Markdown in one git repo. No binary, no daemon, no telemetry. Read it, fork it, change it.

---

## How it makes Fable better in a Claude Code terminal

| Fable 5 trait | Without Superboost | With Superboost |
|---|---|---|
| Dependable async sub‑agents | Fans out, but blind to your RAM | Sizes fan‑out to a live RAM budget — wide when you can, solo when you can't |
| Long, minutes‑long autonomous turns | Can drift, over‑build, or fabricate progress | Doctrine keeps it on‑rails: outcome‑first, no tidying, grounded progress, memory surface |
| Safety classifier refusals | Look like a mysterious failure | Understood as a known mode with automatic Opus fallback |
| ~2× Opus pricing | Runs everything on Fable | Tiers mechanical work down to Sonnet/Haiku |
| Fast auto‑mode | Fast but exposed | Fast *and* guarded against catastrophic actions |
| Plain terminal | Monochrome, opaque | Colorized HUD + action effects you can read at a glance |

---

## Quick start

Superboost lives in `~/.claude`, which Claude Code already reads. Clone it there (or copy the files in), then start a fresh session:

```bash
# back up an existing config first if you have one
git clone https://github.com/frogody/superboost-v5.git ~/.claude
~/.claude/install.sh   # verify prereqs, bless checksums, self-test — ends with the HYVES boot cinema
claude                 # boots "SUPERBOOST V5 ACTIVE", colorized HUD, Fable 5 default
```

`install.sh` is idempotent (re-run it any time) and works from a checkout anywhere — run from outside `~/.claude` it backs up your existing `CLAUDE.md` / `settings.json` to a timestamped folder before copying the new ones in.

Requires **Claude Code ≥ 2.1.170** (for Fable 5) — run `claude update` if needed. On boot you'll see a one‑line health check and your parallelism budget; if anything's misconfigured, it tells you. Useful commands:

```bash
~/.claude/hooks/superboost-parallelism.sh          # your current fan-out budget
~/.claude/hooks/superboost-fx.sh emit preflight     # trigger a status-bar effect
~/.claude/hooks/superboost-banner.sh                # run the install self-test
~/.claude/hooks/bless-hooks.sh                      # re-seal checksums after editing a hook
~/.claude/hooks/hyves-boot.sh                       # replay the HYVES CODE boot cinema
```

---

## What's new in v5.2 "Hyves"

**HYVES CODE** (*Holistic Yield & Validation Engines*) is the new face of the HUD — the brand chip now reads `HYVES CODE V5` — and v5.2 is a power pass over every layer, driven by a two-agent review (one auditing the scripts, one researching professional terminal FX).

- **Live parallelism budget** — a `UserPromptSubmit` hook re-injects the fan-out budget into context *the moment the RAM posture changes* (`wide`↔`balanced`↔`narrow`↔`solo`). Silent on unchanged turns; the budget can no longer go stale over a long session.
- **Outcome-aware FX** — test/build/lint commands now wash the bar **PASS green or FAIL red from the actual result** (the emitter reads the tool response, not just the command). Quiet tools skip the classifier entirely (~7ms).
- **Cinematic motion, tastefully** — fan-out/deploy washes carry a Larson scanner, commits a one-shot sweep; the wash shimmers with a 1D plasma field and decays on a smoothstep ease with a <10% sine pulse (photosensitivity-safe, WCAG 2.3.1). Every frame is a valid still, so a paused statusline never looks broken.
- **`hyves-boot.sh`** — an nms/*Sneakers*-style decrypt reveal of the HYVES CODE logo for the installer/first-boot moment: alt-screen, synchronized-output frames, phosphor-green resolve, live self-test status, OSC 8 repo link. Degrades to one plain line when piped. (Deliberately *not* a session hook — hook stdout is model context.)
- **Denser HUD** — workspace dir, diff churn `+N/-N`, and a red `200K+` chip past 200k tokens; fractional context-% no longer renders red.
- **Tighter safety-guard** — quoted/trailing-slash `rm -rf` home variants, `git push` with a plus-prefixed refspec (a force-update in disguise), real `.env.*` files, and Bash-path writes to calculator-locked files (redirects/`tee`/`sed -i`) are all now caught. Self-test verifies jq + the FX and live-budget bindings.

---

## What's new in v5.1

- **Full‑width statusline** — the HUD now claims the entire terminal width with truecolor *background* chips and a wide RAM gradient bar, plus new context‑used %, effort‑level, and 5‑hour‑rate readouts.
- **FX background washes** — effects flood the bar with a blocky, dithered, pulsing color wash instead of a small colored label; duration tunable via `SUPERBOOST_FX_TTL`.
- **Safety blocks are now visible** — `safety-guard.sh` fires the red BLOCKED wash itself when it denies an action (previously documented but unwired: a denied call never reaches PostToolUse).
- **Deploy effect false‑positive fix** — the indigo deploy wash now requires a real deploy (platform CLI, `git push`, or a deploy script/task in command position), not just the word "deploy" anywhere in a command.
- **Narrow terminals** — the bar degrades to a hard‑truncated compact line instead of wrapping in slim panes.

---

## What's in the box

| File | Role |
|------|------|
| `CLAUDE.md` | The brains — Auto‑Router (RAM‑aware), Fable‑first model tiering, the Fable‑5 doctrine, parallelism budget, terminal FX, and safety guidance. Loaded into every session. |
| `settings.json` | Wires the hooks, sets `model: fable[1m]` + the fallback allowlist, and turns on guarded auto‑mode. |
| `hooks/superboost-parallelism.sh` | Turns the RAM probe into an actionable fan‑out budget. |
| `hooks/superboost-fx.sh` | Terminal FX emitter — colors the status bar on notable actions (and via manual `emit`). |
| `hooks/superboost-statusline.sh` | The full‑width HUD (bg chips, RAM gradient bar, ctx %, capacity, rate, cost, live FX washes). |
| `hooks/safety-guard.sh` | The deny hook that makes auto‑mode safe. |
| `hooks/resource-guard.sh` · `resource-check.sh` · `ram-monitor.sh` | Live resource probing + spawn throttling. |
| `hooks/superboost-banner.sh` | SessionStart self‑test + budget emit (silent unless something's wrong). |
| `hooks/hyves-boot.sh` | The HYVES CODE decrypt boot cinema for installer/first-boot (never a session hook). |
| `hooks/superboost-secrets.sh` | Keychain‑backed credential manager (values never touch a file). |
| `superboost-expertise-report.md` | The verified Fable‑5 research brief behind the tuning. |
| `superboost-version.json` | Version, target‑model spec, model tiers, and hook checksums. |

---

## Design principles

1. **Safety is enforced, not narrated** — a hook blocks the catastrophic cases so auto‑mode is safe by construction.
2. **Scale to the machine** — the RAM probe is a fan‑out budget, not just a number.
3. **Defer to the native harness** — lean on Claude Code's Workflow tool over hand‑rolled orchestration.
4. **No stale model pins** — model tiers are alias‑only (`fable`/`opus`/`sonnet`/`haiku`).
5. **Observable and pleasant, but never fragile** — color via zero‑width sequences only, so the terminal never desyncs.

## Secrets & privacy

No secrets live in this repo. Credentials go in the macOS keychain via `superboost-secrets.sh` and are referenced by name — never written to a file, a commit, or a prompt. The `.gitignore` uses a strict whitelist, so session transcripts, logs, caches, and `.env` files can never be committed. No telemetry.

---
*ISYNCSO · github.com/frogody/superboost-v5*
