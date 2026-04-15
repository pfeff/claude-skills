# Layer Model Reference

How goal tree depth maps to the autoresearch layer architecture. The tree encodes layer ownership without requiring schema changes in the coordinator.

## Layer Assignment Rules

| Rule | Layer | Description |
|------|-------|-------------|
| Tree root | L2 | The objective — what the project delivers |
| Leaf node (any depth) | L0 | A task — dispatched to a workspace session, produces a PR |
| Non-leaf node (any depth) | L1 | Decomposition structure — cycles, phases, sub-goals that organize L0 work |
| Depth-0 non-leaf | L1 boundary | Primary cycle/phase boundary; the unit L2 evaluates |

**Key insight**: leaf-vs-non-leaf determines the layer, not absolute depth. A leaf at depth 1 and a leaf at depth 3 are both L0 tasks. A non-leaf at depth 0 and a non-leaf at depth 2 are both L1 structure.

## Layer Responsibilities

### L2 (Tree Root)

- **Owns**: the objective, success criteria, standing rules, resource budget
- **Input**: mission/schwerpunkt from human or L3
- **Output**: capability delta, discoveries, residual risk
- **Evaluates**: L1 cycle outcomes against success criteria
- **Does not**: dispatch tasks, write code, manage branches

### L1 (Non-Leaf Nodes)

- **Owns**: decomposition of objective into dispatchable units
- **Input**: L2 objective + standing rules + budget
- **Output**: dispatched L0 tasks, cycle reports, evaluation results
- **Evaluates**: L0 task outputs via spec-driven evaluation (execute-tree step 5a)
- **Control loop**: select-ready → dispatch-decision → dispatch-node → monitor → evaluate → repeat

Depth-0 non-leaf nodes are the primary L1 cycle boundary. Deeper non-leaf nodes (e.g., D.3 at depth 2 with children at depth 3) are L1 sub-decomposition — they organize work but don't change the layer contract.

### L0 (Leaf Nodes)

- **Owns**: implementation of a single task within a workspace session
- **Input**: DESIGN.md spec with acceptance criteria
- **Output**: PR (code changes), commit hashes, task-workflow artifacts
- **Follows**: task-workflow (init-workspace → plan → implement → test → finish)
- **Does not**: evaluate its own quality (L1 does that), dispatch other tasks, modify the tree

## Deriving Layer from Coordinator Data

No schema change is needed. Layer is computed from existing fields:

```
function layer(node, tree):
  if node is tree root:
    return "L2"
  if has_children(node, tree):
    return "L1"
  return "L0"

function has_children(node, tree):
  return any(n.parent_id == node.id for n in tree.nodes)

function depth(node, tree):
  d = 0
  current = node
  while current.parent_id is not null:
    current = tree.nodes[current.parent_id]
    d += 1
  return d
```

## Depth Encodes L1 Granularity

Depth within L1 structure encodes decomposition granularity, not a different layer:

```
Depth 0:  A (L1 phase)          — "Research & Formalize"
Depth 1:    A.1 (L0 task)       — "Study Karpathy's autoresearch"
Depth 1:    A.2 (L0 task)       — "Document current process"

Depth 0:  C (L1 phase)          — "Implement Improvements"
Depth 1:    C.3 (L1 sub-cycle)  — "Cycle 3 — L1 withdrawal"
Depth 2:      C.3.22 (L0 task)  — "Tree model update"
Depth 2:      D.3 (L1 sub-goal) — "Container dispatch via Docker MCP"
Depth 3:        D.3.7 (L0 task) — "Add MCP server to AC"
```

The number of intermediate L1 levels varies by how much decomposition the work requires. The convention accommodates this naturally.

## Implications for Operations

| Operation | Layer Relevance |
|-----------|----------------|
| `execute-tree` | Operates as L1 control loop — dispatches L0 leaves, evaluates results, cycles |
| `dispatch-decision` | Only dispatches leaf nodes (L0). Non-leaf nodes are decomposed, not dispatched |
| `select-ready` | Returns ready leaf nodes only. Non-leaf readiness is derived from children |
| `next-cycle` | L1 cycle boundary — observes completed L0 work, orients, proposes new nodes |
| `start-project` | Creates L2 objective (tree) and initial L1 decomposition (top-level nodes) |
| `synthesize` | L2 operation — merges all L1/L0 results into integration branch |
| `spec-driven evaluation` | L1 evaluates L0 output. L2 evaluates L1 cycle outcomes |

## Standing Rules and Layer Scope

Standing rules are scoped at the layer that owns the architectural decision:

- Rules in project CLAUDE.md (`## Standing Rules`) apply to all L0 dispatches within the tree
- Per-task acceptance criteria apply to individual L0 tasks
- Both use the same evaluate machinery (execute-tree step 5a)

The layer that creates a rule is the layer that evaluates compliance. L1 creates standing rules and evaluates them during L0 output assessment.
