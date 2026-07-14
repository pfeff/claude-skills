---
name: review
description: Spawn parallel specialist review agents (security, simplicity, architecture, correctness) against a PR or branch diff. Synthesizes findings by severity. Use when the user requests a code review or invokes /claude-skills:review.
argument-hint: "[PR number, branch name, owner/repo#number, or blank for current branch]"
allowed-tools:
  - Bash(git diff:*)
  - Bash(git -C:*)
  - Bash(gh pr diff:*)
  - Bash(gh pr view:*)
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
version: 0.7.0
---

# Review Skill

Parallel multi-agent code review. Spawns security, simplicity, architecture, and correctness agents against a diff, then consolidates findings.

## Invocation

```
/claude-skills:review              # Current branch vs main
/claude-skills:review 42           # PR #42
/claude-skills:review feature-xyz  # Branch feature-xyz vs main
```

### Out-of-repo anchors (optional)

By default the skill assumes the current working directory **is** the target git
repo. Two optional anchors let it review a target that lives elsewhere — for
example reviewing a PR from a non-git workspace, or a branch in a different
worktree. When neither anchor is given, behavior is **exactly** as above.

```
/claude-skills:review 42 --repo <owner>/<repo>       # PR #42 in another repo
/claude-skills:review pfeff/dotfiles#247             # PR #247 in another repo (shorthand)
/claude-skills:review feature-xyz --worktree <path>  # branch in another worktree
```

- `--repo <owner>/<repo>` — threads the repo through every `gh` call (`gh pr diff`
  and `gh pr view` via `--repo`; `gh repo view` takes it positionally) so a bare
  PR-number target resolves against the named repo instead of cwd. Use when
  reviewing an out-of-repo PR.
- `<owner>/<repo>#<number>` — shorthand equivalent to `<number> --repo <owner>/<repo>`;
  the standard GitHub cross-reference syntax for a PR in another repo, parsed into
  the same `$REPO` and PR-number values. A token of this exact shape always wins
  over a same-named branch (see the Precedence note in `operations/run-review.md`).
  Passing both a `--repo` flag and the `owner/repo#N` shorthand that disagree is a conflicting-input error.
- `--worktree <path>` — anchors `git` diff calls via `git -C <path>` so a branch
  or current-branch target diffs against that worktree instead of cwd. Use when
  the target branch lives in a different checkout. `--repo` may be combined to
  also anchor the verdict-comment posting step.

The anchors only change *where* the diff is fetched from; the target itself is
still a PR number, a git ref, or the `owner/repo#number` shorthand. Plain PR
numbers and branch names are passed through without a character allowlist — a
branch target beginning with `-` is rejected (option-injection guard) and any
metacharacters are passed to `git` inertly as one quoted argument rather than
evaluated; only the `owner/repo#number` shorthand is matched by shape, via an
anchored regex that admits only that safe form.

## Execution Flow

1. **Determine diff source** from `$ARGUMENTS`
2. **Check diff size** — diffs >1000 lines trigger degraded-mode (see Limits)
3. **Spawn 4 review agents** in parallel using Task tool (skipped in degraded-mode)
4. **Synthesize and classify findings** (blocking vs advisory)
5. **Persist results** to `.claude/reviews/latest.md`
6. **Display results** to user
7. **Post sticky verdict comment** — when reviewing a PR, upsert a single review comment (edited in place on re-run, never appended) and, unless it is the reviewer's own PR, submit a formal `REQUEST_CHANGES`/`APPROVE` event

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

Posts a single **sticky verdict comment** (marked with `<!-- review:metadata -->`) that is edited in place on every re-run — never appended. The comment's verdict line and marker are the authoritative cross-operator artifact (`l1-review` reads the marker). When the reviewer is not the PR author, it also submits a lightweight `REQUEST_CHANGES`/`APPROVE` event, dismissing its own prior blocking review so nothing stacks. On a self-PR the event is skipped (GitHub blocks it); the comment stands alone.

## Agent Prompts

Loaded by the orchestrator and passed to Task tool agents:

- `operations/agents/security.md` — OWASP top 10, credential exposure, injection, input validation
- `operations/agents/simplicity.md` — YAGNI violations, over-engineering, unnecessary abstractions
- `operations/agents/architecture.md` — Pattern adherence, separation of concerns, coupling, naming
- `operations/agents/correctness.md` — DESIGN.md conformance, requirement coverage, test coverage

## Findings Format

Each agent returns a markdown report with findings organized by severity (critical > warning > info). The orchestrator classifies findings as blocking (critical) or advisory (warning/info), saves structured output to `.claude/reviews/latest.md` with YAML frontmatter, then displays results to the user.

When the target is a PR, findings are also rendered into the sticky verdict comment (see Post Review) — grouped under `🚫 Blocking` and `💡 Advisory` headings for readability, one entry per finding as ``**`file:line`** · category`` followed by the description.
