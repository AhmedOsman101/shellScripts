## Read File Content

**get** `/api/v1/beta/files/{file_id}/content`

Get a presigned URL to download the file content.

### Path Parameters

- `file_id: string`

### Query Parameters

- `expires_at_seconds: optional number`

- `organization_id: optional string`

- `project_id: optional string`

### Cookie Parameters

- `session: optional string`

### Returns

- `PresignedURL = object { expires_at, url, form_fields }`

  Schema for a presigned URL.

  - `expires_at: string`

    The time at which the presigned URL expires

  - `url: string`

    A presigned URL for IO operations against a private file

  - `form_fields: optional map[string]`

    Form fields for a presigned POST request

### Example

```http
curl https://api.cloud.llamaindex.ai/api/v1/beta/files/$FILE_ID/content \
    -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY"
```

#### Response

```json
{
  "expires_at": "2019-12-27T18:11:19.117Z",
  "url": "https://example.com",
  "form_fields": {
    "foo": "string"
  }
}
```
