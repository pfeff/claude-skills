# DESIGN.md Reconciliation

After problem validation, compare the workspace DESIGN.md against two layers of truth: problem validation findings and repo-level docs. Surfaces contradictions and gaps before downstream planning phases operate on stale assumptions.

> **Extension point**: Additional reconciliation layers can be added by appending steps to this phase.

## Parameters

- `problem_validation` (required): Output from the problem validation phase — user, pain, current workflow, success criteria

## Execution Steps

### 1. Load workspace DESIGN.md

```
Read: file_path="DESIGN.md"
```

If DESIGN.md doesn't exist or contains only placeholder text (`[To be populated]`, `[To be determined]`, `[To be documented]`), report "No substantive DESIGN.md found — skipping reconciliation" and proceed to output.

Parse the following sections (any may be absent):
- **Requirements** — numbered requirement statements (R1, R2, ...)
- **Architecture** — system design, components, file references
- **Design Decisions** — recorded decisions with rationale (DD1, DD2, ...)

### 2. Layer 1 — Problem validation

Compare problem validation output against DESIGN.md sections.

**Check for contradictions**:

| Problem Validation | DESIGN.md Section | Contradiction Signal |
|--------------------|-------------------|---------------------|
| User / persona | Requirements | DESIGN.md targets a different user than validated |
| Pain / problem | Requirements | DESIGN.md solves a different problem than validated |
| Current workflow | Architecture | DESIGN.md describes architecture that doesn't match how things work today |
| Success criteria | Requirements | DESIGN.md requirements don't achieve validated success criteria |

**Check for gaps**:
- Problem validation revealed requirements not captured in DESIGN.md
- Problem validation revealed architectural constraints not in Architecture section
- Problem validation surfaced decisions not recorded in Design Decisions

Collect findings as a list of `{layer, section, type, description, proposed_change}` where type is `contradiction` or `gap`.

### 3. Layer 2 — Repo docs

Locate repo-level documentation. Resolve the repo root by finding the nearest directory containing `.git`:

```
# Find repo root from current working directory
Bash: git rev-parse --show-toplevel

# Repo CLAUDE.md (conventions, key requirements, dev instructions)
Read: file_path="<resolved_repo_root>/CLAUDE.md"

# Repo docs/ directory
Glob: pattern="docs/**/*.md" path="<resolved_repo_root>"
```

If the repo root cannot be determined or repo docs are unavailable, report "Repo docs not found — skipping layer 2" and proceed to step 4.

**Check for contradictions**:

| Repo Doc | DESIGN.md Section | Contradiction Signal |
|----------|-------------------|---------------------|
| CLAUDE.md key requirements (e.g., CR-*) | Requirements | DESIGN.md requirements conflict with repo-level requirement IDs |
| CLAUDE.md conventions | Architecture | DESIGN.md architecture violates repo conventions |
| docs/ content | Architecture, Design Decisions | DESIGN.md contradicts existing repo documentation |

**Check for gaps**:
- Repo CLAUDE.md references requirements that DESIGN.md should address but doesn't
- Repo docs contain relevant architectural context missing from DESIGN.md

Append findings to the same list from step 2.

## Response Rules

These rules apply during contradiction and gap detection (steps 2-3). They do NOT apply during collaborative phases like plan generation or solution search.

### Banned Phrases

Never use these when reporting contradictions or gaps:

- "There seems to be a slight discrepancy" → "DESIGN.md contradicts [source] — [specific conflict]"
- "This might not fully align with" → "This conflicts with [specific doc]: DESIGN.md says X, [doc] says Y"
- "It's worth noting a potential inconsistency" → "Contradiction: [state both sides directly]"
- "The docs could benefit from clarification on this point" → "Gap: DESIGN.md does not address [specific topic] that [source] requires"
- "There may be some tension between these approaches" → "These are incompatible: [approach A] requires X, [approach B] requires not-X"

### Response Posture

- State contradictions as facts, not possibilities. "DESIGN.md requires TTL caching but ARCHITECTURE.md mandates event-driven invalidation" not "there might be a misalignment."
- Name both sides. Every contradiction has two sources — quote or reference both.
- Classify severity. A contradiction in requirements is more consequential than a terminology inconsistency — say which.
- Don't invent alignment. If two docs say different things, they conflict. Don't rationalize how they "could both be correct" unless there's a genuine scope distinction.

### BAD/GOOD Examples

**Pattern 1: Requirement conflict**
- BAD: "There seems to be a slight difference between what DESIGN.md and the repo CLAUDE.md say about authentication. It might be worth reviewing both to ensure consistency."
- GOOD: "**Contradiction** [Layer 2]: DESIGN.md R3 requires 'JWT tokens with 1-hour expiry.' Repo CLAUDE.md CR-AUTH-01 requires 'session-based authentication with server-side storage.' These are incompatible authentication models — one must change."

**Pattern 2: Gap detection**
- BAD: "DESIGN.md covers most of the requirements, though there might be a few areas that could use more detail."
- GOOD: "**Gap** [Layer 1]: Problem validation identified rate limiting as a success criterion, but DESIGN.md has no requirement addressing rate limits. Add a requirement or confirm rate limiting is out of scope."

**Pattern 3: Rationalizing away a conflict**
- BAD: "The architecture section describes a monolith, while ARCHITECTURE.md describes microservices, but both could work depending on the deployment strategy."
- GOOD: "**Contradiction** [Layer 3]: DESIGN.md Architecture describes a monolithic deployment. ARCHITECTURE.md specifies microservice decomposition for this component. These are mutually exclusive deployment models. Resolution needed: update DESIGN.md or flag upstream update to ARCHITECTURE.md."

### 4. Present findings for approval

If no findings, skip to step 5.

Group findings by type and present using AskUserQuestion:

**For contradictions**:
```
"DESIGN.md reconciliation found <N> contradiction(s):

1. [<layer>] <section>: <description>
   Proposed: <proposed_change>

2. ...

Apply these changes to DESIGN.md?"
```

Options:
- "Apply all" — apply all proposed changes
- "Review individually" — present each change for accept/reject
- "Skip" — proceed without changes

**For gaps**:
```
"Problem validation / repo docs revealed <N> item(s) not yet in DESIGN.md:

1. [<layer>] <section>: <description>
   Proposed addition: <proposed_change>

Add these to DESIGN.md?"
```

Options:
- "Add all" — add all proposed items
- "Review individually" — present each for accept/reject
- "Skip" — proceed without additions

### 5. Apply approved changes

For each approved change, use the Edit tool to update DESIGN.md surgically. Preserve all existing content that wasn't flagged.

### 6. Compile output

Produce a section for the plan:

```markdown
## DESIGN.md Reconciliation

### Layer 1: Problem Validation
<"Aligned" | list of contradictions/gaps found and resolution>

### Layer 2: Repo Docs
<"Aligned" | "Skipped (docs unavailable)" | list of findings and resolution>

### Summary
<"DESIGN.md confirmed aligned across all layers" | "N changes applied">
```

### 7. Run fast path gate

After compiling the reconciliation output, load and run `operations/fast-path-gate.md` to evaluate whether the task qualifies for fast path planning. Pass `problem_validation` and `designmd_reconciliation` (the output from step 6) as inputs.

The gate returns a decision: fast path (skip phases 3-6) or full path (continue to phase 3).

## Output

The "DESIGN.md Reconciliation" section, included in the Planning Context appendix. The agent carries this context forward:
- **Fast path gate**: reconciliation output feeds the fast path criteria check (low risk = no unresolved contradictions)
- **Solution search** (full path): reconciled DESIGN.md provides accurate architecture context for query term selection
- **SpecFlow analysis** (full path): reconciled requirements ground flow identification
- **Plan generation**: accepts `designmd_reconciliation` as a formal parameter and includes it in the Planning Context

## Examples

### Aligned (no changes needed)

Task: "Add retry logic to the webhook handler"

DESIGN.md describes webhook handler architecture, requirements for retry behavior, and decision to use exponential backoff. Problem validation confirms this matches the developer's intent. Repo docs align.

```markdown
## DESIGN.md Reconciliation

### Layer 1: Problem Validation
Aligned — DESIGN.md requirements match validated scope.

### Layer 2: Repo Docs
Aligned — no conflicts with repo CLAUDE.md or docs/.

### Summary
DESIGN.md confirmed aligned across all layers.
```

### Contradictions found

Task: "Add DESIGN.md reconciliation to planning workflow"

Problem validation reveals the developer wants two-layer validation (problem validation + repo docs), but DESIGN.md only mentions checking against problem validation findings.

```markdown
## DESIGN.md Reconciliation

### Layer 1: Problem Validation
- **Gap**: R1 only mentions problem validation comparison. Developer confirmed two-layer model (problem validation, repo docs). → Updated R1.

### Layer 2: Repo Docs
Aligned — no conflicts with repo conventions.

### Summary
1 change applied.
```

### Missing docs (graceful degradation)

Task in a repo without repo-level documentation.

```markdown
## DESIGN.md Reconciliation

### Layer 1: Problem Validation
Aligned.

### Layer 2: Repo Docs
Skipped — no docs/ directory found.

### Summary
DESIGN.md confirmed aligned at layer 1. Layer 2 skipped (docs unavailable).
```

## Error Handling

| Condition | Behavior |
|-----------|----------|
| DESIGN.md doesn't exist | Report absence, skip reconciliation, produce minimal output |
| DESIGN.md has only placeholders | Report, skip reconciliation, produce minimal output |
| Repo CLAUDE.md not found | Skip layer 2, note in output |
| Repo docs/ not found | Skip layer 2, note in output |
| User declines all changes | Proceed with original DESIGN.md, note in output |
| Edit tool fails | Warn user, include proposed change in output for manual application |

## Tips

- Bias toward extracting alignment rather than inventing contradictions — unnecessary conflicts slow down planning
- One round of approval per type (contradictions, gaps) — don't ask for approval one item at a time unless the user requests individual review
- Keep the reconciliation report concise — downstream phases need the summary, not a detailed diff
