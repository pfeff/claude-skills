# Privacy Gate: Sensitivity Decision-First

## Overview

Before dispatcher composition begins, the privacy gate checks whether a dispatch
is targeting a **public destination** with **sensitive context**. If both
conditions are true, the operator makes an explicit sensitivity decision
*before* the dispatcher proceeds — not after, and not silently.

This gate prevents accidental leaks of personal, financial, health,
or proprietary information into public channels (GitHub public repos,
published docs, shared Slack channels, etc.).

## Trigger Condition

The privacy gate activates when **both** are true:

1. **Public destination**: The background job will produce output (PR
   description, commit message, branch name, artifact, or other delivery
   surface) that ends up in a public channel.
2. **Sensitive context**: The operator's stated intent, the dispatch
   context, or the reference materials available to the job include
   sensitive data.

If either condition is false, skip the gate.

## Public Destinations

Destinations are **public** if the output is readable by unauthenticated
users or by users outside the operator's trust boundary:

- **Public GitHub repositories** — any PR, issue, commit message, or branch
  name pushed to a public repo
- **Published documentation** — Docs sites, wikis, README files, or
  user-facing skill docs published in public repos
- **Shared Slack / Discord channels** — posts, threads, or reactions in
  channels where > operator's private circle can read
- **Blog posts, tweets, recorded demos** — any publicly indexed or
  discoverable content
- **Open-source projects or community contributions** — by definition public
- **Third-party services** — outputs sent to external APIs, forwarding
  services, or public logging/monitoring

Destinations are **private** if output is confined to:

- Operator's private worktree or branch (uncommitted or force-deleted)
- Private GitHub repos readable only by operator
- Operator's vault, memory, local notes, or encrypted storage
- Closed communication channels (Slack DMs, private org channels)

## Sensitive Context

Context is **sensitive** if it includes any of:

- **Financial data**: salary, net worth, asset allocation, investment
  strategy, cash flow, loan amounts, tax rates, earned interest, liquid
  reserves earmarked for home purchase
- **Health data**: medical conditions, treatment plans, medication names,
  health insurance details, disabilities
- **Private URLs or identifiers**: home address, phone numbers, SSN, email
  aliases, private GitHub URLs, vault links (e.g., `~/ObsidianVault/...`)
- **Proprietary strategy**: company OKRs, confidential product roadmaps,
  customer lists, pricing models, acquisition targets
- **Vault excerpts**: Any quoted or summarized content from operator's
  personal memory (vault notes, Readwise highlights, Obsidian clips)
- **Private personal context**: relationship details, family member names
  (if identifiable), psychological/emotional state, private opinions on
  public figures

Avoid over-filtering — operational information (task counts, project names,
meeting notes if already public, skill names) is **not sensitive**.

## Procedure

### Placement in dispatch-gate

This check runs as **Step 0** — before the four slice-complete criteria
are checked. Sensitivity is a policy gate, independent of task readiness.

### Dispatcher behavior

When invoking dispatch-gate:

1. **Read the operator's stated intent** (the message or context that
   prompted the dispatch).
2. **Identify the destination**:
   - Ask the operator explicitly: "Is this job going to produce output
     in a public channel?" (GitHub PR description, published docs,
     Slack post, etc.)
   - If unclear: default to "public" until confirmed otherwise.
3. **Scan the context for sensitivity**:
   - Operator's message: any financial, health, or vault references?
   - Available resources (DESIGN.md, PLAN.md, vault notes, memory):
     would the job have access to or reference sensitive data?
   - Acceptance test or test plan: does proving the job done require
     revealing sensitive information?
   - If the job is a *search/analysis* task, will the result surface
     sensitive findings?
4. **Privacy decision**:
   - If **public destination AND sensitive context**:
     - Stop and ask the operator: "This dispatch targets a public
       destination and has access to [specific sensitive context]. Do you
       approve publishing this work output to [destination]?"
     - **Operator must approve explicitly** before the gate proceeds to
       Step 1.
     - Record the approval: note it in the task-context file as a Privacy
       Gate Annotation (see format below).
   - If **private destination OR no sensitive context**: proceed to Step 1.

### Privacy Gate Annotation

When the operator approves a public + sensitive dispatch, record the
decision in `.claude/task-context.md` immediately below the four fields
(same placement as Override annotation, but a different annotation type).

Format:

```markdown
> **Privacy Gate** (context: <specific sensitive data>, destination:
> <public channel>): operator approved on <date>.
```

Example:

```markdown
> **Privacy Gate** (context: personal financial data, destination: public
> GitHub PR description): operator approved on 2026-07-07.
```

This annotation makes the decision durable and reviewable by `self-verify`
and the human review layer.

## Failure Cases

### Case 1: Operator declines approval

If the operator declines the sensitivity decision:

- Do not proceed with the dispatch.
- Do not write `.claude/task-context.md`.
- Suggest a workaround: refactoring the task to exclude sensitive
  context, or routing to a private destination.

Example workaround: "Instead of a public PR description, write findings
to a private branch or vault note, then summarize the non-sensitive
parts for the public PR."

### Case 2: Dispatcher misjudges sensitivity

If the dispatcher is unsure whether context is sensitive:

- **Default to asking**. Err on the side of sensitivity; the operator can
  always clarify "this isn't sensitive, proceed."
- Example: "The operator mentioned their home purchase plan. Is that
  sensitive enough to gate?" — YES, ask the operator.

### Case 3: Sensitive data discovered mid-job

If the background job discovers sensitive information during execution
that wasn't foreseeable at dispatch time:

- **Policy**: the job should not include sensitive findings in public
  outputs.
- Responsibility: the job's own author is accountable for scrubbing
  sensitive output before committing/publishing.
- The privacy gate is a **dispatch-time guard**, not a runtime filter.

## Relationship to Other Gates

- **dispatch-gate Step 0** (this check): policy gate — "are we allowed to
  proceed?"
- **dispatch-gate Steps 1–5** (existing): task-readiness gate — "is the
  task well-specified?"
- **self-verify** (review layer): catches any privacy gate violations that
  slipped through (mis-filed public/private, missed sensitive context,
  etc.); flags them for operator review pre-merge.

Both gates must pass. They are independent.

## Calibration & Updates

If the dispatcher frequently asks "is this sensitive?" on data that turns
out non-sensitive, or vice versa:

- Adjust the Sensitive Context list above — document the new category or
  raise a threshold.
- Update examples with real cases (anonymized).
- This reference doc is the living definition of what counts as sensitive
  in this system — maintain it as the policy evolves.

## References

- `../SKILL.md` Step 0 — where this gate is invoked in dispatch-gate
  workflow
- `../references/task-context.md` — format for Privacy Gate Annotation
- `../../self-verify/SKILL.md` — review layer that catches any
  violations
