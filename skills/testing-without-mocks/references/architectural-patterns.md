# Architectural Patterns

Optional architectural patterns that simplify testing. Not required, but helpful.

## A-Frame Architecture

**Problem:** Normal layered architecture puts infrastructure at the bottom, creating difficult-to-test dependency chains.

**Solution:** Structure application so infrastructure and logic are peers, with no dependencies between them. Coordinate at the application layer.

### Traditional Layered Architecture
```
Application
    ↓
Logic
    ↓
Infrastructure  ← Hard to test
```

### A-Frame Architecture
```
   Application
    /        \
Logic    Infrastructure  ← Easy to test independently
```

### Implementation
- **Logic layer**: Pure computation, no infrastructure
- **Infrastructure layer**: External systems, no complex logic
- **Application layer**: Coordinates between Logic and Infrastructure
- **Values layer**: Data structures passed between layers

---

## Logic Sandwich

**Problem:** In A-Frame Architecture, logic and infrastructure can't talk directly.

**Solution:** Application layer reads from infrastructure, processes with logic, writes to infrastructure.

### Example
```python
def process_request():
    # Read from infrastructure
    input_data = database.read()
    
    # Process with logic
    result = business_logic.calculate(input_data)
    
    # Write to infrastructure
    database.write(result)
```

For complex workflows, put this in a loop or add application-specific logic.

---

## Traffic Cop

**Problem:** Event-driven applications need to respond to infrastructure and logic events.

**Solution:** Use Observer pattern. Application layer listens for events and implements Logic Sandwiches for each event.

### Example
```python
class Application:
    def start(self):
        # Listen to infrastructure events
        self._server.on_request(self._handle_request)
        
        # Listen to logic events
        self._user_model.on_change(self._handle_user_change)
    
    def _handle_request(self, request):
        # Logic Sandwich for request event
        login_data = self._parse_form(request)  # Application logic
        user = self._auth_service.login(login_data)  # Infrastructure
        valid = user.is_valid()  # Logic
        if valid:
            self._session_service.create(user.session_data)  # Infrastructure
    
    def _handle_user_change(self, user_data):
        # Logic Sandwich for user change event
        self._user_service.update(user_data)  # Infrastructure
```

**Avoid God Classes** - If Traffic Cop gets complicated, split into multiple classes or reconsider design.

---

## Grow Evolutionary Seeds

**Problem:** Outside-in design typically requires broad integration tests and interaction-based tests, but we want narrow, state-based tests.

**Solution:** Use evolutionary design to grow application from a single file.

### Process

1. **Start with simplest possible Application seed**
```python
class App:
    def render(self):
        return "Hello, Sarah"  # Hardcoded
```

2. **Add barebones Infrastructure Wrapper**
```python
class App:
    def __init__(self, username_service):
        self._username = username_service
    
    def render(self):
        name = self._username.get_username()
        return f"Hello, {name}"
```

3. **Make Infrastructure Nullable**
```python
@staticmethod
def create_null(username="test_user"):
    return App(UsernameService.create_null(username))
```

4. **Add output Infrastructure Wrapper**
```python
def render(self):
    name = self._username.get_username()
    self._ui.display(f"Hello, {name}")
```

5. **Evolve incrementally** - Add features, refactor, repeat

### Result
Tests serve same purpose as end-to-end tests but are narrow, fast, and use Nullables.

---

## Summary

Architectural Patterns are optional but help:

1. **A-Frame Architecture** - Separate logic and infrastructure as peers
2. **Logic Sandwich** - Read infrastructure → process logic → write infrastructure
3. **Traffic Cop** - Handle events with Logic Sandwiches
4. **Grow Evolutionary Seeds** - Build application incrementally with tests

Use when starting fresh. For existing code, see Legacy Patterns.
