# Diataxis Framework Reference

The Diataxis framework (from Greek: dia "across" + taxis "arrangement") organizes documentation into four distinct types based on two axes.

## The Two Axes

### Axis 1: Orientation

- **Practical**: Focuses on doing (tutorials, how-to guides)
- **Theoretical**: Focuses on understanding (reference, explanation)

### Axis 2: Purpose

- **Learning**: Acquiring knowledge/skills (tutorials, explanation)
- **Working**: Applying knowledge/skills (how-to guides, reference)

## The Four Quadrants

```
                    LEARNING              WORKING
            ┌─────────────────────┬─────────────────────┐
            │                     │                     │
 PRACTICAL  │     TUTORIALS       │    HOW-TO GUIDES    │
            │                     │                     │
            │  Learning-oriented  │   Task-oriented     │
            │  Hands-on lessons   │   Problem-solving   │
            │                     │                     │
            ├─────────────────────┼─────────────────────┤
            │                     │                     │
THEORETICAL │    EXPLANATION      │     REFERENCE       │
            │                     │                     │
            │ Understanding-ori.  │  Information-ori.   │
            │ Conceptual discuss. │  Technical descrip. │
            │                     │                     │
            └─────────────────────┴─────────────────────┘
```

## Type Details

### Tutorials

**Purpose**: Enable a beginner to get started

**Characteristics**:
- Learning-oriented
- Allows learning by doing
- Gets the user started
- Teaches general skills through concrete steps
- Provides minimum viable explanation
- Is reliable and repeatable

**The user's need**: "I want to learn"

**Analogy**: Teaching a child to cook - focused on the experience, not the end result

### How-to Guides

**Purpose**: Show how to solve a specific problem

**Characteristics**:
- Task-oriented
- Focuses on goals
- Addresses specific questions
- Doesn't explain concepts
- Allows for flexibility
- Leaves things out (focuses on one path)

**The user's need**: "I want to accomplish X"

**Analogy**: A recipe in a cookbook - assumes cooking knowledge, just shows steps

### Reference

**Purpose**: Describe the machinery

**Characteristics**:
- Information-oriented
- Describes how things work
- Is accurate and complete
- Structured around the code
- Consistent in style
- Does nothing but describe

**The user's need**: "I need to look up X"

**Analogy**: Encyclopedia article - neutral, factual, comprehensive

### Explanation

**Purpose**: Illuminate a topic

**Characteristics**:
- Understanding-oriented
- Explains why
- Provides context
- Discusses alternatives
- Makes connections
- Does not instruct or describe

**The user's need**: "I want to understand why X"

**Analogy**: Article on culinary history - enriching but not required to cook

## Common Mistakes

### Mixing Types

**Problem**: A document tries to do multiple things

**Examples**:
- Tutorial that also serves as reference (too long, overwhelming)
- How-to that explains too much (loses focus on task)
- Reference with instructions (confusing purposes)

**Solution**: Split into separate documents, link between them

### Wrong Classification

| Document | Often Misclassified As | Actually Is |
|----------|----------------------|-------------|
| Getting Started | How-to | Tutorial |
| Architecture Overview | Reference | Explanation |
| API Reference | How-to | Reference |
| FAQ | Reference | Mix (break apart) |
| README | Everything | Index (links to proper docs) |

### Type Contamination

| Type | Contaminated By | How to Fix |
|------|----------------|------------|
| Tutorial | Reference details | Move specs to reference doc |
| Tutorial | Choices/alternatives | Pick one path, mention others in how-to |
| How-to | Concept explanation | Extract to explanation doc, link |
| Reference | Instructions | Move to how-to doc |
| Explanation | Step-by-step guide | Extract to tutorial/how-to |

## User Journeys

### Beginner Path

1. **Tutorial**: Learn basics hands-on
2. **Reference**: Look up specifics encountered
3. **How-to**: Accomplish first real task
4. **Explanation**: Understand the "why"

### Experienced User Path

1. **How-to**: Find solution to specific problem
2. **Reference**: Verify parameters/options
3. Back to work

### Evaluator Path

1. **Explanation**: Understand approach/philosophy
2. **Reference**: Assess completeness
3. **Tutorial**: Quick hands-on evaluation

## Quality Checklist

### Tutorial

- [ ] Does it have a clear learning goal?
- [ ] Can a beginner complete it without prior knowledge?
- [ ] Are all steps concrete and actionable?
- [ ] Does it avoid teaching concepts?
- [ ] Does it work? (tested end-to-end)

### How-to Guide

- [ ] Does it solve a specific problem?
- [ ] Is the goal clear from the title?
- [ ] Are steps numbered and actionable?
- [ ] Does it avoid explaining concepts?
- [ ] Is there only one problem addressed?

### Reference

- [ ] Is it structured around the code/system?
- [ ] Is it accurate and up-to-date?
- [ ] Is the format consistent with other reference docs?
- [ ] Does it avoid instructions?
- [ ] Does it include examples?

### Explanation

- [ ] Does it address "why"?
- [ ] Does it provide context?
- [ ] Does it avoid instructions?
- [ ] Does it connect to the bigger picture?
- [ ] Is there a clear question being answered?

## Resources

- [Diataxis.fr](https://diataxis.fr/) - Official documentation
- [Divio Documentation](https://documentation.divio.com/) - Original formulation
- [The Grand Unified Theory of Documentation](https://diataxis.fr/compass/) - Theoretical foundation
