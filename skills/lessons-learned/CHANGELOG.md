# Changelog

All notable changes to the **lessons-learned** skill will be documented in this file.

## [1.2.1] - 2026-07-07

### Added
- Cross-reference to the `improvement-loop` skill in See Also, documenting that it reads this skill's retro artifacts as one of its experience sources.

**Reasoning**: `improvement-loop` (the dual-pane meta role) is a consumer of this skill's outputs; the pointer keeps the two discoverable from each other.

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
