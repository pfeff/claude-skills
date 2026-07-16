---
name: cadence-goals
description: Manage daily, weekly, monthly, quarterly, and yearly goal-setting loops from Obsidian periodic notes. Use when defining, reviewing, aligning, or updating cadence goals, when distinguishing today's execution from tomorrow or this week/month, or when converting a domain loop into nested annual, quarterly, monthly, weekly, and daily OODA slices.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
version: 1.0.0
---

# cadence-goals — nested cadence goal management

Manage nested cadence goals without flattening everything into the current task.
Use this skill to keep daily work aligned with weekly/monthly/quarterly/yearly
direction, protect time-horizon boundaries, and keep Obsidian periodic notes as
the source of truth.

## Core Rules

- Read the current conversation first, then relevant periodic notes.
- Periodic notes own cadence goals. Project files may link to them but should
  not duplicate them as the editable source of truth.
- Do not hand-create missing periodic notes. Use the Obsidian Periodic Notes
  plugin command surface when available; if unavailable or misconfigured,
  report the blocker before relying on command-created notes.
- Direct Obsidian edits are allowed when the operator authorizes them.
  Direction-changing edits should interview first.
- Prefer additive updates. Do not silently replace earlier goals unless the
  operator explicitly says to replace.
- Keep roadmap, projection, in-progress navigation, and retrospective separate.
- Treat longer cadences as scheduled check-ins that steer nested daily/weekly
  loops, not always-running loops.
- Keep deterministic mechanics in scripts or commands; cadence notes should
  record state, decisions, and links rather than reimplementing automation.

## Search Order

1. Current conversation: extract intent, constraints, decisions, and scope
   corrections.
2. Current periodic notes:
   - yearly note for annual direction and Purpose,
   - quarterly note for mechanism bets if available,
   - monthly note for active slice, roadmap, projection, and tuning notes,
   - weekly note for active lanes and definition/execution stance,
   - daily note for today's OODA and execution boundary.
3. Related Obsidian notes linked from the periodic notes.
4. The runtime's global operating docs (`~/CODEX.md`, `~/AGENTS.md`,
   `~/.claude/CLAUDE.md` as applicable).
5. Existing skills or workflow docs only when they clarify the process.
6. Web or GitHub research only when the user asks for external comparison or
   current best practice.
7. If note creation or command output disagrees with vault convention, inspect
   existing notes and plugin/config state before writing more content.

## Modes

### Define

Use when a cadence goal or lane is ambiguous.

1. Read parent periodic notes.
2. Summarize current direction and the ambiguity.
3. Interview the operator one question at a time.
4. Convert answers into distilled decisions.
5. Update the relevant periodic note if authorized.

### Align

Use when a daily or weekly goal needs parent context.

Name, in order:
- annual direction,
- quarterly bet, if present,
- monthly slice,
- weekly objective,
- today's goal,
- Purpose alignment.

If a lower cadence cannot name its parent direction, pause and clarify doctrine
before dispatching work.

### Rebalance

Use when one lane starts consuming the whole week or month.

1. List lanes.
2. Mark each as `active`, `guardrail`, `paused`, or `deferred`.
3. Enforce the active-lane budget. Current default: 3-4 active lanes.
4. Choose whether the next pass is `definition`, `execution`, `verification`,
   or `retrospective`.
5. Update weekly/monthly notes if authorized.

### Scope Boundary

Use when a task may belong to another time horizon.

1. Identify the smallest meaningful next action.
2. Decide whether it belongs to today, tomorrow, this week, this month, or
   later.
3. Record deferred items in the appropriate cadence note.
4. Do not continue implementation just because the next verification step is
   known.

### Doctrine Repair

Use when the current workflow contradicts established convention or produces
invalid artifacts.

1. Inspect nearby successful notes or artifacts before inferring the rule.
2. Separate content recovery from mechanism repair. Restore the source-of-truth
   note if authorized, then record plugin/script/config repair as a follow-up.
3. Prefer the simplest working mechanism that preserves the doctrine. Defer
   automation when on-demand operation is reliable and burden is unproven.
4. Update parent cadence notes additively so stale blockers do not keep steering
   future work.

### Update Periodic Notes

Use when writing cadence state.

- For existing notes, edit the resulting file directly.
- For missing periodic notes, use Obsidian Periodic Notes plugin commands:
  `periodic-notes:open-daily-note`, `periodic-notes:open-weekly-note`,
  `periodic-notes:open-quarterly-note`, `periodic-notes:open-yearly-note`.
- If only core Daily Notes is available, verify its output path against the
  vault convention before trusting it. If it creates a root or otherwise invalid
  note, treat plugin/config repair as the issue rather than changing the vault
  convention.
- Non-periodic support specs should use the vault's Unique Note convention:
  `Notes/YYYY/MM/YYYY-MM-DD-HHMM-slug.md`.

## Cadence Model

- **Annual:** mission, vector, Purpose, guardrails, success narrative, and
  vector tuning assumptions.
- **Quarterly:** mechanism bets, target movements, active risks, preserved
  guardrails, and intentional deferrals.
- **Monthly:** broad progress across several lanes, roadmap, projection,
  active operating slices, and tuning notes.
- **Weekly:** active lane definition, guardrails, scoping, and setup for later
  daily execution.
- **Daily:** bounded OODA loop, execution or verification for today, and
  explicit deferral of tomorrow/later work.

## Lane And Work Types

Lane states:
- `active`: part of the current 3-4 lane focus.
- `guardrail`: monitored but not advanced unless it trips.
- `paused`: intentionally stopped, with re-evaluation trigger.
- `deferred`: known but outside current cadence.
- `done`: completed for this cadence.
- `verification`: implementation is done; scheduled or external confirmation
  remains.
- `mechanism-repair`: the working content exists, but a plugin, command,
  script, or automation path needs correction before future runs are reliable.

Work types:
- `definition`: clarify terms, scope, outputs, criteria.
- `execution`: implement or produce an artifact.
- `verification`: confirm a prior implementation works.
- `retrospective`: evaluate an ended period.
- `projection`: explore possible futures from trends.
- `doctrine`: clarify or repair the rule that decides where state belongs and
  which mechanism should maintain it.

## Interview Pattern

Ask one question at a time. Prefer questions that narrow:
- active lanes,
- execution vs definition,
- this cadence vs a future cadence,
- output artifact,
- acceptance criteria,
- operator constraints.

Use distilled decisions in notes, not transcript logs.

Do not treat a user answer as permission to execute if the operator is still
scoping week/month goals.

## Light Validation

Before finalizing changes, check:
- Daily goals name their weekly, monthly, and annual parent.
- Weekly objectives state whether they are definition, execution, or
  verification.
- Monthly notes separate roadmap and projection.
- Active lanes do not exceed the chosen budget without operator approval.
- Paused lanes have re-evaluation triggers.
- Deferred work is assigned to a cadence.
- Mechanism-repair items distinguish the missing/incorrect mechanism from the
  cadence content itself.
- Notes were written in the correct source-of-truth location.

## Reference

For the Guardian-derived examples and canonical section patterns, read
`references/guardian-example.md` only when you need concrete examples.

## Sync To Codex

`~/.codex/skills/cadence-goals/` is a synced install target for the Codex
runtime, not a separate source of truth — this directory
(`skills/cadence-goals/`) is canonical. After changing this skill, run
`scripts/sync-codex-skills.sh` to copy the current content into
`~/.codex/skills/cadence-goals/`.
