---
name: testing-without-mocks
description: Test-Driven Development (TDD) using the Testing Without Mocks pattern language. Create fast, maintainable, refactorable tests using Nullables instead of mocking frameworks. Supports sociable, state-based tests without broad integration tests. Use when implementing features with TDD, testing infrastructure code, or converting mock-based tests. Supports Python, Go, and Elixir.
version: 1.0.0
---

# Testing Without Mocks

Write tests that are fast, maintainable, and easy to refactor by using **Nullables** instead of mocking frameworks. This approach combines narrow, sociable tests with state-based assertions to achieve the speed and reliability of unit tests with the power of integration tests.

## Core Concept

**Nullables** are production classes with an "off" switch that disables external communication while preserving all other behavior. Unlike mocks, Nullables are real production code that can be tested and used in production (e.g., for dry-run modes or cache warming).

### Key Benefits

- **No broad tests required** - Test suite consists entirely of narrow, focused tests
- **Easy refactoring** - Tests check behavior, not implementation details
- **Fast and deterministic** - Infrastructure dependencies are "nulled" in tests
- **Readable tests** - Follow arrange-act-assert with clear state-based assertions
- **Legacy compatible** - Mix with existing mocks during incremental conversion

### Trade-offs

- Requires production code modifications (createNull factories, embedded stubs)
- Need hand-written stub code for third-party infrastructure
- Multiple tests may fail when dependencies break (sociable test characteristic)

## When to Use This Skill

Trigger this skill for:
- "Help me write tests using TDD"
- "Test this without mocks"
- "Make this infrastructure code testable"
- "Convert these mock-based tests"
- "Design testable architecture"

## TDD Workflow

### 1. Identify the Type of Code

Determine which pattern category applies:

- **Pure Logic** - No infrastructure dependencies → Use Logic Patterns
- **Infrastructure Wrapper** - Direct third-party dependencies → Use Infrastructure Patterns with Narrow Integration Tests
- **Application/Mixed** - Logic + infrastructure dependencies → Use Nullability Patterns

### 2. Write a Failing Test

Write a narrow, state-based test that describes the desired behavior:

```python
# Python example
def test_transforms_text_with_rot13():
    app = App.create_null(args=["hello"])
    output = app.run()
    assert output == "uryyb\n"
```

### 3. Make It Pass with Minimal Code

Implement just enough to make the test pass, using Nullables for dependencies:

```python
class App:
    @staticmethod
    def create_null(args=None):
        command_line = CommandLine.create_null(args=args or [])
        return App(command_line)
    
    def __init__(self, command_line):
        self._command_line = command_line
    
    def run(self):
        args = self._command_line.args()
        if len(args) == 0:
            return "Usage: run text_to_transform\n"
        return rot13.transform(args[0]) + "\n"
```

### 4. Refactor

Improve the design while keeping tests green. Tests won't break because they check behavior, not implementation.

### 5. Iterate

Add more tests for edge cases, error handling, and additional behaviors.

## Pattern Selection Guide

Use this decision tree to select the right patterns:

**Is this bash/shell script logic (conditionals, validation)?**
→ YES: See [Shell Logic Isolation Patterns](references/shell-testing.md) - Extract and test conditionals in isolation
→ NO: Continue...

**Is the code pure logic (no infrastructure)?**
→ YES: See [Logic Patterns](references/logic-patterns.md)
→ NO: Continue...

**Does it directly use third-party infrastructure?**
→ YES: See [Infrastructure Patterns](references/infrastructure-patterns.md) - Create Infrastructure Wrapper with Embedded Stub
→ NO: Continue...

**Are you building a new application?**
→ YES: See [Architectural Patterns](references/architectural-patterns.md) - Use Grow Evolutionary Seeds
→ NO: Continue...

**Are you converting existing code?**
→ YES: See [Legacy Patterns](references/legacy-patterns.md) - Use Descend/Climb the Ladder
→ NO: See [Nullability Patterns](references/nullability-patterns.md) - Fake It Once You Make It

## Quick Reference by Language

### Python Idioms

```python
# Nullable factory
@staticmethod
def create_null(response=None):
    return MyClass(NulledDependency(response))

# Configurable Responses
class HttpClient:
    @staticmethod
    def create_null(responses=None):
        return HttpClient(StubbedHttp(responses or {}))

# Output Tracking
def track_output(self):
    tracker = OutputTracker()
    self._emitter.on("output", tracker.record)
    return tracker
```

### Go Idioms

```go
// Nullable factory
func CreateNull(opts ...NullOption) *MyStruct {
    config := &nullConfig{}
    for _, opt := range opts {
        opt(config)
    }
    return &MyStruct{dep: &NulledDependency{config}}
}

// Configurable Responses
func WithResponse(resp string) NullOption {
    return func(c *nullConfig) {
        c.response = resp
    }
}

// Output Tracking
type OutputTracker struct {
    calls []OutputCall
    mu    sync.Mutex
}
```

### Elixir Idioms

```elixir
# Nullable factory
def create_null(opts \\ []) do
  %MyModule{
    dependency: NulledDependency.new(opts)
  }
end

# Configurable Responses using keyword lists
def new(response: response) do
  %NulledDependency{response: response}
end

# Output Tracking using process mailbox or Agent
def track_output(pid) do
  Agent.start_link(fn -> [] end)
end
```

## Essential Patterns

Every TDD session will use these core patterns from [Foundational Patterns](references/foundational-patterns.md):

1. **Narrow Tests** - Focus tests on specific behavior, not the whole system
2. **State-Based Tests** - Assert on output/state, not method calls
3. **Overlapping Sociable Tests** - Use real dependencies, creating a chain of overlapping tests
4. **Parameterless Instantiation** - All classes have no-argument factories with sensible defaults
5. **Zero-Impact Instantiation** - Constructors do no significant work

## Pattern Documentation

Complete pattern documentation organized by category:

- **[Foundational Patterns](references/foundational-patterns.md)** - Core principles (Narrow Tests, State-Based Tests, etc.)
- **[Architectural Patterns](references/architectural-patterns.md)** - A-Frame Architecture, Logic Sandwich, Traffic Cop
- **[Logic Patterns](references/logic-patterns.md)** - Testing pure computation
- **[Infrastructure Patterns](references/infrastructure-patterns.md)** - Testing external systems
- **[Nullability Patterns](references/nullability-patterns.md)** - Core Nullables techniques (Embedded Stub, Configurable Responses, Output Tracking)
- **[Legacy Patterns](references/legacy-patterns.md)** - Converting existing code
- **[Shell Logic Isolation Patterns](references/shell-testing.md)** - Testing bash conditionals and validation in isolation

## Language-Specific Examples

Complete working ROT13 encoder examples demonstrating all patterns:

- **[Python Example](references/python-example.md)** - With pytest, OutputTracker helper, Embedded Stubs
- **[Go Example](references/go-example.md)** - With testify, Functional Options pattern, thread-safe tracking
- **[Elixir Example](references/elixir-example.md)** - With ExUnit, Agent-based tracking, keyword lists

Each example includes full production code, tests, and explanations of language-specific idioms.

## Common Scenarios

### Testing a Web Controller

Use Nullables for infrastructure (HTTP, database, etc.) and state-based assertions:

```python
def test_login_writes_to_log():
    log = Log.create_null()
    log_output = log.track_output()
    
    controller = LoginController(log)
    controller.post({"email": "user@example.com"})
    
    assert log_output.data == [{
        "level": "info",
        "message": "User login",
        "email": "user@example.com"
    }]
```

### Testing Infrastructure Wrappers

Use Narrow Integration Tests for low-level wrappers, Embedded Stubs for Nullables:

```python
def test_http_client_makes_request():
    # Real integration test
    server = TestServer()
    client = HttpClient.create()
    
    response = client.get(f"http://localhost:{server.port}/path")
    
    assert response.status == 200
    assert server.last_request.path == "/path"
```

### Testing Error Conditions

Use Configurable Responses to simulate errors:

```python
def test_handles_network_timeout():
    http_client = HttpClient.create_null(
        responses={"/api": TimeoutError()}
    )
    
    client = ApiClient(http_client)
    result = client.fetch_data()
    
    assert result.error == "Network timeout"
```

## Progressive Complexity

Start simple and add complexity as needed:

1. **Level 1** - Pure logic with simple dependencies
2. **Level 2** - Add infrastructure wrappers with Embedded Stubs
3. **Level 3** - Multi-layer dependencies with Fake It Once You Make It
4. **Level 4** - Complex event-driven systems with Behavior Simulation

## Anti-Patterns to Avoid

- **Don't** test implementation details (method calls)
- **Don't** use broad end-to-end tests as the primary safety net
- **Don't** create "God Classes" that do everything
- **Don't** do significant work in constructors
- **Don't** make Nullables that require complex setup

## Getting Started Checklist

- [ ] Read [Foundational Patterns](references/foundational-patterns.md)
- [ ] Review language examples for your language
- [ ] Start with a simple feature using TDD
- [ ] Create your first Nullable infrastructure wrapper
- [ ] Practice state-based assertions
- [ ] Refactor with confidence
