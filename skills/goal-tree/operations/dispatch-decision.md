# Dispatch Decision Operation

Evaluates a ready node and selects the appropriate execution strategy: workspace session, discuss-dispatch, or escalate.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `node` | Yes | The node to evaluate (from select-ready) |
| `tree` | Yes | Full parsed goal tree (for context) |
| `results_log` | Yes | Completed results log entries (for dependency context) |

## Output

```
decision:
  strategy: "workspace-session" | "discuss-dispatch" | "escalate"
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
| 3 | Strategic / ambiguous | Escalate or discuss-dispatch | Human review | Architecture decisions, scope changes |

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
Does the node need human judgment?
├── Yes → ESCALATE
└── No
    ├── Is the spec clear and self-contained?
    │   ├── Yes → WORKSPACE SESSION
    │   └── No (ambiguous, underspecified)
    │       ├── Ambiguity is resolvable via conversation → DISCUSS-DISPATCH
    │       └── Ambiguity requires human decision → ESCALATE
    └── Is it a fallback from a failed workspace session? → WORKSPACE SESSION (with adjusted spec)
```

## Strategy Criteria

### Workspace Session

Choose workspace session when:

- Spec has clear acceptance criteria
- No "clarify", "discuss", "decide" in description
- No unresolved spec gaps
- Dependencies are all completed (results available for context)

This is the default strategy. Everything dispatches to a workspace session — the decision is about spec completeness, not task complexity. A leaf task with 2 files and a deep subtree with 20 files both go to workspace sessions. The spec scales; the substrate doesn't change.

**Context provided**:
```
context:
  repos: [list of repos]
  node_workspace: "<path to node workspace>"
  session_name: "<tmux session name>"
```

### Discuss-Dispatch

Choose discuss-dispatch when:

- Spec has gaps that can be resolved through conversation
- Task description contains "clarify" or "discuss" but not "decide" (decisions need human judgment)
- Acceptance criteria are vague or missing
- The node would benefit from incremental DESIGN.md refinement before autonomous execution

This follows the discuss-dispatch lifecycle: conversation → workspace creation → incremental DESIGN.md → handoff to workspace session.

**Context provided**:
```
context:
  gaps: ["<list of spec gaps to resolve>"]
  repos: [list of repos]
```

### Escalate

Choose escalate when:

- Task requires human judgment (architecture decisions, external API choices)
- Task involves external dependencies not accessible to the agent
- Task description explicitly says "needs discussion" or "decide"
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
  if "decide" or "choose between" in keywords_found:
    strategy = "escalate"
  else:
    strategy = "discuss-dispatch"
```

### Failed Dependency Check

```
for dep_id in node.depends_on:
  log_entry = results_log.find(dep_id)
  if log_entry and log_entry.status == "failed":
    strategy = "escalate"
    reason = "dependency failed — needs human judgment for recovery"
```

## Examples

### Clear spec → Workspace Session

```
Node: A.2 "Implement user CRUD endpoints"
  - repos: [api-service]
  - criteria: 4 items
  - depends_on: [A.1] (completed)
  - description: clear, no ambiguity keywords

Decision:
  strategy: "workspace-session"
  tier: 2
  reason: "Clear spec, dependencies met — dispatch to workspace session"
```

### Complex subtree → Workspace Session

```
Node: C "Frontend redesign" (goal with 6 descendants)
  - repos: [web-app]
  - children: 3 sub-goals, 6 total leaves
  - spec: clear acceptance criteria for each level

Decision:
  strategy: "workspace-session"
  tier: 2
  reason: "Deep subtree but spec is clear — workspace session handles complexity via its own decomposition"
```

### Vague spec → Discuss-Dispatch

```
Node: B.2 "Improve caching layer"
  - repos: [api-service, cache-service]
  - criteria: "Make caching faster" (vague)
  - description: "clarify what the bottleneck is"

Decision:
  strategy: "discuss-dispatch"
  tier: 3
  reason: "Spec has gaps — needs conversation to refine acceptance criteria"
```

### Needs judgment → Escalate

```
Node: B.3 "Choose caching strategy and implement"
  - repos: [api-service, cache-service]
  - description: "Decide between Redis and Memcached based on..."

Decision:
  strategy: "escalate"
  tier: 3
  reason: "Contains 'decide' — needs human judgment"
```

## Integration Points

- **Called by**: execute-tree (step 2, after select-ready)
- **Feeds into**: dispatch-node (provides strategy and context)
- **Reference**: DESIGN.md DD-3 (adaptive dispatch), DD-5 (v1 strategies), DD-19 (parallel execution)
