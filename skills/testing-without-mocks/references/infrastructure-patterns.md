# Infrastructure Patterns

Patterns for testing code that communicates with external systems and state.

## Table of Contents

1. [Infrastructure Wrappers](#infrastructure-wrappers)
2. [Narrow Integration Tests](#narrow-integration-tests)
3. [Paranoic Telemetry](#paranoic-telemetry)

---

## Infrastructure Wrappers

**Problem:** Infrastructure code is complicated, hard to test, and difficult to understand.

**Solution:** Isolate infrastructure code. For each external system (service, database, file system, environment variables), create one wrapper class solely responsible for interfacing with that system.

**Key principles:**
- One wrapper per external system
- Design wrappers to provide clean view of messy outside world
- Avoid complex dependency webs
- Simple one-way chains are OK (LoginClient → HttpClient)

### Examples

#### Python
```python
# Low-level wrapper for HTTP
class HttpClient:
    @staticmethod
    def create():
        return HttpClient(requests.Session())
    
    @staticmethod
    def create_null(responses=None):
        return HttpClient(_NulledSession(responses or {}))
    
    def __init__(self, session):
        self._session = session
    
    def get(self, url, headers=None):
        response = self._session.get(url, headers=headers)
        return {
            "status": response.status_code,
            "headers": dict(response.headers),
            "body": response.text
        }

# High-level wrapper for specific service
class Auth0Client:
    @staticmethod
    def create(host, client_id, client_secret):
        return Auth0Client(HttpClient.create(), host, client_id, client_secret)
    
    @staticmethod
    def create_null(email="null@example.com", email_verified=True):
        # Fake It Once You Make It - use Nulled HttpClient
        http_client = HttpClient.create_null({
            "/oauth/token": {"status": 200, "body": create_token_response(email, email_verified)}
        })
        return Auth0Client(http_client, "null.host", "null_id", "null_secret")
    
    def validate_login(self, code, callback_url):
        response = self._http.post(
            f"{self._host}/oauth/token",
            json={
                "client_id": self._client_id,
                "client_secret": self._client_secret,
                "code": code,
                "redirect_uri": callback_url
            }
        )
        token_data = json.loads(response["body"])
        return decode_token(token_data["id_token"])
```

#### Go
```go
// Low-level wrapper
type HTTPClient struct {
    client *http.Client
}

func NewHTTPClient() *HTTPClient {
    return &HTTPClient{client: &http.Client{}}
}

func NewHTTPClientNull(responses map[string]Response) *HTTPClient {
    return &HTTPClient{client: &nulledHTTPClient{responses: responses}}
}

// High-level wrapper
type Auth0Client struct {
    http *HTTPClient
    host string
    clientID string
    clientSecret string
}

func NewAuth0Client(host, clientID, clientSecret string) *Auth0Client {
    return &Auth0Client{
        http: NewHTTPClient(),
        host: host,
        clientID: clientID,
        clientSecret: clientSecret,
    }
}

func NewAuth0ClientNull(opts ...NullOption) *Auth0Client {
    config := applyNullOptions(opts)
    return &Auth0Client{
        http: NewHTTPClientNull(map[string]Response{
            "/oauth/token": createTokenResponse(config.email, config.emailVerified),
        }),
        host: "null.host",
        clientID: "null_id",
        clientSecret: "null_secret",
    }
}
```

#### Elixir
```elixir
# Low-level wrapper
defmodule HTTPClient do
  def create do
    %HTTPClient{client: HTTPoison}
  end
  
  def create_null(responses \\ %{}) do
    %HTTPClient{client: {:nulled, responses}}
  end
  
  def get(%HTTPClient{client: client}, url, headers) do
    case client do
      HTTPoison -> 
        HTTPoison.get(url, headers)
      {:nulled, responses} -> 
        nulled_get(responses, url)
    end
  end
end

# High-level wrapper
defmodule Auth0Client do
  def create(host, client_id, client_secret) do
    %Auth0Client{
      http: HTTPClient.create(),
      host: host,
      client_id: client_id,
      client_secret: client_secret
    }
  end
  
  def create_null(opts \\ []) do
    email = Keyword.get(opts, :email, "null@example.com")
    verified = Keyword.get(opts, :email_verified, true)
    
    %Auth0Client{
      http: HTTPClient.create_null(%{
        "/oauth/token" => create_token_response(email, verified)
      }),
      host: "null.host",
      client_id: "null_id",
      client_secret: "null_secret"
    }
  end
end
```

---

## Narrow Integration Tests

**Problem:** Infrastructure code ultimately communicates with external systems. Mistakes are easy to make.

**Solution:** Test external communication for real. Use real databases, real file systems, real network calls.

**Key principles:**
- Test systems reserved exclusively for one machine (ideally local)
- Start/stop test systems in your tests or build script
- Match production configuration as closely as possible
- Only test low-level wrappers this way (high-level wrappers use Fake It Once You Make It)

### Examples

#### Python - HTTP Client Tests
```python
import pytest
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import time

class TestHTTPHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'Test response')

@pytest.fixture
def test_server():
    server = HTTPServer(('localhost', 0), TestHTTPHandler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever)
    thread.daemon = True
    thread.start()
    yield f'http://localhost:{port}'
    server.shutdown()

def test_http_client_performs_get_request(test_server):
    client = HttpClient.create()
    response = client.get(f'{test_server}/path')
    
    assert response['status'] == 200
    assert response['body'] == 'Test response'

def test_http_client_includes_headers(test_server):
    client = HttpClient.create()
    response = client.get(f'{test_server}/', headers={'X-Custom': 'value'})
    
    assert response['status'] == 200
```

#### Go - Database Tests
```go
func TestDatabaseInsert(t *testing.T) {
    // Setup local test database
    db := setupTestDB(t)
    defer db.Close()
    
    repo := NewUserRepository(db)
    
    user := &User{Name: "Test User", Email: "test@example.com"}
    err := repo.Insert(user)
    
    require.NoError(t, err)
    assert.NotZero(t, user.ID)
    
    // Verify insertion
    retrieved, err := repo.GetByID(user.ID)
    require.NoError(t, err)
    assert.Equal(t, "Test User", retrieved.Name)
}

func setupTestDB(t *testing.T) *sql.DB {
    db, err := sql.Open("postgres", "postgresql://localhost/test_db")
    require.NoError(t, err)
    
    // Run migrations
    _, err = db.Exec(`CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name TEXT,
        email TEXT
    )`)
    require.NoError(t, err)
    
    t.Cleanup(func() {
        db.Exec("TRUNCATE users")
    })
    
    return db
}
```

#### Elixir - File System Tests
```elixir
defmodule FileStorageTest do
  use ExUnit.Case
  
  @test_dir "/tmp/file_storage_test_#{System.unique_integer()}"
  
  setup do
    File.mkdir_p!(@test_dir)
    on_exit(fn -> File.rm_rf!(@test_dir) end)
    :ok
  end
  
  test "writes file to disk" do
    storage = FileStorage.create(@test_dir)
    
    :ok = FileStorage.write(storage, "test.txt", "content")
    
    assert File.read!("#{@test_dir}/test.txt") == "content"
  end
  
  test "reads file from disk" do
    File.write!("#{@test_dir}/existing.txt", "data")
    storage = FileStorage.create(@test_dir)
    
    {:ok, content} = FileStorage.read(storage, "existing.txt")
    
    assert content == "data"
  end
end
```

---

## Paranoic Telemetry

**Problem:** External systems are unreliable and will eventually fail.

**Solution:** Assume everything will break. Instrument your code accordingly.

**Test that:**
- Every failure case logs an error and sends an alert, OR
- Every failure case throws an exception that ultimately logs and alerts
- Hanging requests are handled (timeouts)

### Examples

#### Python
```python
class ApiClient:
    def __init__(self, http_client, logger, timeout=30):
        self._http = http_client
        self._logger = logger
        self._timeout = timeout
    
    def fetch_data(self, endpoint):
        try:
            response = self._http.get(
                f"{self.base_url}/{endpoint}",
                timeout=self._timeout
            )
            
            if response['status'] == 500:
                self._logger.error("API server error", endpoint=endpoint)
                return None
            
            if response['status'] == 404:
                self._logger.warning("Endpoint not found", endpoint=endpoint)
                return None
            
            return json.loads(response['body'])
            
        except TimeoutError:
            self._logger.error("API request timeout", endpoint=endpoint, timeout=self._timeout)
            return None
        except Exception as e:
            self._logger.error("API request failed", endpoint=endpoint, error=str(e))
            return None

# Test error logging
def test_logs_server_error():
    http = HttpClient.create_null({"/data": {"status": 500}})
    logger = Logger.create_null()
    log_output = logger.track_output()
    
    client = ApiClient(http, logger)
    result = client.fetch_data("data")
    
    assert result is None
    assert any(log['level'] == 'error' and 'server error' in log['message'] 
               for log in log_output.data)

def test_logs_timeout():
    http = HttpClient.create_null({"/data": TimeoutError()})
    logger = Logger.create_null()
    log_output = logger.track_output()
    
    client = ApiClient(http, logger)
    result = client.fetch_data("data")
    
    assert result is None
    assert any(log['level'] == 'error' and 'timeout' in log['message']
               for log in log_output.data)
```

#### Go
```go
func (c *APIClient) FetchData(endpoint string) (*Data, error) {
    ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
    defer cancel()
    
    response, err := c.http.Get(ctx, c.baseURL + "/" + endpoint)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            c.logger.Error("API request timeout", 
                map[string]interface{}{
                    "endpoint": endpoint,
                    "timeout": c.timeout,
                })
            return nil, ErrTimeout
        }
        c.logger.Error("API request failed",
            map[string]interface{}{
                "endpoint": endpoint,
                "error": err.Error(),
            })
        return nil, err
    }
    
    if response.Status == 500 {
        c.logger.Error("API server error", 
            map[string]interface{}{"endpoint": endpoint})
        return nil, ErrServerError
    }
    
    // ... parse response
}

// Test
func TestLogsServerError(t *testing.T) {
    http := NewHTTPClientNull(map[string]Response{
        "/data": {Status: 500},
    })
    logger := NewLoggerNull()
    logOutput := logger.TrackOutput()
    
    client := NewAPIClient(http, logger)
    result, err := client.FetchData("data")
    
    assert.Nil(t, result)
    assert.Error(t, err)
    
    logs := logOutput.Data()
    assert.True(t, hasErrorLog(logs, "server error"))
}
```

#### Elixir
```elixir
def fetch_data(client, endpoint) do
  case HTTPClient.get(client.http, "#{client.base_url}/#{endpoint}", timeout: client.timeout) do
    {:ok, %{status: 200, body: body}} ->
      Jason.decode(body)
    
    {:ok, %{status: 500}} ->
      Logger.error("API server error", endpoint: endpoint)
      {:error, :server_error}
    
    {:ok, %{status: 404}} ->
      Logger.warning("Endpoint not found", endpoint: endpoint)
      {:error, :not_found}
    
    {:error, %HTTPoison.Error{reason: :timeout}} ->
      Logger.error("API request timeout", 
        endpoint: endpoint, 
        timeout: client.timeout)
      {:error, :timeout}
    
    {:error, reason} ->
      Logger.error("API request failed", 
        endpoint: endpoint, 
        error: inspect(reason))
      {:error, :request_failed}
  end
end

# Test
test "logs server error" do
  http = HTTPClient.create_null(%{"/data" => %{status: 500}})
  logger = Logger.create_null()
  log_output = Logger.track_output(logger)
  
  client = %APIClient{http: http, logger: logger}
  result = APIClient.fetch_data(client, "data")
  
  assert {:error, :server_error} = result
  logs = OutputTracker.data(log_output)
  assert Enum.any?(logs, fn log -> 
    log.level == :error and String.contains?(log.message, "server error")
  end)
end
```

---

## Summary

Infrastructure Patterns help you test external systems safely:

1. **Infrastructure Wrappers** - Isolate external system code
2. **Narrow Integration Tests** - Test real external communication
3. **Paranoic Telemetry** - Assume everything will fail and log accordingly

Combined with Nullability Patterns, these give you confidence in your infrastructure code.
