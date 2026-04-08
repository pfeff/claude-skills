# Fast Path Gate

After DESIGN.md reconciliation, evaluate whether the task qualifies for fast path planning. Fast path skips phases 3-6 (solution search, research gating, SpecFlow analysis, detail level selection) and proceeds directly to plan generation with Minimal detail level.

## Parameters

- `problem_validation` (required): Output from the problem validation phase
- `designmd_reconciliation` (required): Output from DESIGN.md reconciliation phase

## Criteria

All three criteria must be true for fast path. Each is a binary check — no judgment calls.

### Criterion 1: Explicit acceptance criteria

The task description contains **verifiable acceptance criteria** — statements that can be checked pass/fail after implementation.

**True when**: The task description, issue body, or DESIGN.md requirements section contains at least one statement that is testable (e.g., "endpoint returns 404", "file is created at path X", "error message includes Y").

**False when**: The task describes a goal without measurable outcomes (e.g., "improve error handling", "clean up the module", "add logging").

### Criterion 2: Known code target

The task targets files or modules that exist in the current repository and can be located.

**True when**: At least one of:
- The task names specific files, functions, classes, or modules AND those exist in the repo (verify with Glob or Grep)
- The DESIGN.md architecture section identifies the affected components AND those components can be mapped to existing files

**False when**:
- The task requires creating a new subsystem or module from scratch
- The affected code cannot be located in the repo
- The task scope spans 3+ unrelated modules

### Criterion 3: Low risk

The DESIGN.md reconciliation produced no unresolved contradictions.

**True when**: The reconciliation summary says "aligned" or all findings were resolved.

**False when**: Any contradiction remains unresolved.

## Execution Steps

### 1. Evaluate criteria

Check each criterion against the problem validation and DESIGN.md reconciliation outputs. Record a pass/fail for each with a one-line justification.

### 2. Decide path

- **All three pass** → fast path
- **Any criterion fails** → full path (continue to phase 3: solution search)

### 3. Produce output

```markdown
## Fast Path Gate

| Criterion | Result | Justification |
|-----------|--------|---------------|
| Explicit acceptance criteria | pass/fail | <one line> |
| Known code target | pass/fail | <one line> |
| Low risk (reconciliation clean) | pass/fail | <one line> |

**Decision**: fast path / full path
```

## On Fast Path

When the decision is "fast path", skip phases 3-6 and proceed directly to plan generation (phase 7) with these parameter defaults:

- `prior_solutions`: "Skipped — fast path"
- `research_decision`: "Skipped — fast path"
- `research_findings`: not provided
- `specflow_analysis`: "Skipped — fast path"
- `detail_level`: "Minimal"

Plan generation handles these skipped values and produces the same PLAN.md output format.

## On Full Path

When the decision is "full path", proceed to phase 3 (solution search) as normal. The fast path gate output is still included in the Planning Context appendix.
