# Superboost v5.1 — Global Configuration (tuned for Claude Fable 5)

Everything in this file is part of Superboost v5.1. It activates when the SessionStart hook (`~/.claude/hooks/superboost-banner.sh`) fires — you'll see **"SUPERBOOST V5 ACTIVE"** in your system context.

**Activation check:** If your system context contains "SUPERBOOST V5 ACTIVE", these rules apply. If it does not, Superboost is not installed and you should IGNORE everything below.

**What v5 is:** v4's philosophy — *enforce with hooks, don't narrate with ceremony; lean on the native harness (Workflow tool, agent teams) over hand-rolled orchestration* — retuned for **Claude Fable 5** as the default model, plus two new capabilities: **RAM-scaled parallelism** (size fan-out to free memory, §10) and a **colored terminal FX layer** (§11). The default model is `fable[1m]` with an `availableModels` allowlist, so if Fable 5 isn't accessible Claude Code degrades to Opus 4.8 with a warning rather than failing.

**Prerequisites (verified):** Fable 5 needs **Claude Code ≥ v2.1.170** (older versions can't show or select it — `claude update`), is **never an account default** (you opt in via the `model` setting, `/model fable`, or the **`best`** alias = "Fable 5 where the org has access, else the latest Opus" — `best` is the cleanest graceful-degradation selector if you'd rather not pin `fable`), and is **not available under zero data retention (ZDR)**. If any of these don't hold, the `availableModels` allowlist quietly falls back to Opus.

---

## 1. Boot check (silent)

The SessionStart hook runs an install self-test (scripts present + executable, settings wired, checksums un-drifted) **silently**, and emits the current **parallelism budget** (§10) into context. On a clean boot it says so in one line — **do not render a banner**. Only if the self-test reports FAIL/WARN, surface those issues to the user so they can repair the install, then continue.

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
- **MoA / synthesis** and **model-tiering** have no native auto-equivalent — those are where Superboost adds value (§5).
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

## 10. Parallelism budget (RAM → fan-out) — the v5 efficiency lever

`superboost-parallelism.sh` converts the live RAM probe into an **actionable** budget so you scale agents to the machine — something plain Fable-5-on-Claude-Code does not do:

```
~/.claude/hooks/superboost-parallelism.sh            # human summary
~/.claude/hooks/superboost-parallelism.sh --budget   # JSON {concurrent_agents, workflow_width, mode, ...}
```

- **mode `wide`** (RAM ample, ≥8 agents) → delegate wide and async; set Workflow width to the budget.
- **mode `balanced`** (3–7) → fan out for genuinely independent streams; keep sequential work solo.
- **mode `narrow`/`solo`** (≤2 / can't spawn) → one helper at most, or solo.

The SessionStart banner emits this line into context every session, and the statusline shows it live as `fanout~N`. Before a large fan-out, glance at (or re-query) the budget and size the work to it. When RAM is ample, **use it** — wide async delegation is where Fable 5 + Superboost beats Fable 5 alone; when RAM is tight, the guard (§3) and the budget both tell you to stay solo.

---

## 11. Terminal FX (colored activity effects)

`superboost-fx.sh` gives the terminal a colored feedback layer without polluting context (it writes a tiny state file, prints nothing; the statusline renders it):

- **Automatic** (PostToolUse): notable actions light up — fan-out=cyan, commit=green, deploy=indigo, edit=amber, web-research=violet. Safety blocks fire red from `safety-guard.sh` itself (a denied call never reaches PostToolUse). Quiet tools (reads/greps) don't flash.
- **Manual** — trigger an effect explicitly from a skill/command/step:
  `~/.claude/hooks/superboost-fx.sh emit preflight`   (blue) · also `fanout|commit|deploy|blocked|edit|search|think|done`.
  Use this to mark meaningful phase changes (e.g. when a preflight/research phase starts).
- Effects last `SUPERBOOST_FX_TTL` seconds (default 7), pulsing and decaying as they age.

The statusline (v5.1) is a **full-width HUD painted with truecolor backgrounds**: brand + model/effort chips (gold for Fable), a wide green→amber→red RAM gradient bar, ctx-used %, `fanout~N`, 5h rate use, session cost — and an active effect floods the free canvas with a quantized, dithered background wash in its color. Visible glyphs stay pure ASCII with **ANSI SGR only (fg + bg), zero wide glyphs**, so the TUI width calc stays exact (v4's hard-won lesson). If any terminal miscounts, `SUPERBOOST_STATUSLINE_PLAIN=1` reverts to pure ASCII.

---

*Superboost v5.1 "Fable" · ISYNCSO · github.com/frogody/superboost-v5*
