# Dispatch Decision Operation

Evaluates a ready node and selects the appropriate execution strategy: subagent, sub-session, container, inline, or escalate.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `node` | Yes | The node to evaluate (from select-ready) |
| `tree` | Yes | Full parsed goal tree (for context) |
| `results_log` | Yes | Completed results log entries (for dependency context) |

## Output

```
decision:
  strategy: "subagent" | "sub-session" | "container" | "inline" | "escalate"
  tier: 1 | 2 | 3
  reason: "<why this strategy was chosen>"
  context: { ... }  # strategy-specific context
```

## Autonomy Tiers

Every dispatch decision includes a tier that controls checkpoint behavior:

| Tier | Category | Dispatch | Post-Completion | Examples |
|------|----------|----------|-----------------|----------|
| 1 | Safe / read-only | Auto | Auto | Research, audits, scans, analysis |
| 2 | Code with solid spec | Auto | Validate → agent review → human review | Features, fixes, refactoring |
| 3 | Strategic / ambiguous | Escalate or inline | Human review | Architecture decisions, scope changes |

### Tier Classification

```
Is the node read-only? (research, audit, scan, analysis, documentation)
├── Yes → Tier 1
└── No (produces code changes)
    ├── Spec solid? (clear criteria, no ambiguity keywords, design exists)
    │   ├── Yes → Tier 2
    │   └── No → Tier 3
    └── Requires human judgment? → Tier 3
```

Read-only signals: "research", "audit", "scan", "analyze", "survey", "investigate", "document", "baseline", "inventory"

### Tier 2 Validation Gate

Before presenting Tier 2 results to human, the agent MUST:
1. Run automated tests (full suite)
2. Run linting/formatting
3. Agent-driven review: spec → test → code traceability
4. Present to human with validation results and traceability summary

Human reviews **indicators of correctness**: spec traces to tests, tests trace to code, code does what the spec says.

## Decision Flow

```
Is the node a leaf task?
├── Yes
│   ├── Does it need human judgment?
│   │   ├── Yes → ESCALATE
│   │   └── No
│   │       ├── Is the spec clear and self-contained?
│   │       │   ├── Yes
│   │       │   │   ├── Repo(s) have Taskfile + Docker available? → CONTAINER
│   │       │   │   ├── Single repo or few repos? → SUBAGENT
│   │       │   │   └── Many repos with complex coordination? → INLINE
│   │       │   └── No (ambiguous, underspecified) → INLINE
│   │       └── Is it a fallback from failed subagent/container? → INLINE
│   └──
└── No (goal with children)
    ├── Shallow subtree (≤3 leaves, all ready)? → dispatch children as SUBAGENT batch
    ├── Deep subtree (4+ nodes, complex)? → SUB-SESSION
    └── Mixed (some children ready, some not)? → dispatch ready children individually
```

## Strategy Criteria

### Subagent

Choose subagent when:

- Leaf task with clear acceptance criteria
- Targets 1-2 repos
- No "clarify", "discuss", "decide" in description
- No unresolved spec gaps
- Dependencies are all completed (results available for context)
- Estimated scope: 1-5 files of changes

**Context provided**:
```
context:
  repos: [list of repos]
  prompt_includes:
    - task description and acceptance criteria
    - relevant design decisions
    - dependency results from Results Log
    - repo paths
```

### Container

Choose container when:

- Leaf task with clear acceptance criteria (Tier 2)
- Targets 1-2 repos that have `Taskfile.yml` (standard gate targets)
- Docker is available on the dispatch host
- No "clarify", "discuss", "decide" in description
- No unresolved spec gaps
- Task benefits from sandboxed execution (no permission prompts)

Container is preferred over subagent when available because it eliminates permission prompts entirely. Fall back to subagent when Docker is unavailable or repos lack Taskfile.

**Context provided**:
```
context:
  repos: [list of repos]
  node_workspace: "<path to node workspace>"
  taskfile_targets: { repo: [available targets] }
```

### Sub-Session

Choose sub-session when:

- Goal node with 4+ descendants
- Complex leaf that needs full planning-workflow + auto-advance
- Multi-repo task requiring workspace-level coordination
- Subtree deep enough to benefit from dedicated session context

**Context provided**:
```
context:
  subtree: <extracted subtree for GOAL partition>
  repos: [list of repos]
  branch: "<project-branch>/<node-id>"
  workspace_path: "~/src/work/<project>/<node-id>/"
```

### Inline

Choose inline when:

- Task description contains "clarify", "discuss", or "decide"
- Task spans many repos with complex coordination
- Task's `depends_on` references a failed task
- Previous subagent dispatch failed (fallback)
- Spec has unresolved gaps
- Root session has sufficient context to implement directly

**Context provided**:
```
context:
  reason: "ambiguous" | "multi-repo" | "fallback" | "spec-gap"
  prior_failure: <issues from failed dispatch, if fallback>
```

### Escalate

Choose escalate when:

- Task requires human judgment (architecture decisions, external API choices)
- Task involves external dependencies not accessible to the agent
- Task description explicitly says "needs discussion" or similar
- Task has acceptance criteria that can't be verified automatically

**Context provided**:
```
context:
  question: "<what the human needs to decide>"
  options: ["option A", "option B"]  # if applicable
```

## Decision Heuristics

### Ambiguity Detection

Scan the node description and acceptance criteria for ambiguity signals:

```
ambiguity_keywords = [
  "clarify", "discuss", "decide", "choose between",
  "TBD", "TODO", "needs investigation", "unclear",
  "might need", "possibly", "depends on decision"
]

if any keyword in node.description.lower():
  strategy = "inline" or "escalate"
```

### Complexity Estimation

```
complexity_signals = {
  "repos_count": len(node.repos),
  "criteria_count": len(node.acceptance_criteria),
  "description_length": len(node.description),
  "dependency_count": len(node.depends_on),
  "subtree_size": count_descendants(node)  # 0 for leaves
}

# Simple leaf, low complexity → subagent
if complexity_signals.repos_count <= 2 and
   complexity_signals.criteria_count <= 5 and
   complexity_signals.subtree_size == 0:
  → subagent candidate

# Deep subtree → sub-session
if complexity_signals.subtree_size >= 4:
  → sub-session candidate
```

### Failed Dependency Check

```
for dep_id in node.depends_on:
  log_entry = results_log.find(dep_id)
  if log_entry and log_entry.status == "failed":
    strategy = "inline"
    reason = "dependency failed — needs human judgment for recovery"
```

## Example

### Simple leaf → Subagent

```
Node: A.2 "Implement user CRUD endpoints"
  - repos: [api-service]
  - criteria: 4 items
  - depends_on: [A.1] (completed)
  - description: clear, no ambiguity keywords

Decision:
  strategy: "subagent"
  reason: "Clear spec, single repo, dependencies met"
```

### Leaf with Taskfile → Container

```
Node: A.3 "Add pagination to list endpoint"
  - repos: [api-service]  (has Taskfile.yml with test, lint, build)
  - criteria: 3 items
  - depends_on: [A.2] (completed)
  - description: clear, no ambiguity keywords
  - Docker: available

Decision:
  strategy: "container"
  reason: "Clear spec, Taskfile-enabled repo, Docker available — sandboxed execution"
```

### Complex leaf → Inline

```
Node: B.3 "Choose caching strategy and implement"
  - repos: [api-service, cache-service]
  - description: "Decide between Redis and Memcached based on..."

Decision:
  strategy: "inline"
  reason: "Contains 'decide' — needs judgment"
```

### Deep subtree → Sub-session

```
Node: C "Frontend redesign" (goal with 6 descendants)
  - repos: [web-app]
  - children: 3 sub-goals, 6 total leaves

Decision:
  strategy: "sub-session"
  reason: "Deep subtree (6 descendants) — benefits from dedicated session"
```

## Integration Points

- **Called by**: execute-tree (step 2, after select-ready)
- **Feeds into**: dispatch-node (provides strategy and context)
- **Reference**: DESIGN.md DD-3 (adaptive dispatch), DD-5 (v1 strategies), DD-19 (parallel execution)
