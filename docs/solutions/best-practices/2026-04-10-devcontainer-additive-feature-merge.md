---
title: "Additively merge devcontainer features from a base config without per-feature enumeration"
date: 2026-04-10
problem_type: best_practice
severity: medium
symptoms:
  - "New devcontainer feature added to a base config but not appearing in merged project configs"
  - "Per-feature `//= {}` jq lines requiring an edit every time a feature is added"
  - "jq error `object and null cannot be multiplied` when project devcontainer sets a feature key to null/false to 'disable' it"
  - "Project devcontainer.json silently overrides base feature values with no operator visibility"
tags: [devcontainer, jq, feature-merge, ralph, supply-chain, override-warning]
root_cause: "Hand-enumerated jq merges that name each feature key individually don't scale and silently drop newly-added base features. jq's recursive merge `*` operator has edge cases (non-object values) that need explicit coercion."
module: ralph-wiggum
repo: claude-skills
---

## Problem

When a wrapper script (e.g. `run-container.sh`) merges a project-supplied `.devcontainer/devcontainer.json` with a base config that ships with the wrapper (e.g. `ralph-wiggum/scripts/.devcontainer/devcontainer.json`), the merge logic typically enumerates each base feature by name:

```jq
.features["ghcr.io/devcontainers/features/node:1"] //= {} |
.features["ghcr.io/devcontainers/features/github-cli:1"] //= {} |
```

This pattern has three failure modes:

1. **Silent feature drop**: Adding a new feature to the base config does nothing for projects that supply their own devcontainer.json — the merge only injects the explicitly-named keys. Discovered in C.2.6 when the new `go-task` feature was added to the ralph base but never reached projects.
2. **No collision visibility**: Project values silently win on key collision. A project could swap a security-relevant base feature (e.g., `node`) with a malicious one and the operator would never see it.
3. **Recursive-merge edge case**: jq's `*` operator errors with `object and null cannot be multiplied` if a project sets a feature key to a non-object value (e.g., `null` or `false` to "disable" a feature).

## Solution

Replace per-feature enumeration with a generalized additive merge, plus an out-of-band override warning, plus null-coercion:

### 1. Generalized merge (run-container.sh)

```jq
.features = (
  ($ralph[0].features // {}) * (
    (.features // {}) | with_entries(
      if (.value | type) == "object" then . else .value = {} end
    )
  )
)
```

- `($base * $project)` is jq's recursive merge with right-hand-side winning on leaf collisions, so project values still win where they should (e.g., `node.version: "20"`).
- Keys present only in the base are preserved — adding a new base feature automatically propagates to merged project configs with no script edits.
- The `with_entries` coercion turns non-object project values into `{}` so the recursive merge cannot raise.

### 2. Override warning (pre-merge, run-container.sh)

Before the merge, list the keys that exist in both the project config and the base config and emit them to stderr:

```bash
OVERRIDDEN_FEATURES=$(jq -r --slurpfile ralph "$ralph_config" '
  ((.features // {}) | keys) as $project
  | (($ralph[0].features // {}) | keys) as $ralph_keys
  | ($project - ($project - $ralph_keys))
  | .[]
' "$project_config" 2>/dev/null || true)
if [[ -n "$OVERRIDDEN_FEATURES" ]]; then
  echo "  Warning: project devcontainer.json overrides ralph feature(s):" >&2
  while IFS= read -r feat; do
    echo "    - $feat" >&2
  done <<< "$OVERRIDDEN_FEATURES"
  echo "  Project values win on key collision. Verify this is intentional." >&2
fi
```

Behavior is unchanged (project still wins) — the warning surfaces the override so it cannot happen silently.

### 3. Pin third-party features by digest

Devcontainer feature references support OCI digests in the same string:

```json
"ghcr.io/eitsupi/devcontainer-features/go-task@sha256:8a6c4b4f9d75...": {}
```

Resolve the digest with `docker buildx imagetools inspect <ref>:<tag> --raw | shasum -a 256`. Tamper-evident, reproducible, immune to upstream account compromise. Especially important for features published from personal namespaces (vs. the official `devcontainers/` org).

## Prevention

- Don't hand-enumerate base features in jq merges. Use `($base * $project)` so new base features propagate without script edits.
- When generalizing a merge that previously had explicit overrides, audit the new override surface and add a visibility mechanism (warning, log, or hard error). Project-wins is fine for legitimate options like `node.version`, but the operator must see when it happens.
- Pin third-party OCI artifacts (devcontainer features, base images, GitHub Actions) by digest for any feature pulled from a personal namespace. Floating tags from official orgs are acceptable; floating tags from personal accounts are not.
- Test the merge logic against three scenarios before shipping: (1) project overrides a base key with options, (2) project adds a custom key, (3) project sets a base key to a non-object value. The third case is the recursive-merge edge case that's easy to miss.
