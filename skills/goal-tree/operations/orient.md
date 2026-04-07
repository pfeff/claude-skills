# Orient Operation

Maps observations to mission and strategy. Surfaces alignment, drift, and reprioritization opportunities.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `project_dir` | No | Project directory (default: current working directory) |
| `observations` | No | Output from a prior `/status` call or conversation context |

## Purpose

Answers: "What does this mean for our strategy?" Takes the current state (from /status or conversation) and evaluates it against the mission, OKRs, and current priorities. Identifies where effort is aligned, where it's drifting, and what should change.

## Execution Steps

### 1. Gather Context (if not provided)

If observations aren't available from a prior `/status`, run the status observation step first.

Read guardian PROJECT.md for:
- Mission statement
- Strategic objectives (S1, S2, S3) and their priority order
- Enabling objectives and KR targets
- Current priority order and capacity allocation

### 2. Map Current Work to Strategy

For each active tree / in-progress work:
- Which strategic objective does it serve?
- Which enabling objective?
- Which KR does it advance?

If work can't trace to a KR: flag it. It's either maintenance (capped at 10%) or out of scope.

### 3. Evaluate Alignment

**Aligned**: Work that directly advances the highest-priority KRs.
**Drifting**: Work that serves a lower-priority objective when higher-priority work is available.
**Missing**: KRs with no active work that should have some.

Present as a brief narrative, not a matrix.

### 4. Surface Reprioritization Opportunities

Based on the alignment evaluation:
- Should the current tree be restructured?
- Are there new nodes needed?
- Should anything be deprioritized?
- Have completed capabilities changed what's most valuable next?

### 5. Conversation

This is a discussion, not a report. Present the orientation and let the operator steer. The operator may:
- Confirm alignment → proceed to Decide/Act
- Identify drift → restructure tree or reprioritize
- Raise new strategic context → update understanding, possibly refine docs
- Request doc changes → capture as commits via worktree

## Example Output

```
Current work (Strategic Control Loop) traces to S3-E2 (self-improving
infrastructure) via KR3.4 (skill evolution). It also serves S1-E2 (dogfooding)
by making AC usable as the primary PM tool.

This is aligned with priority order — S1 work (revenue) benefits directly
because the OODA loop makes dogfooding sustainable.

However: S1-E3 (PM tool MVP) has no active work. The MVP capabilities defined
in ADR-006 haven't progressed since the functional MVP issue. If the goal is
revenue validation, we may need to split attention between the control loop
(makes dogfooding work) and the MVP features (makes the product shippable).

Is the control loop a prerequisite for MVP work, or should they run in parallel?
```

## Integration Points

- **Called by**: `/orient` command, or as step in `/resume-project` preamble
- **Calls**: Read (guardian docs), `coord tree show`
- **May lead to**: Tree restructuring, doc refinement, or Decide phase
