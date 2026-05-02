---
target: PR #77
timestamp: 2026-05-02T03:30:00Z
agents: 4
blocking: 0
advisory: 7
verdict: CLEAN
---

## Review Summary

**Target**: PR #77 (loop-optimizer/I.2 → main)
**Agents**: 4 (security, simplicity, architecture, correctness)
**Verdict**: CLEAN — advisory findings only

### Advisory

- **skills/task-workflow/scripts/create-workspace.sh:885-887** — [architecture] _cohesion_ (warning) — `.envrc` is built in two places: variable-expanded heredoc at 876-884, then `echo ... >>` append at 886. Existing pattern keeps all `.envrc` content in the single heredoc (one source of truth). Since the heredoc is unquoted, `$NODE_DB_ID` would expand inside it. Recommendation: compose `COORD_LINE` before the heredoc and emit it inline, or emit unconditionally (empty value is harmless).
- **DESIGN.md AC3** — [correctness] _test coverage_ (warning) — AC3 ("Validated end-to-end on a fresh node workspace") has no committed evidence. The session validated via stubbed `create-workspace.sh` shim + heredoc smoke test; no real dispatch was run. Acknowledged in the PR body and scheduled follow-up routine (trig_0173asdpXWvtJRF1LGcmHtJU, 2026-05-05) verifies the fix landed but cannot verify a fresh `.envrc` from the cloud.
- **skills/task-workflow/scripts/create-workspace.sh:886** — [security] _input validation_ (info) — `$NODE_DB_ID` is interpolated unvalidated into the generated `.envrc`. Source is trusted (`jq -r '.data.id'` from local coord API), but no `[[ "$NODE_DB_ID" =~ ^[0-9]+$ ]]` guard. A buggy/compromised coord returning a non-numeric value with `"`, `$`, or backticks would yield arbitrary code execution on every direnv load. Trivial to harden — add the regex guard in `create-workspace.sh` (or in `discuss-dispatch.sh` right after the `jq` extraction).
- **skills/goal-tree/scripts/create-node-workspace.sh:28-36** — [correctness] _undocumented behavior_ (info) — `--node-db-id` is silently optional. Legacy positional callers (`dispatch-node.md`, `branch-management.md`, `start-project.md`) don't pass it, so workspaces created via those paths still won't have `COORDINATOR_TASK_ID` and `/finish` will silently no-op there — exactly the Round-1 failure mode. Out of scope per DESIGN.md (which scopes the fix to the dispatch flow), but worth a comment in the script.
- **skills/goal-tree/scripts/create-node-workspace.sh:33** — [architecture] _naming_ (info) — Lowercase `error:` matches sibling `discuss-dispatch.sh:47` but diverges from the delegate `create-workspace.sh:102` ("Error: Unknown argument: …"). Minor.
- **skills/goal-tree/scripts/create-node-workspace.sh:8** — [architecture] _api design_ (info) — Wrapper rejects unknown `-*` flags (stricter than the delegate). Acceptable for a narrow interface; if a second optional flag is added later, switch to an explicit pass-through array (cf. `COORD_ARGS` pattern in `discuss-dispatch.sh:69-76`).
- **skills/goal-tree/scripts/discuss-dispatch.sh:107-109** — [architecture] _pattern adherence_ (info) — Mixed flag/positional call to the wrapper. Works correctly but a brief comment ("legacy callers omit `--node-db-id` and accept that `/finish` cannot update coord status") would document the intentional split.
