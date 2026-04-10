---
title: "Claude CLI rejects -p + stream-json without --verbose, masquerading as auth failure"
date: 2026-04-10
problem_type: runtime_error
severity: high
symptoms:
  - "Ralph container preflight prints 'Validating credentials...' then 'Error: Pre-flight check failed - no valid response'"
  - "Container exits after preflight even though token, network, and container build all look healthy"
  - "Misdiagnosed upstream as 'OAuth token auth blocker' because the error falls through the auth/credit regex"
  - "Running `claude --output-format stream-json -p \"Say OK\"` inside the container exits 1 with `Error: When using --print, --output-format=stream-json requires --verbose`"
  - "Running the same call with `--verbose` added returns `{\"type\":\"result\",\"subtype\":\"success\"}` — proving the token and network path are fine"
tags: [claude-cli, ralph, preflight, stream-json, verbose-flag, oauth, error-regex-blind-spot, autoresearch]
root_cause: "Claude CLI 2.1.100 requires --verbose whenever --print/-p is combined with --output-format=stream-json. loop.sh's preflight call predates this and omits the flag. The CLI-arg error matches none of preflight_auth_check's auth/credit regex patterns, so it falls through to the generic 'no valid response' branch — which looks like an auth problem to anyone reading the log."
module: ralph-wiggum
component: preflight_auth_check
repo: claude-skills
---

## Problem

`skills/ralph-wiggum/scripts/loop.sh`'s `preflight_auth_check` runs a minimal Claude call to verify credentials before starting the Ralph build loop:

```bash
timeout 30 claude --output-format stream-json -p "Say OK" > "$temp_output" 2>&1 || true
```

Claude CLI 2.1.100 rejects this arg combination:

```
Error: When using --print, --output-format=stream-json requires --verbose
```

`preflight_auth_check` then greps the captured output for two error patterns — `credit balance is too low` and an auth/credential regex (`authentication.*(error|failed|...)|invalid.*(api.?key|token|credential)|...`). The CLI-arg error matches **neither**. The function falls through to:

```bash
if ! grep -q '"type":"result"' "$temp_output" 2>/dev/null; then
  echo "Error: Pre-flight check failed - no valid response"
```

Autoresearch node C.2.1 hit this failure during its first live container test and recorded it as an "OAuth token auth blocker" — triggering a whole follow-up investigation (C.2.5) into token extraction, Keychain paths, env var mapping, and devcontainer mounts. All of which were already correct. The token path had never been broken.

## Solution

One-line fix to the preflight call:

```diff
-  timeout 30 claude --output-format stream-json -p "Say OK" > "$temp_output" 2>&1 || true
+  # --verbose required by Claude CLI when combining --print with --output-format=stream-json
+  timeout 30 claude --output-format stream-json --verbose -p "Say OK" > "$temp_output" 2>&1 || true
```

Verified by running the corrected call directly inside the container:

```
{"type":"system","subtype":"init",...,"apiKeySource":"none",...}
{"type":"assistant","message":{...,"content":[{"type":"text","text":"OK"}],...}}
{"type":"result","subtype":"success","is_error":false,"result":"OK",...}
```

`"apiKeySource":"none"` confirms OAuth-subscription auth is working. The preflight then prints `Credentials validated` and the build loop proceeds.

## Prevention

**Primary**: When wrapping the Claude CLI in scripts, always pair `--print` + `--output-format=stream-json` with `--verbose`. The CLI enforces this for any machine-readable stream output.

**Secondary (the real lesson)**: `preflight_auth_check`'s error-classification regex had a blind spot — it only recognized two failure modes (credit, auth) and treated everything else as "no valid response." That's a diagnostic lossy channel. Any future CLI drift that lands outside those two regex classes will surface the same misleading message and send the next agent down another wild-goose chase.

Suggested hardening (not applied in the original fix, filed as follow-up):

```bash
# Catch CLI argument / usage errors before the generic "no valid response" branch
if grep -qiE '^Error: When using|^Usage:|unknown (option|argument)' "$temp_output" 2>/dev/null; then
  echo "Error: Claude CLI argument mismatch — preflight invocation needs updating"
  echo "Output: $(cat "$temp_output")"
  return 1
fi
```

**Meta-prevention (for the autoresearch loop)**: When C.N+1 is about to investigate a reported failure from C.N, **reproduce the failure first** before accepting the original diagnosis. C.2.5 was created to "fix OAuth in container" and nearly became a token-refresh or `claude setup-token` node — which would have shipped code that solved nothing. The validate-first approach in DESIGN.md is what surfaced the real cause; the pattern should be the default, not a per-node decision.

## See Also

- Autoresearch node C.2.5 (`~/src/work/autoresearch/C.2.5-node-c25/NOTES.md`) — full findings and reproduction
- PR pfeff/claude-skills#28 — migration + fix
- `skills/ralph-wiggum/scripts/loop.sh:42` — fixed preflight call
