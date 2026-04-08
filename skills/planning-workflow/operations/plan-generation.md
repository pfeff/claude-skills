# Plan Generation

Generate a living plan as markdown with checkable acceptance criteria. The plan file serves as a progress tracker during implementation.

## Parameters

- `task_description` (required): Issue title, description, requirements
- `problem_validation` (required): Output from problem validation phase
- `designmd_reconciliation` (required): Output from DESIGN.md reconciliation phase (may contain "Skipped" status if DESIGN.md was absent)
- `prior_solutions` (required): Output from solution search phase (may be "Skipped — fast path")
- `research_decision` (required): Output from research gating phase (may be "Skipped — fast path")
- `research_findings` (optional): External research results, if conducted
- `specflow_analysis` (required): Output from SpecFlow analysis phase (may be "Skipped — fast path")
- `detail_level` (required): Selected level — Minimal, More, or A Lot
- `fast_path_gate` (optional): Output from fast path gate evaluation, if the gate was reached

## Plan Templates

### Minimal

```markdown
# Plan: <task title>

## Problem

<concise problem statement>

## Acceptance Criteria

- [ ] <criterion 1>
- [ ] <criterion 2>
- [ ] <criterion 3>
```

### More

```markdown
# Plan: <task title>

## Problem

<problem statement with context>

## Technical Considerations

- <consideration 1>
- <consideration 2>

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| <risk> | <low/medium/high> | <mitigation> |

## Acceptance Criteria

- [ ] <criterion 1>
- [ ] <criterion 2>
- [ ] <criterion 3>

## Dependencies

- <dependency 1>
- <dependency 2>
```

### A Lot

```markdown
# Plan: <task title>

## Problem

<detailed problem statement with background>

## Phases

### Phase 1: <name>
- [ ] <step 1>
- [ ] <step 2>

### Phase 2: <name>
- [ ] <step 1>
- [ ] <step 2>

## Technical Considerations

- <consideration 1>
- <consideration 2>

## Alternatives Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| <approach> | <pros> | <cons> | <chosen/rejected> |

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| <risk> | <low/medium/high> | <mitigation> |

## Resource Requirements

- <requirement 1>
- <requirement 2>

## Acceptance Criteria

- [ ] <criterion 1>
- [ ] <criterion 2>
- [ ] <criterion 3>

## Dependencies

- <dependency 1>
- <dependency 2>
```

## Execution Steps

### 1. Select template

Use the template matching the selected detail level.

### 2. Populate sections

Fill each section using context from prior phases:

- **Problem**: From task description
- **Technical considerations**: From research findings, prior solutions, and DESIGN.md reconciliation findings
- **Risks**: From SpecFlow analysis (error states, edge cases), research, and any unresolved DESIGN.md contradictions
- **Acceptance criteria**: Merge criteria from:
  - Task requirements (explicit)
  - SpecFlow-generated criteria (discovered edge cases) — omit if SpecFlow was skipped via fast path
  - Prior solution prevention guidance (avoid known pitfalls) — omit if solution search was skipped via fast path
  - Standard completion criteria (included by default, deduplicated — omit if not applicable to the task):
    - `Documentation updated to reflect changes (DESIGN.md, README, docs/, or inline as appropriate)`
    - `Deliverable validated via walkthrough or demonstration`
  - **Deduplication**: Before appending standard criteria, check if existing criteria (from task requirements or SpecFlow) already cover documentation or demo. If a criterion already addresses docs or walkthrough/demo, skip the corresponding standard criterion.
- **Phases**: Group related acceptance criteria into logical phases (A Lot only)
- **Alternatives**: From research findings (A Lot only)
- **Dependencies**: From task description and discovered during analysis

### 3. Append context sections

After the plan body, append the phase outputs as reference:

```markdown
---

## Planning Context

<Problem Validation section from problem validation>

<DESIGN.md Reconciliation section from designmd reconciliation>

<Fast Path Gate section from fast path gate, if evaluated>

<Prior Solutions section from solution search>

<Research Decision section from research gating>

<SpecFlow Analysis section from specflow analysis>

<Plan Detail Level section from detail level selection>
```

If DESIGN.md reconciliation was skipped (no DESIGN.md found), include:

```markdown
### DESIGN.md Reconciliation
Skipped — no substantive DESIGN.md found.
```

If phases were skipped via fast path, include their "Skipped — fast path" values as-is in the Planning Context. For example:

```markdown
### Prior Solutions
Skipped — fast path

### Research Decision
Skipped — fast path

### SpecFlow Analysis
Skipped — fast path

### Plan Detail Level
Minimal (fast path default)
```

### 4. Write plan file

Write the plan to PLAN.md in the workspace root:

```
Write: file_path="PLAN.md" content=<generated plan>
```

If PLAN.md already exists, ask the user before overwriting.

## Living Plan Usage

During implementation, acceptance criteria are checked off as completed:

```markdown
- [x] User can log in with valid credentials
- [ ] Invalid credentials show error message
- [ ] Session expires after 30 minutes of inactivity
```

The plan file is the source of truth for task progress. Work execution phases should update it directly.
