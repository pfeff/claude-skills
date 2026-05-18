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

### 6. Audit layers

For each requirement, audit where the rule belongs by answering three questions:

1. **Inputs** — What information does the rule need to produce the right answer? (e.g., issue owner, hostname, "personal vs work" classification, file contents, user identity, request context.)
2. **Layer** — Where will the rule run? Pick one:
   - **Script** (bash/python helper, e.g., `create-workspace.sh`)
   - **Skill operation** (e.g., `operations/workspace-from-issue.md`)
   - **Agent reasoning** (the agent decides in conversation)
   - **Hook** (pre-commit, settings hook, harness lifecycle)
3. **Match** — Does the chosen layer have access to all the inputs from question 1?
   - Yes → the layer is correct.
   - No → push the rule **up** to the layer that does have the inputs. A script cannot apply a rule that depends on inputs only a skill operation has parsed.

A "no" in the "Inputs available?" column of the Layer Audit table (produced in step 7) is a **design defect**. Either move the rule up to a layer with the inputs, or surface the missing input as a specification gap (step 5) for the user to resolve before plan finalization.

### 7. Compile findings

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

### Layer Audit
| Requirement / Criterion | Inputs needed | Proposed layer | Inputs available at that layer? | Resolution |
|-------------------------|---------------|----------------|--------------------------------|------------|
| <id or short title>     | <list>        | script / skill op / agent / hook | yes / no | <"correct" or "move to <higher layer>"> |

### Generated Acceptance Criteria
- [ ] <criterion derived from edge case or gap>
- [ ] <criterion derived from edge case or gap>
```

## Output

The "SpecFlow Analysis" section with flows, edge cases, gaps, layer audit, and generated acceptance criteria. These criteria are merged into the final plan's acceptance criteria list.

## Tips

- Don't exhaustively enumerate every permutation — focus on the ones most likely to be missed or cause bugs
- If a flow has more than 5 decision points, it may indicate the task scope is too large
- Specification gaps should be presented to the user for clarification before finalizing the plan
