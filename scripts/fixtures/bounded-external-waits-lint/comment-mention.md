# comment-mention fixture

Fixture (h): a `#` comment INSIDE a bash-tagged fence that merely mentions
`curl` in prose — no invocation, no companion `run_bounded_external`. Must
NOT be flagged; this lint scans code, not comments narrating the doctrine.

```bash
# don't forget curl needs a timeout wrapper
echo hi
```
