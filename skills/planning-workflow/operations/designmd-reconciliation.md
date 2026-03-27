# DESIGN.md Reconciliation

After problem validation, compare the workspace DESIGN.md against two layers of truth: problem validation findings and repo-level docs. Surfaces contradictions and gaps before downstream planning phases operate on stale assumptions.

> **Extension point**: Additional reconciliation layers (e.g., strategic doc validation) can be added by augmenting this phase.

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

## Output

The "DESIGN.md Reconciliation" section, included in the Planning Context appendix. The agent carries this context forward:
- **Solution search**: reconciled DESIGN.md provides accurate architecture context for query term selection
- **SpecFlow analysis**: reconciled requirements ground flow identification
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
