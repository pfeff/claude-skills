# inline-code-span fixture

Fixture (f): the vocabulary word appears only in an inline code span, e.g.
`curl -sf http://localhost:4000/api/health`, and in ordinary prose — not
inside any fenced code block. Must NOT be flagged — this lint only scans
fenced bash blocks, never inline spans or prose.
