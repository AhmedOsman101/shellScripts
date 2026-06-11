# Projects

## List Projects

**get** `/api/v1/projects`

List projects or get one by name

### Query Parameters

- `organization_id: optional string`

- `project_name: optional string`

### Cookie Parameters

- `session: optional string`

### Returns

- `id: string`

  Unique identifier

- `name: string`

- `organization_id: string`

  The Organization ID the project is under.

- `created_at: optional string`

  Creation datetime

- `is_default: optional boolean`

  Whether this project is the default project for the user.

- `updated_at: optional string`

  Update datetime

### Example

```http
curl https://api.cloud.llamaindex.ai/api/v1/projects \
    -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY"
```

#### Response

```json
[
  {
    "id": "182bd5e5-6e1a-4fe4-a799-aa6d9a6ab26e",
    "name": "x",
    "organization_id": "182bd5e5-6e1a-4fe4-a799-aa6d9a6ab26e",
    "created_at": "2019-12-27T18:11:19.117Z",
    "is_default": true,
    "updated_at": "2019-12-27T18:11:19.117Z"
  }
]
```

## Get Project

**get** `/api/v1/projects/{project_id}`

Get a project by ID.

### Path Parameters

- `project_id: string`

### Query Parameters

- `organization_id: optional string`

### Cookie Parameters

- `session: optional string`

### Returns

- `Project = object { id, name, organization_id, 3 more }`

  Schema for a project.

  - `id: string`

    Unique identifier

  - `name: string`

  - `organization_id: string`

    The Organization ID the project is under.

  - `created_at: optional string`

    Creation datetime

  - `is_default: optional boolean`

    Whether this project is the default project for the user.

  - `updated_at: optional string`

    Update datetime

### Example

```http
curl https://api.cloud.llamaindex.ai/api/v1/projects/$PROJECT_ID \
    -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY"
```

#### Response

```json
{
  "id": "182bd5e5-6e1a-4fe4-a799-aa6d9a6ab26e",
  "name": "x",
  "organization_id": "182bd5e5-6e1a-4fe4-a799-aa6d9a6ab26e",
  "created_at": "2019-12-27T18:11:19.117Z",
  "is_default": true,
  "updated_at": "2019-12-27T18:11:19.117Z"
}
```

## Domain Types

### Project

- `Project = object { id, name, organization_id, 3 more }`

  Schema for a project.

  - `id: string`

    Unique identifier

  - `name: string`

  - `organization_id: string`

    The Organization ID the project is under.

  - `created_at: optional string`

    Creation datetime

  - `is_default: optional boolean`

    Whether this project is the default project for the user.

  - `updated_at: optional string`

    Update datetime

### Project List Response

- `ProjectListResponse = array of Project`

  - `id: string`

    Unique identifier

  - `name: string`

  - `organization_id: string`

    The Organization ID the project is under.

  - `created_at: optional string`

    Creation datetime

  - `is_default: optional boolean`

    Whether this project is the default project for the user.

  - `updated_at: optional string`

    Update datetime
