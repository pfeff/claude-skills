# Workflow vs. Goal-Tree Routing

When a task needs more than one agent, two engines are available. Pick by the
**durability and span** of the orchestration — not by how many agents it needs.

## The rule

- **Bounded, in-session fan-out → native `Workflow` tool.**
  One session decomposes work, fans out, and synthesizes a result *now*. The
  agents are ephemeral; nothing needs to survive a `/clear` or be reviewed as an
  independent PR. Control flow (loops, parallel, pipeline) is deterministic and
  lives in a `.claude/workflows/*.js` script. Examples: review a diff across
  specialist lenses, analyze a repo by domain, research a question across
  sources.

- **Durable, multi-session / multi-repo orchestration → goal-tree / L{N}.**
  Work spans sessions, repos, or days; each unit produces a reviewable PR and is
  tracked in the coordinator; layers (L2/L1/L0) own objective, decomposition, and
  implementation respectively. State lives in the tree and survives interruption.
  This is the engine for *projects*, not for a single fan-out.

## Quick test

| Question | Yes → |
|----------|-------|
| Does each unit of work need its own PR / review cycle? | goal-tree / L{N} |
| Must the work survive `/clear`, a new session, or a handoff? | goal-tree / L{N} |
| Does it span multiple repos or run over days? | goal-tree / L{N} |
| Is it one session producing one synthesized result right now? | Workflow |
| Is the fan-out shape fixed (N lenses, N sources, N domains)? | Workflow |

If two or more right-column answers are "goal-tree", it's a tree. Otherwise reach
for a Workflow.

## They compose

A single L0 leaf (one workspace session, one PR) may *internally* call a
`Workflow` to do its bounded fan-out — e.g. an L0 review task invokes the
`review` workflow. The tree owns the durable unit; the Workflow is an in-session
implementation detail of that unit. The reverse never holds: a Workflow does not
dispatch goal-tree nodes.
