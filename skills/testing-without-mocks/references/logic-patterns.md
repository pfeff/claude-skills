# Logic Patterns

Patterns for testing pure computation (code without infrastructure dependencies).

## Easily-Visible Behavior

**Problem:** Logic can only be tested if its results are visible.

**Solution:** Prefer pure functions and immutable objects. For mutable objects, provide getters or events to observe state changes.

### Pure Functions
```python
def add(a, b):
    return a + b  # Result is visible via return value
```

### Immutable Objects
```python
class Money:
    def __init__(self, amount):
        self._amount = amount
    
    def add(self, other):
        return Money(self._amount + other._amount)  # Returns new object
```

### Mutable Objects with Getters
```python
class Counter:
    def __init__(self):
        self._count = 0
    
    def increment(self):
        self._count += 1
    
    def get_count(self):  # Getter makes state visible
        return self._count
```

**Avoid:** Reaching into dependencies more than one level deep. Each class should completely encapsulate its dependencies.

---

## Testable Libraries

**Problem:** Third-party libraries don't always have visible behavior, introduce breaking changes, or stop being maintained.

**Solution:** Wrap third-party code. Design wrapper's API for your application's needs, not the library's API.

### Example
```python
# Instead of using pandas directly everywhere:
import pandas as pd

df = pd.read_csv("data.csv")
result = df.groupby("category").sum()

# Wrap it:
class DataAnalyzer:
    def __init__(self, dataframe_lib=pd):
        self._df_lib = dataframe_lib
    
    def sum_by_category(self, csv_path, category_col):
        df = self._df_lib.read_csv(csv_path)
        return df.groupby(category_col).sum().to_dict()

# Now your code depends on DataAnalyzer, not pandas directly
analyzer = DataAnalyzer()
result = analyzer.sum_by_category("data.csv", "category")
```

**Don't wrap:**
- Pervasive, stable code (core language features)
- Costly-to-wrap code (UI frameworks) unless absolutely necessary

For infrastructure-related libraries (HTTP, databases), use Infrastructure Wrappers instead.

---

## Collaborator-Based Isolation

**Problem:** Sociable tests fail when any dependency's behavior changes, even when that change is irrelevant to the test.

**Solution:** When a dependency's behavior isn't relevant to the code under test, use the dependency to help define test expectations.

### Example
```python
def test_report_includes_address_in_header():
    # The test doesn't care about address formatting details
    address = Address.create_test_instance(
        street="123 Main St",
        city="Springfield"
    )
    report = InventoryReport(Inventory.create(), [address])
    
    # Use the address to define expectation
    expected = f"Inventory Report for {address.render_one_line()}"
    
    assert report.render_header() == expected
```

**Use sparingly** - This ties tests more tightly to implementation. Only use when:
- The dependency's specific behavior is truly irrelevant
- The test is focused on a specific aspect
- The dependency has its own comprehensive tests

---

## Summary

Logic Patterns keep pure computation simple:

1. **Easily-Visible Behavior** - Make results observable
2. **Testable Libraries** - Wrap third-party code
3. **Collaborator-Based Isolation** - Use dependencies in expectations when their details don't matter

Logic code is the easiest to test. Aim to maximize logic and minimize infrastructure.
