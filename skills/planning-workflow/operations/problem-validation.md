# Problem Validation

Before planning implementation, validate the problem statement. Ensures we understand who we're building for, what pain exists, how things work today, and what success looks like.

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

Scan the task description for evidence of each dimension:

| Dimension | Signal |
|-----------|--------|
| **User** | Named role, persona, or user type (e.g., "engineer", "operator", "end user") |
| **Pain** | Explicit problem statement, frustration, failure mode, or root cause |
| **Current workflow** | Description of how things work today, existing process, or status quo |
| **Success criteria** | Definition of done, desired outcome, measurable improvement |

For each dimension, classify as:
- **Covered**: Task description explicitly addresses it
- **Implied**: Enough context to infer a reasonable answer
- **Missing**: Not addressed or too vague to infer

### 2. Extract validated answers

For dimensions classified as Covered or Implied, extract the answer directly:

```
User: <who is affected and in what context>
Pain: <what problem or friction exists>
Current workflow: <how things work today>
Success criteria: <what "done" looks like>
```

For Implied dimensions, state the inference and flag it for confirmation in step 3.

### 3. Interview for gaps

If any dimension is Missing, or if inferences need confirmation, use AskUserQuestion.

**Interview approach** (follow the informed-interview pattern):
- Propose answers where possible — don't ask open-ended questions when you can offer informed options
- Reference specifics from the task description to show understanding
- Keep it to one round of questions covering all gaps at once

**Question templates by dimension**:

| Dimension | Question |
|-----------|----------|
| User | "Who primarily uses this? I see <context> — is this for <role A> or <role B>?" |
| Pain | "What's the core pain? The issue mentions <symptom> — is the real problem <hypothesis>?" |
| Current workflow | "How does this work today? I'm guessing <inference> — is that right, or is there a step I'm missing?" |
| Success criteria | "How will we know this worked? I'd suggest <proposed criteria> — does that capture it?" |

If all dimensions are Covered with no inferences, skip the interview entirely.

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

These rules apply during gap assessment (step 1) and interview (step 3). They do NOT apply during collaborative phases like solution search or plan generation.

### Banned Phrases

Never use these when assessing gaps or interviewing:

- "That makes sense" → evaluate whether the answer is specific enough: "That's too vague — who specifically?"
- "I can work with that" → if the answer leaves a dimension ambiguous, push for specifics
- "Thanks, that's helpful" → assess whether the answer actually fills the gap, and say if it doesn't
- "That's a reasonable approach" → check if the answer describes a real workflow or a hypothetical: "Is that how it works today, or how you want it to work?"
- "I understand" → if you need more detail, say so: "I need a concrete example — can you describe the last time this happened?"

### Response Posture

- Propose specific answers, don't ask open-ended questions. "Is the user a platform engineer who runs deployments?" not "Who is the user?"
- Push back on vague pain statements. "Everyone is frustrated" is not a pain statement — demand specifics: who, what breaks, how often.
- Reject non-answers. If the user says "it's just generally slow," ask for a number: "How slow? 2 seconds? 20 seconds? Do you have metrics?"
- One round maximum, but make it count. Every question should propose an answer the user can confirm or correct.

### BAD/GOOD Examples

**Pattern 1: Vague user**
- BAD: User says "developers use it." Agent: "Great, so the user is developers. Moving on to pain."
- GOOD: User says "developers use it." Agent: "Which developers? Backend engineers running deployments? Frontend engineers debugging builds? The rules for each are different — I need to know which workflow we're optimizing."

**Pattern 2: Missing pain**
- BAD: Task says "improve the dashboard." Agent infers: "Pain: the dashboard could be better." (Proceeds without asking.)
- GOOD: Task says "improve the dashboard." Agent: "What's broken about the dashboard? Is it slow to load, showing wrong data, missing key metrics, or something else? 'Improve' isn't actionable without a specific failure mode."

**Pattern 3: Accepting vague success criteria**
- BAD: User says "it should be faster." Agent: "Success criteria: improved performance."
- GOOD: User says "it should be faster." Agent: "Faster than what? What's the current load time, and what's the target? Without a number, we can't verify success. If you don't have metrics, the first task should be adding instrumentation."

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

- Bias toward extracting answers from the task description rather than interviewing — unnecessary questions slow down planning
- One round of questions maximum — if answers are still unclear, note the ambiguity and let downstream phases surface it
- This phase is about validating the *problem*, not discussing *solutions* — resist the urge to propose implementations
