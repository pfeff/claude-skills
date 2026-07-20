# internal-service fixture

Fixture (d): a curl call targeting this repo's own coordinator via the
`COORDINATOR_URL` variable (defaults to `http://localhost:4000` everywhere
it's declared). Must NOT be flagged (exclusion 2).

```bash
curl -s -X POST "${COORDINATOR_URL}/api/tasks/${COORDINATOR_TASK_ID}/report" \
  -H "Authorization: Bearer ${COORDINATOR_TOKEN}" > /dev/null
```
