# Guardian → Hermes Migration — Bootstrap Prompt

Paste the block below into a fresh Claude Code session that has **`pfeff/guardian`** attached
as a source (and push access to create a new repo, or create the repo yourself first). It is
self-contained — it does not require reading any other repo.

---

```
You are setting up a dedicated "Guardian" agent on the Hermes Agent harness by porting the
rules and work processes from the pfeff/guardian repo. This is a CLEAN DISTILLATION, not a
copy — the explicit goal is to keep the genuine requirements and drop the cruft.

## Context (decided in a prior session)

I'm moving my personal "Guardian" cadence/goals loop OFF Claude Code and onto Hermes Agent
(Nous Research's open-source, model-agnostic personal-agent harness — NOT the Hermes LLMs,
NOT any internal hermes_mcp). Reasons Claude Code failed as the harness, in priority order:
  1. It edits/modifies the loop instead of EXECUTING it (a failure to do the work).
  2. It misreads my instructions / misunderstands intent.
  3. It needs too much handholding to run unattended.
  4. It serializes work that should run in parallel.

Hermes was chosen because it fits a recurring, unattended, personal-assistant loop:
  - Cron-native scheduler (gateway daemon; jobs in ~/.hermes/cron/jobs.json; natural language
    or cron syntax; runs each due job in an isolated session TO COMPLETION; delivers output).
  - SKILL.md skills (YAML frontmatter, agentskills.io-compatible) in ~/.hermes/skills/. My
    existing Obsidian "cadence-goals" skill ports as-is.
  - Runs locally against my Obsidian vault as files (vault stays source of truth).
  - Model-agnostic hot-swap across providers.
  - Messaging gateway (~20 channels incl. Telegram) = mobile remote control + cron delivery.
  - CRUCIAL distinction it gets right: it separates FAITHFUL EXECUTION (a tick runs its skill
    to completion) from SELF-IMPROVEMENT (skill changes come from a separate background review
    AFTER the turn, gateable via `skills.write_approval: true`, staged in ~/.hermes/pending/
    skills/ for my approval). Self-improving execution is DESIRABLE. "Editing the loop instead
    of executing it" is the failure. Do not confuse the two.

Billing decision: direct provider API keys — Anthropic + OpenAI + xAI — registered via
`hermes model` (cheap model for routine ticks, strong model for weekly synthesis), with a
hard spend limit set on each provider console. (OpenRouter and Nous Portal are deferred
alternatives, not for now.)

## Your task

1. READ all of pfeff/guardian. Inventory everything: rules, work processes, cadence
   definitions (annual/quarterly/monthly/weekly/daily OODA slices), prompts, automation,
   note conventions, CLAUDE.md/AGENTS.md, any GOAL/process docs.

2. INFER the existing requirements set from what's actually there — do NOT define requirements
   from scratch. Present the inferred requirements set to me for review.

3. DISTILL AGGRESSIVELY. Cut cruft and hand me a "KEPT / REMOVED + WHY" log. Two cruft classes:
     - general accumulation: stale, duplicated, superseded, or dead content;
     - intent-drift: artifacts a prior agent created that don't match what I actually wanted.
   I review and confirm the cuts BEFORE anything is discarded or written. Deciding rule-vs-
   cruft is an intent judgment — when unsure, ask me; never guess. (My whole complaint is
   models misreading intent — do not reproduce that here.)

4. On my confirmation, refine the kept set into a Hermes-appropriate requirements set, then
   PORT it to Hermes constructs:
     - SKILL.md skill(s) encoding the Guardian rules/processes (clean, minimal, each artifact
       traceable to a real requirement);
     - cron job spec(s) for the cadence ticks (daily OODA, weekly, etc.);
     - a MEMORY.md seed of durable Guardian facts;
     - config notes (direct-key providers, a Telegram delivery channel, write_approval gate on
       for the first weeks);
     - a validation step (self-verify / a Light-Validation checklist) as each tick's FINAL
       step, since Hermes has no native LLM-judge.

5. OUTPUT to a NEW dedicated repo (suggested: pfeff/guardian-hermes). Include a README that
   documents the agent, the cron cadence, and the setup steps.

## Working guardrails (these encode why I'm switching — follow them literally)

  - Execute, don't edit: when told to run something, run it. Never substitute editing the
    loop/machinery for doing the work.
  - Minimal and traceable: prefer the smallest clean set; every artifact must map to a
    confirmed requirement. Do not re-accumulate cruft.
  - Intent is the source of truth: surface judgment calls and confirm rather than guessing.
  - Faithful execution (good) is distinct from modifying-the-loop-instead-of-executing (bad).

## Optional reference (only if you also attach pfeff/claude-skills)

The full analysis-of-alternatives that led here — evaluation criteria C1–C10, the harness
comparison (Hermes vs OpenClaw vs coding CLIs), billing/model-portability, remote-control,
and the spike plan — is at docs/guardian-loop-harness-shortlist.md on branch
claude/guardian-loop-alternatives-gsl5yd. Not required; the context above is sufficient.

Start with step 1 and report the inferred requirements set before distilling.
```

---

## Evaluation criteria referenced (C1–C10), for continuity

| # | Criterion | Note |
|---|-----------|------|
| C1 | Faithful execution | #1 pain. Execute the tick; don't edit the loop instead. |
| C2 | Instruction fidelity | Don't misread the spec. |
| C3 | Autonomy | Run unattended without handholding. |
| C4 | Parallel dispatch | Don't serialize the 3–4 active lanes. |
| C5 | Cost ceiling | Direct-key spend limits per provider. |
| C6 | Low-maintenance | Turnkey over bespoke. |
| C7 | KB compatibility | Local Obsidian vault; SKILL.md ports as-is. |
| C8 | Billing + model portability | Direct keys now; hot-swap cheap/strong models. |
| C9 | Remote control | Mobile-first (Telegram), web second. |
| C10 | Controlled self-improvement *(desired)* | Learn from successful runs; gateable. |
