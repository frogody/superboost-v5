# HYVES CODE V5 (v5.4.3) — Global Configuration (tuned for Claude Fable 5)

Everything in this file is part of **HYVES CODE V5** (Holistic Yield & Validation Engines, by ISYNCSO — formerly "Superboost"; the hook scripts, env vars, and internal identifiers keep the historical `superboost-` prefix so nothing rewires). It activates when the SessionStart hook (`~/.claude/hooks/superboost-banner.sh`) fires — you'll see **"HYVES CODE V5 ACTIVE"** in your system context.

**Activation check:** If your system context contains "HYVES CODE V5 ACTIVE" (or the pre-rebrand "SUPERBOOST V5 ACTIVE"), these rules apply. If it contains neither, HYVES CODE is not installed and you should IGNORE everything below.

**What v5 is:** v4's philosophy — *enforce with hooks, don't narrate with ceremony; lean on the native harness (Workflow tool, agent teams) over hand-rolled orchestration* — retuned for **Claude Fable 5** as the default model, plus two new capabilities: **RAM-scaled parallelism** (size fan-out to free memory, §10) and a **colored terminal FX layer** (§11). The default model is `fable[1m]` with an `availableModels` allowlist, so if Fable 5 isn't accessible Claude Code degrades to Opus 4.8 with a warning rather than failing. **v5.2 "Hyves" adds:** a LIVE parallelism budget (re-injected per turn the moment the posture changes, §10), outcome-aware FX (test/build results wash the bar PASS-green/FAIL-red, §11), event-typed statusline motion, and the `hyves-boot.sh` decrypt boot cinema for installer moments. **v5.2.1 (frame-capture verified):** float animation clock end-to-end (fx.sh emits a float epoch — integer truncation started phases up to 1s late), a guaranteed ≥18-cell FX stage at common widths (density chips shed statically so motion never turns to mush and the layout never shifts mid-effect), and a committed regression harness (`tests/verify.sh` quick suite + `tests/deepcap.py` deep animation captures). **v5.3 "Instrument" adds:** one enforced visual grammar for the whole bar (hue families, role order, emphasis tiers — §11), lifecycle FX across the entire session (turn-start, sub-agent join, waiting-on-you pink attn, compaction warning, tool-error, long-turn heartbeat), session-scoped atomic FX state (concurrent sessions no longer clobber each other), and a hardened probe/guard layer (swap parse, invalid-JSON, locale, width-law edge cases — 17 confirmed defects fixed). **v5.4 "Radar" adds:** attention pushes (native macOS notifications when Claude is blocked on YOU or finishes a long turn while you're elsewhere), the **three budgets** (rate-limit and context-window join RAM with real feedback loops — threshold crossings inject one actionable line via the live-budget hook, §10), a local cost ledger with `hyves stats`, and the `hyves` CLI (§11).

**Prerequisites (verified):** Fable 5 needs **Claude Code ≥ v2.1.170** (older versions can't show or select it — `claude update`), is **never an account default** (you opt in via the `model` setting, `/model fable`, or the **`best`** alias = "Fable 5 where the org has access, else the latest Opus" — `best` is the cleanest graceful-degradation selector if you'd rather not pin `fable`), and is **not available under zero data retention (ZDR)**. If any of these don't hold, the `availableModels` allowlist quietly falls back to Opus.

---

## 1. Boot check + boot mark

The SessionStart hook runs an install self-test (scripts present + executable, settings wired, checksums un-drifted) and emits the current **parallelism budget** (§10) into context, along with a **two-line HYVES CODE banner block**. **Open your FIRST reply of the session with that banner, verbatim, in a fenced code block** (v5.2.1, user-requested — this is the one deliberate piece of boot ceremony), then proceed with the user's request. If the self-test reports FAIL/WARN, also surface those issues so the user can repair the install, then continue. Render the banner exactly once per session — never repeat it on later turns.

---

## 2. Auto-Router (solo vs. team) — RAM-aware

Before a non-trivial task, quickly (internally) decide solo vs. parallel. **Default to solo.** Fan out only when there are genuinely independent workstreams *and* the work is large enough to pay for coordination — **and** the parallelism budget (§10) says there's RAM for it.

- 1 independent stream, or < ~20 min of work → **solo**.
- 2+ genuinely independent streams, non-trivial, budget mode `balanced`/`wide` → consider the **Workflow tool** (§4), sized to the budget's `workflow_width`.
- Big *sequential* task → still solo. Size is not a reason to fan out; independence is.

You don't need to print a routing decision every time. Make the call and go; mention it only when you actually spawn parallel work.

---

## 3. Resource awareness

`resource-guard.sh` (PreToolUse on Agent/TeamCreate/Task/Workflow) blocks a spawn only when the machine genuinely can't take it (swap / low RAM / memory pressure). It's a **performance** guard, not a security one, and fails open on error so it can never lock you out — it just prevents thrashing this laptop during heavy fan-out.

Manual reads: `~/.claude/hooks/resource-check.sh` (`--quiet` for JSON) · `~/.claude/hooks/superboost-parallelism.sh` (the actionable fan-out budget, §10).

---

## 4. Orchestration → use the native Workflow tool

For multi-agent work, use the **Workflow tool** — it handles concurrency capping (min(16, cores−2)), a shared token budget, resume, and a live `/workflows` progress UI. Don't hand-roll wave loops, rate-limit "zones", or progress bars. Patterns worth composing: pipeline fan-out, adversarial verify, judge panel, MoA (independent solvers → synthesizer), loop-until-dry.

- Cap Workflow concurrency at the parallelism budget's `workflow_width` (§10), not just the harness default.
- **MoA / synthesis** and **model-tiering** have no native auto-equivalent — those are where HYVES CODE adds value (§5).
- For code-quality review of a diff, prefer `/code-review` (or `/code-review ultra`) over a hand-built judge.
- Sub-agents do **not** inherit this file. Put everything they need directly in their prompt (clear task, success criteria, constraints, relevant paths, and the *Why* — see §9). That discipline matters; a printed ceremony announcing it does not.

---

## 5. Model Tiering (alias-only, Fable-first)

The Agent/Workflow `model` option accepts the aliases **`fable | opus | sonnet | haiku`** only — you cannot pin a minor version, so never write "5.x"/"4.x" in guidance (it drifts and can't be passed).

| Role | Alias | Why |
|------|-------|-----|
| Orchestrator / synthesizer / judge | `fable` | Merging + judgment + long-horizon planning need the strongest reasoning — Fable 5 is the frontier tier |
| Implementation worker | `sonnet` | ~90% of frontier quality on scoped tasks, far cheaper |
| Read-only explorer / grep / file-hunt | `haiku` | Cheapest; ideal for mechanical "find X" work |

Rule of thumb: cheap `haiku` explorers + `sonnet` workers + one `fable` synthesizer beats an all-`fable` team on cost for near-identical quality. **Fable 5 costs ~$10/$50 per Mtok (input/output) — 2× Opus 4.8 — so tier deliberately** and don't put `fable` on mechanical work. Omit the override to inherit the session model when unsure.

---

## 6. Safety (enforced, not narrated)

Auto-mode is on (`defaultMode: auto`), so permission prompts are suppressed — safe **because `safety-guard.sh` (PreToolUse on Bash/Write/Edit/MultiEdit) actually blocks the dangerous cases**: `rm -rf` of / or $HOME, disk formatting, fork bombs, `git push --force`, secret exfiltration over the network, and edits to calculator-locked files. Deliberately conservative — ordinary `git push`, deploys, and SQL are allowed.

Still use judgment the hook can't encode:
- **Irreversible / outward-facing actions** (deploys, sending messages/emails, deleting remote branches, publishing) — confirm first unless told to proceed.
- **Secrets** live in the macOS keychain / git-ignored `.env`, referenced by name. Never paste a secret value into a file, a commit, or a sub-agent prompt.
- The config lives in git (`~/.claude`), so your edits are recoverable — but `git push` for it is a deliberate, user-authorized action.

---

## 7. First-boot credentials

User-specific credentials are provisioned **once** and reused. On session start, `superboost-secrets.sh check` reports any *required* credential not yet in the macOS keychain. If you see **"SUPERBOOST FIRST-BOOT SETUP"**:

1. Ask the user for each missing value (one prompt is fine).
2. Store each — never write a secret into a file: `~/.claude/hooks/superboost-secrets.sh set <name> <value>` (or the user runs `set <name>` for a hidden prompt).
3. Confirm with `~/.claude/hooks/superboost-secrets.sh list`.

Retrieve for use by name: `TOKEN=$(~/.claude/hooks/superboost-secrets.sh get supabase-mgmt-token)`. Slots live in `~/.claude/superboost-secrets.json` (git-ignored; names only, never values).

---

## 8. Integrity

Hook scripts are sha256-tracked in `superboost-version.json`. The boot check warns on drift. After intentionally editing a hook, re-seed with `~/.claude/hooks/bless-hooks.sh`. Drift-detection, not tamper-proofing.

Regression suites live in `~/.claude/tests/`: `verify.sh` (quick, ~15s — syntax, bindings, banner, 40-case guard matrix, statusline width/chips, FX classification, budget gating, boot) and `deepcap.py` (~25s — frame-captured animation verification: width law, decay-to-zero, sweep monotonicity, scanner glide). Run both after touching the statusline or FX layer.

---

## 9. Fable-5 doctrine (how to work as Fable 5)

Fable 5 behaves differently from the Opus family. These are the levers that matter (they also apply when you prompt `fable` sub-agents — put the relevant ones in their prompt, since sub-agents don't inherit this file):

- **Thinking is always on (adaptive); depth is set by effort.** There is no `budget_tokens`. Effort is `low → medium → high → xhigh → max`; this config runs `xhigh`. Don't reach for `max` reflexively — it can overthink. For cheap sub-agents, tell them to run lean.
- **Turns are long.** A single hard turn can run many minutes (gather context → build → self-verify). That's expected — don't mistake a long turn for a hang. Structure big work so it can be checked asynchronously.
- **Delegate, and keep working.** Fable 5's parallel sub-agents are dependable. When the budget says `wide`/`balanced` (§10), prefer **delegate-and-keep-working** (async) over spawn-and-block: fan independent subtasks to sub-agents and continue; intervene only if one goes off track. This is the single biggest efficiency win v5 unlocks.
- **State the objective + the *Why*, not step-by-step scripts.** Fable 5 generalizes from goals and over-prescriptive prompts *reduce* its quality. Give the outcome, the reason behind it, and the boundaries — then let it plan.
- **No unrequested tidying at high effort.** At `xhigh` it may refactor/add helpers/over-handle errors beyond the ask. When you want a minimal change, say so: "do the simplest thing that satisfies the goal; no refactors, helpers, or speculative error-handling."
- **Ground progress claims in tool results.** Before reporting something done, point to actual tool output. Don't claim a test passes without the run; if a step was skipped, say so.
- **Verify with fresh eyes — but only where it earns its cost.** Fable 5 self-verifies routine work with little prompting, so skip "remember to test" reminders on normal tasks. For **long or high-risk builds**, spin up a fresh-context verifier sub-agent to audit against the spec/tests rather than self-critiquing — self-critique loops.
- **Memory surface.** Persist lessons to the file-memory at `~/.claude/projects/-Users-godyduinsbergen/memory/` (one fact per file, index in MEMORY.md) — Fable 5 works better when it can write and re-consult notes.
- **Refusals are a known mode, not a bug.** Fable 5 runs safety classifiers (categories include `cyber`, `bio`, `reasoning_extraction`, `frontier_llm`, `null`) that return `stop_reason: "refusal"` as a normal HTTP 200 — often on adjacent-but-benign security/life-sciences work. In Claude Code a flagged cyber/bio turn is **auto-re-run on the default Opus** (Opus 4.8 on the Anthropic API/gateways; Opus 4.7 on AWS) with a transcript notice; in non-interactive/SDK contexts the turn just ends with the refusal. So: if you see a refusal, note it and proceed — don't treat it as a failure or retry blindly. (`reasoning_extraction` fires when a prompt asks the model to reproduce its own internal reasoning in the output — ask for a structured answer instead.)

---

## 10. The three budgets (RAM → fan-out · rate-limit · context) — the efficiency levers

`superboost-parallelism.sh` converts the live RAM probe into an **actionable** budget so you scale agents to the machine — something plain Fable-5-on-Claude-Code does not do:

```
~/.claude/hooks/superboost-parallelism.sh            # human summary
~/.claude/hooks/superboost-parallelism.sh --budget   # JSON {concurrent_agents, workflow_width, mode, ...}
```

- **mode `wide`** (RAM ample, ≥8 agents) → delegate wide and async; set Workflow width to the budget.
- **mode `balanced`** (3–7) → fan out for genuinely independent streams; keep sequential work solo.
- **mode `narrow`/`solo`** (≤2 / can't spawn) → one helper at most, or solo.

The SessionStart banner emits this line into context every session, and the statusline shows it live as `fanout~N`. **v5.2:** a `UserPromptSubmit` hook (`--turn`) re-emits the line into context the moment the mode flips (wide↔balanced↔narrow↔solo) — so the budget in context is never stale; a silent turn means "unchanged". Before a large fan-out, glance at (or re-query) the budget and size the work to it. When RAM is ample, **use it** — wide async delegation is where Fable 5 + HYVES CODE beats Fable 5 alone; when RAM is tight, the guard (§3) and the budget both tell you to stay solo.

**v5.4: rate-limit and context budgets close the loop too.** The statusline stashes this session's live `ctx% / 5h% / 7d% / cost` (`fx/stats.<sid8>`); the same `--turn` hook injects ONE actionable line per threshold crossing, with hysteresis (warn ≥80%, re-arm <70%), silent otherwise:
- **5h window ≥80%** → tier down now: `sonnet`/`haiku` for sub-agents, narrow fan-out, batch related work — a hard rate stop mid-task costs more than slower models do.
- **Context ≥80%** → checkpoint durable state to memory files, delegate exploration to sub-agents (their context is separate), finish or `/compact` at the next natural boundary.
Act on these lines when they appear — they are computed from the live session, not heuristics.

---

## 11. Terminal FX + statusline (one visual grammar — v5.3 LAW)

`superboost-fx.sh` gives the terminal a colored feedback layer without polluting context (it writes a tiny state file, prints nothing; the statusline renders it). Since v5.3 the whole bar obeys **one visual grammar**; any new chip or effect must fit it or change it *here first*.

**Quiet by default (v5.4.1 — the first law):** a healthy value renders NEUTRAL slate. Hue appears only when a state crosses an attention threshold or an event fires. The steady-state bar is calm; color is the exception that carries the signal.

**Hue families (one family = one meaning, everywhere on the bar):**

| Family | Meaning | Where |
|---|---|---|
| violet + gold | IDENTITY | brand + model as bold TEXT on the base strip (Fable=gold, Opus=violet; v5.4.3: no solid identity slabs — solid means "act now"). Never status. |
| green | CONFIRMED EVENTS | `commit` #22c55e, `pass` #4ade80 washes (churn `+N` is desaturated data, not status) |
| amber | CAUTION / CHANGE | RAM ≥75%, ctx ≥60%, `tight~N`, `7d` ≥70%, `edit` #f59e0b, `compact` #fbbf24 |
| red | CRITICAL / FAILED | RAM ≥85%, ctx ≥85% (solid), `200K+`, `solo`, `blocked` #ef4444, `fail` #f87171, `error` #dc2626 |
| cyan | PARALLELISM EVENTS | `fanout` #22d3ee, `join` #67e8f9 washes (the `fanout~N` readout stays neutral until the budget constrains you) |
| blue | INFORMATION WORK | `preflight` #3b82f6, `search` #0ea5e9, `think` #2563eb, `turn` #93c5fd |
| indigo | SHIPPING | `deploy` #6366f1 |
| pink | NEEDS YOU | `attn` #ec4899 — deliberately the only pink anywhere |
| slate | NEUTRAL / HEALTHY | all readouts at rest, RAM bar fill, dir, 5h, cost, `done` #64748b, idle heartbeat |

(v5.4: a `7d N%` weekly-quota chip joins the session-budget group ONLY when ≥70% — amber, red ≥90. A healthy week earns no pixels.)

(v5.3 recolors enforcing this: `search` left violet — violet is identity; `think` left teal — too close to parallelism cyan.) (v5.4.1 "Quiet": the RAM bar dropped its always-on green→amber→red gradient for a single state-chosen hue — neutral / amber ≥75 / red ≥85 — and green/cyan left the steady-state readouts entirely; user feedback: the bar read as a circus.)

**Role order (left → right):** IDENTITY (brand, model+effort) → WORKSPACE (dir, churn) → MACHINE (RAM bar+stats, `fanout~N`) → SESSION BUDGET (ctx%, `200K+`, 5h, cost) → ACTIVITY (FX wash canvas + effect label pinned at the right edge). **Emphasis tiers (exactly three):** SOLID chip (bg+bold — urgent alerts + FX label ONLY; solid means "act now") > TINTED text on the base strip (identity bold, readouts regular) > DIM context (dir). Every chip pads one space each side. ctx ≥ 85% escalates from tinted to a SOLID red alert chip.

**Lifecycle coverage — the bar says what the process is doing at every phase:**

- **Tool events** (PostToolUse): fan-out=cyan, commit=green, deploy=indigo, edit=amber, web-research=sky-blue; test/build/lint/typecheck wash **PASS/FAIL from the actual outcome**. Quiet tools (reads/greps) skip the classifier (~7ms). **v5.3:** failures ride `PostToolUseFailure` — test commands wash FAIL, a broken non-Bash tool washes hard-red ERROR, benign Bash failures (grep exit 1) stay silent. Safety blocks fire red from `safety-guard.sh` itself (a denied call never reaches PostToolUse).
- **Phase events (v5.3):** turn start washes `turn` (WORKING, 3s) via UserPromptSubmit; a finished sub-agent washes `join` via SubagentStop; waiting-on-you (permission prompt / idle / agent-needs-input) washes pink `attn` (45s) via the Notification hook; context compaction washes amber `compact` via PreCompact. SessionEnd still *clears* (a fade would be unseeable — the TUI exits with the session; hygiene wins).
- **Long-turn heartbeat (v5.3):** when an effect expires mid-turn (last event isn't `done`/`attn`), the canvas shows a faint drifting slate shimmer — an active turn is visibly alive without faking an event. Capped at 15 min.
- **Manual** — `~/.claude/hooks/superboost-fx.sh emit preflight` · also `fanout|join|commit|deploy|blocked|edit|search|think|turn|compact|error|attn|done|pass|fail`. Use to mark meaningful phase changes.
- Effects carry **per-event TTLs** (turn=3s, attn=45s, rest 7s); `SUPERBOOST_FX_TTL` overrides for demos. **Intensity dial (v5.4.2):** `SUPERBOOST_FX_INTENSITY` = `normal` | `low` (same full-canvas coverage at ~half the luminance, measured 0.48×) | `off` (no canvas wash/heartbeat; the label chip still names the event). Motion: 1D plasma shimmer, <10% sine pulse (~0.4 Hz, WCAG 2.3.1-safe), Larson scanner on fanout/deploy, one-shot L→R sweep on commit; all motion is a pure function of wall-clock (float epoch), so a paused frame is a valid still. Floored falloff lights the whole canvas; decay holds full strength to 35% of TTL then eases to zero.
- **Session-scoped state (v5.3):** hooks write `~/.claude/fx/state.<sid8>` keyed by their stdin `session_id`; manual emits write the global `state`; the statusline renders whichever record is newest for its own session — concurrent sessions no longer clobber each other's effects, and SessionEnd clears only its own file (stale siblings pruned after 4h). Writes are atomic (tmp+rename) — the old truncating write tore 15% of concurrent reads.
- **Attention pushes (v5.4)** — the two moments the terminal itself cannot carry become native macOS notifications: *Claude needs you* (permission prompt / idle / agent-needs-input, with the message + project dir) and *Claude finished* after a turn ran ≥45s (`SUPERBOOST_PUSH_LONG_TURN_SEC`). Gated: `SUPERBOOST_PUSH=0` disables, 90s rate limit, suppressed while a terminal app is frontmost (`SUPERBOOST_PUSH=2` forces), macOS-only. No extra wiring — rides the Notification/UserPromptSubmit/Stop hooks.
- **Cost ledger + `hyves` CLI (v5.4)** — SessionEnd folds each session's final `cost/dir` snapshot into `~/.claude/logs/cost-ledger.tsv`; `~/.claude/hooks/hyves.sh` is the front door: `hyves status|doctor [--full]|stats [days]|demo|update|version` (alias it: `alias hyves=~/.claude/hooks/hyves.sh`).
- **Boot cinema**: `~/.claude/hooks/hyves-boot.sh` plays an nms-style decrypt reveal of the HYVES CODE logo (alt-screen, synchronized-output frames, live self-test status). Installer/manual use ONLY — never wire it to a session hook: hook stdout lands in model context, and the live TUI owns the terminal.

The statusline is a **full-width HUD painted with truecolor backgrounds** (chips per the grammar above; active effects flood the canvas with a quantized, dithered wash). The FX canvas is a guaranteed stage of ≥18 cells — when a terminal is too narrow, the RAM bar shrinks and then the churn/dir chips are shed *statically* (never mid-effect). Visible glyphs stay pure ASCII with **ANSI SGR only (fg + bg), zero wide glyphs**, so the TUI width calc stays exact (v4's hard-won lesson; doubly justified now that Claude Code wraps renders in DECSET 2026 synchronized output — never emit cursor control/OSC/sync sequences from the statusline). The script runs under `LC_ALL=C` (comma-decimal locales broke `printf`), sanitizes every JSON-sourced string to printable ASCII, and validates every state-file field before arithmetic. `statusLine.refreshInterval: 1` keeps FX motion and the attn wash alive while the session idles (event-driven renders stop exactly when you're being waited on). If any terminal miscounts, `SUPERBOOST_STATUSLINE_PLAIN=1` reverts to pure ASCII.

---

*HYVES CODE V5 (v5.4.3) — formerly Superboost · ISYNCSO · github.com/frogody/hyves-code*
