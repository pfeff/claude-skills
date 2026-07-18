---
name: verify-inherited-premise
description: >-
  Use when dispatching a task (or about to act) whose premise comes from an
  inherited claim rather than direct observation of the live system — a
  handoff/HANDOFF.md doc, an inbox or spec artifact, a skill's own documented
  schema/paths/behavior, a prior agent's summary, or a PR-body assertion. Adds
  a fidelity guard: verify the load-bearing claim against reality FIRST, and
  STOP-and-report if it's false instead of building on it or fabricating to
  fill the gap. Fires on "verify the premise", "add a fidelity guard", "don't
  trust the doc", or any dispatch whose success hinges on a claim not yet
  checked against the actual system.
version: 1.0.0
allowed-tools: Agent, Read, Grep, Glob, Bash
---

# verify-inherited-premise

Inherited claims drift from reality. A handoff says "the PR disclosed X"; the PR doesn't. A skill documents a vault schema that doesn't exist. A worker reports "resolved" when it wasn't. A load-bearing metric is a counting artifact. Building on an unverified premise wastes the work — or ships something wrong. This makes premise-verification an explicit, mechanical step of any dispatch.

## When to use

Before dispatching a worker, or acting yourself, when success depends on a claim you have NOT checked against the live system. Highest value when the premise came from: a handoff/session-summary doc; an inbox item, spec note, or design artifact; a skill's self-description (its documented templates, schemas, paths, flags); a prior agent's or your own earlier summary; a PR body, comment, or commit message.

## Steps

1. **Name the load-bearing premise(s).** Which claim, if false, wastes or misdirects this work? List those, not every assumption.
2. **Trace each to its source.** Mark any sourced from a document/summary rather than direct observation.
3. **Add a fidelity guard to the dispatch.** Instruct the worker to verify each document-sourced premise against the actual artifact FIRST — read the file, the PR body, the live schema, run the command — before building on it. Name the specific check.
4. **Require STOP-and-report on mismatch.** The worker halts with an explicit `STOP — <premise>: <what disagrees>` and returns, rather than improvising a fix, paraphrasing over a gap, or proceeding on a wrong assumption. Fabricating to fill a gap is the failure this prevents.
5. **When verifying yourself, cite reality, not the doc.** Prefer "verified against <artifact>" over "per the doc." If a metric is load-bearing for a decision, confirm what it actually measures before concluding.

## Edge Cases

- **Cheap, directly observable premise** — check it inline; no worker guard needed.
- **Operator-supplied claim** — still verify checkable facts (a spec built on it must be correct), respectfully; don't treat operator decisions/preferences as premises to "verify."
- **Load-bearing vs incidental** — guard the premise whose falsity breaks the task; don't bloat the dispatch verifying trivia.
- **Over-correction** — verifying a wrong claim tempts an equally-wrong opposite conclusion; if the check is ambiguous, mark UNCERTAIN and quote the evidence rather than forcing a new confident claim.
