# Elixir Complete Example

ROT13 encoder demonstrating Testing Without Mocks patterns with functional Elixir.

## Production Code

```elixir
# lib/app.ex
defmodule Rot13.App do
  @moduledoc "Application layer"
  
  defstruct [:command_line]
  
  def create do
    %__MODULE__{
      command_line: Rot13.CommandLine.create()
    }
  end
  
  def create_null(opts \\ []) do
    %__MODULE__{
      command_line: Rot13.CommandLine.create_null(opts)
    }
  end
  
  def run(%__MODULE__{command_line: cmd} = _app) do
    args = Rot13.CommandLine.args(cmd)
    
    cond do
      length(args) == 0 ->
        Rot13.CommandLine.write_output(cmd, "Usage: rot13 TEXT\n")
      
      length(args) > 1 ->
        Rot13.CommandLine.write_output(cmd, "Error: too many arguments\n")
      
      true ->
        [input_text] = args
        output_text = Rot13.Logic.transform(input_text)
        Rot13.CommandLine.write_output(cmd, output_text <> "\n")
    end
  end
end

# lib/command_line.ex
defmodule Rot13.CommandLine do
  @moduledoc "Infrastructure wrapper for command-line"
  
  defstruct [:args_source, :output_target, :trackers]
  
  def create do
    %__MODULE__{
      args_source: :real,
      output_target: :stdio,
      trackers: []
    }
  end
  
  def create_null(opts \\ []) do
    args = Keyword.get(opts, :args, [])
    %__MODULE__{
      args_source: {:nulled, args},
      output_target: :null,
      trackers: []
    }
  end
  
  def args(%__MODULE__{args_source: source}) do
    case source do
      :real -> 
        System.argv()
      {:nulled, args} -> 
        args
    end
  end
  
  def write_output(%__MODULE__{output_target: target, trackers: trackers}, text) do
    # Write to output
    case target do
      :stdio -> IO.write(text)
      :null -> :ok
    end
    
    # Notify trackers
    Enum.each(trackers, fn tracker ->
      Rot13.OutputTracker.record(tracker, text)
    end)
  end
  
  def track_output(cmd) do
    tracker = Rot13.OutputTracker.new()
    {%{cmd | trackers: [tracker | cmd.trackers]}, tracker}
  end
end

# lib/logic.ex
defmodule Rot13.Logic do
  @moduledoc "Pure ROT13 logic"
  
  def transform(text) do
    text
    |> String.to_charlist()
    |> Enum.map(&transform_char/1)
    |> List.to_string()
  end
  
  defp transform_char(char) when char >= ?a and char <= ?z do
    rem(char - ?a + 13, 26) + ?a
  end
  
  defp transform_char(char) when char >= ?A and char <= ?Z do
    rem(char - ?A + 13, 26) + ?A
  end
  
  defp transform_char(char), do: char
end

# lib/output_tracker.ex
defmodule Rot13.OutputTracker do
  @moduledoc "Output tracking using Agent"
  use Agent
  
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
```

## Test Code

```elixir
# test/app_test.exs
defmodule Rot13.AppTest do
  use ExUnit.Case
  alias Rot13.{App, CommandLine, OutputTracker}
  
  test "transforms with rot13" do
    app = App.create_null(args: ["hello"])
    {cmd, output} = CommandLine.track_output(app.command_line)
    app = %{app | command_line: cmd}
    
    App.run(app)
    
    assert OutputTracker.data(output) == ["uryyb\n"]
  end
  
  test "shows usage when no args" do
    app = App.create_null(args: [])
    {cmd, output} = CommandLine.track_output(app.command_line)
    app = %{app | command_line: cmd}
    
    App.run(app)
    
    assert OutputTracker.data(output) == ["Usage: rot13 TEXT\n"]
  end
  
  test "shows error with too many args" do
    app = App.create_null(args: ["one", "two"])
    {cmd, output} = CommandLine.track_output(app.command_line)
    app = %{app | command_line: cmd}
    
    App.run(app)
    
    assert OutputTracker.data(output) == ["Error: too many arguments\n"]
  end
end

# test/logic_test.exs
defmodule Rot13.LogicTest do
  use ExUnit.Case
  alias Rot13.Logic
  
  test "encodes lowercase" do
    assert Logic.transform("abc") == "nop"
  end
  
  test "encodes uppercase" do
    assert Logic.transform("XYZ") == "KLM"
  end
  
  test "preserves non-letters" do
    assert Logic.transform("Hello, World!") == "Uryyb, Jbeyq!"
  end
end
```

## Elixir Idioms Demonstrated

- **Keyword Lists** - `opts \\ []` for Configurable Responses
- **Pattern Matching** - Struct patterns and case expressions
- **Agent for State** - `OutputTracker` uses Agent for mutable state
- **Pipe Operator** - `|>` for data transformation pipelines
- **Guard Clauses** - `when` for character range checks
- **Immutable Updates** - `%{cmd | trackers: [tracker | cmd.trackers]}`

## Testing

```bash
# Run tests
mix test

# With coverage
mix test --cover

# Watch mode
mix test.watch
```

## Project Structure

```
rot13/
├── mix.exs
├── lib/
│   ├── app.ex
│   ├── command_line.ex
│   ├── logic.ex
│   └── output_tracker.ex
└── test/
    ├── test_helper.exs
    ├── app_test.exs
    └── logic_test.exs
```

## Mix Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
  ]
end
```
