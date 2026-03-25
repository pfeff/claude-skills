# Documentation Anti-patterns

Common mistakes when writing documentation and how to avoid them.

## Tutorial Anti-patterns

### Teaching Instead of Guiding

**Bad**:
```markdown
# Understanding Authentication

Authentication is the process of verifying identity. There are several
types: basic auth, token-based, OAuth 2.0...

[3 pages of explanation]

Now let's set up authentication...
```

**Good**:
```markdown
# Build Your First Authenticated App

In this tutorial, you'll add login to a simple web app.

## Step 1: Create the Login Form

Create a file called `login.html`:

```html
<form action="/login" method="post">
  <input name="email" type="email">
  <input name="password" type="password">
  <button type="submit">Login</button>
</form>
```
```

**Why**: Tutorials are about learning by doing. Explanations belong in explanation docs.

---

### Offering Choices

**Bad**:
```markdown
## Step 3: Choose a Database

You can use PostgreSQL, MySQL, or SQLite. Here's how to set up each:

### Option A: PostgreSQL
[instructions]

### Option B: MySQL
[instructions]

### Option C: SQLite
[instructions]
```

**Good**:
```markdown
## Step 3: Set Up the Database

We'll use PostgreSQL for this tutorial.

```bash
createdb myapp
```

> Using a different database? See our [database configuration guide](../how-to/configure-database.md).
```

**Why**: Choices confuse beginners. Pick one path. Mention alternatives in how-to guides.

---

### Assuming Prior Knowledge

**Bad**:
```markdown
## Prerequisites

- Familiarity with React hooks
- Understanding of state management patterns
- Experience with REST APIs
```

**Good**:
```markdown
## Prerequisites

- Node.js installed ([download here](https://nodejs.org))
- A text editor (we'll use VS Code)
- 30 minutes of free time

No prior React experience needed - we'll explain everything as we go.
```

**Why**: Tutorials are for beginners. If prerequisites are needed, link to prerequisite tutorials.

---

## How-to Guide Anti-patterns

### Explaining Concepts

**Bad**:
```markdown
# How to Deploy to Production

Deployment is the process of making your application available to users.
In modern software development, we use CI/CD pipelines to automate this
process. CI stands for Continuous Integration, which means...

[2 paragraphs later]

## Steps

1. Run the deploy command
```

**Good**:
```markdown
# How to Deploy to Production

Deploy your app to production in three steps.

> New to deployment? See [Understanding Our Deploy Process](../explanation/deployment.md) first.

## Steps

1. Ensure tests pass:
   ```bash
   npm test
   ```

2. Build for production:
   ```bash
   npm run build
   ```

3. Deploy:
   ```bash
   npm run deploy
   ```
```

**Why**: How-to guides are for practitioners who know what they want to do. Link to explanations for the curious.

---

### Multiple Problems in One Guide

**Bad**:
```markdown
# How to Set Up, Configure, and Troubleshoot the Cache

## Setting Up Redis
[10 steps]

## Configuring Cache TTL
[8 steps]

## Troubleshooting Cache Misses
[6 steps]

## Monitoring Cache Performance
[7 steps]
```

**Good**:
```markdown
# How to Set Up Redis Cache

Configure Redis as your application cache.

[focused steps for ONE task]

## See Also

- [How to Configure Cache TTL](./configure-cache-ttl.md)
- [How to Troubleshoot Cache Misses](./troubleshoot-cache-misses.md)
- [How to Monitor Cache Performance](./monitor-cache.md)
```

**Why**: Each how-to should solve one problem. Users search for specific solutions.

---

## Reference Anti-patterns

### Including Instructions

**Bad**:
```markdown
# Configuration Reference

## database_url

**Type**: string

To configure the database URL, first open your config file, then
add the following line. Make sure to replace the placeholders with
your actual values:

```yaml
database_url: postgres://user:pass@host:5432/db
```

After saving, restart the application.
```

**Good**:
```markdown
# Configuration Reference

## database_url

**Type**: `string`
**Required**: Yes
**Format**: `postgres://user:pass@host:port/database`

Connection string for the primary database.

**Example**:
```yaml
database_url: postgres://admin:secret@db.example.com:5432/myapp
```

See [How to Configure Database Connection](../how-to/configure-database.md) for setup instructions.
```

**Why**: Reference docs describe. They don't instruct. Link to how-to guides for instructions.

---

### Inconsistent Format

**Bad**:
```markdown
## create_user()

Creates a user. Takes name as first arg, email as second.

Returns the user ID.

---

## `delete_user(user_id: int) -> bool`

| Parameter | Type | Description |
|-----------|------|-------------|
| user_id | int | The user to delete |

**Returns**: Boolean indicating success

---

## UpdateUser

updates a user
args: user_id, **kwargs
```

**Good**:
```markdown
## create_user

```python
create_user(name: str, email: str) -> int
```

Creates a new user account.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| name | str | Yes | User's display name |
| email | str | Yes | User's email address |

**Returns**: `int` - The new user's ID

---

## delete_user

```python
delete_user(user_id: int) -> bool
```

Removes a user account.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| user_id | int | Yes | ID of user to delete |

**Returns**: `bool` - True if deleted, False if not found
```

**Why**: Reference docs should be scannable. Consistent formatting aids lookup.

---

## Explanation Anti-patterns

### Being Too Abstract

**Bad**:
```markdown
# Understanding Our Architecture

Our system follows modern architectural principles with a focus on
scalability and maintainability. We leverage industry best practices
to ensure robust performance and reliability.

The microservices paradigm enables us to achieve loose coupling while
maintaining high cohesion within service boundaries.
```

**Good**:
```markdown
# Understanding Our Architecture

We use microservices because our team ships features independently.

## Why Microservices?

In 2022, we had a monolith. Deploying any change meant deploying everything.
The auth team couldn't ship without waiting for the payments team.

Now, each team owns their service:

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│    Auth     │  │  Payments   │  │   Orders    │
│   Service   │  │   Service   │  │   Service   │
└─────────────┘  └─────────────┘  └─────────────┘
      │                │                │
      └────────────────┼────────────────┘
                       │
                ┌──────┴──────┐
                │   Gateway   │
                └─────────────┘
```

This lets us deploy auth changes without touching payments code.
```

**Why**: Explanation without concrete examples becomes meaningless. Ground abstractions in reality.

---

### Step-by-Step Instructions

**Bad**:
```markdown
# Understanding Event-Driven Architecture

Event-driven architecture is a powerful pattern. Here's how to implement it:

1. First, install RabbitMQ:
   ```bash
   brew install rabbitmq
   ```

2. Create your first queue:
   ```bash
   rabbitmqadmin declare queue name=events
   ```

3. ...
```

**Good**:
```markdown
# Understanding Event-Driven Architecture

Events let services communicate without knowing about each other.

## The Problem with Direct Calls

When Service A calls Service B directly:

```
Service A ──HTTP──> Service B
```

Service A must know Service B's address. If B is down, A fails.
If we add Service C, we modify A.

## Events as Middleman

With events:

```
Service A ──publish──> Event Bus ──subscribe──> Service B
                                ──subscribe──> Service C
```

A publishes events without knowing who listens. B and C subscribe
independently. If C is added, A doesn't change.

## When to Use Events

Events work well when:
- Services shouldn't know about each other
- Actions trigger multiple downstream effects
- Timing isn't critical (eventual consistency is OK)

For implementation details, see:
- [How to Publish Events](../how-to/publish-events.md)
- [RabbitMQ Reference](../reference/rabbitmq.md)
```

**Why**: Explanation illuminates concepts. Implementation belongs in tutorials and how-to guides.

---

## Meta Anti-patterns

### The Everything README

**Bad**:
```markdown
# MyProject

[500 lines covering installation, quickstart, API reference,
 architecture explanation, contributing guidelines, and changelog]
```

**Good**:
```markdown
# MyProject

One-line description.

## Quick Start

```bash
npm install myproject
```

## Documentation

- [Tutorials](docs/tutorials/) - Learn the basics
- [How-to Guides](docs/how-to/) - Solve specific problems
- [Reference](docs/reference/) - API and configuration
- [Explanation](docs/explanation/) - Architecture and design

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)
```

**Why**: README is an index, not the documentation itself. Link to proper docs.

---

### FAQ as Documentation

**Bad**:
```markdown
# FAQ

Q: How do I install the project?
A: Run `npm install myproject`

Q: What is the configuration file format?
A: YAML. See example below...

Q: Why does the cache use Redis?
A: We evaluated several options...
```

**Good**: Split FAQs into proper documentation types:

- "How do I install?" → Tutorial or How-to
- "What is the format?" → Reference
- "Why Redis?" → Explanation

FAQs often indicate documentation gaps. Fill those gaps properly.

---

## Quick Reference

| If you find yourself... | You're probably... | Instead... |
|------------------------|-------------------|------------|
| Explaining concepts in a tutorial | Mixing types | Link to explanation |
| Giving choices in a tutorial | Confusing beginners | Pick one path |
| Writing paragraphs in a how-to | Teaching | Be terse, link to explanation |
| Solving multiple problems in one how-to | Overloading | Split into separate guides |
| Giving steps in reference | Instructing | Link to how-to guide |
| Using inconsistent format in reference | Being sloppy | Follow established format |
| Being abstract in explanation | Being unhelpful | Use concrete examples |
| Giving implementation steps in explanation | Wrong type | Link to tutorial/how-to |
