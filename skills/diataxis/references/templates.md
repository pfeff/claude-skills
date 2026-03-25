# Documentation Templates

Ready-to-use templates for each Diataxis documentation type.

## Tutorial Template

```markdown
# [Project Name]: [What You'll Build/Learn]

Learn [skill/concept] by building [concrete deliverable].

**Time**: ~[X] minutes
**Level**: Beginner

## What You'll Learn

By the end of this tutorial, you will:

- [Concrete skill 1]
- [Concrete skill 2]
- [Concrete skill 3]

## Prerequisites

Before starting, you need:

- [Tool/environment requirement]
- [Knowledge requirement, if any]

## Step 1: [First Concrete Action]

[One sentence of context - why this step matters]

[Instruction - what to do]

```[language]
[code to write or command to run]
```

You should see:

```
[expected output]
```

## Step 2: [Second Concrete Action]

[Continue the pattern...]

## Step 3: [Third Concrete Action]

[Continue...]

## What You've Built

Congratulations! You've successfully [summary of accomplishment].

[Screenshot or demonstration of final result]

## Next Steps

Now that you know the basics, try:

- [Link to next tutorial]
- [Link to related how-to guide]
- [Link to reference for deeper details]
```

---

## How-to Guide Template

```markdown
# How to [Accomplish Specific Task]

[One sentence describing what this guide helps you do and when you'd need it.]

## Prerequisites

- [Requirement 1]
- [Requirement 2]

## Steps

### 1. [First Action Verb Phrase]

[Clear instruction]

```[language]
[command or code]
```

### 2. [Second Action Verb Phrase]

[Clear instruction]

```[language]
[command or code]
```

### 3. [Continue as needed...]

[Clear instruction]

## Verify It Worked

[How to confirm the task succeeded]

```[language]
[verification command]
```

Expected result:

```
[what success looks like]
```

## Troubleshooting

### [Common Error Message or Symptom]

**Cause**: [Why this happens]

**Fix**: [How to resolve it]

### [Another Common Issue]

**Cause**: [Why this happens]

**Fix**: [How to resolve it]

## See Also

- [Related how-to guide]
- [Reference documentation]
```

---

## Reference Template (API/Function)

```markdown
# [Component/API Name]

[One-line description of what it does]

## Synopsis

```[language]
[signature/usage pattern]
```

## Description

[Brief technical description - what it is and does, not how to use it]

## Parameters

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `param1` | `string` | Yes | - | [What it's for] |
| `param2` | `number` | No | `10` | [What it's for] |
| `param3` | `boolean` | No | `false` | [What it's for] |

## Return Value

**Type**: `[return type]`

[Description of what is returned]

## Examples

### Basic Usage

```[language]
[minimal example]
```

### [Specific Use Case]

```[language]
[example with context]
```

## Errors

| Error | Condition | Resolution |
|-------|-----------|------------|
| `ErrorName` | [When it occurs] | [How to handle] |

## Notes

- [Important consideration]
- [Edge case behavior]

## See Also

- [`relatedFunction()`](./related-function.md)
- [Explanation: Why This Works This Way](../explanation/topic.md)
```

---

## Reference Template (Configuration)

```markdown
# [Configuration File/Section] Reference

[One-line description of what this configures]

## Location

```
[path/to/config/file]
```

## Format

```[format]
[example structure]
```

## Options

### `option_name`

**Type**: `string`
**Default**: `"default_value"`
**Required**: No

[What this option controls]

**Values**:
- `"value1"` - [what it does]
- `"value2"` - [what it does]

**Example**:

```[format]
option_name = "value1"
```

### `another_option`

**Type**: `number`
**Default**: `100`
**Required**: No
**Range**: `1-1000`

[What this option controls]

## Complete Example

```[format]
[full example with common options]
```

## Environment Variables

| Variable | Overrides | Description |
|----------|-----------|-------------|
| `ENV_VAR` | `option_name` | [What it does] |

## See Also

- [How to Configure X](../how-to/configure-x.md)
- [Understanding Configuration](../explanation/configuration.md)
```

---

## Explanation Template

```markdown
# [Topic/Concept]

[Opening statement or question that frames the discussion]

## Background

[Context - what led to this, historical perspective, why it exists]

## [Core Concept Name]

[Main explanation - the "why" behind the topic]

### [Aspect 1]

[Detailed exploration of one facet]

### [Aspect 2]

[Detailed exploration of another facet]

## How It Works

[High-level description of mechanism - enough to understand, not to implement]

## Alternatives

### [Alternative Approach 1]

[What it is and why it wasn't chosen]

### [Alternative Approach 2]

[What it is and why it wasn't chosen]

## Trade-offs

| Approach | Pros | Cons |
|----------|------|------|
| Current | [benefits] | [drawbacks] |
| Alternative | [benefits] | [drawbacks] |

## Implications

[What this means for users/developers/the system]

## Common Misconceptions

### "[Misconception]"

[Why it's wrong and what's actually true]

## Further Reading

- [Link to deeper resource]
- [Link to related explanation]
- [External resource]

## See Also

- [Tutorial: Getting Started with X](../tutorials/x.md)
- [Reference: X API](../reference/x-api.md)
```

---

## README/Index Template

```markdown
# [Project] Documentation

[One-paragraph description of what this project does]

## Quick Start

New to [project]? Start here:

1. [Link to getting started tutorial]
2. [Link to first how-to guide]

## Documentation

### [Tutorials](tutorials/)

Learn [project] step-by-step:

- [Tutorial 1](tutorials/tutorial-1.md) - [what you'll learn]
- [Tutorial 2](tutorials/tutorial-2.md) - [what you'll learn]

### [How-to Guides](how-to/)

Solve common problems:

- [How to X](how-to/x.md)
- [How to Y](how-to/y.md)

### [Reference](reference/)

Technical specifications:

- [API Reference](reference/api.md)
- [Configuration](reference/configuration.md)
- [CLI Commands](reference/cli.md)

### [Explanation](explanation/)

Understand the design:

- [Architecture](explanation/architecture.md)
- [Why We Chose X](explanation/why-x.md)

## Getting Help

- [GitHub Issues](link)
- [Discord/Slack](link)
- [FAQ](faq.md)
```
