# Foundational Patterns

These patterns establish the ground rules for Testing Without Mocks. Start here.

## Table of Contents

1. [Narrow Tests](#narrow-tests)
2. [State-Based Tests](#state-based-tests)
3. [Overlapping Sociable Tests](#overlapping-sociable-tests)
4. [Smoke Tests](#smoke-tests)
5. [Zero-Impact Instantiation](#zero-impact-instantiation)
6. [Parameterless Instantiation](#parameterless-instantiation)
7. [Signature Shielding](#signature-shielding)

---

## Narrow Tests

**Problem:** Broad tests (end-to-end) are slow, brittle, complicated to write, and often fail randomly.

**Solution:** Use narrow tests that check a specific function or behavior, not the system as a whole. Unit tests are a common type of narrow test.

**When testing:**
- **Infrastructure** - Use Narrow Integration Tests
- **Pure logic** - Use Logic Patterns
- **Code with infrastructure dependencies** - Use Nullables

### Examples

#### Python
```python
# Narrow test - focuses on App.run() behavior only
def test_encodes_input_with_rot13():
    app = App.create_null(args=["hello"])
    result = app.run()
    assert result == "uryyb\n"

# Each dependency has its own narrow tests
def test_command_line_reads_args():
    cmd = CommandLine.create_null(args=["arg1", "arg2"])
    assert cmd.args() == ["arg1", "arg2"]
```

#### Go
```go
func TestEncodesInputWithRot13(t *testing.T) {
    app := NewAppNull(WithArgs("hello"))
    result := app.Run()
    assert.Equal(t, "uryyb\n", result)
}
```

#### Elixir
```elixir
test "encodes input with rot13" do
  app = App.create_null(args: ["hello"])
  result = App.run(app)
  assert result == "uryyb\n"
end
```

---

## State-Based Tests

**Problem:** Interaction-based tests (mocks/spies) are hard to read and lock in implementation details, making refactoring difficult.

**Solution:** Check the output or state of the code under test, without awareness of its implementation.

**Key distinction:**
- **State-based**: "What is the result?"
- **Interaction-based**: "Which methods were called?"

### Examples

#### Python - State-Based (Good)
```python
def test_describes_phase_of_moon():
    date_of_full_moon = datetime(2022, 12, 8)
    description = describe_moon_phase(date_of_full_moon)
    assert description == "The moon is full on December 8th, 2022."
```

#### Python - Interaction-Based (Avoid)
```python
def test_describes_phase_of_moon():
    # Using mocks to check method calls
    with patch('moon.get_percent_occluded') as mock_occluded:
        with patch('moon.describe_phase') as mock_phase:
            mock_occluded.return_value = 999
            mock_phase.return_value = "PHASE"
            
            result = describe_moon_phase(date)
            
            mock_occluded.assert_called_with(date)
            mock_phase.assert_called_with(999)
```

#### Go
```go
// State-based - checks result
func TestDescribesMoonPhase(t *testing.T) {
    fullMoon := time.Date(2022, 12, 8, 0, 0, 0, 0, time.UTC)
    description := DescribeMoonPhase(fullMoon)
    assert.Equal(t, "The moon is full on December 8th, 2022.", description)
}
```

#### Elixir
```elixir
# State-based - checks result
test "describes phase of moon" do
  full_moon = ~D[2022-12-08]
  description = MoonPhase.describe(full_moon)
  assert description == "The moon is full on December 8th, 2022."
end
```

---

## Overlapping Sociable Tests

**Problem:** Tests using mocks isolate code from its dependencies, requiring broad tests to confirm the system works as a whole. But we don't want broad tests.

**Solution:** Use real dependencies in tests. Each test overlaps with its dependencies' tests, creating a linked chain of tests that ensures the whole system is checked.

**Key principle:** Test that your code uses its dependencies correctly, but don't test the dependencies' internal behavior (they have their own tests).

### Example Chain

```
LoginController tests → check LoginController + how it uses Auth0Client
    ↓
Auth0Client tests → check Auth0Client + how it uses HttpClient
    ↓
HttpClient tests → check HttpClient + real HTTP communication
```

If Auth0Client's behavior changes in a breaking way, LoginController tests will fail. No mocks needed.

### Examples

#### Python
```python
# LoginController test - uses real Auth0Client
def test_logs_in_user():
    auth_client = Auth0Client.create_null(
        email="user@example.com",
        email_verified=True
    )
    log = Log.create_null()
    
    controller = LoginController(auth_client, log)
    result = controller.login("auth_code", "callback_url")
    
    assert result.success == True
    assert result.email == "user@example.com"
```

#### Go
```go
func TestLogsInUser(t *testing.T) {
    authClient := NewAuth0ClientNull(
        WithEmail("user@example.com"),
        WithEmailVerified(true),
    )
    log := NewLogNull()
    
    controller := NewLoginController(authClient, log)
    result := controller.Login("auth_code", "callback_url")
    
    assert.True(t, result.Success)
    assert.Equal(t, "user@example.com", result.Email)
}
```

#### Elixir
```elixir
test "logs in user" do
  auth_client = Auth0Client.create_null(
    email: "user@example.com",
    email_verified: true
  )
  log = Log.create_null()
  
  controller = LoginController.new(auth_client, log)
  result = LoginController.login(controller, "auth_code", "callback_url")
  
  assert result.success == true
  assert result.email == "user@example.com"
end
```

---

## Smoke Tests

**Problem:** Nobody's perfect. Mistakes happen, and sociable tests might miss something.

**Solution:** Write 1-2 end-to-end tests that ensure your code starts up and runs a common workflow.

**Important:** Don't rely on smoke tests to catch errors. If they catch something your narrow tests don't, add more narrow tests to fill the gap.

### Example

#### Python
```python
def test_smoke_can_process_request():
    """End-to-end smoke test - starts real server"""
    app = create_production_app()
    server = TestServer(app)
    server.start()
    
    try:
        response = requests.get(f"http://localhost:{server.port}/")
        assert response.status_code == 200
    finally:
        server.stop()
```

---

## Zero-Impact Instantiation

**Problem:** Sociable tests instantiate entire dependency trees. If constructors do significant work, tests will be slow or fail unpredictably.

**Solution:** Don't do significant work in constructors. Don't connect to external systems, start services, or perform long calculations.

- **For connections/services**: Provide `connect()` or `start()` methods
- **For calculations**: Consider lazy initialization

### Examples

#### Python
```python
# Bad - connects in constructor
class Database:
    def __init__(self, connection_string):
        self.conn = psycopg2.connect(connection_string)  # ❌ Connects immediately

# Good - connect on demand
class Database:
    def __init__(self, connection_string):
        self.connection_string = connection_string
        self.conn = None
    
    def connect(self):
        if self.conn is None:
            self.conn = psycopg2.connect(self.connection_string)
    
    def query(self, sql):
        self.connect()  # Lazy connection
        return self.conn.execute(sql)
```

#### Go
```go
// Good - no work in constructor
type Server struct {
    port int
    listener net.Listener
}

func NewServer(port int) *Server {
    return &Server{port: port}  // ✓ Just stores data
}

func (s *Server) Start() error {
    listener, err := net.Listen("tcp", fmt.Sprintf(":%d", s.port))
    s.listener = listener
    return err
}
```

#### Elixir
```elixir
# Good - GenServer doesn't connect in init
defmodule Database do
  use GenServer
  
  def init(connection_string) do
    {:ok, %{connection_string: connection_string, conn: nil}}
  end
  
  def handle_call(:connect, _from, state) do
    conn = Postgrex.start_link(state.connection_string)
    {:reply, :ok, %{state | conn: conn}}
  end
end
```

---

## Parameterless Instantiation

**Problem:** Multi-level dependency chains are difficult to set up in tests.

**Solution:** Ensure all classes have a constructor or factory that doesn't take any parameters, with sensible defaults that set up everything needed (including dependencies).

### Examples

#### Python
```python
class LoginController:
    @staticmethod
    def create():
        """Production factory with defaults"""
        auth_client = Auth0Client.create()
        log = Log.create()
        return LoginController(auth_client, log)
    
    def __init__(self, auth_client, log):
        self._auth_client = auth_client
        self._log = log
```

#### Go
```go
func NewLoginController() *LoginController {
    return &LoginController{
        authClient: NewAuth0Client(),
        log: NewLog(),
    }
}

// Override dependencies in tests
func NewLoginControllerWithDeps(authClient *Auth0Client, log *Log) *LoginController {
    return &LoginController{
        authClient: authClient,
        log: log,
    }
}
```

#### Elixir
```elixir
defmodule LoginController do
  def create do
    %LoginController{
      auth_client: Auth0Client.create(),
      log: Log.create()
    }
  end
  
  def new(auth_client, log) do
    %LoginController{
      auth_client: auth_client,
      log: log
    }
  end
end
```

### Test-Specific Factories

For Value Objects where parameterless construction doesn't make sense in production:

#### Python
```python
class Address:
    def __init__(self, street, city, state, country, postal_code):
        self.street = street
        self.city = city
        # ...
    
    @staticmethod
    def create_test_instance(
        street="Test Street",
        city="Test City",
        state=None,
        country=None,
        postal_code="12345"
    ):
        return Address(
            street,
            city,
            state or State.create_test_instance(),
            country or Country.create_test_instance(),
            postal_code
        )
```

---

## Signature Shielding

**Problem:** When method signatures change during refactoring, you have to update many duplicated calls in tests.

**Solution:** Provide helper functions that instantiate classes and call methods. Make them take optional parameters and return multiple optional values.

### Examples

#### Python
```python
def test_login_succeeds():
    result = perform_login(
        email="user@example.com",
        password="secret"
    )
    assert result.success == True

def perform_login(
    email="test@example.com",
    password="password",
    client_id="test_id",
    remember_me=False
):
    """Helper shields tests from signature changes"""
    auth = Auth0Client.create_null()
    controller = LoginController(auth)
    result = controller.login(email, password, client_id, remember_me)
    return {
        "result": result,
        "controller": controller,
        "auth": auth
    }
```

#### Go
```go
type LoginResult struct {
    Result     *LoginResponse
    Controller *LoginController
    Auth       *Auth0Client
}

func performLogin(opts ...LoginOption) LoginResult {
    config := &loginConfig{
        email: "test@example.com",
        password: "password",
    }
    for _, opt := range opts {
        opt(config)
    }
    
    auth := NewAuth0ClientNull()
    controller := NewLoginController(auth)
    result := controller.Login(config.email, config.password)
    
    return LoginResult{
        Result: result,
        Controller: controller,
        Auth: auth,
    }
}

type LoginOption func(*loginConfig)

func WithEmail(email string) LoginOption {
    return func(c *loginConfig) { c.email = email }
}
```

#### Elixir
```elixir
defp perform_login(opts \\ []) do
  config = Keyword.merge([
    email: "test@example.com",
    password: "password"
  ], opts)
  
  auth = Auth0Client.create_null()
  controller = LoginController.new(auth)
  result = LoginController.login(controller, config[:email], config[:password])
  
  %{result: result, controller: controller, auth: auth}
end

test "login succeeds" do
  %{result: result} = perform_login(email: "user@example.com")
  assert result.success == true
end
```

---

## Summary

These foundational patterns work together:

1. **Narrow Tests** - Focus on specific behavior
2. **State-Based Tests** - Check results, not implementation
3. **Overlapping Sociable Tests** - Use real dependencies to ensure integration
4. **Zero-Impact Instantiation** - Keep constructors lightweight
5. **Parameterless Instantiation** - Make it easy to create objects
6. **Signature Shielding** - Protect tests from signature changes
7. **Smoke Tests** - Safety net for the whole system

Master these before moving to more advanced patterns.
