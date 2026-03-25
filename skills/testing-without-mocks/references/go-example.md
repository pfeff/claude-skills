# Go Complete Example

ROT13 encoder demonstrating Testing Without Mocks patterns with idiomatic Go.

## Production Code

```go
// app.go
package main

type App struct {
    commandLine *CommandLine
}

func NewApp() *App {
    return &App{commandLine: NewCommandLine()}
}

func NewAppNull(opts ...AppNullOption) *App {
    config := &appNullConfig{args: []string{}}
    for _, opt := range opts {
        opt(config)
    }
    return &App{commandLine: NewCommandLineNull(WithArgs(config.args...))}
}

type AppNullOption func(*appNullConfig)
type appNullConfig struct {
    args []string
}

func WithArgs(args ...string) CommandLineNullOption {
    return func(c *commandLineNullConfig) {
        c.args = args
    }
}

func (a *App) Run() {
    args := a.commandLine.Args()
    
    if len(args) == 0 {
        a.commandLine.WriteOutput("Usage: rot13 TEXT\n")
        return
    }
    
    if len(args) > 1 {
        a.commandLine.WriteOutput("Error: too many arguments\n")
        return
    }
    
    inputText := args[0]
    outputText := Transform(inputText)
    a.commandLine.WriteOutput(outputText + "\n")
}

// command_line.go
package main

import (
    "io"
    "os"
    "sync"
)

type CommandLine struct {
    args []string
    output io.Writer
    trackers []*OutputTracker
}

func NewCommandLine() *CommandLine {
    return &CommandLine{
        args: os.Args[1:],
        output: os.Stdout,
    }
}

type CommandLineNullOption func(*commandLineNullConfig)
type commandLineNullConfig struct {
    args []string
}

func NewCommandLineNull(opts ...CommandLineNullOption) *CommandLine {
    config := &commandLineNullConfig{args: []string{}}
    for _, opt := range opts {
        opt(config)
    }
    return &CommandLine{
        args: config.args,
        output: io.Discard,
    }
}

func (c *CommandLine) Args() []string {
    return c.args
}

func (c *CommandLine) WriteOutput(text string) {
    c.output.Write([]byte(text))
    for _, tracker := range c.trackers {
        tracker.Record(text)
    }
}

func (c *CommandLine) TrackOutput() *OutputTracker {
    tracker := &OutputTracker{}
    c.trackers = append(c.trackers, tracker)
    return tracker
}

// output_tracker.go
type OutputTracker struct {
    data []string
    mu   sync.Mutex
}

func (t *OutputTracker) Record(text string) {
    t.mu.Lock()
    defer t.mu.Unlock()
    t.data = append(t.data, text)
}

func (t *OutputTracker) Data() []string {
    t.mu.Lock()
    defer t.mu.Unlock()
    return append([]string{}, t.data...)
}

// rot13.go
package main

func Transform(text string) string {
    result := make([]rune, len(text))
    for i, char := range text {
        result[i] = transformChar(char)
    }
    return string(result)
}

func transformChar(char rune) rune {
    switch {
    case char >= 'a' && char <= 'z':
        return ((char - 'a' + 13) % 26) + 'a'
    case char >= 'A' && char <= 'Z':
        return ((char - 'A' + 13) % 26) + 'A'
    default:
        return char
    }
}
```

## Test Code

```go
// app_test.go
package main

import (
    "testing"
    "github.com/stretchr/testify/assert"
)

func TestTransformsWithRot13(t *testing.T) {
    app := NewAppNull(WithArgs("hello"))
    output := app.commandLine.TrackOutput()
    
    app.Run()
    
    assert.Equal(t, []string{"uryyb\n"}, output.Data())
}

func TestShowsUsageWhenNoArgs(t *testing.T) {
    app := NewAppNull()
    output := app.commandLine.TrackOutput()
    
    app.Run()
    
    assert.Equal(t, []string{"Usage: rot13 TEXT\n"}, output.Data())
}

func TestShowsErrorWithTooManyArgs(t *testing.T) {
    app := NewAppNull(WithArgs("one", "two"))
    output := app.commandLine.TrackOutput()
    
    app.Run()
    
    assert.Equal(t, []string{"Error: too many arguments\n"}, output.Data())
}

// rot13_test.go
func TestEncodesLowercase(t *testing.T) {
    assert.Equal(t, "nop", Transform("abc"))
}

func TestEncodesUppercase(t *testing.T) {
    assert.Equal(t, "KLM", Transform("XYZ"))
}

func TestPreservesNonLetters(t *testing.T) {
    assert.Equal(t, "Uryyb, Jbeyq!", Transform("Hello, World!"))
}
```

## Go Idioms Demonstrated

- **Functional Options Pattern** - `WithArgs()` for Configurable Responses
- **Interface-based Embedded Stubs** - `io.Writer` for output abstraction
- **Thread-safe Output Tracking** - `sync.Mutex` for concurrent access
- **Constructor Functions** - `NewApp()` and `NewAppNull()`
- **Variadic Options** - `opts ...AppNullOption` for flexible configuration

## Testing

```bash
# Run tests
go test ./...

# With coverage
go test -cover ./...

# Verbose output
go test -v ./...
```

## Project Structure

```
myproject/
├── go.mod
├── app.go
├── app_test.go
├── command_line.go
├── output_tracker.go
├── rot13.go
└── rot13_test.go
```
