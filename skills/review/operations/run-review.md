# Run Review

## Step 1: Determine Diff Source

### Parse anchors

Before resolving the target, extract two optional anchors from `$ARGUMENTS`.
Both default to empty (in-repo behavior). When both are empty, every command in
this step is byte-for-byte identical to the no-anchor form.

- `--repo <owner>/<repo>`: out-of-repo anchor for `gh` PR calls. Validate that
  `<owner>` and `<repo>` each contain only alphanumerics, hyphens, underscores,
  and dots (one `/` separator). Store as `$EXPLICIT_REPO`. If invalid, report
  the error and stop.
- `--worktree <path>`: out-of-repo anchor for `git` diff calls. Store as
  `$WORKTREE`.

Remove the parsed flags (and their values) from `$ARGUMENTS`; the remaining
token is the target (PR number, branch name, owner/repo#number shorthand, or
empty). Plain PR numbers and branch names pass through with no character
restriction — exactly as before shorthand support existed; only the shorthand
case below imposes a shape, and it does so via a self-validating anchored regex.

Set `$REPO` = `$EXPLICIT_REPO` (may be empty). Shorthand parsing in "Parse
arguments" below may overwrite `$REPO`; `$EXPLICIT_REPO` itself is never
overwritten, so the original `--repo` value (if any) stays available there for
the conflict check.

Derive `$GIT` = `git -C "$WORKTREE"` when `$WORKTREE` is set, otherwise `git`.

Note: `$REPO_FLAG` is **not** derived here. It is derived in "Parse arguments"
below, after shorthand parsing has had a chance to set `$REPO` — deriving it
here would freeze it at whatever `$EXPLICIT_REPO` was (often empty), which is
exactly the bug the shorthand form exists to avoid.

### Detect base branch

Detect the remote default branch to use as the diff base:

1. Run `$GIT symbolic-ref refs/remotes/origin/HEAD`. If successful, strip the `refs/remotes/` prefix (e.g., `refs/remotes/origin/main` → `origin/main`).
2. If the command fails, fall back to `origin/main`.

Store the result as `$BASE`.

### Parse arguments

Also recognize the shorthand `<owner>/<repo>#<number>` (standard GitHub
cross-reference syntax, e.g. `pfeff/dotfiles#247`) as an alternative way to
specify the same thing as `<number> --repo <owner>/<repo>`.

**Classify the target token.** Run this shorthand case first, before the
Numeric and Otherwise cases in the dispatch below:

- **Shorthand** — the token matches, in its entirety, the anchored regex
  `^[A-Za-z0-9._][A-Za-z0-9._-]*/[A-Za-z0-9._-]+#[0-9]+$`: an `<owner>`
  segment whose first character is not a hyphen (so a leading-dash token like
  `-x/repo#1` can never match and can never reach a downstream shell call as an
  option), a `/`, a `<repo>` segment, a literal `#`, then one or more digits.
  Because the regex admits only this exact safe shape, it is its own
  validation — no separate character-gate and no `git`/`gh` call is needed to
  classify the token, and it cannot match a token containing shell
  metacharacters. A token shaped exactly like `owner/repo#N` is **always**
  treated as this shorthand; branch disambiguation is not attempted (see the
  precedence note below).

  Before mutating `$REPO`: if `$EXPLICIT_REPO` is set (an explicit `--repo`
  flag was given) and its value disagrees with the `<owner>/<repo>` parsed from
  the shorthand — compared case-insensitively, since GitHub owner/repo segments
  are case-insensitive — report a conflicting-input error and stop. This
  compare-before-mutate ordering keeps the conflict check independent of any
  later change to `$REPO`.

  Then split the token: store the `<owner>/<repo>` part in `$REPO` (overwriting
  the `$EXPLICIT_REPO`-derived value, if any) and replace the target token with
  the bare `<number>` so it falls through to the Numeric case below.

- **Not shorthand** — anything else, including plain PR numbers like `42` and
  ordinary branch names (even those containing git-legal characters such as
  `!`, `@`, `+`, `%`, `(`, `)`): pass it through unchanged, with no character
  restriction and no git call, to the dispatch below — exactly as before
  shorthand support existed.

**Precedence:** a token shaped exactly like `<owner>/<repo>#<number>` is always
interpreted as the out-of-repo shorthand, never as a branch. Git branch names
may legally contain `/` and `#`, so a local branch literally named
`owner/repo#N` is theoretically possible, but such a branch is not reviewable
by that bare name through this skill — review it another way (e.g. rename it,
or pass an explicit branch/worktree target). This deliberate, documented
tradeoff replaces the earlier branch-existence (`rev-parse`) disambiguation,
whose guarding machinery was the source of repeated regressions.

Now that `$REPO` has its final value, derive `$REPO_FLAG` = ` --repo $REPO`
when `$REPO` is set, otherwise empty. Deriving it here (after shorthand
classification) rather than earlier is deliberate: the shorthand must be able
to set `$REPO` first.

**Dispatch** on the (possibly shorthand-rewritten) target token:

- **Empty / no args**: Current branch vs base. Run `$GIT diff $BASE...HEAD`. Set `$PR_NUMBER` to empty.
- **Numeric** (e.g. `42`): PR number. Run `gh pr diff <target>$REPO_FLAG`. Set `$PR_NUMBER` to the numeric value.
- **Otherwise**: Branch name. Run `$GIT diff $BASE...<target>`. Set `$PR_NUMBER` to empty.

Capture the diff output. If the diff is empty, inform the user and stop.

Carry `$REPO` forward to Step 10 so the inline-comment posting step targets the same repo.

## Step 2: Check Diff Size

Count the number of lines in the diff. Store as `$DIFF_LINES`.

**If `$DIFF_LINES` > 1000**: perform a degraded-mode inline review instead of the multi-agent pass. Skip Steps 3–6 and go directly to the degraded review below, then continue at Step 8.

### Degraded-mode inline review

When the diff exceeds 1000 lines, review the diff yourself (without spawning agents) using this condensed checklist:

- **Security**: hardcoded secrets, missing auth, injection via string interpolation, XSS, PII in logs
- **Correctness**: logic errors, missing error handling at system boundaries, unhandled edge cases
- **Data loss**: destructive operations without guards (drops, deletes, overwrites)
- **Architecture**: new circular dependencies, schema/interface mismatches
- **Simplicity**: dead code, obvious YAGNI violations

Report findings using the same format as the full review (Critical/Warning/Info per agent area). Set `$AGENT_COUNT` to 1.

Add a prominent notice at the top of the review output:

```
> **Degraded-mode review** — diff is {$DIFF_LINES} lines (threshold: 1000). Multi-agent pass skipped. Coverage may be incomplete.
```

After producing the degraded findings, skip to Step 8 (Persist Review Output).

---

**If `$DIFF_LINES` ≤ 1000**: continue with the full multi-agent review below. Set `$AGENT_COUNT` to 4.

## Step 3: Load Agent Prompts

Read the four agent prompt files:
- `operations/agents/security.md`
- `operations/agents/simplicity.md`
- `operations/agents/architecture.md`
- `operations/agents/correctness.md`

## Step 4: Detect Platform Context

Check for language-specific marker files in the working directory to load platform context:

- If `mix.exs` exists → read `contexts/elixir-otp.md`
- If `go.mod` exists → read `contexts/go.md` (if it exists)
- If `pyproject.toml` or `requirements.txt` exists → read `contexts/python.md` (if it exists)

Use the first match. If no marker file is found or the corresponding context file does not exist, skip this step (no context will be injected).

## Step 5: Load Project Context

Search for project documentation to give agents design awareness:

1. **DESIGN.md**: Walk up from the working directory to find the nearest `DESIGN.md`, stopping at the repository root (`.git` boundary). Read its contents.
2. **ARCHITECTURE.md**: Read from the repository root (same directory as `.git`), if it exists.

For each file: if it exists, read its contents. If it does not exist, skip it silently.

After loading, note which documents were found. If none were found, continue without project context (agents will still review using their own checklists).

## Step 6: Spawn Review Agents in Parallel

Launch 4 Task tool agents in parallel, each with `subagent_type: general-purpose`. Each agent receives:
1. The agent prompt (from Step 3)
2. The platform context (from Step 4, if detected)
3. The project context (from Step 5, if any documents were found)
4. The full diff (from Step 1)

Format each Task prompt as:

```
<agent-prompt>
{contents of the agent .md file}
</agent-prompt>

<platform-context>
{contents of the context .md file, if detected}
</platform-context>

<project-context>
Found: {comma-separated list of documents loaded, e.g. "DESIGN.md, ARCHITECTURE.md"}

{contents of each found document, separated by filename headers:}

## DESIGN.md
{contents}

## ARCHITECTURE.md
{contents}
</project-context>

<diff>
{the diff output}
</diff>
```

Omit the `<platform-context>` block if no platform context was detected. Omit the `<project-context>` block if no project documents were found. Within `<project-context>`, only include sections for documents that exist.

### Timeout

Wait for all agents to return. If any agents have not returned after **10 minutes of wall-clock time**, do not continue waiting. Emit a structured timeout failure instead of hanging:

```
> **Review timed out** — agents did not complete within 10 minutes.
> Diff size: {$DIFF_LINES} lines. Elapsed: ~10 min.
> Partial results (if any) are not persisted. Re-run on a smaller diff or try again.
```

Stop after emitting this message. Do not persist partial output to `latest.md`.

## Step 7: Synthesize and Classify Findings

After all agents return, synthesize their reports into a single consolidated summary:

1. Collect all findings from the four agents
2. If multiple agents flagged the same file and line, combine into a single entry
3. Classify each finding:
   - **Blocking**: Findings that are **correctness failures, security vulnerabilities, or data-loss risks** — regardless of agent or severity label. These must be addressed before merge. Style preferences, naming choices, ergonomic suggestions, and structural opinions are **never** BLOCKING, even if an agent labels them Critical.
   - **Advisory**: Everything else — including style, naming, architecture preferences, and ergonomics, even at Critical severity from the agent. Evaluate each in context based on potential impact and cost of fix. Advisory findings are not automatically dismissed — they represent genuine observations that may warrant action.
4. Group findings by classification (blocking first, then advisory)
5. Within each classification group, order by severity (critical, warning, info)
6. Omit empty sections

Each synthesized finding must include: file, line, agent, category, classification (blocking/advisory), and description.

## Step 8: Persist Review Output

Save the synthesized review to `.claude/reviews/latest.md` (relative to the working directory). Create the `.claude/reviews/` directory if it does not exist. Overwrite any existing `latest.md`.

Write the file using this exact structure:

```markdown
---
target: {branch name, PR #N, or "current branch"}
timestamp: {ISO 8601 UTC, e.g. 2026-02-23T14:30:00Z}
agents: {$AGENT_COUNT}
degraded: {true if degraded-mode, false otherwise}
blocking: {count}
advisory: {count}
verdict: {BLOCKING | CLEAN}
---

## Review Summary

**Target**: {target}
**Agents**: {$AGENT_COUNT}
**Verdict**: {BLOCKING — N issue(s) must be resolved | CLEAN — advisory findings only | CLEAN — no issues found}

{If degraded-mode, include the degraded-mode notice here}

### Blocking

- **file:line** — [agent] _category_ — Description

### Advisory

- **file:line** — [agent] _category_ (warning|info) — Description
```

Rules:
- The YAML frontmatter must be machine-parseable. Use exact field names shown above.
- `verdict` in frontmatter is `BLOCKING` if any blocking findings exist, otherwise `CLEAN`.
- `degraded` in frontmatter is `true` if the diff-size threshold was exceeded; `false` otherwise.
- Omit the `### Blocking` section if there are no blocking findings.
- Omit the `### Advisory` section if there are no advisory findings.
- If no findings at all, write only the frontmatter and a single line: `No issues found across {$AGENT_COUNT} agents.`
- Each finding line must preserve the `**file:line**` format exactly — downstream PR annotation depends on parsing this.

## Step 9: Display Results

Present the contents of `.claude/reviews/latest.md` to the user (without the YAML frontmatter).

## Step 10: Post Inline PR Comments

**Skip this step** if `$PR_NUMBER` is empty (branch-only reviews).

When `$PR_NUMBER` is set, automatically post findings as inline PR review comments by executing the `operations/post-review.md` operation with the current `$PR_NUMBER` (and `$REPO` from Step 1, if set, so the comments post to the out-of-repo PR). This posts line-level comments on the PR diff and a summary review comment.
