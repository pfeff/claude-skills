# loopback-comment-loophole fixture

Fixture (j): a genuinely external curl call whose trailing comment happens
to mention "localhost" — must still be FLAGGED. The loopback exclusion is
checked against the code portion of the line only (before any `#`), so a
comment mentioning a loopback host can't suppress a real violation whose
actual target is external.

```bash
curl https://external.example.com/x  # not localhost
```
