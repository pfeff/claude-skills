# ADR Propagation

After plan generation, propagate design decisions that supersede existing decisions to downstream artifacts. Ensures PROJECT.md, REQUIREMENTS.md, ARCHITECTURE.md, GitHub issues, and project board stay current when the planning workflow produces superseding decisions.

## Parameters

- `designmd_reconciliation` (required): Output from the DESIGN.md reconciliation phase — specifically the "Upstream Flags" section
- `task_description` (required): Issue title, description, and requirements for context

## Execution Steps

### 1. Check for upstream flags

Parse the DESIGN.md reconciliation output for the "Upstream Flags" section.

If the section contains "None", or if DESIGN.md reconciliation was skipped (no substantive DESIGN.md found), report "No upstream flags — skipping ADR propagation" and proceed directly to step 6 with a minimal output.

Otherwise, extract each flag as a structured item:
```
- target_doc: <PROJECT.md | REQUIREMENTS.md | ARCHITECTURE.md>
- description: <what needs to change and why>
- supersedes: <the existing decision or section being superseded>
```

### 2. Locate strategic docs

Resolve the guardian repo path using the same mechanism as DESIGN.md reconciliation layer 3:

```
Grep: pattern="Project Documentation" path="<repo_root>/CLAUDE.md" output_mode="content"
```

Check for a local clone at conventional paths (`~/src/github/pfeff/guardian`, or `../../pfeff/guardian` relative to the repo root).

If the guardian repo cannot be located:
- Mark all strategic doc updates as "deferred" in the checklist
- Skip to step 4 (issue/board propagation)

If found, read the target files:
```
Read: file_path="<guardian_path>/PROJECT.md"
Read: file_path="<guardian_path>/REQUIREMENTS.md"
Read: file_path="<guardian_path>/ARCHITECTURE.md"
```

Only read files referenced by the upstream flags.

### 3. Generate strategic doc changes

For each upstream flag targeting a strategic doc:

1. **Search for affected sections** — find the specific section(s) in the target doc that reference the superseded decision. Use Grep to locate mentions of the decision, requirement ID, or component name.

2. **Propose a change** — draft a specific text edit (before/after) that reflects the new decision. Keep edits minimal and surgical — only change what the upstream flag requires.

3. **Add to checklist** with the format:
```markdown
#### <target_doc>: <section name>

**Upstream flag**: <description>
**Current text**:
> <existing text being superseded>

**Proposed text**:
> <updated text reflecting new decision>
```

If the superseded decision cannot be found in the target doc (e.g., the flag references something that doesn't appear in the file), note it as "Reference not found — may require manual review" and include the flag description for context.

### 4. Identify affected issues and board items

For each upstream flag, derive search terms from the superseded decision (requirement IDs, component names, decision titles).

Generate checklist items for issue and board propagation:

```markdown
#### GitHub Issues

Search for issues referencing the superseded decision:
- `gh issue list --search "<superseded decision or requirement ID>" --state open`

For each matching issue:
- If the issue is entirely about the superseded approach: propose closing with a comment linking to the new decision
- If the issue partially references the superseded approach: propose updating the description

#### Project Board

Search for board items tied to the superseded decision:
- Items with Requirement ID matching the affected requirement
- Items whose title or body references the superseded approach

For each matching item:
- If the item is obsolete: propose moving to "Done" or "Won't Do" with a note
- If the item needs updating: propose field or description changes
```

Since the planning-workflow skill does not have Bash access, these items are output as actionable checklist entries for the user or another skill to execute.

### 5. Present checklist for approval

Present the complete propagation checklist using AskUserQuestion:

```
"ADR propagation identified <N> change(s) across <M> artifact(s):

<checklist summary — one line per change>

How should we proceed?"
```

Options:
- "Apply strategic doc changes" — apply the PROJECT.md/REQUIREMENTS.md/ARCHITECTURE.md edits (items the planning-workflow can execute directly via Edit tool). Issue/board items remain as checklist entries.
- "Checklist only" — include all items as an unapplied checklist in the plan output
- "Skip" — no propagation, note that upstream flags were not acted on

If the user chooses "Apply strategic doc changes":
- Use Edit tool for each approved strategic doc change
- Confirm each edit succeeded
- Leave issue/board items as checklist entries in the output

### 6. Compile output

Produce a section for the plan:

```markdown
## ADR Propagation

### Upstream Flags Processed
<count> flag(s) from DESIGN.md reconciliation

### Strategic Doc Changes
<"Applied" | "Deferred (guardian repo unavailable)" | "Skipped by user" | "None needed">

<For each applied change:>
- **<target_doc>**: <section> — <one-line summary of change>

### Issue/Board Checklist
<actionable items for issue and board propagation, or "None">

- [ ] `gh issue list --search "<term>" --state open` — check for issues referencing <superseded decision>
- [ ] Close/update issues as appropriate with link to new decision
- [ ] Check project board for items with Requirement ID: <id>
- [ ] Update board item status if obsolete

### Summary
<"N strategic doc changes applied, M issue/board items flagged for action" | "No propagation needed">
```

If no upstream flags were found (step 1 early exit):

```markdown
## ADR Propagation

No upstream flags from DESIGN.md reconciliation — propagation skipped.
```

## Output

The "ADR Propagation" section, appended to the Planning Context in PLAN.md. The issue/board checklist items persist as actionable reminders that can be executed during implementation or workspace closure.

## Examples

### Full propagation with strategic doc changes

Planning produced a design decision to replace webhook integration with event streaming, flagged during DESIGN.md reconciliation.

```markdown
## ADR Propagation

### Upstream Flags Processed
1 flag(s) from DESIGN.md reconciliation

### Strategic Doc Changes
Applied

- **ARCHITECTURE.md**: Integration Patterns — updated webhook integration reference to event streaming for notification-service component

### Issue/Board Checklist

- [ ] `gh issue list --search "webhook notification-service" --state open` — check for issues referencing webhook integration
- [ ] Close/update issues as appropriate with link to event streaming decision
- [ ] Check project board for items with Requirement ID: AO-INT-03
- [ ] Update board item status if approach is now obsolete

### Summary
1 strategic doc change applied, 4 issue/board items flagged for action.
```

### No propagation needed

DESIGN.md reconciliation found no upstream flags.

```markdown
## ADR Propagation

No upstream flags from DESIGN.md reconciliation — propagation skipped.
```

### Guardian repo unavailable

Upstream flags exist but guardian repo not found locally.

```markdown
## ADR Propagation

### Upstream Flags Processed
2 flag(s) from DESIGN.md reconciliation

### Strategic Doc Changes
Deferred (guardian repo unavailable)

- **REQUIREMENTS.md**: AO-AGENT-01 — status may need update from "In Progress" to reflect new backend selection approach
- **PROJECT.md**: S3-E3 — KR3.7 target may need revision based on reduced backend count

### Issue/Board Checklist

- [ ] `gh issue list --search "AO-AGENT-01 backend" --state open` — check for issues referencing previous backend approach
- [ ] Check project board for items with Requirement ID: AO-AGENT-01

### Summary
0 strategic doc changes applied (deferred), 2 issue/board items flagged for action.
```

### User chooses checklist only

User prefers not to apply changes automatically.

```markdown
## ADR Propagation

### Upstream Flags Processed
1 flag(s) from DESIGN.md reconciliation

### Strategic Doc Changes
Checklist only (user deferred)

- [ ] **REQUIREMENTS.md**: CR-SKILL-02 — update status from "In Progress" to "Complete" per new autonomous loop architecture decision
- [ ] **PROJECT.md**: KR3.1 — update target metric to reflect revised agent PR workflow

### Issue/Board Checklist

- [ ] `gh issue list --search "CR-SKILL-02 autonomous loop" --state open` — check for issues referencing previous approach
- [ ] Close/update issues as appropriate

### Summary
0 strategic doc changes applied, 2 strategic doc changes deferred to checklist, 2 issue/board items flagged for action.
```

## Error Handling

| Condition | Behavior |
|-----------|----------|
| DESIGN.md reconciliation was skipped | No upstream flags possible — skip propagation, minimal output |
| Upstream flags section is "None" | Skip propagation, minimal output |
| Guardian repo not found locally | Defer strategic doc changes to checklist, continue with issue/board items |
| Target file doesn't contain the superseded reference | Note "reference not found" in checklist, include for manual review |
| Edit tool fails when applying a change | Warn user, convert to checklist item for manual application |
| User skips all propagation | Note in output that upstream flags were not acted on |

## Tips

- Upstream flags from DESIGN.md reconciliation are the sole trigger — don't re-analyze the plan for superseding decisions
- Keep strategic doc edits minimal — change only what the upstream flag requires, preserve surrounding context
- Issue/board items are deliberately output as checklist entries, not executed — this respects the planning-workflow's tool boundary (no Bash access)
- If the same upstream flag affects multiple sections in one doc, batch them into a single Edit for cleaner diffs
