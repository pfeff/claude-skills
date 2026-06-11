# Workspace Initialization Operation

Populates a workspace with issue/ticket content, enriches CLAUDE.md and DESIGN.md, and creates an implementation task list.

**Requirements**: Must be run from within an existing workspace created by `/create-workspace`.

## Purpose

Bridges the gap between workspace scaffolding (`/create-workspace`) and implementation (`/next-task`). Fetches issue/ticket content, populates workspace documentation with real requirements, and decomposes the work into a task list.

## Coordinator Sync (Optional)

If `COORDINATOR_URL`, `COORDINATOR_TOKEN`, and `COORDINATOR_MISSION_ID` are set, task creation in step 11 will also create tasks in the coordinator. This mirrors the task list to the coordinator for visibility and persistence.

```bash
source ${CLAUDE_PLUGIN_ROOT}/skills/goal-tree/scripts/coord-helpers.sh
```

This provides `coord_create_task`, `coord_sync_status`, and `coord_report_progress`. All are no-ops when coordinator env vars are unset.

## Execution Steps

### 1. Verify Workspace Context

Confirm we're in a valid workspace:

```
Required files:
- DESIGN.md (must exist)
- CLAUDE.md (must exist)

If either is missing:
  Error: "Not in a valid workspace. Run /create-workspace first."
```

### 2. Read Workspace Files

Read both DESIGN.md and CLAUDE.md to extract:
- Task ID, Epic, Headline (from DESIGN.md first line: `# TASK-ID: Headline`)
- GitHub Issue reference (from CLAUDE.md `GitHub Issue:` field)
- Jira Ticket reference (from DESIGN.md `Jira Ticket:` field)
- Current content of all sections (to detect placeholders vs. manual edits)

### 3. Detect Issue Source

Priority order:

1. **GitHub Issue**: CLAUDE.md contains `GitHub Issue:` with a non-empty value
2. **Jira Ticket**: DESIGN.md contains `Jira Ticket:` with a non-empty value
3. **Ask user**: If neither found, use AskUserQuestion:
   - "What is the issue source?" → GitHub / Jira / None
   - If GitHub: "What is the issue reference?" (e.g., `org/repo#123`)
   - If Jira: "What is the ticket key?" (e.g., `PROJ-456`)
   - If None: Skip to step 8 (user interview)

### 4. Fetch Issue Content

#### GitHub Issues

```bash
gh issue view <ref> --json title,body,labels,assignees,milestone,comments
```

Extract:
- `title` → issue title
- `body` → issue description (markdown)
- `labels` → categorization
- `assignees` → ownership
- `milestone` → timeline context
- `comments` → discussion and decisions

#### Jira Tickets

```bash
acli jira --action getIssue --issue <KEY> --outputFormat 2
```

Extract:
- Summary → ticket title
- Description → ticket body
- Labels/Components → categorization
- Assignee → ownership
- Sprint → timeline context
- Comments → discussion and decisions

#### Error Handling

| Error | Response |
|-------|----------|
| `gh` not installed | Warn, offer to continue without issue data |
| `acli` not installed | Warn, offer to continue without issue data |
| Auth failure | Suggest `gh auth login` or `acli` auth setup |
| Issue not found | Warn, offer to continue without issue data |

### 5. Enrich CLAUDE.md

Update the existing CLAUDE.md, preserving all non-placeholder content.

**Sections to enrich**:

| Section | Source | Action |
|---------|--------|--------|
| Description | Issue title + body summary | Populate if placeholder or empty |
| Links | Issue URL | Add issue link if missing |
| Notes | Acceptance criteria, key constraints | Append if not already present |

**Placeholder detection**: A section is a placeholder if its content is empty or contains only text matching:
- `[To be populated]`
- `[To be determined]`
- `[To be documented]`
- The default template text (e.g., "Consult DESIGN.md for architecture")

**Convention injection**:
- Check if Notes section contains: "Session tasks are implementation steps for this issue"
- If not present, append: `- Session tasks are implementation steps for this issue. Do not create separate GitHub issues for implementation steps.`
- This is idempotent — skip if already present (covers workspaces created with updated template)

**Enrichment rules**:
- Read the full file content
- For each target section, check if it contains only placeholder text
- If placeholder: replace with issue-derived content
- If non-placeholder: preserve existing content, do not modify
- Use the Edit tool for surgical updates

### 6. Enrich DESIGN.md

Update the existing DESIGN.md, preserving all non-placeholder content.

**Sections to enrich**:

| Section | Source | Action |
|---------|--------|--------|
| GitHub Issue | Issue reference | Populate if empty |
| Jira Ticket | Ticket key | Populate if empty |
| Requirements | Issue body, acceptance criteria | Populate if placeholder |
| Architecture | Technical context from issue | Populate if placeholder |
| Design Decisions | Issue discussion/comments | Populate if placeholder |

**Requirements extraction**:

Parse the issue body for:
1. Explicit acceptance criteria (checkboxes, numbered lists under "Acceptance Criteria" heading)
2. Requirement statements ("must", "should", "shall" keywords)
3. User stories ("As a ... I want ... so that ...")
4. Structured sections (headings that map to requirements)

Format extracted requirements as a numbered list with IDs:
```markdown
## Requirements

### R1: <requirement title>
<requirement description>

### R2: <requirement title>
<requirement description>
```

**Architecture section**:
- If the issue contains technical details (code references, architecture mentions, component names), extract into Architecture section
- If insufficient technical context, leave as placeholder for user interview

**Design Decisions section**:
- If issue comments contain decisions or trade-off discussions, summarize them
- If no substantive discussion, leave as placeholder

### 7. Formalize Acceptance Criteria

Write an explicit, checkable done-contract to DESIGN.md before any task decomposition. This section is the single source of truth for "done" — task decomposition (step 11), the review gate (step 12), and auto-advance's completion gate all reference it by AC ID.

**Extraction sources** (priority order — first source with substantive content wins; lower sources supplement only when higher ones are sparse):

1. Explicit "Acceptance Criteria" / "Definition of Done" heading in the issue body
2. Checkbox lists (`- [ ]`) anywhere in the issue body
3. "must" / "shall" / "should" statements in the requirements text (step 6 extraction)
4. User interview (step 8) — when the above yield insufficient content, draft 2–5 candidate ACs from the Requirements section and issue title; the interview presents them for confirmation

**Format** — write a `## Acceptance Criteria` section to DESIGN.md, immediately after `## Requirements`:

```markdown
## Acceptance Criteria

- [ ] **AC-1**: <criterion — a verifiable statement about the deliverable>
- [ ] **AC-2**: <criterion>
```

**Writing rules**:
- Each criterion is an observable outcome of the deliverable ("X exists / does Y when Z"), not an implementation step
- IDs are stable: never renumber existing ACs on re-run; only append new ones
- The bold `**AC-N**` IDs make the contract greppable — `grep '^- \[ \] \*\*AC-' DESIGN.md` lists open criteria

**Idempotency**: same non-placeholder rule as Requirements/Architecture — if the section already exists with non-placeholder content, preserve it (manual edits win). Append genuinely new criteria derived from new issue content; never rewrite, reorder, or renumber existing ones, and never reset a checked box to unchecked.

### 8. User Interview (Conditional)

The interview leads with ratification of the AC contract; generic section questions run only for gaps that remain afterward.

**Part 1 — Ratify acceptance criteria**:

Skip Part 1 only when step 7 extracted the ACs verbatim from an explicit "Acceptance Criteria" / "Definition of Done" section (extraction source 1) — those are already human-authored. For ACs derived from weaker sources (checkbox lists, must/should statements, drafted candidates), present the list for confirmation:

```
Display the drafted ## Acceptance Criteria list (IDs + text).

AskUserQuestion: "These acceptance criteria define 'done' for this task. Do they capture it?"
  Options:
    - "Confirm" → ACs are ratified as-is
    - "Amend" → user states additions/removals/rewording; apply to DESIGN.md, re-ask
```

The ratified contract is what task decomposition (step 11) and the completion gate verify against — getting it right here is cheaper than discovering a missing criterion at PR time.

**Part 2 — Fill remaining gaps** (only sections still placeholder after Part 1):

```
For each section in [Requirements, Architecture, Design Decisions]:
  If section content is still a placeholder:
    Ask targeted question(s) about that section
```

| Section | Question |
|---------|----------|
| Requirements | "The issue didn't specify clear requirements. What are the key requirements for this task?" |
| Architecture | "What components/systems does this change affect? Any architectural constraints?" |
| Design Decisions | "Are there any design decisions or trade-offs already made for this task?" |

Ratified ACs often resolve the Requirements gap on their own — only ask about Requirements when the ACs leave genuine context missing.

Use AskUserQuestion with relevant options derived from the issue context when possible.

After interview, update DESIGN.md with the responses.

### 9. Sync Worktrees Against Origin

Update all repo worktrees in the workspace against origin before searching for solutions or creating tasks. Stale local state leads to duplicate work (e.g., creating tasks for files that already exist on main).

```
For each repo worktree in the workspace:
  git fetch origin
  git rebase origin/main (or the worktree's upstream branch)
```

**Error handling**: If rebase fails due to conflicts, warn the user and continue with the remaining repos. Stale data is better than blocking initialization entirely.

<!-- IMPLEMENTED: REC-001 - Add repo sync step to init-workspace -->

### 10. Search Existing Solutions

Run a QMD query against the configured vault collection for relevant prior notes before creating the task list. Per DD4, the Obsidian vault is the single retrieval source; `docs/solutions/` is no longer consulted.

**See `references/solution-search.md`** for the full invocation, output-shape, and fail-open protocol — do not duplicate it here. The steps below are the operation-specific wiring (what inputs to pass, where to persist results).

#### 10a. Refresh the index (best-effort)

```bash
timeout 30 qmd update -c "$QMD_COLLECTION" 2>/dev/null || true
```

Idempotent incremental reindex. Fail-open — a stale index is strictly better than blocking setup. `|| true` ensures a non-zero exit never propagates.

#### 10b. Build the query

Per DESIGN.md OQ #3, the query is the **issue/ticket title followed by the first paragraph of the enriched DESIGN.md** (which now contains the real requirements after steps 5–8), not the raw issue description.

```bash
# Extract the first non-empty paragraph after the H1 line in DESIGN.md.
# awk stops at the first ## heading.
first_para=$(awk '
  /^# / { in_body=1; next }
  in_body && /^## / { exit }
  in_body && NF { print; found=1; next }
  in_body && found && !NF { exit }
' DESIGN.md)

# Sanitize: strip control chars and shell metacharacters that would break
# QMD's query grammar (lex:/vec:/hyde: typed lines start after newlines).
sanitize() { tr '\n\r\t`$\\' '     ' | head -c 2000 ; }

# $issue_title was captured in step 4 (gh issue view --json title, or acli getIssue Summary)
query_text="$(printf '%s. %s' "$issue_title" "$first_para" | sanitize)"
```

Assigning to a shell variable and passing `"$query_text"` (double-quoted) is injection-safe: the shell expands the variable into a single argument regardless of its contents. **Do not inline issue content directly into the `qmd query` command** — that is the unsafe form.

#### 10c. Run the query

```bash
timeout 60 qmd query "$query_text" -c "$QMD_COLLECTION" > /tmp/qmd-prior.out 2>/tmp/qmd-prior.err \
  || qmd_status=$?
```

#### 10d. Persist top-3 into DESIGN.md

Parse the first 3 `qmd://…` URIs (with their Title and Score lines) from `/tmp/qmd-prior.out` using the output-shape rules in `references/solution-search.md`. Then overwrite (not append) the `## Prior Context (QMD)` section of DESIGN.md with the results. If the section does not exist, insert it immediately before `## Requirements`.

```markdown
## Prior Context (QMD)

<!-- Auto-generated by init-workspace step 10. Overwritten on every re-run. -->

Query: `<query_text truncated to 120 chars>` · Collection: `<QMD_COLLECTION>`

1. [<Title>](<qmd://... URI>) — score <pct>%
2. [<Title>](<qmd://... URI>) — score <pct>%
3. [<Title>](<qmd://... URI>) — score <pct>%
```

Empty result set: write the section with a single line `_No prior notes surfaced._`. Fail-open case: write `_QMD skipped: <reason>._`. Either state is a first-class outcome — the section always exists after init-workspace, so `/finish` and the step-12 summary can rely on its presence.

**Idempotency**: re-running replaces the section contents in place. Never duplicate the block.

### 11. Create Task List

Create implementation tasks that collectively satisfy the `## Acceptance Criteria` contract in DESIGN.md. ACs define *what must be true when done*; tasks define *how to get there* — every task traces to the AC(s) it advances, and every AC must be covered.

**Before creating tasks**:
1. Call `TaskList` to check for existing tasks
2. If tasks already exist, skip creation (idempotency)
3. If no tasks exist, proceed with decomposition

**Select decomposition source** (first match wins):

1. **PLAN.md** — If a `PLAN.md` exists in the workspace root (produced by `/claude-skills:planning-workflow`), use it as the primary source for implementation phases and edge cases. The DESIGN.md AC section remains the done-contract; reconcile PLAN.md's checkable items against it.
2. **DESIGN.md** — Fallback when no PLAN.md exists. Decompose from the `## Acceptance Criteria` section, consulting Requirements for context (per design: Requirements are the "why", ACs are the contract).

```
Check for PLAN.md:
  Glob(pattern: "PLAN.md", path: "<workspace-root>")

If PLAN.md exists:
  Read PLAN.md
  Extract tasks from checkable criteria ([ ] items) and implementation phases
  Map each task to the DESIGN.md AC(s) it advances

If no PLAN.md:
  Read DESIGN.md ## Acceptance Criteria (contract) and ## Requirements (context)
  For each AC, determine the implementation steps that make it true
  Group related steps into coherent tasks
```

**Decomposition approach** (applies to both sources):
- Group related steps into coherent tasks
- Order tasks by dependency (earlier tasks should enable later ones)
- Trace every task to the AC(s) it advances; include R-IDs only where they add context

**Task creation**:
For each task, call `TaskCreate` with:
- `subject`: Imperative form (e.g., "Implement issue fetching for GitHub")
- `description`: Detailed description including implementation hints and relevant context, **ending with a `Satisfies: AC-N[, AC-M]` line** naming the AC(s) this task advances. Auto-advance uses these lines to check off criteria as tasks complete.
- `activeForm`: Present continuous (e.g., "Implementing issue fetching")

**AC coverage check** — decomposition is not complete until every AC is accounted for:

```
For each AC-N in DESIGN.md ## Acceptance Criteria:
  If no created task's description contains "AC-N" in its Satisfies line:
    Either create a task covering it,
    or mark it explicitly deferred in DESIGN.md:
      - [ ] **AC-N**: <criterion> _(deferred: <reason>)_
```

An uncovered, undeferred AC is a decomposition bug — it guarantees either a blocked completion gate or silent scope loss.

**Coordinator sync**: For each task created via `TaskCreate`, also call `coord_create_task` with the task subject when coordinator env vars are set. Failures are non-blocking — warn and continue with native task tools.

**Set dependencies** using `TaskUpdate` with `addBlockedBy` where tasks have ordering constraints.

**Standard completion tasks (doc and demo)**:
PLAN.md includes standard documentation and demo acceptance criteria (added by planning-workflow). When decomposing these into tasks:
- Create a **documentation task** with subject "Update documentation to reflect changes" — the agent updates DESIGN.md, README, docs/, or inline docs as appropriate for the work performed.
- Create a **demo task** with subject "Perform interactive walkthrough to validate deliverable" — the agent performs a live walkthrough of the delivered work using browser integration/MCP tools to confirm the deliverable is demonstrable.
- Both tasks should have `addBlockedBy` set to all implementation task IDs, so they run after implementation is complete.
- If the PLAN.md criteria already produced equivalent tasks during decomposition, do not create duplicates.
- If DESIGN.md contains doc/demo ACs, give these tasks the matching `Satisfies: AC-N` line; otherwise they carry no Satisfies line (they serve the standard criteria, not the contract).

<!-- IMPLEMENTED: REC-001 - Init-workspace consumes PLAN.md for task decomposition -->

### 12. Display Summary and Review Gate

Print a summary of everything that was initialized, then ask the user to approve the task list before auto-advance begins.

```
## Workspace Initialized

**Issue**: <issue title> (<source>)
**Source**: <PLAN.md | DESIGN.md> (which document drove task decomposition)

**CLAUDE.md**: <enriched | unchanged>
**DESIGN.md**: <enriched | unchanged>

**Requirements**: <N requirements extracted>

**Existing solutions**: <N relevant | none found>
<solution summaries if any>

**Tasks created**: <N tasks>
<task list with subjects and dependencies>
```

**Review gate**: After displaying the summary, ask the user to approve:

```
AskUserQuestion: "Review the task list above. Ready to start auto-advance?"
  Options:
    - "Start auto-advance" → proceed to step 13
    - "Edit tasks first" → user modifies tasks via TaskUpdate/TaskCreate, then re-ask
    - "Stop here" → end init-workspace without entering auto-advance
```

**Skip review gate when**: The workspace CLAUDE.md contains an `## Auto-Advance` section (indicates the user opted into autonomous mode at workspace creation). In this case, display the summary and proceed directly to step 13 without asking.

### 13. Trigger Auto-Advance

After approval (or auto-approval via Auto-Advance section), load and execute the auto-advance operation:

```
Read: skills/task-workflow/operations/auto-advance.md
```

Execute the auto-advance operation. Its entry guard (step 1) handles all edge cases:
- Fresh init with new tasks → enters loop
- Re-run with partially complete tasks → skips (tasks already exist from step 11, auto-advance resumes from current state)
- Re-run with all tasks complete → outputs summary and stops

**Skip condition**: If step 11 was skipped because tasks already existed AND any task is already `completed`, do not trigger auto-advance. This prevents re-triggering the loop on idempotent re-runs of `/init-workspace` mid-session. The user can resume auto-advance by starting a new conversation in the work session.

## Idempotency

Re-running `/init-workspace` is safe:

| Scenario | Behavior |
|----------|----------|
| Issue data changed | Re-fetches but only updates placeholder sections |
| Manual edits in CLAUDE.md | Preserved (non-placeholder detection) |
| Manual edits in DESIGN.md | Preserved (non-placeholder detection) |
| Acceptance Criteria edited or checked off | Preserved — IDs never renumbered, boxes never reset; new criteria append only |
| Tasks already exist | Skips task creation |
| Solutions search | Always runs (read-only) |
| New sections added manually | Preserved |

## Examples

### GitHub issue workspace

```
User: /init-workspace

Reading workspace files...
  DESIGN.md: 95: Define init-workspace command
  CLAUDE.md: GitHub Issue: pfeff/cursor-rules#95

Fetching GitHub issue pfeff/cursor-rules#95...
  Title: Define init-workspace command
  Labels: enhancement, tooling
  Body: 47 lines

Enriching CLAUDE.md...
  Description: updated from issue body
  Links: added issue URL

Enriching DESIGN.md...
  Requirements: 7 requirements extracted
  Architecture: populated from issue technical context
  Design Decisions: 2 decisions from issue comments

Searching existing solutions (qmd query, collection=work-notes)...
  No existing notes surfaced.

Creating task list...
  Task 1: Add Jira Ticket field to DESIGN.md template
  Task 2: Write init-workspace operation doc
  Task 3: Register init-workspace in SKILL.md
  Task 4: Add allowed-prompts for gh and acli
  Task 5: Test init-workspace on current workspace

Next steps:
  - Review DESIGN.md for accuracy
  - Run /next-task to begin implementation
```

### Jira ticket workspace

```
User: /init-workspace

Reading workspace files...
  DESIGN.md: DO-242: Fix authentication timeout
  DESIGN.md: Jira Ticket: DO-242
  CLAUDE.md: No GitHub Issue found

Fetching Jira ticket DO-242...
  Summary: Fix authentication timeout in API gateway
  Components: API, Auth
  Description: 23 lines

Enriching CLAUDE.md...
  Description: updated from ticket body

Enriching DESIGN.md...
  Requirements: 3 requirements extracted
  Architecture: placeholder (insufficient context)

Searching existing solutions (qmd query, collection=work-notes)...
  Query: "Fix authentication timeout in API gateway. <description>"
  Top 3:
    1. qmd://work-notes/notes/2026/01/2026-01-15-auth-token-expiry-race.md (score 87%)
       Title: Auth token expiry race in API gateway
    2. qmd://work-notes/notes/2026/02/2026-02-01-gateway-connection-pool.md (score 71%)
       Title: Gateway connection-pool saturation under retry storms
    3. qmd://work-notes/notes/2026/03/2026-03-11-jwt-clock-skew-401s.md (score 62%)
       Title: JWT exp clock-skew 401s on pipeline agents

Interviewing for gaps...
  Q: "What components does this change affect? Any architectural constraints?"
  A: (user provides answer)

  Architecture: updated from interview

Creating task list...
  Task 1: Investigate auth timeout root cause
  Task 2: Implement fix in API gateway
  Task 3: Add timeout regression test

Next steps:
  - Review DESIGN.md for accuracy
  - Run /next-task to begin implementation
```

### Re-run (idempotent)

```
User: /init-workspace

Reading workspace files...
  DESIGN.md: 95: Define init-workspace command
  CLAUDE.md: GitHub Issue: pfeff/cursor-rules#95

Fetching GitHub issue pfeff/cursor-rules#95...

Enriching CLAUDE.md...
  Description: unchanged (non-placeholder content)
  Links: unchanged (already present)

Enriching DESIGN.md...
  Requirements: unchanged (non-placeholder content)
  Architecture: unchanged (non-placeholder content)
  Design Decisions: unchanged (non-placeholder content)

Checking task list...
  5 tasks already exist, skipping creation

Workspace already initialized. No changes made.
```

## Integration Points

- **Precondition**: Workspace created by `/create-workspace`
- **Successor**: `/next-task` to begin implementation
- **Issue sources**: `gh` CLI (GitHub), `acli` (Jira)
- **Task tracking**: Claude Code native `TaskCreate`, `TaskList`, `TaskUpdate`
- **Coordinator API** (optional): `COORDINATOR_URL`/`COORDINATOR_TOKEN`/`COORDINATOR_MISSION_ID` — mirrors task creation to coordinator when set
- **File editing**: Claude Code native `Read`, `Edit`, `Write` tools
