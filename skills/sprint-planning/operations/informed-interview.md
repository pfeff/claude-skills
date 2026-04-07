# Informed Interview

Engage the user with substantive questions grounded in loaded project context. This is a conversation between a knowledgeable collaborator and the project lead, not a form to fill out.

## When to Use

After load-context has completed. Never before.

## Prerequisites

- Context summary from Step 1 (strategic objectives, prior sprint, open issues, in-flight work, board state)
- Hypothesis about sprint focus

## Approach

### Anti-Pattern: Form-Filling

Do NOT ask:
- "Which repository should this go in?" (you already know the project structure)
- "What strategic objective does this fall under?" (you've read the objectives)
- "What should the issue title be?" (you can propose one)
- Generic questions that show no project understanding

### Target: Substantive Discussion

DO ask:
- "Sprint 1 shipped X. Should Sprint 2 double down on that direction or pivot to Y?"
- "I see 3 in-flight items (#A, #B, #C). Should we finish those first or deprioritize?"
- "The MVP objective needs Z to advance. Is that the right next step, or is there a dependency I'm missing?"
- Questions that demonstrate you understand the project and are helping think strategically

## Steps

### 1. Present State Summary

Open with a concise summary of what you found. Show the user you've done your homework:

```
Here's what I see heading into Sprint N:

**Prior sprint**: [what shipped, what didn't]
**Strategic objectives**: [current state of each]
**In-flight work**: [active sessions/issues]
**Open landscape**: [N issues across M repos, grouped by theme]
```

### 2. Present Hypothesis

Propose a sprint focus based on the data:

```
Based on this, I'd suggest Sprint N focuses on:
1. [Primary focus] — because [reasoning tied to strategic objectives]
2. [Secondary focus] — because [reasoning]
3. [Tertiary] — if capacity allows

Does this align with your thinking?
```

### 3. Discuss Trade-offs

Use AskUserQuestion for structured choices, but make the options informed:

- Priority ordering between focus areas
- Carryover decisions (finish vs. defer in-flight work)
- Stretch goals vs. conservative planning
- Cross-repo coordination needs

### 4. Refine the Increment

Converge on:
- **Sprint goal**: One sentence describing the coherent increment
- **Focus areas**: Ordered list with rationale
- **Specific issues**: Which issues to include, which to defer
- **Acceptance criteria**: How we know the sprint succeeded

## Interaction Guidelines

- **Max 2 rounds of questions** — you should have enough context from Step 1 to keep it tight
- **Propose, don't interrogate** — offer options with recommendations rather than open-ended questions
- **Show your work** — reference specific issues, objectives, and data points
- **Let the user steer** — they may have context you can't see (upcoming deadlines, team changes, external dependencies)

## Output

A sprint plan ready for issue creation:
- Sprint goal
- Focus areas (prioritized)
- Issue list per focus area (with repo references)
- Carryover items
- Acceptance criteria
- Any items explicitly deferred

## Error Handling

- If user disagrees with hypothesis, adapt — don't defend it
- If user raises issues you didn't find, incorporate them
- If scope is unclear, propose a minimal viable sprint and ask about additions
