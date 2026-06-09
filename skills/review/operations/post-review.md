# Post Review

Posts review findings from `.claude/reviews/latest.md` as a GitHub PR review with line-level annotations.

**Requires**: PR number passed as `$PR_NUMBER`. Must be a positive integer.

**Optional**: `$REPO` (`<owner>/<repo>`) — out-of-repo anchor. When set, the PR
lives in a repo other than the current working directory. Derive
`$REPO_FLAG` = ` --repo $REPO` when `$REPO` is set, otherwise empty. When `$REPO`
is empty, every command below is identical to the in-repo form.

## Step 1: Read Review Output

Read `.claude/reviews/latest.md` (relative to working directory). If the file does not exist, stop silently — there is nothing to post.

## Step 2: Parse Frontmatter

Extract from the YAML frontmatter:
- `verdict`: `BLOCKING` or `CLEAN`
- `blocking`: integer count
- `advisory`: integer count

**Skip posting entirely** if `blocking + advisory == 0`.

## Step 3: Get Repository Context

```bash
gh repo view$REPO_FLAG --json owner,name
```

Extract `owner` and `name` from the JSON response. When `$REPO` is set this
resolves the named repo instead of cwd's repo. Validate that both values contain only alphanumeric characters, hyphens, and underscores.

## Step 4: Build Diff Line Map

Validate that `$PR_NUMBER` is a positive integer before use.

```bash
gh pr diff $PR_NUMBER$REPO_FLAG
```

Parse the unified diff to build a set of valid `(file, line)` pairs on the **right side** of the diff. These are lines that exist in the PR's changed files and can receive line-level comments.

### Parsing algorithm

1. **Extract file paths**: When you encounter a `+++ b/<path>` line, strip the `b/` prefix to get the current file path. Skip lines starting with `--- ` (left-side header). If the line is `+++ /dev/null` (file deleted), skip the entire file — deleted files have no right-side lines.

2. **Track line numbers per hunk**: For each hunk header `@@ -a,b +c,d @@`, set `right_line = c` (the starting line number on the right side). Then for each subsequent line until the next hunk header or file header:
   - **Context line** (starts with ` `): Add `(file, right_line)` to the set. Increment `right_line`.
   - **Added line** (starts with `+`): Add `(file, right_line)` to the set. Increment `right_line`.
   - **Removed line** (starts with `-`): Do NOT add to the set. Do NOT increment `right_line`.
   - **No-newline marker** (`\ No newline at end of file`): Skip, do not modify counters.

3. **Collect file set**: Track all file paths encountered (for fallback classification in Step 6).

### Edge cases

- **Binary files**: Lines like `Binary files ... differ` have no hunks — skip them.
- **Rename-only diffs**: `rename from`/`rename to` with no hunks — skip, no commentable lines.
- **Multiple hunks in one file**: Each `@@` header resets `right_line` to the new `c` value.

## Step 5: Parse Findings

Extract each finding line from the review output. Findings follow this format:

```
- **file:line** — [agent] _category_ — Description
```

For each finding, extract:
- `file`: the file path (strip any leading `./` for normalization)
- `line`: the line number (must be a positive integer)
- `agent`: the agent name in brackets
- `category`: the category in italics
- `description`: the remaining text

If a finding line doesn't match the expected format, or `line` is not a positive integer, classify it as **body-only** (Step 6) — do not discard it.

## Step 6: Classify by Diff Presence

For each finding, determine its comment placement:

1. **Normalize paths**: Strip any leading `./` from the finding's `file` path before lookup. The diff line map paths from Step 4 have no `./` prefix (they are stripped from `+++ b/<path>`).
2. **Line comment**: `(file, line)` exists in the diff line map → use `path` + `line` + `side: "RIGHT"` in the comments array.
3. **Body-only**: `(file, line)` is not in the diff line map → include the finding text in the review body instead of the comments array. This includes malformed findings from Step 5.

## Step 7: Build Review Body

Compose the review body text:

1. Start with a verdict summary line:
   - BLOCKING: `**BLOCKING** — {blocking} blocking and {advisory} advisory finding(s). Blocking issues must be resolved before merge.`
   - CLEAN with advisories: `**CLEAN** — {N} advisory finding(s) for consideration.`
2. If there are body-only findings (from Step 6), add them under a `### Findings outside this diff` heading, preserving the original finding format.

All findings (both blocking and advisory) are posted as line comments or body text regardless of verdict.

## Step 8: Build JSON Payload

Construct the review API payload using proper JSON serialization. All string values must be JSON-escaped (quotes, backslashes, newlines). Do not use string concatenation to build JSON.

```json
{
  "event": "<EVENT>",
  "body": "<BODY>",
  "comments": [<COMMENTS>]
}
```

- **event**: `"REQUEST_CHANGES"` if verdict is `BLOCKING`, otherwise `"COMMENT"`.
- **body**: The review body from Step 7.
- **comments**: Array of comment objects. Each object:
  - `{"path": "<file>", "line": <line>, "side": "RIGHT", "body": "[<agent>] _<category>_ — <description>"}`

If the comments array is empty (all findings were body-only), omit the `comments` field.

## Step 9: Post Review

Write the JSON payload to a temporary file with restrictive permissions, then post it:

```bash
TMPFILE=$(mktemp /tmp/review-payload.XXXXXX.json)
chmod 600 "$TMPFILE"
# Write JSON payload to $TMPFILE
cat "$TMPFILE" | gh api repos/{owner}/{repo}/pulls/{number}/reviews --input -
rm -f "$TMPFILE"
```

Use `--input -` to pipe the JSON via stdin. This avoids shell escaping issues with the JSON body.

After posting, report success to the user with the review event type and number of comments posted.

## Error Handling

| Error | Action |
|-------|--------|
| `.claude/reviews/latest.md` missing | Stop silently |
| `$PR_NUMBER` not a positive integer | Report error, stop |
| `gh repo view` fails | Report error, stop |
| `gh pr diff` fails | Report error, stop |
| Review API returns 422 | See 422 recovery procedure below. |
| Review API returns other error | Report the error to the user |

### 422 Recovery Procedure

A 422 typically means a comment targets a line not in the diff (despite the diff line map check — this can happen with stale diffs or GitHub API inconsistencies).

1. **Log the error body** — the API response usually identifies the problematic field.
2. **Identify the offending comment** — parse the error message for a path or line reference. If the error doesn't identify a specific comment, remove all inline comments as a batch.
3. **Move offending comments to the review body** — append them under the `### Findings outside this diff` heading (same as body-only findings).
4. **Retry once** — resubmit the payload with the remaining inline comments (or body-only if all were moved).
5. **If the retry also returns 422** — post a body-only review (no `comments` field) with all findings in the body. Do not retry further.
