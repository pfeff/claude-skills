---
name: self-improvement
description: Read recommendations from lessons learned documents and incrementally improve skills, commands, and agents. Use when user asks to improve skills from lessons, apply recommendations, or requests "/claude-skills:self-improvement".
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
  - TaskList
  - TaskGet
  - TaskUpdate
  - Task
version: 1.2.1
---

# Self-Improvement Skill

Closes the feedback loop between `/claude-skills:lessons-learned` analysis and system enhancement. Reads recommendations from lessons learned documents and incrementally implements improvements to skills, commands, and agents.

## Core Concepts

**Improvement Cycle**:
1. **Scan** - Find pending recommendations from lessons learned files
2. **Analyze** - Assess feasibility and identify target files
3. **Propose** - Generate specific changes for review
4. **Apply** - Implement with user confirmation and traceability

**Safety Model**: All changes require explicit user confirmation before application.

**Traceability**: Each improvement links back to its source REC-ID.

## Design Principles

### Scripts vs Generative Tasks

**Prefer deterministic scripts** for repeatable, precision-critical operations:

| Use Scripts For | Use Claude For |
|-----------------|----------------|
| File parsing and validation | Analyzing patterns and context |
| Structured data extraction | Generating documentation |
| Session/environment setup | Design decisions and tradeoffs |
| Status checks and reporting | Synthesizing recommendations |
| Template expansion | Adapting to novel situations |

**Why**: Scripts provide consistency, testability, and predictable behavior. Claude excels at judgment, synthesis, and handling variability.

**When implementing improvements**:
1. If the task is repeatable and well-defined → create a script
2. If the task requires judgment or varies by context → document guidance for Claude
3. If both → script handles mechanics, Claude handles decisions

**Examples**:
- `validate-tmux-session.sh` - Script checks window names (deterministic)
- `create-tmuxp-session.sh` - Script creates standard layout (repeatable)
- Analyzing lesson patterns - Claude synthesizes (variable, requires judgment)
- Proposing code changes - Claude generates (context-dependent)

## Operations

### 1. List Recommendations (Default)

**When**: User requests `/claude-skills:self-improvement` without arguments

**Implementation**: Load `operations/scan-recommendations.md`

**Quick summary**: Find and display pending skill/command recommendations ranked by priority

### 2. Analyze Recommendation

**When**: User selects a specific REC-ID to investigate

**Implementation**: Load `operations/analyze-improvement.md`

**Quick summary**: Deep analysis of recommendation feasibility, target files, and dependencies

### 3. Propose Changes

**When**: User wants to see proposed edits before applying

**Implementation**: Load `operations/propose-changes.md`

**Quick summary**: Generate diff-style preview of changes with rationale

### 4. Apply Improvement

**When**: User approves proposed changes

**Implementation**: Load `operations/apply-improvement.md`

**Quick summary**: Apply edits with confirmation, bump skill version and update CHANGELOG.md, update source file to mark REC as implemented

## Execution

When this skill is invoked:

**Step 1**: Determine operation based on arguments

| Arguments | Operation |
|-----------|-----------|
| (none) | List pending recommendations |
| `REC-XXX` | Analyze specific recommendation |
| `REC-XXX --propose` | Generate proposed changes |
| `REC-XXX --apply` | Apply with confirmation |
| `--batch` | Process multiple recommendations |

**Step 2**: Load appropriate operation file

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/self-improvement/operations/{operation}.md")
```

**Step 3**: Execute operation steps

**Step 4**: Report results and next actions

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `REC-XXX` | string | none | Target specific recommendation by ID |
| `--propose` | boolean | false | Show proposed changes without applying |
| `--apply` | boolean | false | Apply changes (requires confirmation) |
| `--batch` | boolean | false | Process multiple recommendations |
| `--category` | string | all | Filter by category (Workflow/Commands/Utilities/Skills) |
| `--priority` | string | all | Filter by priority (HIGH/MEDIUM/LOW) |
| `--limit` | int | 10 | Max recommendations to display |
| `--dry-run` | boolean | false | Simulate apply without writing files |

## Batch Mode with Subagent Dispatch

When `--batch` is used, each recommendation analysis is dispatched to a subagent via the dispatch-task operation:

```
Read: skills/task-workflow/operations/dispatch-task.md
Read: skills/task-workflow/references/subagent-dispatch.md
```

### Batch Flow

1. **Scan**: Run `operations/scan-recommendations.md` to find pending recommendations (inline — needs file system access)
2. **Dispatch each**: For each recommendation (up to `--limit`), dispatch a subagent with:
   - `prompt`: The recommendation's source text, target file paths, and `operations/analyze-improvement.md` + `operations/propose-changes.md` instructions
   - `task_subject`: "Analyze: REC-XXX"
   - `max_retries`: 1
3. **Review**: Parent receives each `dispatch_result` and presents the proposal to the user
4. **Apply**: On user confirmation, apply changes inline via `operations/apply-improvement.md`

Dispatching analysis to subagents reduces context window consumption — each subagent reads source files and generates proposals independently. The parent only sees the summarized proposal, not all the intermediate file reads.

### Fallback

If a dispatch returns `status: fallback`, skip that recommendation and report it as "analysis failed — manual review needed."

## Example Usage

```
# List pending recommendations
/claude-skills:self-improvement

# Analyze specific recommendation
/claude-skills:self-improvement REC-001

# See proposed changes
/claude-skills:self-improvement REC-001 --propose

# Apply with confirmation
/claude-skills:self-improvement REC-001 --apply

# Filter by category
/claude-skills:self-improvement --category Workflow --priority HIGH

# Batch mode (with confirmation per item)
/claude-skills:self-improvement --batch --limit 5
```

## Output Format

**List Mode**:
```
## Pending Recommendations

| Priority | REC-ID | Category | Title | Source |
|----------|--------|----------|-------|--------|
| HIGH | REC-001 | Workflow | Add parallel file reading | 20260115-Lessons.md |
| MEDIUM | REC-003 | Commands | Cache git status results | 20260114-Lessons.md |

Found 5 actionable recommendations. Use `/self-improvement REC-XXX` to analyze.
```

**Analyze Mode**:
```
## REC-001: Add parallel file reading

**Source**: 20260115-Lessons Learned - Task Workflow.md
**Category**: Workflow | **Priority**: HIGH | **Effort**: Medium

### Context
[Original recommendation text]

### Target Files
- `skills/task-workflow/operations/workspace-setup.md` (line 45-60)

### Feasibility
- Complexity: Low
- Dependencies: None
- Conflicts: None detected

### Next Steps
Use `--propose` to see specific changes or `--apply` to implement.
```

## Progressive Disclosure

Load operation details on-demand:

**Operations**:
- `operations/scan-recommendations.md` - Find and parse recommendations
- `operations/analyze-improvement.md` - Feasibility analysis
- `operations/propose-changes.md` - Generate specific edits
- `operations/apply-improvement.md` - Apply with confirmation

**References**:
- `references/recommendation-categories.md` - Category to target mapping
- `references/improvement-workflow.md` - Full cycle workflow guidance

## Error Handling

**No recommendations found**: Display "No pending recommendations found. Run `/claude-skills:lessons-learned` to generate."

**Invalid REC-ID**: Display "REC-ID not found. Use `/claude-skills:self-improvement` to list available."

**Target file not found**: Display warning, suggest manual review

**Apply fails**: Rollback changes, display error, preserve original state

## Integration Points

- **lessons-learned skill**: Source of recommendations
- **obsidian-notes skill**: Note creation and updates
- **git skill**: Optional commit after apply
- **Native Task Tools**: Auto-complete tasks containing REC-ID, store source file in task metadata

## See Also

- `/claude-skills:lessons-learned` - Generate recommendations
- `/lessons-learned --aggregate` - Aggregate patterns across sessions
- `references/improvement-workflow.md` - Review cadence and decision criteria
- `improvement-loop` - Invokes this skill's apply machinery from the meta
  pane; drafts each improvement as a PR-gated change against the target
  surface's repo (see `improvement-loop/references/surface-repo-map.md`)
