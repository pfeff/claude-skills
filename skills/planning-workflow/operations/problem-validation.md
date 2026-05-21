# Problem Validation

Before planning implementation, validate the problem statement. Ensures we understand who we're building for, what pain exists, how things work today, and what success looks like.

## Elicitation Doctrine (source of truth)

The funnel, ask-vs-default rule, and interview wording used by this phase are **not defined here**. They live in the `operator-interview-doctrine` skill — the single source of truth for interview logic. This phase is a thin caller: it reads the doctrine and applies it to the four validation dimensions (user, pain, current workflow, success criteria).

**Load the doctrine** (`operator-interview-doctrine`) before running the gap-assessment and interview steps below. Apply, from the doctrine: the **Question taxonomy** (context-free questions first, then funnel, neutral non-leading wording), the **Ask-vs-default rule** (reversibility-gated; `[NEEDS CLARIFICATION]` for unknowns), the **Stop conditions**, and the **AskUserQuestion usage rules**. Do not re-derive or duplicate those rules in this file. The dimension set this phase elicits (user / pain / current workflow / success criteria), and the coverage tiers used to assess them, are the phase-specific binding.

For an explicit, standalone operator interview outside the planning pipeline, use the `/operator-interview <topic>` command, which runs the same doctrine.

## Parameters

- `task_description` (required): Issue title, description, requirements, and any available context

## Execution Steps

### 0. Subagent context detection

Check whether this workspace was dispatched by a goal-tree coordinator (subagent context). Subagents cannot interview the user, so the interactive steps must be bypassed.

**Detection**: Read `DESIGN.md` in the workspace root. If it contains **both** of:
- A `Node ID` field (e.g., `- **Node ID**: C.1.5`)
- An `## Acceptance Criteria` section

Then this is a **subagent context**. The DESIGN.md already contains the structured task spec from the coordinator dispatch.

**When subagent context is detected**, extract the four validation dimensions directly from DESIGN.md:

| Dimension | DESIGN.md source |
|-----------|-----------------|
| **User** | Infer from Project Context, Parent goal, and Requirements — identify who is affected |
| **Pain** | `## Requirements` section — the problem statement and motivation |
| **Current workflow** | `## Design Decisions` and `## Project Context` — how things work today |
| **Success criteria** | `## Acceptance Criteria` — the checkboxes define done |

Produce the output using the same format as step 6 (Compile output), with Validation Method set to `"Extracted from DESIGN.md (subagent context)"`. Then **skip steps 1–5** and proceed directly to the Output phase.

**When subagent context is NOT detected** (no DESIGN.md, or DESIGN.md lacks the required sections), proceed with the interactive flow starting at step 1.

### 1. Assess coverage

Scan the task description for evidence of each dimension (this coverage scan is the phase-specific binding the doctrine's funnel narrows toward):

| Dimension | Signal |
|-----------|--------|
| **User** | Named role, persona, or user type (e.g., "engineer", "operator", "end user") |
| **Pain** | Explicit problem statement, frustration, failure mode, or root cause |
| **Current workflow** | Description of how things work today, existing process, or status quo |
| **Success criteria** | Definition of done, desired outcome, measurable improvement |

Classify each dimension as **Covered** (explicitly addressed), **Implied** (enough context to infer), or **Missing** (not addressed or too vague). These coverage tiers are phase-local; the doctrine governs *how* to ask once a gap is found.

### 2. Extract validated answers

> **Synthesis discipline**: If extracting a "Current workflow" or "Pain" answer asserts a specific infra/system state ("X is broken", "Y deploys via Z", "no instance exists in Q"), apply `skills/task-workflow/operations/falsification-check.md` before committing the answer to the plan — the answer becomes load-bearing for everything downstream.

For dimensions the doctrine classifies as Covered or Implied, extract the answer directly:

```
User: <who is affected and in what context>
Pain: <what problem or friction exists>
Current workflow: <how things work today>
Success criteria: <what "done" looks like>
```

For Implied dimensions, state the inference and flag it for confirmation in step 3, applying the doctrine's ask-vs-default rule (reversibility-gated).

### 3. Interview for gaps

If any dimension is Missing, or an inference needs confirmation, run the interview using the doctrine's **Question taxonomy** (context-free first, then funnel, neutral wording), **Ask-vs-default rule**, **Stop conditions**, and **AskUserQuestion usage rules**. Bind the interview to the four dimensions above; the doctrine governs *how* to ask and when to stop.

If the doctrine's ask-vs-default and stop conditions warrant no questions (all dimensions Covered with no inferences), skip the interview entirely.

### 4. Classify task type

Determine whether the task is a **document/plan task** (where the issue content itself is the deliverable) or a **code implementation task**.

**Document signals** — title or body contains: roadmap, ADR, spec, specification, plan, RFC, design doc, proposal, policy, runbook, playbook, guide, template
**Code signals** — title or body contains: implement, fix, add, refactor, bug, feature, migrate, upgrade, deprecate, remove, test

**Classification logic**:
1. Count document signals and code signals in the issue title and body
2. If only document signals found → classify as **document task** (high confidence)
3. If only code signals found → classify as **code task** (high confidence)
4. If both signal types found → **low confidence** (hybrid)
5. If neither signal type found → **low confidence** (ambiguous)

**When confidence is low**, ask the user:

```
AskUserQuestion:
  question: "Is this a document/plan task (where the issue content is the deliverable) or a code implementation task?"
  options:
    - "Document task" — the issue content defines the deliverable (roadmap, ADR, spec, etc.)
    - "Code task" — the deliverable is code changes
```

If classified as **code task** (by heuristic or user), skip step 5 and proceed to step 6 (compile output).

If classified as **document task**, proceed to step 5 (interactive content gate).

### 5. Interactive content gate (document tasks only)

For document/plan tasks, the issue content defines the deliverable. Before running downstream planning phases on that content, validate it with the user.

Present the gate using AskUserQuestion:

```
AskUserQuestion:
  question: "This looks like a document/plan task where the issue content defines the deliverable. Is the content correct, or does it need revision before planning proceeds?"
  options:
    - "Content is correct" — proceed with planning using the issue content as-is
    - "Needs revision" — stop here; revise the issue content and re-run the planning workflow
```

**If "Content is correct"**: Proceed to step 6 (compile output). Downstream phases operate on the validated content.

**If "Needs revision"**: Stop the planning workflow. Output:

```
Planning paused — issue content flagged for revision.

Revise the issue content, then re-run /claude-skills:planning-workflow to continue.
```

Do not proceed to downstream phases.

### 6. Compile output

Produce a section for the plan:

```markdown
## Problem Validation

**User**: <validated user/persona>
**Pain**: <validated problem statement>
**Current workflow**: <validated description of today's process>
**Success criteria**: <validated definition of done>

### Validation Method
<"Extracted from task description" | "Confirmed via interview" | "Partially inferred, partially confirmed">
```

## Response Rules

Interview wording and posture during gap assessment (step 1) and the interview (step 3) follow the doctrine's **Question taxonomy → Neutral, non-leading wording** and **AskUserQuestion usage rules** (every option carries a recommended default; ≤4 questions, ≤4 options). Apply them from the `operator-interview-doctrine` skill; do not duplicate them here.

**Phase-specific scope** (the only binding this file adds): these rules apply during gap assessment and interview only. They do NOT apply during collaborative phases like solution search or plan generation.

## Output

The "Problem Validation" section, included first in the Planning Context appendix. The agent carries this context forward implicitly when executing downstream phases:
- **Solution search**: validated problem domain informs query term selection
- **SpecFlow analysis**: validated user and workflow ground flow identification
- **Plan generation**: accepts `problem_validation` as a formal parameter and includes it in the Planning Context

## Examples

### Well-specified issue (no interview needed)

Task description:
> When starting a feature issue, agents jump straight to implementation without validating the problem. This leads to building the wrong thing. Add a problem-validation phase to the planning workflow.

Assessment:
- User: **Covered** — agents (AI coding assistants)
- Pain: **Covered** — jumps to implementation, builds wrong thing
- Current workflow: **Implied** — planning workflow runs without validation step
- Success criteria: **Implied** — planning workflow validates before implementing

Output:
```markdown
## Problem Validation

**User**: AI coding agents using the planning-workflow skill
**Pain**: Agents jump to implementation refinement without validating the problem, leading to building the wrong solution
**Current workflow**: Planning workflow runs 6 phases (problem validation → solution search → research gating → SpecFlow → detail level → plan generation) but problem validation was not previously included
**Success criteria**: Planning workflow includes a problem-validation phase that runs first, ensuring the problem is understood before implementation planning begins

### Validation Method
Extracted from task description (2 inferences confirmed by context)
```

### Underspecified issue (interview needed)

Task description:
> Fix the dashboard

Assessment:
- User: **Missing**
- Pain: **Missing**
- Current workflow: **Missing**
- Success criteria: **Missing**

Interview:
```
AskUserQuestion:
  "The issue says 'fix the dashboard' — I need a bit more context:
   1. Who uses this dashboard? (ops team, end users, developers?)
   2. What's broken or painful about it?
   3. How is the dashboard used today?
   4. How will we know it's fixed?"
```

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Task description is empty | Interview for all 4 dimensions |
| User declines to answer a question | Note the gap, proceed with available information |
| All dimensions already covered | Skip interview, extract and compile |
| No document or code signals found | Low confidence — ask user to classify task type |
| Both document and code signals found | Low confidence — ask user to classify task type |
| User selects "Needs revision" at content gate | Stop workflow, do not proceed to downstream phases |

### Document task (content gate fires)

Task description:
> Create a roadmap for Q3 2026 infrastructure improvements including Kafka migration timeline and observability rollout.

Assessment:
- User: **Implied** — engineering leadership / planning stakeholders
- Pain: **Implied** — no structured plan for Q3 infrastructure work
- Current workflow: **Implied** — ad-hoc infrastructure decisions
- Success criteria: **Implied** — documented roadmap with timelines

Classification:
- Document signals: "roadmap" → **document task** (high confidence)
- Content gate fires → user confirms "Content is correct" → proceed

### Hybrid task (low confidence, asks user)

Task description:
> Draft an ADR for the new caching layer and implement the cache invalidation logic.

Assessment:
- Document signals: "ADR" → 1 match
- Code signals: "implement" → 1 match
- Both present → **low confidence** → ask user to classify

## Tips

- Bias toward extracting answers from the task description rather than interviewing — unnecessary questions slow down planning (the doctrine's ask-vs-default rule and stop conditions encode this).
- This phase is about validating the *problem*, not discussing *solutions* — resist the urge to propose implementations.
- For when to stop asking and interview posture, defer to the doctrine's Stop conditions and Question taxonomy; do not restate those rules here.
