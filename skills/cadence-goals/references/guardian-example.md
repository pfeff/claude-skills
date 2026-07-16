# Guardian Cadence Example

This reference captures the first concrete process used to design the
`cadence-goals` skill. Load it when you need examples for Guardian-like domain
loops or when implementing the skill itself.

## Source Process

Guardian used R/I/P/H/D/V as a measurement and dispatch vector underneath the
broader Purpose layer.

Purpose domains:
- Health.
- Wealth.
- Family.
- Citizenship.

Key decisions:
- Obsidian periodic notes are the source of truth for cadence goals.
- Project files may link to cadence notes but should not duplicate goals.
- Longer cadences are check-ins, not always-running loops.
- Daily work must name parent direction before acting.
- Active lanes should be limited. The July planning assumption was 3-4 active
  lanes, with other lanes monitored as guardrails.
- Weekly goals can be definition and scoping, not execution.
- Monthly goals should show broad progress and not become the lane currently
  being worked.
- Mechanism work should remain proportional. If on-demand processing is
  reliable and burden is unproven, do not escalate to scheduler or daemon work.
- When Obsidian note creation fails, preserve the vault convention rather than
  adapting doctrine to the bad output.

## Observed Failure Modes

- Daily implementation can spill into tomorrow's verification work.
- Weekly goals can be mistaken for execution when the operator intends
  definition and scoping.
- Monthly plans can over-center the current lane.
- Project files can drift into being the source of truth for periodic goals.
- Retrospective, roadmap, projection, and in-progress navigation can blur.
- Assistant edits can prematurely decide content that should be interviewed.
- Automation can become the work instead of supporting the lane.
- Plugin or command misconfiguration can create plausible-looking notes in the
  wrong location.

## Canonical Sections

Daily:
- `Cadence Alignment`
- `OODA`
- `Act`
- lane-specific scope
- `Guardrails`
- generated or linked supporting summaries

Daily note convention:
- Canonical Guardian daily notes live under `Journal/Daily/YYYY/MM/YYYY-MM-DD.md`.
- If a command creates `YYYY-MM-DD.md` at the vault root, delete or ignore that
  artifact only with operator approval and repair the plugin/config path.
- For an existing missing daily note, direct creation in the canonical location
  is acceptable as content recovery when the operator has authorized direct
  Obsidian edits. Record the plugin/config issue separately.

Weekly:
- `Guardian Weekly Objective`
- `Purpose Balance`
- `Guardian Current State`
- `This Week's Decisions`
- `Operating Slice`
- `Lane content`
- `Vector review schedule`

Monthly:
- `In-Progress Navigation`
- `Projection`
- `Roadmap`
- `Operating Slice`
- `Done when`
- `Tuning Notes`

## Example Boundary

During the July 1 H slice, "verify two consecutive complete prior-day exports"
was identified as a tomorrow task. The correct action was to record it as
deferred/verification work, not continue implementing on July 1.

During the July 3 H slice, the work shifted from scheduled automation to
on-demand batch processing. The correct action was to close H as baseline-ready,
record automation as deferred until burden is demonstrated, and rebalance toward
non-H lanes.

## Example Lane Definitions

I:
- Define the non-job income experiment portfolio.
- Planning assumption: three low-burden experiments by month end.
- Optimization order: minimal operator burden, fastest cash, strategic
  compounding.
- Execution belongs to later daily slices.

H:
- Health Auto Export ingestion established through Dropbox raw delivery and
  on-demand batch normalization.
- Raw source:
  `~/Dropbox/Apps/Health Auto Export/Health Auto Export/Guardian Health Daily`.
- Normalized vault output:
  `Data/Health/apple-health/normalized/daily`.
- Operator command examples: `guardian-health-normalize --all`,
  `guardian-health-normalize --since YYYY-MM-DD`, or
  `guardian-health-normalize YYYY-MM-DD`.
- Daily summary should prefer the complete prior day, not partial same-day data.
- Daily guardrail: expected raw files either process into vault `Data` plus
  health-log notes, or the blocker is visible.
- Automation stance: on-demand first; scheduler only if manual batch processing
  becomes a demonstrated burden.
- Scoring stance: baseline collection only until enough samples and valid goals
  exist for trends and goal attainment.

V:
- Define an AI agents book theme map from existing Guardian/Codex/AI-agent
  material.
- Actual content must be the operator's, though derived analysis of third-party
  sources can inform framing.
- Do not force a table of contents yet.

Family:
- Define a qualitative weekly check covering presence/time, health,
  education/development, and household coordination friction.
- Education/development is the priority focus and needs clearer scope before
  execution.

## Example Doctrine Repair

Problem: the command intended to create the July 3 daily note created an empty
root-level note instead of `Journal/Daily/2026/07/2026-07-03.md`.

Correct handling:
1. Inspect previous valid daily notes to recover the convention.
2. Confirm whether Periodic Notes or Daily Notes configuration is available.
3. Restore today's content in the canonical location if authorized.
4. Record plugin/config repair as a mechanism-repair item.
5. Update weekly/monthly notes additively so stale blockers do not continue to
   steer planning.

Wrong handling:
- Treating the bad root note as the new convention.
- Rewriting weekly/monthly goals around a tool failure.
- Continuing to implement automation while the cadence note itself is missing.
