---
name: review
description: Spawn parallel specialist review agents (security, simplicity, architecture, correctness) against a PR or branch diff. Synthesizes findings by severity. Use when the user requests a code review or invokes /claude-skills:review.
argument-hint: "[PR number, branch name, or blank for current branch]"
allowed-tools:
  - Bash(git diff:*)
  - Bash(gh pr diff:*)
  - Bash(git rev-parse:*)
  - Bash(git branch:*)
  - Bash(git log:*)
  - Bash(git merge-base:*)
  - Bash(mkdir:*)
  - Bash(gh api:*)
  - Bash(gh repo view:*)
  - Task
  - Read
  - Write
  - Grep
  - Glob
version: 0.4.0
---

# Review Skill

Parallel multi-agent code review. Spawns security, simplicity, architecture, and correctness agents against a diff, then consolidates findings.

## Invocation

```
/claude-skills:review              # Current branch vs main
/claude-skills:review 42           # PR #42
/claude-skills:review feature-xyz  # Branch feature-xyz vs main
```

## Execution Flow

1. **Determine diff source** from `$ARGUMENTS`
2. **Check diff size** — diffs >1000 lines trigger degraded-mode (see Limits)
3. **Spawn 4 review agents** in parallel using Task tool (skipped in degraded-mode)
4. **Synthesize and classify findings** (blocking vs advisory)
5. **Persist results** to `.claude/reviews/latest.md`
6. **Display results** to user
7. **Post inline PR comments** — when reviewing a PR, automatically post findings as line-level review comments via the GitHub API

**Implementation**: Load `operations/run-review.md` for full orchestration logic.

## Limits

### Diff-size degradation

Diffs exceeding **1000 lines** skip the multi-agent pass. The orchestrator performs a single inline review using a condensed checklist (security, correctness, data-loss, architecture, simplicity). The output is labeled:

```
> **Degraded-mode review** — diff is N lines (threshold: 1000). Multi-agent pass skipped. Coverage may be incomplete.
```

`agents: 1` and `degraded: true` are set in the frontmatter.

### Timeout

The multi-agent pass has a **10-minute wall-clock timeout**. If agents do not return within 10 minutes, the review emits a structured timeout failure and stops — no partial results are persisted.

## BLOCKING Tier

BLOCKING is restricted to **correctness failures, security vulnerabilities, and data-loss risks**. Style, naming, ergonomics, and structural preferences are always ADVISORY regardless of agent severity label.

## Operations

### Run Review
**File**: `operations/run-review.md`
**When**: User invokes `/claude-skills:review` with any arguments

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
