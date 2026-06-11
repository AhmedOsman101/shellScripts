## List Files

**get** `/api/v1/beta/files`

List files with optional filtering and pagination.

Filter by `file_name`, `file_ids`, or `external_file_id`.
Supports cursor-based pagination and custom ordering.

### Query Parameters

- `expand: optional array of string`

  Fields to expand on each file.

- `external_file_id: optional string`

  Filter by external file ID.

- `file_ids: optional array of string`

  Filter by specific file IDs.

- `file_name: optional string`

  Filter by file name (exact match).

- `order_by: optional string`

  A comma-separated list of fields to order by, sorted in ascending order. Use 'field_name desc' to specify descending order.

- `organization_id: optional string`

- `page_size: optional number`

  The maximum number of items to return. Defaults to 50, maximum is 1000.

- `page_token: optional string`

  A page token received from a previous list call. Provide this to retrieve the subsequent page.

- `project_id: optional string`

### Cookie Parameters

- `session: optional string`

### Returns

- `items: array of object { id, name, project_id, 6 more }`

  The list of items.

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

- `next_page_token: optional string`

  A token, which can be sent as page_token to retrieve the next page. If this field is omitted, there are no subsequent pages.

- `total_size: optional number`

  The total number of items available. This is only populated when specifically requested. The value may be an estimate and can be used for display purposes only.

### Example

```http
curl https://api.cloud.llamaindex.ai/api/v1/beta/files \
    -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY"
```

#### Response

```json
{
  "items": [
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
  ],
  "next_page_token": "next_page_token",
  "total_size": 0
}
```
