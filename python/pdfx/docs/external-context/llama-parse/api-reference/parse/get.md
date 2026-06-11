## Get Parse Job

**get** `/api/v2/parse/{job_id}`

Retrieve a parse job with optional expanded content.

By default returns job metadata only. Use `expand` to include
parsed content:

- `text` — plain text output
- `markdown` — markdown output
- `items` — structured page-by-page output
- `job_metadata` — usage and processing details

Content metadata fields (e.g. `text_content_metadata`) return
presigned URLs for downloading large results.

### Path Parameters

- `job_id: string`

### Query Parameters

- `expand: optional array of string`

  Fields to include: text, markdown, items, metadata, job_metadata, text_content_metadata, markdown_content_metadata, items_content_metadata, metadata_content_metadata, raw_words_content_metadata, xlsx_content_metadata, output_pdf_content_metadata, images_content_metadata. Metadata fields include presigned URLs.

- `image_filenames: optional string`

  Filter to specific image filenames (optional). Example: image_0.png,image_1.jpg

- `organization_id: optional string`

- `project_id: optional string`

### Cookie Parameters

- `session: optional string`

### Returns

- `job: object { id, project_id, status, 5 more }`

  Parse job status and metadata

  - `id: string`

    Unique parse job identifier

  - `project_id: string`

    Project this job belongs to

  - `status: "PENDING" or "RUNNING" or "COMPLETED" or 2 more`

    Current job status: PENDING, RUNNING, COMPLETED, FAILED, or CANCELLED

    - `"PENDING"`

    - `"RUNNING"`

    - `"COMPLETED"`

    - `"FAILED"`

    - `"CANCELLED"`

  - `created_at: optional string`

    Creation datetime

  - `error_message: optional string`

    Error details when status is FAILED

  - `name: optional string`

    Optional display name for this parse job

  - `tier: optional string`

    Parsing tier used for this job

  - `updated_at: optional string`

    Update datetime

- `images_content_metadata: optional object { images, total_count }`

  Metadata for all extracted images.

  - `images: array of object { filename, index, bbox, 4 more }`

    List of image metadata with presigned URLs

    - `filename: string`

      Image filename (e.g., 'image_0.png')

    - `index: number`

      Index of the image in the extraction order

    - `bbox: optional object { h, w, x, y }`

      Bounding box for an image on its page.

      - `h: number`

        Height of the bounding box

      - `w: number`

        Width of the bounding box

      - `x: number`

        X coordinate of the bounding box

      - `y: number`

        Y coordinate of the bounding box

    - `category: optional "screenshot" or "embedded" or "layout"`

      Image category: 'screenshot' (full page), 'embedded' (images in document), or 'layout' (cropped from layout detection)

      - `"screenshot"`

      - `"embedded"`

      - `"layout"`

    - `content_type: optional string`

      MIME type of the image

    - `presigned_url: optional string`

      Presigned URL to download the image

    - `size_bytes: optional number`

      Deprecated: always returns None. Will be removed in a future release.

  - `total_count: number`

    Total number of extracted images

- `items: optional object { pages }`

  Structured JSON result (if requested)

  - `pages: array of object { items, page_height, page_number, 2 more }  or object { error, page_number, success }`

    List of structured pages or failed page entries

    - `StructuredResultPage = object { items, page_height, page_number, 2 more }`

      - `items: array of TextItem or HeadingItem or ListItem or 6 more`

        List of structured items on the page

        - `TextItem = object { md, value, bbox, type }`

          - `md: string`

            Markdown representation preserving formatting

          - `value: string`

            Text content

          - `bbox: optional array of BBox`

            List of bounding boxes

            - `h: number`

              Height of the bounding box

            - `w: number`

              Width of the bounding box

            - `x: number`

              X coordinate of the bounding box

            - `y: number`

              Y coordinate of the bounding box

            - `confidence: optional number`

              Confidence score

            - `end_index: optional number`

              End index in the text

            - `label: optional string`

              Label for the bounding box

            - `r: optional number`

              Optional visual text rotation angle in degrees. Omitted when unrotated.

            - `start_index: optional number`

              Start index in the text

          - `type: optional "text"`

            Text item type

            - `"text"`

        - `HeadingItem = object { level, md, value, 2 more }`

          - `level: number`

            Heading level (1-6)

          - `md: string`

            Markdown representation preserving formatting

          - `value: string`

            Heading text content

          - `bbox: optional array of BBox`

            List of bounding boxes

            - `h: number`

              Height of the bounding box

            - `w: number`

              Width of the bounding box

            - `x: number`

              X coordinate of the bounding box

            - `y: number`

              Y coordinate of the bounding box

            - `confidence: optional number`

              Confidence score

            - `end_index: optional number`

              End index in the text

            - `label: optional string`

              Label for the bounding box

            - `r: optional number`

              Optional visual text rotation angle in degrees. Omitted when unrotated.

            - `start_index: optional number`

              Start index in the text

          - `type: optional "heading"`

            Heading item type

            - `"heading"`

        - `ListItem = object { items, md, ordered, 2 more }`

          - `items: array of TextItem or ListItem`

            List of nested text or list items

            - `TextItem = object { md, value, bbox, type }`

            - `ListItem = object { items, md, ordered, 2 more }`

          - `md: string`

            Markdown representation preserving formatting

          - `ordered: boolean`

            Whether the list is ordered or unordered

          - `bbox: optional array of BBox`

            List of bounding boxes

            - `h: number`

              Height of the bounding box

            - `w: number`

              Width of the bounding box

            - `x: number`

              X coordinate of the bounding box

            - `y: number`

              Y coordinate of the bounding box

            - `confidence: optional number`

              Confidence score

            - `end_index: optional number`

              End index in the text

            - `label: optional string`

              Label for the bounding box

            - `r: optional number`

              Optional visual text rotation angle in degrees. Omitted when unrotated.

            - `start_index: optional number`

              Start index in the text

          - `type: optional "list"`

            List item type

            - `"list"`

        - `CodeItem = object { md, value, bbox, 2 more }`

          - `md: string`

            Markdown representation preserving formatting

          - `value: string`

            Code content

          - `bbox: optional array of BBox`

            List of bounding boxes

            - `h: number`

              Height of the bounding box

            - `w: number`

              Width of the bounding box

            - `x: number`

              X coordinate of the bounding box

            - `y: number`

              Y coordinate of the bounding box

            - `confidence: optional number`

              Confidence score

            - `end_index: optional number`

              End index in the text

            - `label: optional string`

              Label for the bounding box

            - `r: optional number`

              Optional visual text rotation angle in degrees. Omitted when unrotated.

            - `start_index: optional number`

              Start index in the text

          - `language: optional string`

            Programming language identifier

          - `type: optional "code"`

            Code block item type

            - `"code"`

        - `TableItem = object { csv, html, md, 6 more }`

          - `csv: string`

            CSV representation of the table

          - `html: string`

            HTML representation of the table

          - `md: string`

            Markdown representation preserving formatting

          - `rows: array of array of string or number`

            Table data as array of arrays (string, number, or null)

            - `string`

            - `number`

          - `bbox: optional array of BBox`

            List of bounding boxes

            - `h: number`

              Height of the bounding box

            - `w: number`

              Width of the bounding box

            - `x: number`

              X coordinate of the bounding box

            - `y: number`

              Y coordinate of the bounding box

            - `confidence: optional number`

              Confidence score

            - `end_index: optional number`

              End index in the text

            - `label: optional string`

              Label for the bounding box

            - `r: optional number`

              Optional visual text rotation angle in degrees. Omitted when unrotated.

            - `start_index: optional number`

              Start index in the text

          - `merged_from_pages: optional array of number`

            List of page numbers with tables that were merged into this table (e.g., [1, 2, 3, 4])

          - `merged_into_page: optional number`

            Populated when merged into another table. Page number where the full merged table begins (used on empty tables).

          - `parse_concerns: optional array of object { details, type }`

            Quality concerns detected during table extraction, indicating the table may have issues

            - `details: string`

              Human-readable details about the concern

            - `type: string`

              Type of parse concern (e.g. header_value_type_mismatch, inconsistent_row_cell_count)

          - `type: optional "table"`

            Table item type

            - `"table"`

        - `ImageItem = object { caption, md, url, 2 more }`

          - `caption: string`

            Image caption

          - `md: string`

            Markdown representation preserving formatting

          - `url: string`

            URL to the image

          - `bbox: optional array of BBox`

            List of bounding boxes

            - `h: number`

              Height of the bounding box

            - `w: number`

              Width of the bounding box

            - `x: number`

              X coordinate of the bounding box

            - `y: number`

              Y coordinate of the bounding box

            - `confidence: optional number`

              Confidence score

            - `end_index: optional number`

              End index in the text

            - `label: optional string`

              Label for the bounding box

            - `r: optional number`

              Optional visual text rotation angle in degrees. Omitted when unrotated.

            - `start_index: optional number`

              Start index in the text

          - `type: optional "image"`

            Image item type

            - `"image"`

        - `LinkItem = object { md, text, url, 2 more }`

          - `md: string`

            Markdown representation preserving formatting

          - `text: string`

            Display text of the link

          - `url: string`

            URL of the link

          - `bbox: optional array of BBox`

            List of bounding boxes

            - `h: number`

              Height of the bounding box

            - `w: number`

              Width of the bounding box

            - `x: number`

              X coordinate of the bounding box

            - `y: number`

              Y coordinate of the bounding box

            - `confidence: optional number`

              Confidence score

            - `end_index: optional number`

              End index in the text

            - `label: optional string`

              Label for the bounding box

            - `r: optional number`

              Optional visual text rotation angle in degrees. Omitted when unrotated.

            - `start_index: optional number`

              Start index in the text

          - `type: optional "link"`

            Link item type

            - `"link"`

        - `HeaderItem = object { items, md, bbox, type }`

          - `items: array of TextItem or HeadingItem or ListItem or 4 more`

            List of items within the header

            - `TextItem = object { md, value, bbox, type }`

            - `HeadingItem = object { level, md, value, 2 more }`

            - `ListItem = object { items, md, ordered, 2 more }`

            - `CodeItem = object { md, value, bbox, 2 more }`

            - `TableItem = object { csv, html, md, 6 more }`

            - `ImageItem = object { caption, md, url, 2 more }`

            - `LinkItem = object { md, text, url, 2 more }`

          - `md: string`

            Markdown representation preserving formatting

          - `bbox: optional array of BBox`

            List of bounding boxes

            - `h: number`

              Height of the bounding box

            - `w: number`

              Width of the bounding box

            - `x: number`

              X coordinate of the bounding box

            - `y: number`

              Y coordinate of the bounding box

            - `confidence: optional number`

              Confidence score

            - `end_index: optional number`

              End index in the text

            - `label: optional string`

              Label for the bounding box

            - `r: optional number`

              Optional visual text rotation angle in degrees. Omitted when unrotated.

            - `start_index: optional number`

              Start index in the text

          - `type: optional "header"`

            Page header container

            - `"header"`

        - `FooterItem = object { items, md, bbox, type }`

          - `items: array of TextItem or HeadingItem or ListItem or 4 more`

            List of items within the footer

            - `TextItem = object { md, value, bbox, type }`

            - `HeadingItem = object { level, md, value, 2 more }`

            - `ListItem = object { items, md, ordered, 2 more }`

            - `CodeItem = object { md, value, bbox, 2 more }`

            - `TableItem = object { csv, html, md, 6 more }`

            - `ImageItem = object { caption, md, url, 2 more }`

            - `LinkItem = object { md, text, url, 2 more }`

          - `md: string`

            Markdown representation preserving formatting

          - `bbox: optional array of BBox`

            List of bounding boxes

            - `h: number`

              Height of the bounding box

            - `w: number`

              Width of the bounding box

            - `x: number`

              X coordinate of the bounding box

            - `y: number`

              Y coordinate of the bounding box

            - `confidence: optional number`

              Confidence score

            - `end_index: optional number`

              End index in the text

            - `label: optional string`

              Label for the bounding box

            - `r: optional number`

              Optional visual text rotation angle in degrees. Omitted when unrotated.

            - `start_index: optional number`

              Start index in the text

          - `type: optional "footer"`

            Page footer container

            - `"footer"`

      - `page_height: number`

        Height of the page in points

      - `page_number: number`

        Page number of the document

      - `page_width: number`

        Width of the page in points

      - `success: true`

        Success indicator

        - `true`

    - `FailedStructuredPage = object { error, page_number, success }`

      - `error: string`

        Error message describing the failure

      - `page_number: number`

        Page number of the document

      - `success: false`

        Failure indicator

        - `false`

- `job_metadata: optional map[unknown]`

  Job execution metadata (if requested)

- `markdown: optional object { pages }`

  Markdown result (if requested)

  - `pages: array of object { markdown, page_number, success, 2 more }  or object { error, page_number, success }`

    List of markdown pages or failed page entries

    - `MarkdownResultPage = object { markdown, page_number, success, 2 more }`

      - `markdown: string`

        Markdown content of the page

      - `page_number: number`

        Page number of the document

      - `success: true`

        Success indicator

        - `true`

      - `footer: optional string`

        Footer of the page in markdown

      - `header: optional string`

        Header of the page in markdown

    - `FailedMarkdownPage = object { error, page_number, success }`

      - `error: string`

        Error message describing the failure

      - `page_number: number`

        Page number of the document

      - `success: false`

        Failure indicator

        - `false`

- `markdown_full: optional string`

  Full raw markdown content (if requested)

- `metadata: optional object { pages }`

  Result containing metadata (page level and general) for the parsed document.

  - `pages: array of object { page_number, confidence, cost_optimized, 5 more }`

    List of page metadata entries

    - `page_number: number`

      Page number of the document

    - `confidence: optional number`

      Confidence score for the page parsing (0-1)

    - `cost_optimized: optional boolean`

      Whether cost-optimized parsing was used for the page

    - `original_orientation_angle: optional number`

      Original orientation angle of the page in degrees

    - `printed_page_number: optional string`

      Printed page number as it appears in the document

    - `slide_section_name: optional string`

      Section name from presentation slides

    - `speaker_notes: optional string`

      Speaker notes from presentation slides

    - `triggered_auto_mode: optional boolean`

      Whether auto mode was triggered for the page

- `raw_parameters: optional map[unknown]`

- `result_content_metadata: optional map[object { size_bytes, exists, presigned_url } ]`

  Metadata including size, existence, and presigned URLs for result files

  - `size_bytes: number`

    Size of the result file in bytes

  - `exists: optional boolean`

    Whether the result file exists in S3

  - `presigned_url: optional string`

    Presigned URL to download the result file

- `text: optional object { pages }`

  Plain text result (if requested)

  - `pages: array of object { page_number, text }`

    List of text pages

    - `page_number: number`

      Page number of the document

    - `text: string`

      Plain text content of the page

- `text_full: optional string`

  Full raw text content (if requested)

### Example

```http
curl https://api.cloud.llamaindex.ai/api/v2/parse/$JOB_ID \
    -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY"
```

#### Response

```json
{
  "job": {
    "id": "pjb-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    "project_id": "prj-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    "status": "PENDING",
    "created_at": "2019-12-27T18:11:19.117Z",
    "error_message": "error_message",
    "name": "Q4 Financial Report",
    "tier": "fast",
    "updated_at": "2019-12-27T18:11:19.117Z"
  },
  "images_content_metadata": {
    "images": [
      {
        "filename": "filename",
        "index": 0,
        "bbox": {
          "h": 0,
          "w": 0,
          "x": 0,
          "y": 0
        },
        "category": "screenshot",
        "content_type": "content_type",
        "presigned_url": "presigned_url",
        "size_bytes": 0
      }
    ],
    "total_count": 0
  },
  "items": {
    "pages": [
      {
        "items": [
          {
            "md": "md",
            "value": "value",
            "bbox": [
              {
                "h": 0,
                "w": 0,
                "x": 0,
                "y": 0,
                "confidence": 0,
                "end_index": 0,
                "label": "label",
                "r": 0,
                "start_index": 0
              }
            ],
            "type": "text"
          }
        ],
        "page_height": 0,
        "page_number": 0,
        "page_width": 0,
        "success": true
      }
    ]
  },
  "job_metadata": {
    "foo": "bar"
  },
  "markdown": {
    "pages": [
      {
        "markdown": "markdown",
        "page_number": 0,
        "success": true,
        "footer": "footer",
        "header": "header"
      }
    ]
  },
  "markdown_full": "markdown_full",
  "metadata": {
    "pages": [
      {
        "page_number": 0,
        "confidence": 0,
        "cost_optimized": true,
        "original_orientation_angle": 0,
        "printed_page_number": "printed_page_number",
        "slide_section_name": "slide_section_name",
        "speaker_notes": "speaker_notes",
        "triggered_auto_mode": true
      }
    ]
  },
  "raw_parameters": {
    "foo": "bar"
  },
  "result_content_metadata": {
    "foo": {
      "size_bytes": 0,
      "exists": true,
      "presigned_url": "presigned_url"
    }
  },
  "text": {
    "pages": [
      {
        "page_number": 0,
        "text": "text"
      }
    ]
  },
  "text_full": "text_full"
}
```
