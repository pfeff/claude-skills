# Legacy Patterns

Patterns for converting existing code to use Nullables incrementally.

## Descend the Ladder

**Problem:** Complex codebases have many dependencies. Converting everything at once isn't feasible.

**Solution:** Convert code and its direct dependencies only. Work down the dependency tree gradually.

### Strategy for Each Module

When converting module X:

**A. No Infrastructure Dependencies**
→ Use Logic Patterns. No Nullables needed.

**B. Infrastructure Wrapper with Third-Party Dependencies**
→ Test with Narrow Integration Tests + make Nullable with Embedded Stub.

**C. Everything Else**
For each direct dependency:
- If already Nullable → No changes needed
- If all dependencies are Nullable → Fake It Once You Make It
- If low-level Infrastructure Wrapper → Add Embedded Stub
- If third-party infrastructure → Extract to Infrastructure Wrapper, add Embedded Stub
- Otherwise → Create Throwaway Stub (temporary)

Then Fake It Once You Make It for the module itself, replacing any Throwaway Stubs.

### Example Conversion

Dependency chain: `Router → LoginController → Auth0Client → HttpClient`

**Step 1: Convert Router**
- LoginController isn't Nullable yet → Create Throwaway Stub
- Make Router Nullable with Fake It Once You Make It
- Convert Router's tests

**Step 2: Convert Auth0Client**
- HttpClient is low-level → Make Nullable with Embedded Stub
- Make Auth0Client Nullable with Fake It Once You Make It
- Convert Auth0Client's tests

**Step 3: Convert LoginController**
- Auth0Client is now Nullable → No Throwaway Stub needed
- Replace Throwaway Stub with Fake It Once You Make It
- Convert LoginController's tests

**Step 4: Test HttpClient**
- HttpClient is already Nullable (from Step 2)
- Add Narrow Integration Tests

---

## Climb the Ladder

**Problem:** Descend the Ladder creates wasteful Throwaway Stubs.

**Solution:** For simple dependency trees, convert the entire tree at once, bottom-up.

### When to Use

- Small dependency trees (< 5 classes deep)
- Clear, linear dependencies
- Willing to do more upfront work

### Strategy

1. Graph out dependency tree
2. Convert each node bottom-up (post-order depth-first)

For each node:
- Pure logic → Ensure Easily Visible Behavior
- Already Nullable → Convert tests (Replace Mocks with Nullables)
- Infrastructure Wrapper with third-party code → Embedded Stub + Narrow Integration Tests
- Uses third-party infrastructure → Extract to Infrastructure Wrapper, then above
- Otherwise → Fake It Once You Make It + Convert tests

### Example

Same dependency chain: `Router → LoginController → Auth0Client → HttpClient`

**Convert in order:**
1. HttpClient (bottom) - Embedded Stub + Narrow Integration Tests
2. Auth0Client - Fake It Once You Make It + Convert tests
3. LoginController - Fake It Once You Make It + Convert tests
4. Router (top) - Fake It Once You Make It + Convert tests

Result: Entire tree converted, no Throwaway Stubs.

---

## Replace Mocks with Nullables

**Problem:** Existing tests use mocks/spies that may be hard to maintain or make refactoring difficult.

**Solution:** Replace test doubles with Nullables one at a time within each test.

### Process

For each mock/spy in a test:

1. Replace with `create_null()` of real dependency
2. Replace configuration with Configurable Responses
3. Replace event mocking with Behavior Simulation
4. Replace call verification with Output Tracking (do this last)

### Example

**Before (with mocks):**
```python
def test_login_calls_auth_service(mocker):
    auth = mocker.Mock(Auth0Client)
    auth.validate_login.return_value = {"email": "user@example.com"}
    
    controller = LoginController(auth)
    result = controller.login("code", "callback")
    
    auth.validate_login.assert_called_once_with("code", "callback")
    assert result.email == "user@example.com"
```

**After (with Nullables):**
```python
def test_login_calls_auth_service():
    auth = Auth0Client.create_null(email="user@example.com")
    auth_requests = auth.track_requests()
    
    controller = LoginController(auth)
    result = controller.login("code", "callback")
    
    assert auth_requests.data == [{"code": "code", "callback": "callback"}]
    assert result.email == "user@example.com"
```

### Benefits of Incremental Conversion

- Nullables coexist with mocks in same test
- Convert one dependency at a time
- Tests keep passing throughout conversion
- Stop whenever you want

---

## Throwaway Stub

**Problem:** Making all dependencies Nullable at once is too much work.

**Solution:** Create temporary Embedded Stubs for dependencies you're not ready to convert. Replace with Fake It Once You Make It when dependencies become Nullable.

### Example

```python
# Temporary stub while LoginController isn't Nullable yet
class _ThrowawayLoginControllerStub:
    def login(self, code, callback):
        return {"success": True, "email": "stub@example.com"}

class Router:
    @staticmethod
    def create_null():
        return Router(_ThrowawayLoginControllerStub())
```

**Replace with Fake It Once You Make It as soon as LoginController is Nullable:**

```python
class Router:
    @staticmethod
    def create_null():
        return Router(LoginController.create_null())
```

Throwaway Stubs break the chain of Overlapping Sociable Tests, so replace them as soon as practical.

---

## Summary

Legacy Patterns enable incremental conversion:

1. **Descend the Ladder** - Convert top-down, one module at a time (uses Throwaway Stubs)
2. **Climb the Ladder** - Convert bottom-up, entire tree at once (no Throwaway Stubs)
3. **Replace Mocks with Nullables** - Convert individual tests incrementally
4. **Throwaway Stub** - Temporary stub until dependencies are Nullable

Choose strategy based on your codebase complexity and available time.
