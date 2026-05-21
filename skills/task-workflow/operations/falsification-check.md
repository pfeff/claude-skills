# Falsification Check Operation

Before writing down a synthesis claim about infrastructure state, run the most direct read-only query that would falsify the claim. Refute first, then assert.

**Requirements**: Trigger this step at the synthesis/write boundary — anywhere a claim about infra state is about to be persisted (Obsidian note, Jira ticket, PR description, DESIGN.md, status update, lessons-learned entry).

## Inputs

None — invoked as a sub-routine from any operation that produces written claims. Caller supplies the candidate claim in conversational context.

## Purpose

Catches diagnostic-framing errors that arise from synthesizing on a single evidence path (logs alone, state files alone, console UI alone). The discipline is to identify the **single most direct read-only query** that would refute the claim, run it, and only assert after the query confirms the claim. This narrows the gap between "the agent thinks X is true" and "X is observably true in the authoritative system" before the claim is recorded for downstream readers.

Source: DO-588 Octopus stack17 investigation (LL-1 / R1). See `qmd://tcetra/Generated/202605210922-Lessons-Learned-DO-588-Octopus-Investigation.md`.

## Trigger Condition

Run this step **any time the agent is about to assert a fact about infrastructure state in writing**. Concrete trigger surfaces:

- Writing a status update or summary (chat, PR description, Jira comment, Slack post)
- Writing or updating an Obsidian note (Lessons Learned, Investigation, incident report)
- Writing or updating `DESIGN.md`, `PLAN.md`, ADRs, or other workspace documentation
- Drafting a commit message or PR body that names a specific cause or state
- Composing a recommendation that depends on the current state being a particular way

Do **not** run this step during evidence-gathering. The check fires at the moment of synthesis — when the next words on the page would commit the agent to a factual claim.

## Execution Steps

### 1. State the Claim Explicitly

Write the candidate claim as a single sentence, in declarative form. Examples:

- "The stack17 EC2 instance does not exist."
- "The deployment is blocked because the branch is stale."
- "The Lambda has been failing since the dotnet6 deprecation date."

If the claim is hedged ("seems to", "probably", "looks like"), either commit it to a falsifiable form or drop it — hedged claims slip past this check because nothing definite can be queried.

### 2. Identify the Single Most Direct Falsifying Query

Pick the **one** read-only query whose result would refute the claim if false. Selection criteria:

- **Authoritative source**, not a downstream view. AWS API, not a Terraform plan summary. Octopus API, not a Slack notification. `git log` on origin, not a stale local branch.
- **Direct**, not transitive. `aws ec2 describe-instances` to check whether an instance exists, not `terraform plan` (which describes intended changes, not current state).
- **Read-only**, no side effects. `kubectl get pod`, not `kubectl rollout restart`.

| Claim shape | Falsifying query |
|-------------|------------------|
| Resource exists / does not exist | `aws ec2 describe-instances`, `aws rds describe-db-instances`, `kubectl get <kind> <name>` |
| Deployment / process state | `gh run view`, `gh pr view`, Octopus API release/deployment lookup |
| Branch / commit / merge state | `git log origin/<branch>`, `gh pr view --json mergedAt,state` |
| Variable / config value | Octopus variable inspect, `aws ssm get-parameter`, `kubectl get configmap` |
| Schedule / timer state | EventBridge `list-rules`, cron entry inspection, Lambda `get-function` |

If no single direct read-only query exists, the claim is probably too broad — narrow it until one does.

### 3. Run the Query and Capture the Output

Execute the query. Record the exact command and the relevant output excerpt (not a summary) in the same place the claim will appear, or in conversational context for caller operations to consume.

If the query fails (auth error, permissions, transient), retry once. If it still fails, treat the claim as unverified — go back to step 1 and either pick a different query, or do not write the claim down.

### 4. Compare Output to Claim, Then Write

- **Query refutes the claim**: drop or rewrite the claim. The synthesis was wrong; back up and resume evidence-gathering from this counter-example.
- **Query confirms the claim**: write the claim, and cite the query and its output inline so the reader can re-run it.
- **Query is ambiguous** (neither confirms nor refutes): do not write the claim. Either gather more evidence or write a narrower, falsifiable version.

## Anti-pattern

Synthesizing from a single evidence path without cross-checking the authoritative read-only API. Common shapes:

- Reading **GitHub Actions logs** and concluding the underlying resource is in state X, without checking the cloud-provider API directly.
- Reading a **Terraform plan diff** (`0 added, 0 changed, 0 destroyed`) and concluding the resource exists or does not exist — a plan diff describes intended changes against state, not current real-world state.
- Reading **Octopus deployment history** and concluding the variable is or isn't set, without inspecting the variable directly.
- Reading a **dashboard** and concluding the metric reflects current state, without checking the dashboard's lag and the underlying data source.

The fix is always the same: identify the authoritative read-only API for the kind of fact being asserted, and query it directly before writing the claim down.

## Concrete Example (DO-588)

**Claim drafted by the agent**: "The stack17 EC2 instance does not exist."

**Evidence used**: Terraform plan output from `apply-workspace-stacks (stack17)` showed `0 added, 0 changed, 0 destroyed`. The agent read this as "no EC2 to manage, therefore none exists."

**Falsifying query (skipped, then required by this step)**:

```bash
aws ec2 describe-instances \
  --filters Name=tag:Stack,Values=stack17 \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags]' \
  --output table
```

**What the query actually returned**: a running instance with `Stack=stack17`. The plan diff `0 added, 0 changed, 0 destroyed` meant **workspace state is in-sync**, not **resource is absent**. The two are very different propositions; only one was supported by the evidence, and it wasn't the one the agent wrote.

**Outcome had the check run**: the agent would have rewritten the claim to "Terraform workspace state for stack17 is in-sync with the configured infrastructure" — a narrower, accurate, and useful statement.

## Integration Points

- **Caller operations** (consult this step at synthesis time):
  - `skills/task-workflow/operations/finish.md` — when drafting PR description / knowledge-capture notes
  - `skills/planning-workflow/operations/problem-validation.md` — when documenting current workflow / pain (infra state claims)
  - Any incident / RCA / lessons-learned authoring flow that produces written claims
- **Related references**:
  - `references/error-classification.md` — distinguishes transient query failures (retry) from permanent ones (cannot verify, do not write claim)
- **Source**: `qmd://tcetra/Generated/202605210922-Lessons-Learned-DO-588-Octopus-Investigation.md` (LL-1 / R1)
