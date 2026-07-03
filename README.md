# HYVES CODE V5

*Holistic Yield & Validation Engines* — formerly **Superboost**. The internal hook scripts, env vars, and sentinels keep the historical `superboost-` prefix, so upgrading is a `git pull`, not a migration.

![version](https://img.shields.io/badge/HYVES%20CODE-V5.4.3-a855f7)
![Claude Code](https://img.shields.io/badge/Claude%20Code-%E2%89%A5%202.1.170-22d3ee)
![tuned for](https://img.shields.io/badge/tuned%20for-Claude%20Fable%205-facc15)
![safety](https://img.shields.io/badge/auto--mode-guarded-22c55e)

**HYVES CODE is an operating layer for [Claude Code](https://claude.com/claude-code) that makes Claude Fable 5 in your terminal faster, safer, cheaper, and far nicer to use — without changing how you work.** You drop it into `~/.claude`, and every session boots with real safety guardrails, agents that scale to your machine's RAM, smart model tiering, and a colorized heads‑up display that reacts to what Claude is doing. It's the difference between *running* Fable 5 and *getting the most out of it*.

Built by [ISYNCSO](https://isyncso.com). Zero dependencies, zero lock‑in — it's shell hooks and a `CLAUDE.md`, all in one folder you already have.

---

## Why it exists

Claude Fable 5 is a phenomenal model: a 1M‑token context, always‑on adaptive reasoning, dependable parallel sub‑agents, and turns that can run productively for minutes on hard, ambiguous work. But out of the box, Claude Code doesn't know anything about **your machine, your budget, or your safety posture** — and it leaves Fable's best traits half‑used:

- It will fan out sub‑agents, but it won't size that fan‑out to the RAM you actually have.
- Auto‑mode suppresses permission prompts for speed — but nothing is stopping a genuinely destructive command.
- Fable costs ~2× Opus, yet mechanical "find‑this‑file" work runs on the expensive model.
- Fable's safety classifier can decline benign security work; if you don't know that, a normal refusal looks like a bug.
- The terminal is a wall of monochrome text with no sense of what's happening.

HYVES CODE closes every one of those gaps. **It's the config layer that turns "Fable 5 in Claude Code" into a tuned cockpit.**

---

## What you get

### Tuned for Fable 5 — the model, done right
The default model is set to `fable[1m]` with a graceful‑degradation allowlist (if your org lacks Fable access, it falls back to Opus with a warning instead of failing). On top of that, a **Fable‑5 doctrine** baked into `CLAUDE.md` teaches Claude how to actually behave like Fable 5: state the *outcome and the why* instead of step‑by‑step scripts, delegate to async sub‑agents and keep working, don't over‑refactor at high effort, ground every progress claim in real tool output, and treat the safety‑classifier refusal (auto‑routed to Opus) as a known mode — not a failure. Every point is backed by a **verified deep‑research brief** ([`superboost-expertise-report.md`](./superboost-expertise-report.md), 25/25 claims confirmed against first‑party Anthropic docs).

### Agents that scale to your machine — the standout feature
HYVES CODE reads your live RAM and converts it into an **actionable fan‑out budget**: how many agents can run at once, what Workflow width to use, and a one‑word posture (`wide` / `balanced` / `narrow` / `solo`). It's emitted into context at session start and shown live in the status bar as `fanout~N`. When you have headroom, HYVES CODE tells the orchestrator to **delegate wide and async** — exactly what Fable 5's dependable sub‑agents are built for. When RAM is tight, it says stay solo, and a guard hook physically blocks spawns that would thrash the machine. **This is the benefit plain Fable‑on‑Claude‑Code simply doesn't offer: parallelism that's matched to your hardware, automatically.**

### Safety that's actually enforced — not a checklist
Auto‑mode (no permission prompts) is fast but risky. HYVES CODE makes it safe with a real `PreToolUse` **deny hook** that blocks the catastrophic cases — `rm -rf` of `/` or `$HOME`, disk formatting, fork bombs, `git push --force`, secret exfiltration over the network, and edits to files you've locked — while deliberately allowing ordinary `git push`, deploys, and SQL. It's a guardrail the model *cannot* talk its way past, so you get the speed of auto‑mode without the exposure.

### A terminal you enjoy looking at
The status bar is a **full‑width HUD painted with truecolor backgrounds** (new in 5.1): a violet brand chip, the model + effort level on a gold chip when you're on Fable, a wide green→amber→red RAM gradient bar, context‑window use, your fan‑out capacity, 5‑hour rate use, and session cost — edge to edge. Notable actions **flood the bar** with a quantized, dithered background wash in the action's color that pulses and decays — fan‑out is cyan, commits green, deploys indigo, edits amber, web research violet, and safety blocks fire red *from the guard itself*, so even a denied action is visible. Washes last `SUPERBOOST_FX_TTL` seconds (default 7). It's all done with zero‑width ANSI color on plain‑ASCII glyphs, so it never corrupts the terminal layout (a hard‑won lesson), and `SUPERBOOST_STATUSLINE_PLAIN=1` reverts to pure ASCII if you ever want it. (One macOS quirk: if the terminal window is fully covered, App Nap pauses redraws, so short‑lived washes can pass unseen — they resume the moment the window is visible.)

### Smart model tiering — pay for judgment, not grep
HYVES CODE's guidance tiers work across models: `fable` for orchestration, synthesis, and judgment; `sonnet` for implementation; `haiku` for cheap read‑only exploration. Cheap explorers + Sonnet workers + one Fable synthesizer gets you near‑frontier quality at a fraction of an all‑Fable bill — and it keeps the expensive model off mechanical work.

---

## Why it's special

1. **Enforce with hooks, don't narrate with ceremony.** HYVES CODE doesn't ask the model to *remember* to be safe or efficient — it wires those behaviors into the harness where they can't be skipped, and keeps the model focused on your task instead of on rituals.
2. **It scales to *your* machine.** The RAM number isn't just a HUD stat — it's a budget the orchestrator acts on. More parallelism when you can afford it, none when you can't.
3. **It's grounded in verified facts, not vibes.** The Fable‑5 tuning comes from a fact‑checked research pass against Anthropic's own docs, shipped alongside the config so you can audit every claim.
4. **It's transparent and recoverable.** Everything is plain shell + Markdown in one git repo. No binary, no daemon, no telemetry. Read it, fork it, change it.

---

## How it makes Fable better in a Claude Code terminal

| Fable 5 trait | Without HYVES CODE | With HYVES CODE |
|---|---|---|
| Dependable async sub‑agents | Fans out, but blind to your RAM | Sizes fan‑out to a live RAM budget — wide when you can, solo when you can't |
| Long, minutes‑long autonomous turns | Can drift, over‑build, or fabricate progress | Doctrine keeps it on‑rails: outcome‑first, no tidying, grounded progress, memory surface |
| Safety classifier refusals | Look like a mysterious failure | Understood as a known mode with automatic Opus fallback |
| ~2× Opus pricing | Runs everything on Fable | Tiers mechanical work down to Sonnet/Haiku |
| Fast auto‑mode | Fast but exposed | Fast *and* guarded against catastrophic actions |
| Plain terminal | Monochrome, opaque | Colorized HUD + action effects you can read at a glance |

---

## Quick start

HYVES CODE lives in `~/.claude`, which Claude Code already reads. Clone it there (or copy the files in), then start a fresh session:

```bash
# back up an existing config first if you have one
git clone https://github.com/frogody/hyves-code.git ~/.claude
~/.claude/install.sh   # verify prereqs, bless checksums, self-test — ends with the HYVES boot cinema
claude                 # opens with the HYVES CODE V5 boot banner, colorized HUD, Fable 5 default
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

## What's new in v5.4.1 — quiet by default

User feedback on 5.4.0: *"it looks like a circus."* Correct. The steady-state bar now renders **neutral slate unless something needs you**: single-hue RAM bar (amber ≥75%, red ≥85%), neutral readouts until pressure, desaturated churn, gold *text* instead of a gold slab for the model chip. Color belongs to events (washes) and alerts (`200K+`, ctx ≥85%, `tight`/`solo`) — and now it's the exception, so it reads. Measured: 28 → 11 distinct colors in a steady-state render.

**v5.4.2 adds the wash dial:** `SUPERBOOST_FX_INTENSITY=low` keeps every event visible at ~half the luminance (0.48× measured); `off` drops the canvas wash entirely and keeps the label chip. The shipped `settings.json` now sets `low` out of the box (the script default without the env var remains `normal`).

---

## What's new in v5.4.0 "Radar" — it taps your shoulder, watches all three budgets, and knows what you spent

**Attention pushes.** The two moments a terminal can't carry now arrive as native macOS notifications: **"Claude needs you"** when a session is blocked on a permission prompt or your input (with the message and project name), and **"Claude finished"** when a turn ran long while you were in another app. Smart by default: suppressed while you're looking at a terminal, rate-limited to one per 90s, `SUPERBOOST_PUSH=0` to disable, `=2` to force. This closes the App Nap gap — the pink NEEDS-YOU wash pauses exactly when the window is hidden, which is exactly when you need the tap.

**Three budgets, one loop.** RAM already had a real feedback loop (probe → budget in context → spawn guard). Now the other two budgets you live under get the same treatment, riding the existing live-budget hook with the same zero-ceremony contract (one line per threshold crossing, hysteresis, silence otherwise):
- **Rate-limit budget** — 5h window ≥80% → Claude is told to tier down to `sonnet`/`haiku` sub-agents, narrow fan-out, and batch work *before* a hard rate stop interrupts the task. A `7d N%` weekly chip appears on the bar only when ≥70%.
- **Context budget** — window ≥80% → checkpoint state to memory, delegate exploration to sub-agents, `/compact` at a natural boundary — before compaction chooses the boundary for you.

**`hyves` — one command for the whole layer.**
```bash
alias hyves=~/.claude/hooks/hyves.sh
hyves            # boot mark + live budgets + version
hyves doctor     # full self-test (add --full to run both regression suites)
hyves stats 14   # what did the last two weeks cost, per day and per project?
hyves demo       # cycle every FX wash in your statusline
hyves update     # git pull --ff-only + re-bless + self-test
```
`hyves stats` reads a local cost ledger that fills automatically as sessions end (`logs/cost-ledger.tsv` — plain TSV, no telemetry, yours).

**Roadmap** (next candidates, in value order): Linux `notify-send` pushes · a session-start "update available" check (cached, offline-safe) · per-project HYVES profiles · rate-budget-aware auto-tiering hints in the Agent/Workflow router.

---

## What's new in v5.3.0 "Instrument" — one grammar, whole-lifecycle FX, hardened probes

**The bar is now a designed instrument, not a row of accumulated widgets.** v5.3 commits to one visual grammar and enforces it in code and tests (CLAUDE.md §11 is the law):

- **Hue families mean exactly one thing** — violet/gold=identity, green=confirmed, amber=caution/change, red=failed, cyan=parallelism, blue=information work, indigo=shipping, pink=needs-you, slate=neutral. Two effects were recolored to obey it: `search` left violet (identity's family) for sky-blue, `think` left teal (too close to parallelism cyan) for deep blue.
- **Role ordering** — identity → workspace (dir, churn) → machine (RAM, `fanout~N`) → session budget (ctx, `200K+`, 5h, cost) → activity, with the FX wash + label pinned at the right edge where the eye checks "what is it doing now." Three emphasis tiers only: solid chip > tinted readout > dim context. ctx ≥ 85% escalates to a solid red alert chip.

**FX now cover the whole session lifecycle, not just five tool events:**

- `turn` (WORKING, blue, 3s) at prompt submit · `join` (cyan) when a sub-agent finishes · **pink `attn` (NEEDS YOU, 45s)** when Claude is blocked on a permission prompt or your input — the highest-signal effect on the bar · amber `compact` before context compaction · hard-red `error` when a tool itself breaks (distinct from a red FAIL verdict; benign Bash failures like `grep` exit 1 stay silent, riding the `PostToolUseFailure` event that current Claude Code uses for failures).
- **Long-turn heartbeat** — when an effect expires mid-turn, a faint drifting slate shimmer keeps the canvas visibly alive; it never fires after `done`/`attn`, and caps at 15 minutes.
- **Session-scoped, atomic FX state** — hooks key state by `session_id` (`state.<sid8>`), so concurrent sessions no longer clobber each other's washes and SessionEnd clears only its own file; every write is tmp+rename atomic (the old truncating write tore ~15% of concurrent statusline reads).
- `statusLine.refreshInterval: 1` keeps motion and the attn wash alive while the session idles — event-driven renders used to stop exactly when Claude was waiting on you.

**Review-and-fix pass (adversarially verified, 17 confirmed defects):** the macOS swap probe parsed the *word* "used" (check never fired) while the Linux path summed *free* swap (would have permanently blocked spawns); `bc` emitted `.5` — invalid JSON that made the resource guard **fail open at exactly the low-RAM moment it guards**; a dangling `--min-agents` looped forever; a stale process-count check hard-blocked spawns on busy-but-healthy machines; non-ASCII model names and non-integer `COLUMNS` broke the width law; comma-decimal locales broke `printf`; malformed FX state leaked stderr ~3×/sec; `install.sh` had version drift; plus flaky/hair-trigger test windows. All fixed and pinned by 15 new regression checks (verify.sh: 55 checks; deepcap: heartbeat frame-capture suite).

---

## What's new in v5.2.2 — a wash you can actually see

The FX wash was too timid to work as *visual confirmation* (screenshot-verified on a ~250-column terminal): the `g^1.5` distance falloff left the far half of the canvas black even at full strength, and the decay curve was near-black by mid-life while the label chip stayed lit — so a commit glanced at 5 seconds late read as "label, no confirmation."

- **Floored falloff** — `base = 0.35 + 0.65·g^1.5`: every canvas cell participates, still brightest at the label.
- **Hold-then-ease decay** — full strength for the first 35% of the TTL, then smoothstep to zero at TTL (still strictly falling, so the decay-to-zero verdict holds).
- **Punchier alpha levels** — 18/36/56/80% → 20/40/62/82%.
- Measured at 250 columns: **100% of the canvas lit for the first 2s** (was: left two-thirds black), 80% at 4s, 55% at 5s (was: black), fully dark by TTL. `deepcap.py` now enforces ≥90% fresh-wash coverage as a regression check.

---

## What's new in v5.2.1 (rebrand + regression pass, frame-capture verified)

- **HYVES CODE is the name.** The repo is now [`frogody/hyves-code`](https://github.com/frogody/hyves-code) (GitHub redirects the old `superboost-v5` URLs), the docs and installer say HYVES CODE, and the context sentinel is `HYVES CODE V5 ACTIVE`. Internal script filenames and `SUPERBOOST_*` env vars are unchanged — no rewiring on upgrade.
- **Visible boot mark.** Each new session now *opens with a two-line HYVES CODE banner* (self-test result, free RAM, health, fan-out posture) rendered by the model from the SessionStart hook's context — the boot cinema itself stays installer-only, since hook stdout can never paint the terminal.

Every claim below was verified from captured statusline frames (~3fps across the full 7s effect life) and a PTY boot-cinema capture — not by eyeballing.

- **FX canvas floor** — the v5.2 density chips had quietly starved the animation canvas to **9 cells** at a 150-column terminal, turning the scanner and sweep into unreadable mush. The statusline now guarantees an **18-cell FX stage**, shedding statically (RAM bar shrinks → churn chip → dir chip) so the layout never shifts mid-effect. Measured after: scanner bounces full-range `1→21→1`, moving in 11/11 frames with zero freezes; commit sweep monotonic `1→…→20` across its 3s travel.
- **Float emit epoch** — `superboost-fx.sh` stamped effects with integer `date +%s`, so every animation phase started up to 1s late and the commit sweep could lose a third of its travel. Effects now carry a float epoch (perl `Time::HiRes`, integer fallback).
- **Crisper heads** — ambient glow dims to 35% (was 45%) while a scanner/sweep head travels.
- **Deep test suite** — new `tests/deepcap.py` verifies the width law, decay-to-zero, sweep monotonicity, and scanner glide from frame data; `tests/verify.sh` grew canvas-floor and float-epoch checks; `tests/fxcap.py`'s wash detection is now label-anchored (the RAM bar's left cells are literally commit-green and used to masquerade as the wash). Render stays ~57ms against the 80ms budget.

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
| `tests/verify.sh` | Quick regression suite (~15s): hook syntax, bindings, banner, 40‑case guard matrix, statusline width/chips, FX classification, live‑budget gating, boot. |
| `tests/deepcap.py` · `fxcap.py` · `ansi2json.py` | Deep animation verification: frame captures at ~3fps proving sweep monotonicity, scanner glide, decay‑to‑zero, the width law, and the boot decrypt progression. |

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
*ISYNCSO · github.com/frogody/hyves-code*
