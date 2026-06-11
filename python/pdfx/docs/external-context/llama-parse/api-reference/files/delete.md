## Delete File

**delete** `/api/v1/beta/files/{file_id}`

Delete a file from the project.

### Path Parameters

- `file_id: string`

### Query Parameters

- `organization_id: optional string`

- `project_id: optional string`

### Cookie Parameters

- `session: optional string`

### Example

```http
curl https://api.cloud.llamaindex.ai/api/v1/beta/files/$FILE_ID \
    -X DELETE \
    -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY"
```
