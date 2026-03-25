# Python Complete Example

A simple command-line ROT13 encoder demonstrating all Testing Without Mocks patterns.

## Production Code

```python
# app.py - Application layer
import sys
from command_line import CommandLine
import rot13

class App:
    @staticmethod
    def create():
        """Production factory"""
        return App(CommandLine.create())
    
    @staticmethod
    def create_null(args=None):
        """Null factory for tests"""
        return App(CommandLine.create_null(args=args or []))
    
    def __init__(self, command_line):
        self._command_line = command_line
    
    def run(self):
        """Logic Sandwich: read infrastructure → process logic → write infrastructure"""
        args = self._command_line.args()
        
        if len(args) == 0:
            self._command_line.write_output("Usage: rot13 TEXT\n")
            return
        
        if len(args) > 1:
            self._command_line.write_output("Error: too many arguments\n")
            return
        
        # Logic Sandwich
        input_text = args[0]
        output_text = rot13.transform(input_text)
        self._command_line.write_output(output_text + "\n")

# command_line.py - Infrastructure Wrapper
class CommandLine:
    @staticmethod
    def create():
        """Production factory"""
        return CommandLine(sys)
    
    @staticmethod
    def create_null(args=None):
        """Null factory with Configurable Responses"""
        return CommandLine(_NulledSys(args or []))
    
    def __init__(self, sys_module):
        self._sys = sys_module
        self._output_listeners = []
    
    def args(self):
        """Extract command-line arguments"""
        return self._sys.argv[1:]
    
    def write_output(self, text):
        """Write to stdout with Output Tracking"""
        self._sys.stdout.write(text)
        for listener in self._output_listeners:
            listener(text)
    
    def track_output(self):
        """Output Tracking"""
        tracker = OutputTracker()
        self._output_listeners.append(tracker.record)
        return tracker

# Embedded Stub for sys module
class _NulledSys:
    def __init__(self, args):
        self.argv = ["program_name"] + args
        self.stdout = _NullStdout()

class _NullStdout:
    def write(self, text):
        pass  # Discard output

# rot13.py - Pure logic
def transform(text):
    """ROT13 transformation - pure function"""
    result = []
    for char in text:
        if 'a' <= char <= 'z':
            result.append(chr((ord(char) - ord('a') + 13) % 26 + ord('a')))
        elif 'A' <= char <= 'Z':
            result.append(chr((ord(char) - ord('A') + 13) % 26 + ord('A')))
        else:
            result.append(char)
    return ''.join(result)

# output_tracker.py - Reusable helper
class OutputTracker:
    def __init__(self):
        self._data = []
    
    def record(self, item):
        self._data.append(item)
    
    @property
    def data(self):
        return self._data.copy()
```

## Test Code

```python
# test_app.py - Application tests
def test_transforms_with_rot13():
    """Narrow, sociable, state-based test"""
    app = App.create_null(args=["hello"])
    cmd = app._command_line
    output = cmd.track_output()
    
    app.run()
    
    assert output.data == ["uryyb\n"]

def test_shows_usage_when_no_args():
    app = App.create_null(args=[])
    cmd = app._command_line
    output = cmd.track_output()
    
    app.run()
    
    assert output.data == ["Usage: rot13 TEXT\n"]

def test_shows_error_with_too_many_args():
    app = App.create_null(args=["one", "two"])
    cmd = app._command_line
    output = cmd.track_output()
    
    app.run()
    
    assert output.data == ["Error: too many arguments\n"]

# test_rot13.py - Logic tests
def test_encodes_lowercase():
    assert rot13.transform("abc") == "nop"

def test_encodes_uppercase():
    assert rot13.transform("XYZ") == "KLM"

def test_preserves_non_letters():
    assert rot13.transform("Hello, World!") == "Uryyb, Jbeyq!"
```

## Patterns Demonstrated

- **Narrow Tests** - Each test focuses on specific behavior
- **State-Based Tests** - Tests check output, not method calls
- **Sociable Tests** - Tests use real dependencies (Nulled)
- **Nullables** - `create_null()` factories disable infrastructure
- **Embedded Stub** - `_NulledSys` stubs the `sys` module
- **Configurable Responses** - Args configured via parameters
- **Output Tracking** - `track_output()` verifies writes
- **Logic Sandwich** - App reads → processes → writes
- **Zero-Impact Instantiation** - Constructors do minimal work
- **Parameterless Instantiation** - `create()` and `create_null()` factories

## Testing Frameworks

Works with pytest, unittest, or any Python testing framework:

```bash
# With pytest
pip install pytest
pytest test_app.py

# With unittest
python -m unittest test_app.py
```
