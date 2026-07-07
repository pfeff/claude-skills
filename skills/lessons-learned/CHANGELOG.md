# Changelog

All notable changes to the **lessons-learned** skill will be documented in this file.

## [1.2.1] - 2026-07-07

### Added
- Cross-reference to the `improvement-loop` host skill in See Also, documenting that this analysis now runs continuously in the improvement pane (transcript-delta mining + `/skillify` queue drain per `ct` tick).

**Reasoning**: The split-screen self-improvement loop (improvement-loop DESIGN R7) evolves this skill into a hosted component rather than a manual one-off; the pointer keeps the two discoverable from each other without forking the concept.

## [1.2.0] - 2026-02-18

### Added
- Phase 3d: Solution doc bridge in single-session-analysis operation
- When a discussed problem has a concrete, reusable fix, offers to capture it as a searchable solution doc via `/claude-skills:compound` skill
- Solution Docs Created section in output note template

**Reasoning**: Session retrospectives identify problems but don't make solutions discoverable by future agents. Phase 3d bridges to `/claude-skills:compound` so concrete fixes become searchable via grep-first frontmatter filtering (<owner>/<repo>#88, R2).

## [1.1.0] - 2026-02-15

### Added
- Effectiveness tracking in aggregate-patterns operation
- Previous aggregation baseline comparison (Step 1b)
- Frequency delta computation and recommendation correlation (Step 3b)
- Effectiveness section in aggregation report output
- Skill version references in improvement opportunities

**Reasoning**: Without effectiveness tracking, there was no way to measure whether skill improvements actually reduced anti-pattern recurrence. This closes the feedback loop so the evolution cycle can be validated (pfeff/cursor-rules#36, R2).

## [1.0.0] - 2026-02-15

### Added
- Initial version tracking

**Reasoning**: Baseline version established to enable skill evolution tracking (pfeff/cursor-rules#36).
