---
name: review
description: Spawn parallel specialist review agents (security, simplicity, architecture, correctness) against a PR or branch diff. Synthesizes findings by severity. Use when the user requests a code review or invokes /review.
argument-hint: "[PR number, branch name, or blank for current branch]"
allowed-tools: Bash(git diff:*), Bash(gh pr diff:*), Bash(git rev-parse:*), Bash(git branch:*), Bash(git log:*), Bash(git merge-base:*), Bash(mkdir:*), Bash(gh api:*), Bash(gh repo view:*), Task, Read, Write, Grep, Glob
version: 0.3.0
---

# Review Skill

Parallel multi-agent code review. Spawns security, simplicity, architecture, and correctness agents against a diff, then consolidates findings.

## Invocation

```
/review              # Current branch vs main
/review 42           # PR #42
/review feature-xyz  # Branch feature-xyz vs main
```

## Execution Flow

1. **Determine diff source** from `$ARGUMENTS`
2. **Acquire diff** via git or gh
3. **Spawn 4 review agents** in parallel using Task tool
4. **Synthesize and classify findings** (blocking vs advisory)
5. **Persist results** to `.claude/reviews/latest.md`
6. **Display results** to user
7. **Post inline PR comments** — when reviewing a PR, automatically post findings as line-level review comments via the GitHub API

**Implementation**: Load `operations/run-review.md` for full orchestration logic.

## Operations

### Run Review
**File**: `operations/run-review.md`
**When**: User invokes `/review` with any arguments

### Post Review
**File**: `operations/post-review.md`
**When**: Automatically called at the end of `run-review` when the target is a PR number. Can also be invoked independently after PR creation. Requires `$PR_NUMBER`.

## Agent Prompts

Loaded by the orchestrator and passed to Task tool agents:

- `operations/agents/security.md` — OWASP top 10, credential exposure, injection, input validation
- `operations/agents/simplicity.md` — YAGNI violations, over-engineering, unnecessary abstractions
- `operations/agents/architecture.md` — Pattern adherence, separation of concerns, coupling, naming
- `operations/agents/correctness.md` — DESIGN.md conformance, requirement coverage, test coverage

## Findings Format

Each agent returns a markdown report with findings organized by severity (critical > warning > info). The orchestrator classifies findings as blocking (critical) or advisory (warning/info), saves structured output to `.claude/reviews/latest.md` with YAML frontmatter, then displays results to the user.
