# Workspace Initialization Operation

Populates a workspace with issue/ticket content, enriches CLAUDE.md and DESIGN.md, and creates an implementation task list.

**Requirements**: Must be run from within an existing workspace created by `/create-workspace`.

## Purpose

Bridges the gap between workspace scaffolding (`/create-workspace`) and implementation (`/next-task`). Fetches issue/ticket content, populates workspace documentation with real requirements, and decomposes the work into a task list.

## Coordinator Sync (Optional)

If `COORDINATOR_URL`, `COORDINATOR_TOKEN`, and `COORDINATOR_MISSION_ID` are set, task creation in step 10 will also create tasks in the coordinator. This mirrors the task list to the coordinator for visibility and persistence.

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
   - If None: Skip to step 5 (user interview)

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

### 7. User Interview (Conditional)

Only interview if DESIGN.md still has placeholder sections after issue enrichment.

**Check each section**:
```
For each section in [Requirements, Architecture, Design Decisions]:
  If section content is still a placeholder:
    Ask targeted question(s) about that section
```

**Interview questions by section**:

| Section | Question |
|---------|----------|
| Requirements | "The issue didn't specify clear requirements. What are the key requirements for this task?" |
| Architecture | "What components/systems does this change affect? Any architectural constraints?" |
| Design Decisions | "Are there any design decisions or trade-offs already made for this task?" |

Use AskUserQuestion with relevant options derived from the issue context when possible.

After interview, update DESIGN.md with the responses.

### 8. Sync Worktrees Against Origin

Update all repo worktrees in the workspace against origin before searching for solutions or creating tasks. Stale local state leads to duplicate work (e.g., creating tasks for files that already exist on main).

```
For each repo worktree in the workspace:
  git fetch origin
  git rebase origin/main (or the worktree's upstream branch)
```

Also update the primary repo main clones (under `~/src/github/`) so the solutions search fallback has current data:

```
For each repo with a main clone:
  git -C <main-clone> fetch origin
  git -C <main-clone> pull --rebase origin main
```

**Error handling**: If rebase fails due to conflicts, warn the user and continue with the remaining repos. Stale data is better than blocking initialization entirely.

<!-- IMPLEMENTED: REC-001 - Add repo sync step to init-workspace -->

### 9. Search Existing Solutions

Search `docs/solutions/` across all repo worktrees in the workspace for relevant past solutions before creating the task list. This surfaces institutional knowledge that may inform implementation.

**Identify search paths**:
```
For each subdirectory in the workspace that contains docs/solutions/:
  Add to search paths
Also check the primary repo's main clone for docs/solutions/ (in case the
worktree was freshly created and has no solutions yet)
```

**Extract keywords** from the issue title and body:
- Module/system names (e.g., "PolicyEngine", "Orchestrator")
- Technical terms (e.g., "N+1", "timeout", "authentication")
- Error indicators (e.g., "crash", "slow", "failing")
- Component names (e.g., "supervisor", "adapter", "webhook")

**Search strategy**: Follow the grep-first protocol in `references/solution-search.md`:
1. Stage 1: Grep frontmatter fields (title, tags, symptoms, module, problem_type, component) in parallel
2. Stage 2: Read full content of matched files
3. Always check `critical-patterns.md` regardless of keyword matches

**Report findings**:
- If relevant solutions found: summarize key insights and note which solutions apply
- If no solutions found: state "No existing solutions found" (this is valuable info)
- Include findings in the step 11 summary output

**Idempotency**: This step is read-only and safe to re-run.

### 10. Create Task List

Create implementation tasks from the best available planning artifact.

**Before creating tasks**:
1. Call `TaskList` to check for existing tasks
2. If tasks already exist, skip creation (idempotency)
3. If no tasks exist, proceed with decomposition

**Select decomposition source** (first match wins):

1. **PLAN.md** — If a `PLAN.md` exists in the workspace root (produced by `/claude-skills:planning-workflow`), use it as the primary source. PLAN.md contains refined acceptance criteria, edge case analysis, and checkable items that produce higher-quality task decomposition than raw requirements.
2. **DESIGN.md** — Fallback when no PLAN.md exists. Read the Requirements section and decompose from there.

```
Check for PLAN.md:
  Glob(pattern: "PLAN.md", path: "<workspace-root>")

If PLAN.md exists:
  Read PLAN.md
  Extract tasks from checkable criteria ([ ] items) and implementation phases
  Cross-reference with DESIGN.md requirements for traceability (R-IDs)

If no PLAN.md:
  Read DESIGN.md Requirements section
  For each requirement, determine the implementation steps
  Group related steps into coherent tasks
```

**Decomposition approach** (applies to both sources):
- Group related steps into coherent tasks
- Order tasks by dependency (earlier tasks should enable later ones)
- Include requirement IDs (from DESIGN.md) in task descriptions for traceability

**Task creation**:
For each task, call `TaskCreate` with:
- `subject`: Imperative form (e.g., "Implement issue fetching for GitHub")
- `description`: Detailed description including relevant requirement IDs, acceptance criteria, and implementation hints
- `activeForm`: Present continuous (e.g., "Implementing issue fetching")

**Coordinator sync**: For each task created via `TaskCreate`, also call `coord_create_task` with the task subject when coordinator env vars are set. Failures are non-blocking — warn and continue with native task tools.

**Set dependencies** using `TaskUpdate` with `addBlockedBy` where tasks have ordering constraints.

**Standard completion tasks (doc and demo)**:
PLAN.md includes standard documentation and demo acceptance criteria (added by planning-workflow). When decomposing these into tasks:
- Create a **documentation task** with subject "Update documentation to reflect changes" — the agent updates DESIGN.md, README, docs/, or inline docs as appropriate for the work performed.
- Create a **demo task** with subject "Perform interactive walkthrough to validate deliverable" — the agent performs a live walkthrough of the delivered work using browser integration/MCP tools to confirm the deliverable is demonstrable.
- Both tasks should have `addBlockedBy` set to all implementation task IDs, so they run after implementation is complete.
- If the PLAN.md criteria already produced equivalent tasks during decomposition, do not create duplicates.

<!-- IMPLEMENTED: REC-001 - Init-workspace consumes PLAN.md for task decomposition -->

### 11. Display Summary and Review Gate

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
    - "Start auto-advance" → proceed to step 12
    - "Edit tasks first" → user modifies tasks via TaskUpdate/TaskCreate, then re-ask
    - "Stop here" → end init-workspace without entering auto-advance
```

**Skip review gate when**: The workspace CLAUDE.md contains an `## Auto-Advance` section (indicates the user opted into autonomous mode at workspace creation). In this case, display the summary and proceed directly to step 12 without asking.

### 12. Trigger Auto-Advance

After approval (or auto-approval via Auto-Advance section), load and execute the auto-advance operation:

```
Read: skills/task-workflow/operations/auto-advance.md
```

Execute the auto-advance operation. Its entry guard (step 1) handles all edge cases:
- Fresh init with new tasks → enters loop
- Re-run with partially complete tasks → skips (tasks already exist from step 10, auto-advance resumes from current state)
- Re-run with all tasks complete → outputs summary and stops

**Skip condition**: If step 10 was skipped because tasks already existed AND any task is already `completed`, do not trigger auto-advance. This prevents re-triggering the loop on idempotent re-runs of `/init-workspace` mid-session. The user can resume auto-advance by starting a new conversation in the work session.

## Idempotency

Re-running `/init-workspace` is safe:

| Scenario | Behavior |
|----------|----------|
| Issue data changed | Re-fetches but only updates placeholder sections |
| Manual edits in CLAUDE.md | Preserved (non-placeholder detection) |
| Manual edits in DESIGN.md | Preserved (non-placeholder detection) |
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

Searching existing solutions...
  Searched: cursor-rules/docs/solutions/ (0 files)
  Critical patterns: checked (no matches)
  No existing solutions found.

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

Searching existing solutions...
  Searched: api-gateway/docs/solutions/ (12 files)
  Keywords: authentication, timeout, API, gateway
  Found 2 relevant solutions:
    - runtime-errors/2026-01-15-auth-token-expiry-race.md (high severity)
    - performance-issues/2026-02-01-gateway-connection-pool.md (medium)
  Critical patterns: checked (1 match: CP-3 timeout handling)

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
