# Nullability Patterns

The core patterns for creating and using Nullables - production code with an "off" switch.

## Table of Contents

1. [Nullables](#nullables)
2. [Embedded Stub](#embedded-stub)
3. [Thin Wrapper](#thin-wrapper)
4. [Configurable Responses](#configurable-responses)
5. [Output Tracking](#output-tracking)
6. [Behavior Simulation](#behavior-simulation)
7. [Fake It Once You Make It](#fake-it-once-you-make-it)

---

## Nullables

**Problem:** Infrastructure dependencies make tests slow and complicated.

**Solution:** Create `create_null()` factories that disable external communication while behaving normally in every other respect.

**Key characteristics:**
- Nullables are **production code**, not test doubles
- They can be used in production (dry-run, cache warming, etc.)
- They support Parameterless Instantiation
- They must be tested like any other production code

### Examples

#### Python
```python
class LoginClient:
    @staticmethod
    def create():
        """Production factory"""
        return LoginClient(requests.Session())
    
    @staticmethod
    def create_null(email="null@example.com", email_verified=True):
        """Null factory - disables HTTP"""
        return LoginClient(NulledSession(email, email_verified))
    
    def __init__(self, session):
        self._session = session
    
    def get_user_info(self, token):
        response = self._session.get(f"{self.host}/userinfo", 
                                     headers={"Authorization": f"Bearer {token}"})
        data = response.json()
        return {"email": data["email"], "verified": data["email_verified"]}

# Embedded Stub (see below)
class NulledSession:
    def __init__(self, email, email_verified):
        self._email = email
        self._verified = email_verified
    
    def get(self, url, headers=None):
        return NulledResponse(self._email, self._verified)

class NulledResponse:
    def __init__(self, email, verified):
        self._data = {"email": email, "email_verified": verified}
    
    def json(self):
        return self._data
```

#### Go
```go
type LoginClient struct {
    client HTTPClient
}

func NewLoginClient() *LoginClient {
    return &LoginClient{client: &http.Client{}}
}

func NewLoginClientNull(opts ...NullOption) *LoginClient {
    config := &nullConfig{
        email: "null@example.com",
        emailVerified: true,
    }
    for _, opt := range opts {
        opt(config)
    }
    return &LoginClient{client: &NulledHTTPClient{config}}
}

type NullOption func(*nullConfig)

func WithEmail(email string) NullOption {
    return func(c *nullConfig) { c.email = email }
}
```

#### Elixir
```elixir
defmodule LoginClient do
  def create do
    %LoginClient{http_client: HTTPoison}
  end
  
  def create_null(opts \\ []) do
    email = Keyword.get(opts, :email, "null@example.com")
    verified = Keyword.get(opts, :email_verified, true)
    %LoginClient{http_client: NulledHTTPClient.new(email, verified)}
  end
end

defmodule NulledHTTPClient do
  defstruct [:email, :email_verified]
  
  def new(email, verified) do
    %__MODULE__{email: email, email_verified: verified}
  end
  
  def get(_url, _headers) do
    {:ok, %{body: Jason.encode!(%{
      email: @email,
      email_verified: @email_verified
    })}}
  end
end
```

---

## Embedded Stub

**Problem:** Nullables need to disable external systems, but surrounding code with "if" statements creates spaghetti.

**Solution:** Stub out the third-party code that accesses external systems. Put the stub in the same file as your production code.

**Key principles:**
- Stub the **third-party code**, not your code
- Implement only what's needed (test-drive through your code's interface)
- Match third-party behavior exactly (especially edge cases, async, errors)
- Put stub in production file for easier maintenance

### Example: Random Number Generator

#### Python
```python
import random

class DiceRoller:
    @staticmethod
    def create():
        return DiceRoller(random)
    
    @staticmethod
    def create_null(rolls=1):
        """rolls can be: int (always return that), or list (return each once)"""
        return DiceRoller(_NulledRandom(rolls))
    
    def __init__(self, rng):
        self._rng = rng
    
    def roll(self):
        """Roll a 6-sided die"""
        return int(self._rng.random() * 6) + 1

# Embedded Stub - only stubs what we use
class _NulledRandom:
    def __init__(self, rolls):
        if isinstance(rolls, list):
            self._rolls = rolls.copy()
            self._exhaustible = True
        else:
            self._roll = rolls
            self._exhaustible = False
    
    def random(self):
        """Return float [0, 1) like real random.random()"""
        if self._exhaustible:
            if not self._rolls:
                raise RuntimeError("No more rolls configured in nulled DiceRoller")
            roll = self._rolls.pop(0)
        else:
            roll = self._roll
        
        # Convert die roll (1-6) to random float (0-1)
        return (roll - 1) / 6.0
```

#### Go
```go
package dice

import (
    "fmt"
    "math/rand"
)

type DiceRoller struct {
    rng RandomSource
}

type RandomSource interface {
    Float64() float64
}

func New() *DiceRoller {
    return &DiceRoller{rng: rand.New(rand.NewSource(time.Now().UnixNano()))}
}

func NewNull(rolls interface{}) *DiceRoller {
    return &DiceRoller{rng: &nulledRandom{rolls: rolls}}
}

func (d *DiceRoller) Roll() int {
    return int(d.rng.Float64() * 6) + 1
}

// Embedded Stub
type nulledRandom struct {
    rolls interface{}
    index int
}

func (n *nulledRandom) Float64() float64 {
    var roll int
    switch r := n.rolls.(type) {
    case []int:
        if n.index >= len(r) {
            panic("No more rolls configured in nulled DiceRoller")
        }
        roll = r[n.index]
        n.index++
    case int:
        roll = r
    default:
        roll = 1
    }
    return float64(roll-1) / 6.0
}
```

#### Elixir
```elixir
defmodule DiceRoller do
  def create do
    %DiceRoller{rng: :random}
  end
  
  def create_null(rolls \\ 1) do
    %DiceRoller{rng: {:nulled, rolls}}
  end
  
  def roll(%DiceRoller{rng: rng}) do
    random_float = get_random(rng)
    trunc(random_float * 6) + 1
  end
  
  # Dispatch to real or nulled random
  defp get_random(:random), do: :rand.uniform()
  defp get_random({:nulled, rolls}), do: nulled_random(rolls)
  
  # Embedded Stub
  defp nulled_random(roll) when is_integer(roll) do
    (roll - 1) / 6.0
  end
  
  defp nulled_random([roll | rest]) do
    # Store remaining rolls in process dictionary for stateful behavior
    Process.put(:remaining_rolls, rest)
    (roll - 1) / 6.0
  end
  
  defp nulled_random([]) do
    raise "No more rolls configured in nulled DiceRoller"
  end
end
```

### Example: HTTP Client

#### Python
```python
import httpx

class HttpClient:
    @staticmethod
    def create():
        return HttpClient(httpx.Client())
    
    @staticmethod
    def create_null(responses=None):
        return HttpClient(_NulledHttpx(responses or {}))
    
    def __init__(self, client):
        self._client = client
    
    def get(self, url, headers=None):
        response = self._client.get(url, headers=headers or {})
        return {
            "status": response.status_code,
            "headers": dict(response.headers),
            "body": response.text
        }

# Embedded Stub
class _NulledHttpx:
    def __init__(self, responses):
        self._responses = responses
    
    def get(self, url, headers=None):
        # Extract path from URL for matching
        from urllib.parse import urlparse
        path = urlparse(url).path
        
        if path in self._responses:
            response_data = self._responses[path]
            if isinstance(response_data, Exception):
                raise response_data
            return _NulledResponse(response_data)
        
        return _NulledResponse({"status": 200, "body": "Nulled HTTP response"})

class _NulledResponse:
    def __init__(self, data):
        self.status_code = data.get("status", 200)
        self.headers = data.get("headers", {})
        self.text = data.get("body", "")
```

---

## Thin Wrapper

**Problem:** Statically-typed languages (Go, Java, C#) require your Embedded Stub to share an interface with the real dependency.

**Solution:** Create a custom interface matching only the methods you use. Provide two implementations: one that forwards to the real dependency, one that's the Embedded Stub.

### Example

#### Go
```go
package dice

import "math/rand"

type DiceRoller struct {
    rng RandomWrapper
}

// Thin Wrapper interface - only methods we actually use
type RandomWrapper interface {
    Float64() float64
}

func New() *DiceRoller {
    return &DiceRoller{rng: &realRandom{rand.New(rand.NewSource(time.Now().UnixNano()))}}
}

func NewNull(rolls interface{}) *DiceRoller {
    return &DiceRoller{rng: &nulledRandom{rolls: rolls}}
}

func (d *DiceRoller) Roll() int {
    return int(d.rng.Float64() * 6) + 1
}

// Real implementation of Thin Wrapper
type realRandom struct {
    source *rand.Rand
}

func (r *realRandom) Float64() float64 {
    return r.source.Float64()
}

// Nulled implementation of Thin Wrapper (Embedded Stub)
type nulledRandom struct {
    rolls interface{}
    index int
}

func (n *nulledRandom) Float64() float64 {
    var roll int
    switch r := n.rolls.(type) {
    case []int:
        if n.index >= len(r) {
            panic("No more rolls configured")
        }
        roll = r[n.index]
        n.index++
    case int:
        roll = r
    default:
        roll = 1
    }
    return float64(roll-1) / 6.0
}
```

---

## Configurable Responses

**Problem:** State-based tests need to set up infrastructure state, but setting up external systems is slow and complicated.

**Solution:** Make `create_null()` factories take desired responses as parameters. Define responses from the dependency's externally-visible behavior, not implementation.

**Key principles:**
- Configure from caller's perspective (user data, not HTTP details)
- Use named/optional parameters
- Support both single values (repeating) and lists (sequential)
- Decompose responses down to next level in Embedded Stub

### Examples

#### Python - Multiple Response Types
```python
class LoginClient:
    @staticmethod
    def create_null(
        email="null@example.com",
        email_verified=True,
        forbidden=None  # Set to error message to simulate 403
    ):
        return LoginClient(_NulledSession(email, email_verified, forbidden))
    
    # ... implementation ...

# Test
def test_handles_forbidden_response():
    client = LoginClient.create_null(forbidden="Access denied")
    with pytest.raises(ForbiddenError):
        client.get_user_info("token")
```

#### Python - Sequential Responses
```python
class DiceRoller:
    @staticmethod
    def create_null(rolls=1):
        """
        rolls: int for repeating value, or list for sequence
        """
        return DiceRoller(_NulledRandom(rolls))

# Test with sequence
def test_rolls_multiple_dice():
    roller = DiceRoller.create_null(rolls=[1, 2, 3, 4, 5])
    hand = [roller.roll() for _ in range(5)]
    assert hand == [1, 2, 3, 4, 5]
```

#### Go - Functional Options Pattern
```go
type LoginClient struct {
    client HTTPClient
}

type nullConfig struct {
    email         string
    emailVerified bool
    forbidden     string
}

type NullOption func(*nullConfig)

func WithEmail(email string) NullOption {
    return func(c *nullConfig) { c.email = email }
}

func WithEmailVerified(verified bool) NullOption {
    return func(c *nullConfig) { c.emailVerified = verified }
}

func WithForbidden(msg string) NullOption {
    return func(c *nullConfig) { c.forbidden = msg }
}

func NewLoginClientNull(opts ...NullOption) *LoginClient {
    config := &nullConfig{
        email: "null@example.com",
        emailVerified: true,
    }
    for _, opt := range opts {
        opt(config)
    }
    return &LoginClient{client: newNulledClient(config)}
}

// Test
func TestHandlesForbiddenResponse(t *testing.T) {
    client := NewLoginClientNull(WithForbidden("Access denied"))
    _, err := client.GetUserInfo("token")
    assert.Error(t, err)
}
```

#### Elixir - Keyword Lists
```elixir
defmodule LoginClient do
  def create_null(opts \\ []) do
    email = Keyword.get(opts, :email, "null@example.com")
    verified = Keyword.get(opts, :email_verified, true)
    forbidden = Keyword.get(opts, :forbidden, nil)
    
    %LoginClient{
      http_client: NulledHTTPClient.new(email, verified, forbidden)
    }
  end
end

# Test
test "handles forbidden response" do
  client = LoginClient.create_null(forbidden: "Access denied")
  assert {:error, :forbidden} = LoginClient.get_user_info(client, "token")
end
```

---

## Output Tracking

**Problem:** Tests need to verify writes to external systems, but setting up those systems is complicated and slow.

**Solution:** Add production-grade `track_xxx()` methods that record otherwise-invisible writes, regardless of whether the object is Nulled.

**Key principles:**
- Track behavior, not function calls (unlike spies)
- Track from caller's perspective (structured data, not raw strings)
- Use event emitters/observers for loose coupling
- Return data structures, not assertions

### Examples

#### Python - Using EventEmitter Pattern
```python
from typing import List, Dict, Any
from collections import deque

class OutputTracker:
    def __init__(self):
        self._data: List[Any] = []
    
    def record(self, item):
        self._data.append(item)
    
    @property
    def data(self) -> List[Any]:
        return self._data.copy()
    
    def clear(self) -> List[Any]:
        result = self._data.copy()
        self._data.clear()
        return result

class Log:
    @staticmethod
    def create():
        return Log(sys.stdout)
    
    @staticmethod
    def create_null():
        return Log(io.StringIO())  # Null output
    
    def __init__(self, output_stream):
        self._output = output_stream
        self._listeners = []
    
    def track_output(self) -> OutputTracker:
        tracker = OutputTracker()
        self._listeners.append(tracker.record)
        return tracker
    
    def info(self, message: str, **kwargs):
        log_entry = {"level": "info", "message": message, **kwargs}
        
        # Write to output
        self._output.write(json.dumps(log_entry) + "\n")
        
        # Notify listeners (including trackers)
        for listener in self._listeners:
            listener(log_entry)

# Test
def test_logs_user_login():
    log = Log.create_null()
    tracker = log.track_output()
    
    controller = LoginController(log)
    controller.login("user@example.com", "password")
    
    assert tracker.data == [
        {"level": "info", "message": "User login", "email": "user@example.com"}
    ]
```

#### Go - Thread-Safe Tracker
```go
package log

import "sync"

type OutputTracker struct {
    data []LogEntry
    mu   sync.Mutex
}

func (t *OutputTracker) Record(entry LogEntry) {
    t.mu.Lock()
    defer t.mu.Unlock()
    t.data = append(t.data, entry)
}

func (t *OutputTracker) Data() []LogEntry {
    t.mu.Lock()
    defer t.mu.Unlock()
    return append([]LogEntry{}, t.data...)
}

type Log struct {
    output io.Writer
    trackers []*OutputTracker
}

func (l *Log) TrackOutput() *OutputTracker {
    tracker := &OutputTracker{}
    l.trackers = append(l.trackers, tracker)
    return tracker
}

func (l *Log) Info(message string, fields map[string]interface{}) {
    entry := LogEntry{Level: "info", Message: message, Fields: fields}
    
    // Write to output
    l.output.Write([]byte(entry.String()))
    
    // Notify trackers
    for _, tracker := range l.trackers {
        tracker.Record(entry)
    }
}

// Test
func TestLogsUserLogin(t *testing.T) {
    log := NewLogNull()
    tracker := log.TrackOutput()
    
    controller := NewLoginController(log)
    controller.Login("user@example.com", "password")
    
    data := tracker.Data()
    assert.Len(t, data, 1)
    assert.Equal(t, "User login", data[0].Message)
    assert.Equal(t, "user@example.com", data[0].Fields["email"])
}
```

#### Elixir - Using Agent for State
```elixir
defmodule OutputTracker do
  def new do
    {:ok, agent} = Agent.start_link(fn -> [] end)
    agent
  end
  
  def record(agent, item) do
    Agent.update(agent, fn data -> [item | data] end)
  end
  
  def data(agent) do
    Agent.get(agent, fn data -> Enum.reverse(data) end)
  end
end

defmodule Log do
  defstruct [:output, :trackers]
  
  def create do
    %Log{output: :stdio, trackers: []}
  end
  
  def create_null do
    %Log{output: :null, trackers: []}
  end
  
  def track_output(log) do
    tracker = OutputTracker.new()
    %{log | trackers: [tracker | log.trackers]}
  end
  
  def info(log, message, opts \\ []) do
    entry = %{level: :info, message: message, fields: Enum.into(opts, %{})}
    
    # Write to output
    case log.output do
      :stdio -> IO.puts(Jason.encode!(entry))
      :null -> :ok
    end
    
    # Notify trackers
    Enum.each(log.trackers, fn tracker ->
      OutputTracker.record(tracker, entry)
    end)
  end
end

# Test
test "logs user login" do
  log = Log.create_null()
  {log, tracker} = Log.track_output(log)
  
  controller = LoginController.new(log)
  LoginController.login(controller, "user@example.com", "password")
  
  assert OutputTracker.data(tracker) == [
    %{level: :info, message: "User login", fields: %{email: "user@example.com"}}
  ]
end
```

---

## Behavior Simulation

**Problem:** External systems push data to you (events, callbacks, websockets). Tests need to simulate these events without setting up real infrastructure.

**Solution:** Add methods that simulate receiving events from external systems. Share as much code as possible with real event handlers.

### Examples

#### Python - WebSocket Server
```python
class WebSocketServer:
    @staticmethod
    def create(port):
        return WebSocketServer(WebSocket(), port)
    
    @staticmethod
    def create_null():
        return WebSocketServer(_NulledWebSocket(), 8080)
    
    def __init__(self, websocket, port):
        self._ws = websocket
        self._port = port
        self._clients = {}
        self._on_message_handlers = []
    
    def start(self):
        self._ws.on_connection(self._handle_connection)
        self._ws.on_message(self._handle_message)
        self._ws.listen(self._port)
    
    # Behavior Simulation
    def simulate_connection(self, client_id):
        self._handle_connection(client_id)
    
    def simulate_message(self, client_id, message):
        self._handle_message(client_id, message)
    
    # Shared implementation
    def _handle_connection(self, client_id):
        self._clients[client_id] = True
    
    def _handle_message(self, client_id, message):
        for handler in self._on_message_handlers:
            handler(client_id, message)
    
    def on_message(self, handler):
        self._on_message_handlers.append(handler)
    
    def broadcast(self, message, exclude_client=None):
        for client_id in self._clients:
            if client_id != exclude_client:
                self._ws.send(client_id, message)

# Test
def test_broadcasts_message_to_all_clients():
    server = WebSocketServer.create_null()
    messages = []
    
    server.on_message(lambda client_id, msg: messages.append((client_id, msg)))
    server.start()
    
    # Simulate clients connecting
    server.simulate_connection("client1")
    server.simulate_connection("client2")
    
    # Simulate message from client1
    server.simulate_message("client1", "Hello")
    
    assert len(messages) == 1
    assert messages[0] == ("client1", "Hello")
```

#### Go - Event-Driven System
```go
type MessageServer struct {
    wsServer *WebSocketServer
}

func (m *MessageServer) Start() {
    m.wsServer.OnMessage(m.handleMessage)
}

func (m *MessageServer) handleMessage(clientID string, msg Message) {
    m.wsServer.BroadcastExcept(clientID, msg)
}

// Test
func TestBroadcastsMessageToAllClients(t *testing.T) {
    wsServer := NewWebSocketServerNull()
    server := &MessageServer{wsServer: wsServer}
    
    server.Start()
    
    // Simulate connections
    wsServer.SimulateConnection("client1")
    wsServer.SimulateConnection("client2")
    
    // Simulate message
    wsServer.SimulateMessage("client1", Message{Text: "Hello"})
    
    // Check broadcast using Output Tracking
    broadcasts := wsServer.TrackBroadcasts()
    assert.Len(t, broadcasts.Data(), 1)
    assert.Equal(t, "client1", broadcasts.Data()[0].ExcludedClient)
}
```

#### Elixir - GenServer with Simulated Events
```elixir
defmodule WebSocketServer do
  use GenServer
  
  # Behavior Simulation (for tests)
  def simulate_connection(pid, client_id) do
    GenServer.cast(pid, {:connection, client_id})
  end
  
  def simulate_message(pid, client_id, message) do
    GenServer.cast(pid, {:message, client_id, message})
  end
  
  # Real implementation
  def handle_cast({:connection, client_id}, state) do
    handle_connection(state, client_id)
  end
  
  def handle_cast({:message, client_id, message}, state) do
    handle_message(state, client_id, message)
  end
  
  # Shared implementation
  defp handle_connection(state, client_id) do
    {:noreply, Map.put(state.clients, client_id, true)}
  end
  
  defp handle_message(state, client_id, message) do
    # Notify message handlers
    Enum.each(state.message_handlers, fn handler ->
      handler.(client_id, message)
    end)
    {:noreply, state}
  end
end

# Test
test "broadcasts message to all clients" do
  {:ok, server} = WebSocketServer.create_null()
  
  WebSocketServer.simulate_connection(server, "client1")
  WebSocketServer.simulate_connection(server, "client2")
  WebSocketServer.simulate_message(server, "client1", "Hello")
  
  broadcasts = WebSocketServer.get_broadcasts(server)
  assert length(broadcasts) == 1
end
```

---

## Fake It Once You Make It

**Problem:** Low-level infrastructure wrappers need Narrow Integration Tests and Embedded Stubs, but that's overkill for higher-level code.

**Solution:** For code that doesn't directly use third-party infrastructure, delegate to Nulled dependencies instead of creating Embedded Stubs.

**When to use:**
- Application-layer code
- High-level infrastructure wrappers (LoginClient, DatabaseClient)
- Any code whose dependencies are already Nullable

**Process:**
1. Make dependencies Nullable (if not already)
2. Create `create_null()` that instantiates Nulled dependencies
3. Decompose Configurable Responses to match what dependencies expect

### Example: High-Level Client

#### Python
```python
class LoginController:
    @staticmethod
    def create():
        return LoginController(
            Auth0Client.create(),
            SessionStore.create(),
            Log.create()
        )
    
    @staticmethod
    def create_null(
        email="test@example.com",
        email_verified=True,
        session_id="test_session"
    ):
        # Fake It - use Nulled dependencies, decompose responses
        auth_client = Auth0Client.create_null(
            email=email,
            email_verified=email_verified
        )
        session_store = SessionStore.create_null(
            session_id=session_id
        )
        log = Log.create_null()
        
        return LoginController(auth_client, session_store, log)
    
    def __init__(self, auth_client, session_store, log):
        self._auth = auth_client
        self._sessions = session_store
        self._log = log
    
    def login(self, code, callback_url):
        # LoginController doesn't need Embedded Stubs
        # It just uses its Nulled dependencies
        user_info = self._auth.validate_login(code, callback_url)
        session_id = self._sessions.create_session(user_info)
        self._log.info("User login", email=user_info["email"])
        return session_id

# Test - simple because dependencies are Nullable
def test_creates_session_on_login():
    controller = LoginController.create_null(
        email="user@example.com",
        session_id="session_123"
    )
    
    result = controller.login("auth_code", "http://callback")
    
    assert result == "session_123"
```

#### Go
```go
type LoginController struct {
    auth     *Auth0Client
    sessions *SessionStore
    log      *Log
}

func NewLoginController() *LoginController {
    return &LoginController{
        auth:     NewAuth0Client(),
        sessions: NewSessionStore(),
        log:      NewLog(),
    }
}

func NewLoginControllerNull(opts ...ControllerNullOption) *LoginController {
    config := &controllerNullConfig{
        email:         "test@example.com",
        emailVerified: true,
        sessionID:     "test_session",
    }
    for _, opt := range opts {
        opt(config)
    }
    
    // Fake It - decompose to dependencies
    return &LoginController{
        auth: NewAuth0ClientNull(
            WithEmail(config.email),
            WithEmailVerified(config.emailVerified),
        ),
        sessions: NewSessionStoreNull(
            WithSessionID(config.sessionID),
        ),
        log: NewLogNull(),
    }
}

// Test
func TestCreatesSessionOnLogin(t *testing.T) {
    controller := NewLoginControllerNull(
        WithEmail("user@example.com"),
        WithSessionID("session_123"),
    )
    
    result := controller.Login("auth_code", "http://callback")
    
    assert.Equal(t, "session_123", result)
}
```

#### Elixir
```elixir
defmodule LoginController do
  def create do
    %LoginController{
      auth: Auth0Client.create(),
      sessions: SessionStore.create(),
      log: Log.create()
    }
  end
  
  def create_null(opts \\ []) do
    email = Keyword.get(opts, :email, "test@example.com")
    verified = Keyword.get(opts, :email_verified, true)
    session_id = Keyword.get(opts, :session_id, "test_session")
    
    # Fake It - decompose to dependencies
    %LoginController{
      auth: Auth0Client.create_null(
        email: email,
        email_verified: verified
      ),
      sessions: SessionStore.create_null(
        session_id: session_id
      ),
      log: Log.create_null()
    }
  end
end

# Test
test "creates session on login" do
  controller = LoginController.create_null(
    email: "user@example.com",
    session_id: "session_123"
  )
  
  result = LoginController.login(controller, "auth_code", "http://callback")
  
  assert result == "session_123"
end
```

---

## Summary

The Nullability Patterns work together:

1. **Nullables** - The core concept: production code with an "off" switch
2. **Embedded Stub** - How to create Nullables for low-level infrastructure
3. **Thin Wrapper** - Adaptation for statically-typed languages
4. **Configurable Responses** - How to control what Nullables return
5. **Output Tracking** - How to verify what Nullables write
6. **Behavior Simulation** - How to trigger Nullable event handlers
7. **Fake It Once You Make It** - How to create Nullables for higher-level code

Master these patterns to write fast, maintainable tests without mocking frameworks.
