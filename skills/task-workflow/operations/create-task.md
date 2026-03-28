# Task Creation Operation

Creates task documentation for in-workspace coordination in `docs/tasks/` directory with standardized format.

**Requirements**: Must be run from within an existing workspace (requires DESIGN.md).

## Coordinator Sync (Optional)

If `COORDINATOR_URL`, `COORDINATOR_TOKEN`, and `COORDINATOR_MISSION_ID` are set, also create the task in the coordinator API. This is additive — native `TaskCreate` remains the primary interface.

```bash
# Helper: create task in coordinator
coord_create_task() {
  local objective="$1" status="${2:-pending}"
  if [[ -n "${COORDINATOR_URL:-}" && -n "${COORDINATOR_TOKEN:-}" && -n "${COORDINATOR_MISSION_ID:-}" ]]; then
    curl -s -X POST "${COORDINATOR_URL}/api/missions/${COORDINATOR_MISSION_ID}/tasks" \
      -H "Authorization: Bearer ${COORDINATOR_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"task\":{\"objective\":\"${objective}\",\"status\":\"${status}\"}}"
  fi
}
```

## Parameters

- `--issue <ref>`: GitHub issue reference (number, org/repo#number, or URL)
- `--quick`: Minimal mode (5 questions)
- `--full`: Comprehensive mode (15-20 questions)
- `--preset <type>`: Use preset (bug/feature/refactor/docs/infrastructure)
- `--task-id <id>`: Pre-specify task identifier
- `--headline <text>`: Pre-specify headline
- `--epic <slug>`: Pre-specify epic category
- `--output-dir <path>`: Custom output directory (default: `docs/tasks/`)

## Execution Steps

### 1. Verify Workspace Context

Check for DESIGN.md in current directory:

```bash
if [ ! -f "DESIGN.md" ]; then
  echo "Error: Not in a workspace. DESIGN.md not found."
  echo "This command creates in-workspace task files."
  echo "Use /create-workspace to create a new workspace."
  exit 1
fi
```

### 2. Determine Mode

Ask user or detect from parameters:
- **quick**: 5 questions (~1 min)
- **progressive**: Adaptive 5-11 questions (default)
- **full**: 15-20 questions
- **preset**: Tailored by type

### 2. GitHub Integration (if --issue provided)

```bash
gh issue view <ref> --json title,body,labels,milestone
```

Extract and pre-populate:
- `title` → headline
- `body` → description
- `labels` → tags
- `milestone` → project phase

### 3. Gather Requirements

Use AskUserQuestion for interactive collection:

**Quick Mode (5 questions)**:
1. Task ID (if not from issue)
2. Headline (if not from issue)
3. Epic category
4. Brief description
5. Priority (low/medium/high/critical)

**Progressive Mode (adds 3-6 more)**:
6. Estimated effort
7. Dependencies
8. Acceptance criteria
9. Related tasks (if complex)
10. Technical constraints (if needed)
11. Testing requirements (if needed)

**Full Mode (adds 5-9 more)**:
12. Detailed requirements
13. Milestone breakdown
14. Subtask identification
15. Risk assessment
16. Non-functional requirements
17. Success metrics
18. Rollback plan
19. Documentation needs
20. Review requirements

**Preset Adjustments**:
- `bug`: Add reproduction steps, expected behavior, impact
- `feature`: Add user stories, UX requirements
- `refactor`: Add scope, backward compatibility
- `docs`: Skip technical details, add audience
- `infrastructure`: Add security, performance, operational impact

### 4. Generate Slug

Algorithm:
```
1. Tokenize headline (split on spaces)
2. Filter: Remove articles (a, an, the), prepositions (in, on, at, for, to)
3. Extract: First 2-3 nouns or verbs
4. Transform: Lowercase, join with hyphens
```

Examples:
- "Fix authentication timeout in API" → `fix-auth-timeout`
- "Add user profile editing feature" → `user-profile-edit`
- "Refactor database connection pool" → `refactor-db-pool`

### 5. Create Task File

**Filename**: `docs/tasks/task-{slug}-{YYYY-MM-DD}.md`

**Content Template**:
```markdown
# {TASK-ID}: {HEADLINE}

## Epic
{epic}

## Description
{description}

## Priority
{priority}

## Estimated Effort
{effort}

## Requirements
{requirements}

## Dependencies
{dependencies}

## Acceptance Criteria
- [ ] {criterion-1}
- [ ] {criterion-2}
...

## Technical Notes
{technical-notes}

## Risks
{risks}

## Success Metrics
{metrics}

---

Created: {date}
GitHub Issue: {issue-link if applicable}
```

### 6. Coordinator Sync

If coordinator env vars are set, create the task in the coordinator:

```bash
coord_create_task "${headline}" "pending"
```

Failures are non-blocking — warn and continue.

### 7. Confirm and Report

Display:
```
✓ Task created: docs/tasks/task-{slug}-{date}.md

Task ID: {task-id}
Epic: {epic}
Priority: {priority}

Next steps:
- Review and refine task documentation
- Task file ready for in-workspace coordination
```

## Error Handling

**GitHub CLI not found**:
- Warn user
- Continue without GitHub integration
- Suggest: `brew install gh`

**GitHub auth failed**:
- Warn user
- Suggest: `gh auth login`
- Fall back to manual entry

**Issue not found**:
- Error: "Issue {ref} not found"
- Verify issue number and repository
- Offer to continue without issue

**Output directory not writable**:
- Try to create: `mkdir -p docs/tasks`
- If fails, error and suggest manual creation

**Invalid priority**:
- Show valid options: low, medium, high, critical
- Re-prompt

## Non-Interactive Mode

If all required fields provided via parameters:
- Skip questions
- Validate inputs
- Create file directly

Minimum requirements:
- `--task-id`
- `--headline`
- `--epic`
- `--description`

## Integration Notes

**Preset Defaults**:
```yaml
bug:
  priority: high
  questions: [reproduction, expected, actual, impact]

feature:
  priority: medium
  questions: [user-story, acceptance-criteria, dependencies]

refactor:
  priority: low
  questions: [scope, backward-compat, testing]

docs:
  priority: low
  questions: [audience, format, scope]

infrastructure:
  priority: medium
  questions: [security, performance, rollback]
```

**Output Directory Resolution**:
1. Check `--output-dir` parameter
2. Check `docs/tasks/` in current directory
3. Check project root `docs/tasks/`
4. Create if doesn't exist
5. Error if can't create
