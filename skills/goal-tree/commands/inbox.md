# /inbox — Review Pending Notifications

Read and display pending inbox notifications from background agents and sub-sessions. Distinguishes blocked sessions from informational messages.

## Procedure

1. Read `~/.claude/inbox.jsonl`. If the file is missing or empty, say "No pending notifications." and stop.

2. Parse each JSONL line. Each entry has fields: `ts`, `source`, `source_id`, `summary`, and optionally `message_type` (defaults to `"info"` if absent).

3. Separate entries into two groups:
   - **Blocked**: entries where `message_type` is `"blocked"`
   - **Info**: all other entries

4. Display blocked entries first (if any), then info entries:

```
## Inbox (N pending)

### Blocked Sessions (M)

1. [prompt] node-C.3.21 — Permission needed: Bash: npm install ... (2026-04-14T10:32:00Z)
2. [dependency] node-C.3.22 — Missing API endpoint: /v2/users (2026-04-14T10:35:12Z)

### Notifications (K)

1. [subagent] agent-abc123 — Implemented OAuth token refresh logic... (2026-04-14T14:32:00Z)
2. [workspace-session] node-2.1 — auth-middleware: PR ready for review (2026-04-14T14:35:12Z)
```

Format each line: `N. [source] source_id — summary (timestamp)`

If there are no blocked entries, omit the "Blocked Sessions" header. If there are no info entries, omit the "Notifications" header.

5. After displaying, clear the inbox:
   - Truncate `~/.claude/inbox.jsonl` to empty
   - Write `0` to `/tmp/claude-inbox-count`

6. Confirm: "Inbox cleared."
