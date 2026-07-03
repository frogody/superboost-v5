# Superboost v5 — Claude Fable 5 Expertise Report

*Deep-research brief backing the v5 "Fable" retune. 5 search angles → 21 sources fetched → 102 claims → 25 adversarially verified (3 independent skeptic votes each) → 11 synthesized findings. **25/25 confirmed, 0 killed**, all high-confidence against first-party Anthropic docs (platform.claude.com, code.claude.com, anthropic.com) with third-party corroboration. Verified July 2026.*

> Synthesis note: this report was produced by an Opus 4.8 harness from verified claims, not first-hand Fable 5 behavior.

---

## 1. What Claude Fable 5 is

| Property | Value |
|---|---|
| Model id | `claude-fable-5` (GA 2026-06-09) |
| Context window | **1M tokens by default** (the max *is* the default; no beta header) |
| Max output | **128K tokens** / request |
| Pricing | **$10 / MTok input · $50 / MTok output**; 90% prompt-cache discount (reads $1/MTok); **no long-context surcharge** (a 900k request bills at the same per-token rate as a 9k one) |
| Thinking | **Always-on adaptive only.** No manual `budget_tokens`; `thinking:{type:"disabled"}` is rejected. Thinking tokens are a subset of `max_tokens`, billed as output, allocated dynamically. |
| Effort | `low · medium · high · xhigh · max` — **default `high`**. In Claude Code, `MAX_THINKING_TOKENS=0`, `alwaysThinkingEnabled`, and `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` have **no effect** on Fable 5. |
| Sibling | **Claude Mythos 5** — same capabilities, *without* the safety classifiers (Project Glasswing only). |
| Data retention | **Not available under zero data retention (ZDR).** |

## 2. The safety classifier & refusal machinery (the operationally important part)

Fable 5 runs built-in classifiers over the request. When one declines, the Messages API returns a **normal HTTP 200** (not an error) with `stop_reason: "refusal"` and a `stop_details.category`:

- Categories include **`cyber`** (malware/exploit dev — *benign cybersecurity work can also trip it*), **`bio`** (life-sciences lab methods), **`reasoning_extraction`** (asking the model to reproduce its internal reasoning in the response), plus **`frontier_llm`** and **`null`**. The set is **not** limited to three.
- **Auto-fallback:** in Claude Code, a flagged cyber/bio request is **re-run on the default Opus model — Opus 4.8** on the Anthropic API & LLM gateways, **Opus 4.7** on Claude Platform on AWS — with a transcript notice. In **non-interactive / SDK** contexts that can't prompt, the turn just **ends with a refusal**.
- **Branch on `stop_reason`, never on `stop_details`** — `stop_details` is informational and can be `null` even on a refusal.
- Server-side recovery: the beta `fallbacks` parameter (header `server-side-fallback-2026-06-01`, e.g. target `claude-opus-4-8`), SDK refusal-fallback middleware, or manual retry on another model. (Beta; unavailable on Batches, Bedrock, GCP, Foundry.)

## 3. Claude Code integration

- **Requires Claude Code ≥ v2.1.170** — older versions don't show Fable 5 in the picker and can't select it (`claude update`).
- **Never an account default.** Select it via `/model fable`, a `model` setting (what Superboost v5 does: `model: fable[1m]`), or the **`best` alias** = "Fable 5 where the org has access, otherwise the latest Opus." `best` is the cleanest graceful-degradation selector.
- **Keybindings (rebindable defaults):** `Meta+T` toggle thinking · `Meta+P` model picker · `Meta+O` fast mode. Inside the picker: `Left`/`Right` decrease/increase effort, `s` = apply to this session only. (`meta` = Option on macOS, Alt on Windows/Linux.)

## 4. How to prompt Fable 5 (Anthropic's own guidance)

- **Describe the outcome, not the steps** — hand it the result you want and let it plan the path.
- **Hand it ambiguous / investigation-heavy work** — root-cause, outage debugging, architecture decisions — where the extra investigation and verification pay off.
- **Skip verification reminders for routine work** — it self-verifies with less prompting; "remember to test" is usually unnecessary. (Complementary, not contradictory, to using a **fresh-context verifier sub-agent for long / high-risk builds**.)
- **Size up larger tasks** — give it work you'd normally break into pieces; it holds long sessions ("larger than a single sitting") without losing the thread.

## 5. What v5 does about each (retune → implementation)

| Finding | v5 action |
|---|---|
| `claude-fable-5`, 1M default, $10/$50, ~2× Opus | Default `model: fable[1m]`; tiering flags the cost so `fable` isn't wasted on mechanical work (`CLAUDE.md §5`) |
| Always-on adaptive; effort is the only depth knob | No manual thinking-budget machinery anywhere; effort left at the session level (`xhigh` for this coding-agent config; `high` is the model default) |
| Refusal = HTTP 200 + Opus fallback | `CLAUDE.md §9` documents it so a refusal is understood, not mistaken for a failure |
| Not default; needs v2.1.170; `best` alias | `availableModels` allowlist degrades a blocked default to Opus with a warning; prerequisite + `best` documented |
| Describe-outcome / ambiguous / self-verify / long tasks | `CLAUDE.md §9` doctrine: state objective + the *Why*, delegate async, no-tidying at high effort, grounded progress, verifier for long builds, memory surface |
| RAM not used to scale fan-out | `superboost-parallelism.sh` turns the RAM probe into a fan-out budget (§10) — the standout add |

## 6. Open questions (unverified — treat as best-practice, not doc-backed)

- Exact interaction of `availableModels` / `opusplan` with `best` and whether Fable can be added/removed from the allowlist at runtime.
- The precise `/config key=value` path to set model/effort non-interactively (settings.json `model`/`effort` is confirmed to work; a `/config` equivalent was not verified).
- The task-size/risk threshold at which an external verifier beats Fable's self-verification.
- Official guidance on scope-constraining at `xhigh`/`max` effort and on a memory-file convention (Superboost's §9 memory + no-tidying guidance is community/observed best-practice).

## 7. Primary sources

- introducing-claude-fable-5-and-mythos-5 · anthropic.com/claude/fable · build-with-claude/context-windows
- build-with-claude/refusals-and-fallback · handling-stop-reasons · handle-streaming-refusals · cookbook/fable-5-fallback-billing-guide
- code.claude.com/docs/en/model-config · /keybindings · build-with-claude/prompt-engineering/prompting-claude-fable-5 · about-claude/pricing

*ISYNCSO · Superboost v5.0 "Fable"*
