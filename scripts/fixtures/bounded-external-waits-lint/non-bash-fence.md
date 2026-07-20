# non-bash-fence fixture

Fixture (e): the vocabulary word appears inside an illustrative
```markdown``` example fence (documentation showing what an AC criterion
looks like), not an actual bash code block. Must NOT be flagged — this
lint only scans shell-ish fenced blocks.

```markdown
- [x] **AC-3**: Returns 401 for invalid tokens _(verify: curl the endpoint)_
```
