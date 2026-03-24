# Shell Logic Isolation Patterns

Patterns for testing bash script logic without executing the full script.

## Table of Contents

1. [Conditional Extraction](#conditional-extraction)
2. [When to Use Isolation vs Full Execution](#when-to-use-isolation-vs-full-execution)

---

## Conditional Extraction

**Problem:** Bash scripts combine environment checks, credential validation, and business logic into monolithic files that are difficult to test. Running the full script requires real infrastructure (Keychain, Docker, network) and produces side effects.

**Solution:** Extract conditional blocks into standalone snippets that can be evaluated in isolation. Source the relevant variables, then test just the conditional logic.

### Pattern

1. Identify the conditional block to test
2. Set up the input variables with known values
3. Run only the conditional, capturing exit codes and output
4. Assert on exit code and stderr/stdout

### Example: Command Existence Check

Given this production script:
```bash
# run-container.sh
if ! command -v security &>/dev/null; then
  echo "Error: 'security' command not found (macOS required)" >&2
  exit 1
fi
```

Test in isolation:
```bash
# test: command exists
PATH="/usr/bin:/bin" # ensure 'security' is findable
if ! command -v security &>/dev/null; then
  echo "FAIL: security should be found"
  exit 1
fi
echo "PASS: security command found"

# test: command missing
PATH="/empty"
if command -v security &>/dev/null; then
  echo "FAIL: security should not be found"
  exit 1
fi
echo "PASS: missing command detected"
```

### Example: Credential Extraction

Given this production script:
```bash
# run-container.sh
CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || {
  echo "Error: Claude credentials not found. Run 'claude login'" >&2
  exit 1
}
```

Test the downstream validation without touching Keychain:
```bash
# test: valid credentials
CREDS='{"claudeAiOauth":{"accessToken":"tok_abc123"}}'
TOKEN=$(echo "$CREDS" | jq -r '.claudeAiOauth.accessToken')
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "FAIL: token should be extracted"
  exit 1
fi
echo "PASS: token=$TOKEN"

# test: missing token field
CREDS='{"claudeAiOauth":{}}'
TOKEN=$(echo "$CREDS" | jq -r '.claudeAiOauth.accessToken')
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "PASS: missing token detected"
else
  echo "FAIL: should have detected missing token"
  exit 1
fi

# test: malformed JSON
CREDS='not-json'
TOKEN=$(echo "$CREDS" | jq -r '.claudeAiOauth.accessToken' 2>/dev/null)
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "PASS: malformed JSON detected"
else
  echo "FAIL: should have rejected malformed input"
  exit 1
fi
```

### Example: Multi-Condition Validation

Given this production script:
```bash
# run-container.sh
export CLAUDE_CODE_OAUTH_TOKEN=$(echo "$CREDS" | jq -r '.claudeAiOauth.accessToken')
if [[ -z "$CLAUDE_CODE_OAUTH_TOKEN" || "$CLAUDE_CODE_OAUTH_TOKEN" == "null" ]]; then
  echo "Error: OAuth token missing. Run 'claude logout && claude login'" >&2
  exit 1
fi
```

Test the combined empty-or-null check:
```bash
validate_token() {
  local token="$1"
  [[ -n "$token" && "$token" != "null" ]]
}

# test: valid token
validate_token "tok_abc123" && echo "PASS" || echo "FAIL"

# test: empty string
validate_token "" && echo "FAIL" || echo "PASS: empty rejected"

# test: literal null
validate_token "null" && echo "FAIL" || echo "PASS: null rejected"

# test: whitespace only
validate_token "  " && echo "PASS: whitespace accepted (expected)" || echo "FAIL"
```

---

## When to Use Isolation vs Full Execution

### Use Isolation Testing When

- **Validating conditional logic** - if/else branches, case statements, guard clauses
- **Testing input parsing** - argument handling, environment variable checks
- **Checking error messages** - verifying the right error is emitted for each failure mode
- **Infrastructure is unavailable** - CI environments without macOS Keychain, Docker, etc.
- **Speed matters** - isolated snippets run in milliseconds vs seconds for full scripts

### Use Full Script Execution When

- **Testing end-to-end flow** - the script's overall orchestration matters
- **Verifying side effects** - files created, services started, containers launched
- **Integration with real systems** - the script's value is in how it connects components
- **Argument parsing + execution** - testing that CLI flags reach the right code paths

### Decision Guide

```
Is the logic pure conditionals/validation?
  → YES: Isolation testing
  → NO: Continue...

Does the script require infrastructure you don't have?
  → YES: Isolation testing (extract what you can)
  → NO: Continue...

Are you testing orchestration between components?
  → YES: Full execution (with test fixtures)
  → NO: Isolation testing
```

---

## Anti-Patterns

- **Testing the shell itself** - Don't test that `[[ -z "" ]]` works. Test your specific conditional logic.
- **Reproducing the entire environment** - If you need to mock Keychain, Docker, and jq, you're testing too much. Extract the logic layer.
- **Ignoring exit codes** - Always assert on `$?`. A passing test that ignores failures is worse than no test.
- **Hardcoding paths in tests** - Use variables so tests are portable across machines.

---

## Summary

Shell Logic Isolation Patterns keep bash testing fast and focused:

1. **Conditional Extraction** - Pull validation logic out of scripts and test it standalone
2. **Isolation vs Full Execution** - Use isolation for logic, full execution for orchestration

This pattern is especially useful for scripts that interact with platform-specific infrastructure (macOS Keychain, Docker, cloud CLIs) where full execution isn't always possible.
