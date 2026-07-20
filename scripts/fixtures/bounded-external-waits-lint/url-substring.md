# url-substring fixture

Fixture (i): a URL substring like `curl.example.com` inside an `echo`
string — the vocabulary word appears as part of a hostname token, not as a
command invocation. Must NOT be flagged; command-position matching rules
this out since `curl` here isn't preceded by a statement-starting
delimiter.

```bash
echo "see https://curl.example.com/docs for more"
```
