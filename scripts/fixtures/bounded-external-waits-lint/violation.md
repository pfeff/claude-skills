# violation fixture

Fixture (a): a verify step shells out to a genuinely external host without
the bounded-wait wrapper. Must be flagged.

```bash
curl -sf https://api.example.com/health || echo "down"
```
