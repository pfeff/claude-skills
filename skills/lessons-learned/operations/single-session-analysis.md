# Single Session Analysis Operation

**When**: User requests `/claude-skills:lessons-learned` to analyze current conversation session

## Purpose

Facilitates an interactive retrospective discussion about problems encountered during the session. Surfaces issues for collaborative analysis with the user, then captures agreed-upon findings and recommendations in an Obsidian note.

## Interaction Model

This operation is a **conversation, not a report**. The flow alternates between Claude's observations and user input. Do not run all phases silently and dump a report — engage the user at each stage.

## Execution

### Phase 1: Surface Problems (~3 min)

Review the conversation context and identify the **problems, friction points, and surprises** from the session. Present them as a concise numbered list for discussion.

**Scan FEEDBACK.md** (if present in workspace):

```
Glob(pattern: "FEEDBACK.md", path: "<workspace-root>")
```

If found, read it and extract non-empty entries. Each entry becomes a candidate problem alongside conversation-derived ones. Deduplicate — if a FEEDBACK.md entry describes the same friction visible in the conversation, merge them (prefer the richer description).

**What to surface**:
- Tasks that took longer than expected (and why)
- Approaches that didn't work on first attempt
- Unexpected errors or blockers
- Moments of confusion or ambiguity
- Places where Claude went down the wrong path
- Missing information that caused rework
- Tools or skills that didn't behave as expected
- Repeated manual approvals for the same tool/command (permission whitelist candidates)
- Command friction, tool gaps, and repeated patterns from FEEDBACK.md

**Present to user**:
```
Here are the problems and friction points I noticed in this session:

1. [Problem description] — [brief context of what happened]
2. [Problem description] — [brief context]
3. ...

Which of these do you want to dig into? Anything I missed?
```

**Wait for user response.** The user may:
- Select specific items to discuss
- Add problems Claude didn't notice
- Reframe or correct Claude's characterization
- Skip items they consider unimportant

### Phase 2: Discuss Each Problem (~5-7 min)

For each problem the user wants to discuss, have a focused conversation:

**For each problem, use Five Whys to find the root cause**:

1. **Describe what happened** — Walk through the sequence of events concisely
2. **Start the Five Whys** — State the first "why" based on observable facts, then ask the user's perspective
3. **Drill deeper together** — Progress through layers: Symptom → Tool → Platform → Process → Organization. At each level, share your hypothesis and invite the user to confirm, correct, or add context
4. **Arrive at root cause** — Stop when you reach a cause that is **actionable**, **preventable**, and **generalizable**. State it clearly
5. **Propose a fix** — Suggest how to prevent recurrence, focused on skill/command/agent improvements
6. **Get user agreement** — Confirm the problem, root cause, and proposed fix before moving on

**Five Whys guidance**:
- Every problem gets Five Whys treatment — this is the core analytical method
- Follow the natural thread; you don't need exactly five levels, but always push past the surface symptom
- The user often has context Claude lacks — ask at each level rather than assuming
- For minor issues, 2-3 levels may suffice; for significant bottlenecks, go deeper
- Progress through system layers: Symptom → Tool → Platform → Process → Organization

**Example**:
```
Problem: Deploy script failed three times before finding the issue

Why did it fail? — Missing env var (SYMPTOM)
Why was it missing? — The skill doesn't document required vars (TOOL)
Why doesn't it? — No reference section for environment setup (PLATFORM)
Why not? — Skill was written without considering env dependencies (PROCESS)
→ Root cause: Skills lack a standard section for env requirements
→ Fix: Add env requirements template to skill-creator
```

**Keep it natural**: This is a discussion, not an interrogation. Let the user steer depth.

### Phase 3: Agree on Recommendations (~3 min)

After discussing all selected problems, synthesize recommendations:

**Present a summary**:
```
Based on our discussion, here's what I'd recommend:

1. [Recommendation] — addresses [problem]
   Target: [file path in claude-skills repo]
   Effort: Quick/Medium/Complex

2. [Recommendation] — addresses [problem]
   ...

Also noting these positive patterns worth keeping:
- [What worked well]

Does this capture it? Anything to add or change?
```

**Wait for user confirmation** before writing the note.

#### Recommendation Focus: Skills, Commands, and Agents

**Primary goal**: Generate recommendations that improve Claude's capabilities through skills, commands, and agents — NOT recommendations about external applications or user projects.

**INCLUDE** recommendations that:
- Enhance existing skills (`${CLAUDE_PLUGIN_ROOT}/skills/`)
- Add new slash commands (`~/.claude/commands/`)
- Improve agent configurations
- Add new operations to existing skills
- Improve skill documentation for better context loading
- Add shell script utilities in skill `bin/` directories

**EXCLUDE** recommendations that:
- Are about the user's application code (bugfixes, features, refactoring)
- Require changes to external systems (AWS, Octopus, databases)
- Are operational tasks (restart services, clean up resources)

**EXCEPTION — Project Docs**: Findings that prevent rediscovery (dev env quirks, non-obvious patterns, setup gotchas) belong in repo or global CLAUDE.md. See Phase 3b.

**Transform where possible**: If an insight could become a skill improvement, frame it that way.
- Instead of "Add monitoring to Tentacle" → "Add Tentacle diagnostics to octopus skill"
- Instead of "Document IAM requirements" → "Add IAM reference to aws skill"

#### Categorize Recommendations

| Category | Description | Target Location |
|----------|-------------|-----------------|
| Workflow | Process improvements | `skills/*/operations/*.md` |
| Commands | Slash command enhancements | `commands/*.md` |
| Utilities | Script or tool improvements | `skills/*/bin/*` |
| Skills | New skill capabilities | `skills/*/SKILL.md` |
| Documentation | Skill/command doc gaps | `skills/*/references/*.md` |
| Project Docs | Durable findings for a repo | Repo `CLAUDE.md` or `~/.claude/CLAUDE.md` |
| Permission Whitelist | Tool/command approval patterns to auto-approve | `.claude/settings.json` or `~/.claude/settings.json` |
| User Practices | Behavioral changes | (no target - lowest priority) |

> **Note**: Target locations are paths within the `claude-skills` repository. Improvements are implemented via PR to that repo. Files in `${CLAUDE_PLUGIN_ROOT}/skills/` are loaded from this repo. (Previously, `pfeff/cursor-rules` served this role.)

#### Validate Target Paths

**Before including any recommendation**, verify the target file or directory exists in the claude-skills repo:

```
# For skill enhancements
Glob(pattern: "skills/<skill-name>/SKILL.md", path: "${CLAUDE_PLUGIN_ROOT}")

# For command additions
Glob(pattern: "commands/*.md", path: "${CLAUDE_PLUGIN_ROOT}")

# For operation files
Glob(pattern: "skills/<skill-name>/operations/*.md", path: "${CLAUDE_PLUGIN_ROOT}")
```

**If target doesn't exist**:
- Check for similar paths (typos, renamed files)
- Verify the skill/command exists before recommending enhancements
- If skill doesn't exist, recommend creating it first (separate recommendation)
- Never include recommendations targeting non-existent files

### Phase 3b: Propose CLAUDE.md Updates

After agreeing on recommendations, check whether any findings should be persisted to CLAUDE.md files so they aren't rediscovered in future workspaces.

**What qualifies as a CLAUDE.md finding**:
- Dev environment quirks (required env vars, setup gotchas)
- Non-obvious patterns or conventions discovered during implementation
- Workflow requirements that Claude can't infer from code

**What does NOT belong in CLAUDE.md**:
- Task-specific notes or implementation plans (use PLAN.md)
- Information already evident from reading the code
- Temporary workarounds that will be removed
- Session history or progress notes (use PROGRESS.md)
- Design decisions or architectural decisions (use DECISIONS.md)
- Cycle retrospectives (use memory/lessons_cycle_<N>.md)

**Size discipline**: CLAUDE.md loads into every message in every conversation. Target <5 KB for project CLAUDE.md files. If a finding would push CLAUDE.md over budget, route it to the appropriate sibling file instead.

**Discovery process**:

1. **Identify candidate findings** from the problems discussed in Phase 2
2. **Determine target CLAUDE.md** for each finding:

| Scope | Target | When to use |
|-------|--------|-------------|
| Repo-specific | `<repo>/CLAUDE.md` | Dev setup, repo conventions, testing patterns |
| Cross-project | `~/.claude/CLAUDE.md` | Workflow practices, tool usage, global preferences |

3. **Check that the target file exists** before proposing an update:

```
# For repo CLAUDE.md — MUST exist already; never create one
Glob(pattern: "CLAUDE.md", path: "<repo-root>")

# Global CLAUDE.md — always exists
Read(file_path: "~/.claude/CLAUDE.md")
```

**CRITICAL**: Do NOT propose creating a CLAUDE.md in a repo that does not already have one. The repo owner may have intentionally excluded it. Only propose additions to existing files.

4. **Present proposed updates to user**:

```
I'd also suggest persisting these findings to CLAUDE.md so they
aren't rediscovered in future workspaces:

Repo: <repo-name>/CLAUDE.md
+ Add to "Development Commands" section:
+   - Run tests with docker DB: `USER=postgres mix test`

Global: ~/.claude/CLAUDE.md
+ (none)

Want me to include these as action items?
```

5. **Wait for user confirmation** before including in the output note

**If no findings qualify**: Skip this phase silently — don't force findings that aren't there.

### Phase 3c: Identify Permission Whitelist Candidates

After discussing problems and CLAUDE.md updates, check whether any tool/command approval patterns should be whitelisted in `.claude/settings.json` to reduce supervision friction.

**What to look for**:
- Tools approved multiple times in the session (Read, Glob, Grep, Bash commands)
- Bash commands with consistent patterns (e.g., `pytest`, `go test`, `git status`)
- Operations that are safe and read-only but required manual approval

**Discovery process**:

1. **Scan session for repeated approvals** of the same tool or command pattern
2. **Determine scope** for each candidate:

| Scope | Target | When to use |
|-------|--------|-------------|
| All projects | `~/.claude/settings.json` | Safe, universal operations (e.g., `Bash(pytest:*)`) |
| Single repo | `.claude/settings.json` | Project-specific scripts or commands |

3. **Format as allowlist entries** using Claude Code syntax:

| Pattern | Example |
|---------|---------|
| Tool name | `Read`, `Glob`, `Grep` |
| Bash with prefix | `Bash(pytest:*)`, `Bash(git status:*)` |
| Bash with script | `Bash(./scripts/test.sh:*)` |

4. **Present to user**:

```
I noticed these tools/commands were approved repeatedly this session.
Consider whitelisting them in settings.json:

User-level (~/.claude/settings.json):
  + Bash(pytest:*)
  + Bash(go test:*)

Project-level (.claude/settings.json):
  + Bash(./scripts/deploy-preview.sh:*)

Want me to include these as action items?
```

5. **Wait for user confirmation** before including in the output note

**If no candidates found**: Skip this phase silently.

### Phase 3d: Solution Doc Bridge

After agreeing on recommendations, check whether any discussed problems have a clear root cause AND a concrete fix that would help future agents. These are candidates for solution documentation via `/claude-skills:compound`.

**What qualifies as a solution doc candidate**:
- Problem has an identified root cause (from Five Whys)
- A concrete fix was applied or agreed upon (not just a process recommendation)
- The fix is reusable — another agent hitting the same problem would benefit from finding it
- The problem is technical, not purely procedural

**What does NOT qualify**:
- Process-only recommendations ("we should do X differently") — these stay as REC-items
- Problems without a clear fix yet (still under investigation)
- One-off issues unlikely to recur

**Discovery process**:

1. **Review Phase 2 problems** for solution-doc candidates
2. **For each candidate**, summarize:
   - Problem + root cause (from Five Whys)
   - The fix that was applied
   - Which repo it affects

3. **Present to user**:

```
These problems have concrete fixes that could help future agents:

1. [Problem title] — [root cause] → [fix applied]
   Would file in: <repo>/docs/solutions/<category>/

2. [Problem title] — ...

Want me to capture any of these as solution docs?
```

4. **Wait for user response**. The user may:
   - Select which problems to capture
   - Skip all (no solution docs needed)
   - Adjust the framing

5. **For each selected problem**, invoke the compound skill's document-solution operation:
   - Load `${CLAUDE_PLUGIN_ROOT}/skills/compound/operations/document-solution.md`
   - Use the Five Whys analysis from Phase 2 as input context (problem, root cause, fix)
   - Skip the gathering step (context already available from the retrospective)
   - Write the solution doc to `docs/solutions/<category>/`
   - Note the created file path for inclusion in Phase 4 output

6. **Record created solution docs** for the Phase 4 output note (see Solution Docs section in template below)

**If no candidates found**: Skip this phase silently.

### Phase 4: Write Output Note

Only after the user confirms the recommendations.

**REQUIRED Pre-flight Check**:
```
Read(file_path: "~/.claude/skills/obsidian-notes/SKILL.md")
```
This ensures correct filename format, frontmatter structure, and required tags.

**Tag constraint**: Only use note-type tags from the approved vocabulary in `obsidian-notes/SKILL.md`. Lessons learned notes MUST include both `generated_note` and `lessons_learned` tags. Do NOT invent new tags. Use `keywords:` with wikilinks for all topic-specific terms. Keywords must be capitalized and space-separated (e.g., `"[[Lessons Learned]]"`, `"[[Workflow Improvement]]"`).

**Location**: `Generated/YYYYMMDDHHmm-Lessons Learned - {topic}.md`

**Template** (follows obsidian-notes conventions):

```markdown
---
date: "[[YYYY-MM-DD]]"
month: "[[YYYY-MM]]"
tags:
  - generated_note
  - lessons_learned
keywords:
  - "[[Lessons Learned]]"
  - "[[Domain Specific Term]]"
---

# Lessons Learned - {Topic}

## Session Overview

- **Date**: YYYY-MM-DD
- **Duration**: [estimated]
- **Primary Task**: [description]
- **Completion**: [status]

## Problems Discussed

### [Problem Title]

**What happened**: [concise description of the problem]

**Five Whys**:
1. Why? [first level — symptom]
2. Why? [second level — tool/immediate cause]
3. Why? [deeper level — platform/process]
4. Why? [if applicable]
5. Why? [if applicable]

**Root cause**: [agreed-upon actionable, preventable cause]

**Resolution**: [what was decided]

### [Problem Title]
...

## Recommendations

#### REC-001: [Title]
**Category**: [category]
**Effort**: [effort]
**Impact**: [HIGH/MEDIUM/LOW]
**Target**: [file path in claude-skills repo]

[Description of the issue and proposed solution]

**Implementation**: PR to `claude-skills` — [specific steps or changes needed]

---

#### REC-002: [Title]
...

## Positive Patterns

- [What worked well and should be continued]

## CLAUDE.md Updates

Findings to persist so they aren't rediscovered in future workspaces.

### [Repo or Global]: [target file]

**Section**: [target section in CLAUDE.md]
**Addition**:
> [content to add]

**Status**: [ ] Proposed / [ ] Applied

## Permission Whitelist Candidates

Tools/commands approved repeatedly that should be added to `.claude/settings.json`.

### User-level (`~/.claude/settings.json`)
- [ ] `Bash(example:*)` — [reason]

### Project-level (`.claude/settings.json`)
- [ ] `Bash(./scripts/example.sh:*)` — [reason]

**Status**: [ ] Proposed / [ ] Applied

## Solution Docs Created

Problems captured as searchable solution documents for future agent discovery.

- [ ] `<repo>/docs/solutions/<category>/<filename>` — [problem title]

**Status**: [ ] Created / [ ] Committed

## Action Items

- [ ] [Agreed-upon action 1]
- [ ] [Agreed-upon action 2]

## Related

- [[Previous lessons learned]]
- [[Relevant documentation]]
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--focus` | string | all | Focus area: efficiency/workflow/commands |
| `--include-summary` | boolean | false | Include detailed conversation summary |
| `--verbose` | boolean | false | Show detailed analysis with supporting data |

## Error Handling

**No conversation context**: Display "No conversation to analyze."

**Obsidian vault not found**: Fall back to `docs/lessons-learned/` directory

**Insufficient data**: Create partial report with available data

**Analysis incomplete**: Create partial report with completed phases, note gaps
