# Files

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

## Query Files

**post** `/api/v1/beta/files/query`

Query files with filtering and pagination. Deprecated: use `GET /files`.

### Query Parameters

- `organization_id: optional string`

- `project_id: optional string`

### Cookie Parameters

- `session: optional string`

### Body Parameters

- `filter: optional object { data_source_id, external_file_id, file_ids, 3 more }`

  Filter parameters for file queries.

  - `data_source_id: optional string`

    Filter by data source ID

  - `external_file_id: optional string`

    Filter by external file ID

  - `file_ids: optional array of string`

    Filter by specific file IDs

  - `file_name: optional string`

    Filter by file name

  - `only_manually_uploaded: optional boolean`

    Filter only manually uploaded files (data_source_id is null)

  - `project_id: optional string`

    Filter by project ID

- `order_by: optional string`

  A comma-separated list of fields to order by, sorted in ascending order. Use 'field_name desc' to specify descending order.

- `page_size: optional number`

  The maximum number of items to return. The service may return fewer than this value. If unspecified, a default page size will be used. The maximum value is typically 1000; values above this will be coerced to the maximum.

- `page_token: optional string`

  A page token, received from a previous list call. Provide this to retrieve the subsequent page.

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
curl https://api.cloud.llamaindex.ai/api/v1/beta/files/query \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY" \
    -d '{}'
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

## Domain Types

### File

- `File = object { id, name, project_id, 11 more }`

  Schema for a file.

  - `id: string`

    Unique identifier

  - `name: string`

  - `project_id: string`

    The ID of the project that the file belongs to

  - `created_at: optional string`

    Creation datetime

  - `data_source_id: optional string`

    The ID of the data source that the file belongs to

  - `expires_at: optional string`

    The expiration date for the file. Files past this date can be deleted.

  - `external_file_id: optional string`

    The ID of the file in the external system

  - `file_size: optional number`

    Size of the file in bytes

  - `file_type: optional string`

    File type (e.g. pdf, docx, etc.)

  - `last_modified_at: optional string`

    The last modified time of the file

  - `permission_info: optional map[map[unknown] or array of unknown or string or 2 more]`

    Permission information for the file

    - `map[unknown]`

    - `array of unknown`

    - `string`

    - `number`

    - `boolean`

  - `purpose: optional string`

    The intended purpose of the file (e.g., 'user_data', 'parse', 'extract', 'split', 'classify')

  - `resource_info: optional map[map[unknown] or array of unknown or string or 2 more]`

    Resource information for the file

    - `map[unknown]`

    - `array of unknown`

    - `string`

    - `number`

    - `boolean`

  - `updated_at: optional string`

    Update datetime

### Presigned URL

- `PresignedURL = object { expires_at, url, form_fields }`

  Schema for a presigned URL.

  - `expires_at: string`

    The time at which the presigned URL expires

  - `url: string`

    A presigned URL for IO operations against a private file

  - `form_fields: optional map[string]`

    Form fields for a presigned POST request

### File Create Response

- `FileCreateResponse = object { id, name, project_id, 6 more }`

  An uploaded file.

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

### File Query Response

- `FileQueryResponse = object { items, next_page_token, total_size }`

  Paginated list of files.

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

### File List Response

- `FileListResponse = object { id, name, project_id, 6 more }`

  An uploaded file.

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
