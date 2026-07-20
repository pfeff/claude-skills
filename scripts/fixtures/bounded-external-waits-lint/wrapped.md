# wrapped fixture

Fixture (b): the same external call, but run through the bounded-wait
recipe. Must NOT be flagged (exclusion 1).

```bash
run_bounded_external 'curl -sf https://api.example.com/health' 30 2 3 5 5
```
