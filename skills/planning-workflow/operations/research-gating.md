# Research Gating

After local solution search, decide whether external research (web search, documentation lookup, API docs) adds value. Prevents unnecessary research on familiar topics while ensuring high-risk areas get proper attention.

## Parameters

- `prior_solutions` (required): Output from the solution search phase — number of matches, relevance assessment
- `task_description` (required): The issue title, description, and any relevant context

## Execution Steps

### 1. Identify risk category

Classify the task into one of these categories based on its description and domain:

**High-risk** (always research externally):
- Security: authentication, authorization, encryption, secrets management
- Payments: billing, transactions, financial data
- External APIs: third-party integrations, API contracts, webhook handling
- Data privacy: PII handling, GDPR, compliance
- Infrastructure: DNS, TLS, networking, cloud provider configuration

**Low-risk** (skip external research when local knowledge is strong):
- Internal tooling and scripts
- Documentation and process changes
- Familiar framework patterns with strong local solutions
- Bug fixes where root cause is already understood

**Uncertain** (research externally):
- New technology or library not previously used
- Unfamiliar domain or first encounter with a component
- Multiple viable approaches with unclear tradeoffs
- Version upgrades or migration paths

### 2. Evaluate local knowledge strength

Assess how well the solution search covered this topic:

| Local Knowledge | Indicator |
|----------------|-----------|
| **Strong** | 2+ relevant solutions found, critical patterns apply, familiar domain |
| **Partial** | 1 solution found or tangentially related matches |
| **Weak** | No solutions found, no critical patterns relevant |

### 3. Make decision

Apply the decision matrix:

| Risk | Local Knowledge | Decision |
|------|----------------|----------|
| High | Any | Research externally |
| Low | Strong | Skip external research |
| Low | Partial/Weak | Research externally |
| Uncertain | Any | Research externally |

### 4. Log decision

Produce a brief section for the plan:

```markdown
## Research Decision

**Risk category**: <high/low/uncertain> — <one-line justification>
**Local knowledge**: <strong/partial/weak> — <N> prior solutions found
**Decision**: <Research externally / Skip external research>
<one sentence explaining why>
```

## Output

The "Research Decision" section, appended after "Prior Solutions" in the plan context. Downstream phases use this to determine whether to invoke web search or documentation lookup tools.

## Examples

### High-risk, skip not allowed
```markdown
## Research Decision

**Risk category**: high — task involves OAuth token refresh with external provider
**Local knowledge**: strong — 2 prior solutions on OAuth integration
**Decision**: Research externally
Security-sensitive integration requires verifying against current provider docs despite local knowledge.
```

### Low-risk, strong local knowledge
```markdown
## Research Decision

**Risk category**: low — internal CI script enhancement
**Local knowledge**: strong — 3 prior solutions on CI workflow patterns
**Decision**: Skip external research
Familiar domain with well-documented local patterns; external research unlikely to add value.
```

### Uncertain territory
```markdown
## Research Decision

**Risk category**: uncertain — first use of SpecFlow analysis in planning
**Local knowledge**: weak — no prior solutions found
**Decision**: Research externally
New technique with no local precedent; external research needed to establish approach.
```
