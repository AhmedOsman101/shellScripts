## Upload File

**post** `/api/v1/beta/files`

Upload a file using multipart/form-data.

Set `purpose` to indicate how the file will be used:
`user_data`, `parse`, `extract`, `classify`, `split`,
`sheet`, or `agent_app`.

Returns the created file metadata including its ID for use
in subsequent parse, extract, or classify operations.

### Query Parameters

- `organization_id: optional string`

- `project_id: optional string`

### Cookie Parameters

- `session: optional string`

### Returns

- `id: string`

  Unique file identifier

- `name: string`

  File name including extension

- `project_id: string`

  Project this file belongs to

- `download_url: optional PresignedURL`

  Schema for a presigned URL.

  - `expires_at: string`

    The time at which the presigned URL expires

  - `url: string`

    A presigned URL for IO operations against a private file

  - `form_fields: optional map[string]`

    Form fields for a presigned POST request

- `expires_at: optional string`

  When the file expires and may be automatically removed. Null means no expiration.

- `external_file_id: optional string`

  Optional ID for correlating with an external system

- `file_type: optional string`

  File extension (pdf, docx, png, etc.)

- `last_modified_at: optional string`

  When the file was last modified (ISO 8601)

- `purpose: optional string`

  How the file will be used: user_data, parse, extract, classify, split, sheet, or agent_app

### Example

```http
curl https://api.cloud.llamaindex.ai/api/v1/beta/files \
    -H 'Content-Type: multipart/form-data' \
    -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY" \
    -F 'file=@/path/to/file' \
    -F purpose=purpose
```

#### Response

```json
{
  "id": "dfl-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "name": "invoice.pdf",
  "project_id": "123e4567-e89b-12d3-a456-426614174000",
  "download_url": {
    "expires_at": "2019-12-27T18:11:19.117Z",
    "url": "https://example.com",
    "form_fields": {
      "foo": "string"
    }
  },
  "expires_at": "2019-12-27T18:11:19.117Z",
  "external_file_id": "ext-12345",
  "file_type": "pdf",
  "last_modified_at": "2019-12-27T18:11:19.117Z",
  "purpose": "parse"
}
```
