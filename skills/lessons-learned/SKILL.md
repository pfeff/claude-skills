---
name: lessons-learned
description: Interactive retrospective discussion about session problems, generating actionable recommendations
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
version: 1.2.1
---

# Lessons Learned Skill

Interactive retrospective that surfaces problems from the current session, discusses them collaboratively with the user, and captures agreed-upon findings and recommendations.

## Core Concepts

**Interactive Process**:
1. **Surface Problems** - Identify friction points and present for discussion
2. **Discuss Each Problem** - Collaborative root cause analysis with user
3. **Agree on Recommendations** - Synthesize and confirm with user
   - 3b: Propose CLAUDE.md updates
   - 3c: Identify permission whitelist candidates
   - 3d: Bridge to solution docs (problems with concrete fixes → `/claude-skills:compound`)
4. **Write Output** - Capture agreed findings in Obsidian note

**Interaction Model**: This is a **conversation, not a report**. Engage the user at each phase. Wait for their input before proceeding. Let them steer which problems to explore and how deep to go.

**Output**: Obsidian note capturing discussed problems, agreed root causes, and confirmed recommendations. Optionally also creates solution docs via `/claude-skills:compound` for problems with concrete, reusable fixes.

**Implementation Path**: Skill/command improvements are submitted via PR to the `claude-skills` repo. (Skills were previously symlinked from `pfeff/cursor-rules`, which is now deprecated.)

**Target Duration**: ~15 minutes

## Operations

### 1. Single Session Analysis (Default)

**When**: User requests `/claude-skills:lessons-learned` to analyze current session

**Implementation**: Load `operations/single-session-analysis.md`

**Quick summary**: Surface problems, discuss interactively with user, agree on recommendations, create Obsidian note

### 2. Pattern Aggregation

**When**: User requests `/lessons-learned --aggregate` or wants to identify recurring patterns across sessions

**Implementation**: Load `operations/aggregate-patterns.md` for detailed steps

**Quick summary**: Scan historical lessons learned files, extract patterns/anti-patterns/recommendations, aggregate by frequency, surface top improvement opportunities. Compares against previous aggregation to track effectiveness of skill improvements.

## Execution

When this skill is invoked:

**Step 1**: Determine operation based on arguments

| Arguments | Operation |
|-----------|-----------|
| (none) | Single session analysis |
| `--aggregate` | Pattern aggregation across sessions |

**Step 2**: Load appropriate operation file

```
Read(file_path: "${CLAUDE_PLUGIN_ROOT}/skills/lessons-learned/operations/{operation}.md")
```

**Step 3**: Execute operation steps interactively (wait for user input between phases)

**Step 4**: Create output note in Obsidian vault (only after user confirms recommendations)
- **Before writing**: Consult `obsidian-notes` skill for frontmatter standards (tags vs keywords, required tags)
- Path: `Generated/YYYYMMDDHHmm-Lessons Learned - {topic}.md`
- Format: Structured markdown with frontmatter per obsidian-notes conventions
- Content: Problems discussed, agreed root causes, confirmed recommendations

## Options

| Option              | Type    | Default | Description                                |
| ------------------- | ------- | ------- | ------------------------------------------ |
| `--aggregate`       | boolean | false   | Aggregate patterns across historical sessions |
| `--focus`           | string  | all     | Focus area: efficiency/workflow/commands   |
| `--include-summary` | boolean | false   | Include detailed conversation summary      |
| `--verbose`         | boolean | false   | Show detailed analysis with supporting data|
| `--limit`           | int     | 20      | Max files to analyze (with --aggregate)    |
| `--since`           | date    | none    | Only analyze files after date (--aggregate)|
| `--min-frequency`   | int     | 2       | Min occurrences to include (--aggregate)   |

## Output Format

Creates Obsidian note in vault with:

**Structure**:
- Session Overview (date, duration, tasks completed)
- Problems Discussed (with root causes from Five Whys analysis)
- Recommendations (confirmed by user)
- Positive Patterns (what worked well)
- Action Items (agreed-upon next steps)

**Location**: `Generated/YYYYMMDDHHmm-Lessons Learned - {topic}.md`

**Frontmatter**: Follow `obsidian-notes` skill conventions:
- Required tag: `generated_note`
- Keywords: Use wikilinks with capitalized, space-separated terms (e.g., `"[[Lessons Learned]]"`, `"[[Workflow Improvement]]"`)

## Five Whys Strategy

The Five Whys is the core analytical technique for this skill. Apply it conversationally during Phase 2 for each problem discussed:

**Approach**:
- Start from verifiable facts — errors, logs, observable behavior
- Progress through system layers: Symptom → Tool → Platform → Process → Organization
- Ask "why" naturally in conversation — don't rigidly force five levels
- Stop when you reach a cause that is **actionable**, **preventable**, and **generalizable**
- Engage the user at each level — they often have context Claude lacks

**When to apply**:
- Every problem discussed in Phase 2 gets at least lightweight Five Whys treatment
- Significant bottlenecks (>10 min impact) get deeper analysis
- Skip only when root cause is immediately obvious to both parties

**Example conversational flow**:
```
"The deploy script failed three times before we found the issue.
 Why did it fail? — Missing env var.
 Why was it missing? — The skill doesn't document required vars.
 Why not? — No reference section for environment setup.
 → Fix: Add env requirements to the skill's references/"
```

## Common Patterns

**Problem Categories** (what to surface in Phase 1):
- Tasks that took longer than expected
- Approaches that didn't work on first attempt
- Unexpected errors or blockers
- Places where Claude went down the wrong path
- Missing information that caused rework
- Tools or skills that didn't behave as expected
- Repeated manual approvals for the same tool/command (permission whitelist candidates)

**Recommendations** (focused on skills/commands/agents):
- **Priority**: High / Medium / Low
- **Effort**: Quick (<30m) / Medium (30-120m) / Complex (>2h)
- **Impact**: High / Medium / Low
- **Category**: Workflow / Commands / Utilities / Skills / Documentation / Permission Whitelist / User Practices
- **Target**: File path in `claude-skills` repo
- **Implementation**: Via PR to `claude-skills`

## Progressive Disclosure

Load operation details on-demand:

**Operations**:
- `operations/single-session-analysis.md` - Interactive retrospective with Five Whys discussion
- `operations/aggregate-patterns.md` - Pattern aggregation across historical sessions

## Error Handling

**No conversation context**: Display message "No conversation to analyze."

**Obsidian vault not found**: Fall back to `docs/lessons-learned/` directory

**Insufficient data**: Create partial report with available data

**Analysis fails**: Create partial report with completed phases, log errors

## Integration Points

- **Task Progress Tracker**: Extract task completion metrics
- **Change Analytics**: Detect conversation patterns
- **Content Summarizer**: Compress analysis into concise insights
- **obsidian-notes skill**: Frontmatter standards, tag vocabulary, keyword format (must load before writing)
- **compound skill**: Solution doc bridge — Phase 3d creates searchable solution docs for problems with concrete fixes

## See Also

- `/obsidian-notes` - Note conventions and frontmatter standards (required before writing)
- `/analyze-project` - Parallel architecture analysis
- `/create-task` - Interactive task definition
- `/status` - Current workflow progress
- `/claude-skills:compound` - Document solved problems as searchable solution docs (Phase 3d bridge target)
- `/claude-skills:self-improvement` - Apply recommendations to skills
- `self-improvement/references/improvement-workflow.md` - Complete improvement cycle
- `improvement-loop` - Reads this skill's retro artifacts as one of its
  experience sources and hands actionable findings to `self-improvement` as
  PR-gated changes
