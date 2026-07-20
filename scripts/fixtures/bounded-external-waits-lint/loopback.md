# loopback fixture

Fixture (c): a curl call targeting a loopback host. Must NOT be flagged
(exclusion 2) — this is internal tooling, not the third-party/flaky class.

```bash
curl -sf http://localhost:4000/api/health || echo "WARNING: health check failed"
```
