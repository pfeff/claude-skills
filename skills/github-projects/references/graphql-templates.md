# GraphQL Templates

Reusable GraphQL mutation and query templates for GitHub Projects V2.

## Mutations

### Update Item Field Value

Sets a single-select field (Status, Sprint, Horizon, etc.) on a project item.

```graphql
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "<project_node_id>"
    itemId: "<item_id>"
    fieldId: "<field_id>"
    value: { singleSelectOptionId: "<option_id>" }
  }) {
    projectV2Item { id }
  }
}
```

**Via `gh` CLI**:
```bash
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "<project_node_id>"
    itemId: "<item_id>"
    fieldId: "<field_id>"
    value: { singleSelectOptionId: "<option_id>" }
  }) { projectV2Item { id } }
}'
```

**Parameters**:
| Parameter | Source | Example |
|-----------|--------|---------|
| `project_node_id` | `references/project-defaults.md` | `PVT_kwHNa8POARiyqQ` |
| `item_id` | `project-board-helper lookup` | `PVTI_lAHNa8POARiyqc4BcDef` |
| `field_id` | `project-board-helper field <name>` | `PVTSSF_lAHNa8POARiyqc4A1234` |
| `option_id` | `project-board-helper field <name>` options | `abc123` |

### Update Text Field Value

Sets a text field on a project item.

```graphql
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "<project_node_id>"
    itemId: "<item_id>"
    fieldId: "<field_id>"
    value: { text: "<text_value>" }
  }) {
    projectV2Item { id }
  }
}
```

### Clear Field Value

Removes a field value from a project item.

```graphql
mutation {
  clearProjectV2ItemFieldValue(input: {
    projectId: "<project_node_id>"
    itemId: "<item_id>"
    fieldId: "<field_id>"
  }) {
    projectV2Item { id }
  }
}
```

## Queries

### Recent Items (Last N)

Fetch the most recently added items. Useful after `add-to-board` to find the new item ID without a full cache sync.

```graphql
{
  user(login: "<owner>") {
    projectV2(number: <project_number>) {
      items(last: <count>) {
        nodes {
          id
          content {
            ... on Issue {
              number
              title
              repository { name }
            }
          }
        }
      }
    }
  }
}
```

**Via `gh` CLI**:
```bash
gh api graphql -f query='{
  user(login: "<owner>") {
    projectV2(number: <project_number>) {
      items(last: 5) {
        nodes {
          id
          content { ... on Issue { number title repository { name } } }
        }
      }
    }
  }
}'
```

## Shell Escaping Notes

### Variable interpolation in `gh api graphql`

Use `-f` for string fields and `-F` for integer/boolean fields. The parameterized form is preferred — it avoids shell escaping issues and is safer with complex values.

**Recommended — parameterized variables**:
```bash
gh api graphql \
  -f query='mutation($proj:ID! $item:ID! $field:ID! $opt:String!) { updateProjectV2ItemFieldValue(input: { projectId:$proj itemId:$item fieldId:$field value: { singleSelectOptionId:$opt } }) { projectV2Item { id } } }' \
  -f proj="$PROJECT_ID" \
  -f item="$ITEM_ID" \
  -f field="$FIELD_ID" \
  -f opt="$OPTION_ID"
```

**Alternative — inline interpolation** (use only when parameterized form is impractical):
```bash
gh api graphql \
  -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "'"$PROJECT_ID"'" itemId: "'"$ITEM_ID"'" fieldId: "'"$FIELD_ID"'" value: { singleSelectOptionId: "'"$OPTION_ID"'" } }) { projectV2Item { id } } }'
```
