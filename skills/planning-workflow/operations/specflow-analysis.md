# SpecFlow Analysis

After research and before finalizing the plan, systematically walk all user flows to discover edge cases, missing specifications, and gaps. Produces acceptance criteria that cover the full permutation space.

## Parameters

- `task_description` (required): The issue title, description, and requirements
- `prior_solutions` (required): Output from solution search phase
- `research_findings` (optional): Output from external research, if conducted

## Execution Steps

### 1. Identify user flows

List all distinct user-facing flows affected by this task. For each flow, name it and describe the happy path in one sentence.

Example:
```
1. Login flow — user enters credentials and gains access
2. Password reset flow — user requests reset link and sets new password
3. Session timeout flow — idle user is prompted to re-authenticate
```

For non-user-facing tasks (infrastructure, tooling), identify the operational flows instead:
```
1. Deployment flow — engineer triggers deploy and it reaches production
2. Rollback flow — failed deploy is reverted to previous version
3. Config update flow — setting change propagates without restart
```

### 2. Map decision points

For each flow, identify every point where behavior branches:

- **User choices**: button clicks, form selections, navigation
- **System conditions**: feature flags, permissions, configuration
- **Data states**: empty/populated, valid/invalid, exists/missing
- **External dependencies**: API up/down, timeout, rate limited

Format:
```
Flow: <name>
  Decision: <description>
    → Path A: <outcome>
    → Path B: <outcome>
```

### 3. Enumerate error states

For each flow, list what can go wrong:

- **Validation errors**: invalid input, missing required fields
- **Authorization failures**: insufficient permissions, expired tokens
- **External failures**: network errors, service unavailable, timeouts
- **Concurrency issues**: race conditions, stale data, duplicate submissions
- **Resource limits**: quota exceeded, disk full, memory pressure

### 4. Identify edge cases

Look for combinations that are easy to miss:

- **Boundary values**: zero, one, maximum, empty string, null
- **State transitions**: what happens mid-operation if state changes?
- **Order dependencies**: does sequence matter? What if steps are skipped?
- **First-time vs. repeat**: different behavior on initial vs. subsequent use?
- **Partial completion**: what if the user abandons halfway?

### 5. Find specification gaps

Compare the discovered permutations against the task requirements. Flag anything not explicitly specified:

```markdown
### Specification Gaps

- [ ] **<gap description>** — <which flow/decision point revealed this>
```

### 6. Compile findings

Produce a section for the plan:

```markdown
## SpecFlow Analysis

### Flows Analyzed
1. **<flow name>** — <happy path summary>
   - Decision points: <count>
   - Error states: <count>
   - Edge cases: <count>

### Key Edge Cases
- <edge case 1>
- <edge case 2>
- <edge case 3>

### Specification Gaps
- [ ] <gap 1>
- [ ] <gap 2>

### Generated Acceptance Criteria
- [ ] <criterion derived from edge case or gap>
- [ ] <criterion derived from edge case or gap>
```

## Output

The "SpecFlow Analysis" section with flows, edge cases, gaps, and generated acceptance criteria. These criteria are merged into the final plan's acceptance criteria list.

## Tips

- Don't exhaustively enumerate every permutation — focus on the ones most likely to be missed or cause bugs
- If a flow has more than 5 decision points, it may indicate the task scope is too large
- Specification gaps should be presented to the user for clarification before finalizing the plan
