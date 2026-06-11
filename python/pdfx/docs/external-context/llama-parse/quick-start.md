---
title: LlamaParse Platform Quickstart | Developer Documentation
description: Install the SDK, get an API key, and run your first call against Parse, Extract, Classify, Split, Sheets, or Index — all from one platform.
---

**Build document agents powered by agentic OCR.**

LlamaParse is the enterprise platform for turning documents into production AI pipelines. One API key, one SDK, and six composable products: **Parse** (agentic OCR), **Extract** (structured data), **Classify**, **Split**, **Sheets**, and **Index**.

Using a coding agent?

Give your AI agent access to these docs: `claude mcp add llama-index-docs --transport http https://developers.llamaindex.ai/mcp` — [More options](/python/shared/mcp/index.md)

## Install

- [Python](#tab-panel-0)
- [TypeScript](#tab-panel-1)

Terminal window

```
pip install llama-cloud>=2.1
```

Terminal window

```
npm install @llamaindex/llama-cloud
```

Set your API key:

Terminal window

```
export LLAMA_CLOUD_API_KEY=llx-...
```

[Get an API key](general/api_key) from the [LlamaCloud dashboard](https://cloud.llamaindex.ai).

---

## Which product do I want?

Map what you’re trying to do to the right product:

| I want to…                                                                                                                                | Use                                      |
| ----------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| Turn PDFs, scans, or images into clean LLM-ready text                                                                                     | **[Parse](parse/)**                      |
| Pull structured JSON out of documents that matches my schema                                                                              | **[Extract](extract/)**                  |
| Route documents into categories with natural-language rules                                                                               | **[Classify](classify/)**                |
| Split concatenated documents into their logical parts                                                                                     | **[Split](split/)**                      |
| Work with spreadsheet-like data and reason over rows                                                                                      | **[Sheets](sheets/)**                    |
| Build a hosted vector search pipeline for RAG                                                                                             | **[Index](cloud-index/getting_started)** |
| New here? Start with **Parse**—it’s the foundation most pipelines build on. Or scroll down for a runnable snippet in every product below. |                                          |

---

## Quick Start

- [Parse](#tab-panel-2)
- [Extract](#tab-panel-3)
- [Classify](#tab-panel-4)
- [Split](#tab-panel-5)
- [Sheets](#tab-panel-6)
- [Index](#tab-panel-7)

Agentic OCR and parsing for 130+ formats. Turn PDFs and scans into LLM-ready text—the foundation for document agents.

Python (python)

Copy as agent context

```
from llama_cloud import LlamaCloud


client = LlamaCloud()  # Uses LLAMA_CLOUD_API_KEY env var


# Upload and parse a document
file = client.files.create(file="document.pdf", purpose="parse")
result = client.parsing.parse(
    file_id=file.id,
    tier="agentic",
    version="latest",
    expand=["markdown"],
)


# Get markdown output
print(result.markdown.pages[0].markdown)
```

Copy as agent context

```
import LlamaCloud from '@llamaindex/llama-cloud';
import fs from 'fs';


const client = new LlamaCloud(); // Uses LLAMA_CLOUD_API_KEY env var


// Upload and parse a document
const file = await client.files.create({
  file: fs.createReadStream('document.pdf'),
  purpose: 'parse',
});
const result = await client.parsing.parse({
  file_id: file.id,
  tier: 'agentic',
  version: 'latest',
  expand: ['markdown']
});


// Get markdown output
console.log(result.markdown.pages[0].markdown);
```

[Full Guide](parse/getting_started/) | [Examples](parse/examples/) | [Tiers & Pricing](parse/guides/tiers/)

Structured data from documents with custom schemas. Feed agents with clean entities, tables, and fields.

Python (python)

Copy as agent context

```
from pydantic import BaseModel, Field
from llama_cloud import LlamaCloud


# Define your schema
class Resume(BaseModel):
    name: str = Field(description="Full name of candidate")
    email: str = Field(description="Email address")
    skills: list[str] = Field(description="Technical skills")


client = LlamaCloud()


# Upload and extract
file = client.files.create(file="resume.pdf", purpose="extract")
job = client.extract.create(
    document_input_value=file.id,
    config={
        "extract_options": {
            "data_schema": Resume.model_json_schema(),
            "tier": "agentic",
        },
    },
)
print(job.extract_result)
```

Copy as agent context

```
import LlamaCloud from '@llamaindex/llama-cloud';
import { z } from 'zod';
import fs from 'fs';


// Define your schema with Zod
const ResumeSchema = z.object({
  name: z.string().describe('Full name of candidate'),
  email: z.string().describe('Email address'),
  skills: z.array(z.string()).describe('Technical skills'),
});


const client = new LlamaCloud();


// Upload and extract
const file = await client.files.create({
  file: fs.createReadStream('resume.pdf'),
  purpose: 'extract',
});
let job = await client.extract.create({
  document_input_value: file.id,
  config: {
    extract_options: {
      data_schema: ResumeSchema,
      tier: 'agentic',
    },
  },
});
console.log(job.extract_result);
```

[Full Guide](extract/sdk/) | [Examples](extract/examples/) | [Schema Design](extract/guides/schema_design/)

Beta

This feature is currently in beta.

Categorize documents with natural-language rules. Pre-processing for extraction, parsing, or indexing.

Python (python)

Copy as agent context

```
from llama_cloud import LlamaCloud


client = LlamaCloud()


# Upload a document
file = client.files.create(file="document.pdf", purpose="classify")


# Classify with natural language rules
result = client.classifier.classify(
    file_ids=[file.id],
    rules=[
        {
            "type": "invoice",
            "description": "Documents with invoice numbers, line items, and totals"
        },
        {
            "type": "receipt",
            "description": "Short POS receipts with merchant and total"
        },
        {
            "type": "contract",
            "description": "Legal agreements with terms and signatures"
        },
    ],
    mode="FAST",  # or "MULTIMODAL" for visual docs
)


for item in result.items:
    print(f"Type: {item.result.type}, Confidence: {item.result.confidence}")
```

Copy as agent context

```
import LlamaCloud from '@llamaindex/llama-cloud';
import fs from 'fs';


const client = new LlamaCloud();


// Upload a document
const file = await client.files.create({
  file: fs.createReadStream('document.pdf'),
  purpose: 'classify',
});


// Classify with natural language rules
const result = await client.classifier.classify({
  file_ids: [file.id],
  rules: [
    {
      type: 'invoice',
      description: 'Documents with invoice numbers, line items, and totals',
    },
    {
      type: 'receipt',
      description: 'Short POS receipts with merchant and total',
    },
    {
      type: 'contract',
      description: 'Legal agreements with terms and signatures',
    },
  ],
  mode: 'FAST', // or 'MULTIMODAL' for visual docs
});


for (const item of result.items) {
  if (item.result) {
    console.log(`Type: ${item.result.type}, Confidence: ${item.result.confidence}`);
  }
}
```

[Full Guide](classify/sdk/) | [Examples](classify/examples/)

Beta

This feature is currently in beta.

Segment concatenated PDFs into logical sections. AI-powered classification to split combined documents.

Python (python)

Copy as agent context

```
from llama_cloud import LlamaCloud


client = LlamaCloud()


# Upload a combined PDF
file = client.files.create(file="combined.pdf", purpose="split")


# Split into logical sections
result = await client.beta.split.split(
    categories=[
        {
            "name": "invoice",
            "description": "Commercial document with line items and totals"
        },
        {
            "name": "contract",
            "description": "Legal agreement with terms and signatures"
        },
    ],
    document_input={"type": "file_id", "value": file.id},
)


for segment in result.result.segments:
    print(f"Pages {segment.pages}: {segment.category} ({segment.confidence_category})")
```

Copy as agent context

```
import LlamaCloud from '@llamaindex/llama-cloud';
import fs from 'fs';


const client = new LlamaCloud();


// Upload a combined PDF
const file = await client.files.create({
  file: fs.createReadStream('combined.pdf'),
  purpose: 'split',
});


// Split into logical sections
const result = await client.beta.split.split({
  categories: [
    {
      name: 'invoice',
      description: 'Commercial document with line items and totals',
    },
    {
      name: 'contract',
      description: 'Legal agreement with terms and signatures',
    },
  ],
  document_input: { type: 'file_id', value: file.id },
});


for (const segment of result.result.segments) {
  console.log(`Pages ${segment.pages}: ${segment.category} (${segment.confidence_category})`);
}
```

[Full Guide](split/getting_started/) | [Examples](split/examples/)

Beta

This feature is currently in beta.

Extract tables and metadata from messy spreadsheets. Output as Parquet files with rich cell metadata.

Python (python)

Copy as agent context

```
from llama_cloud import LlamaCloud


client = LlamaCloud()


# Upload a spreadsheet
file = client.files.create(file="spreadsheet.xlsx", purpose="parse")


# Extract tables and regions
result = client.beta.sheets.parse(
    file_id=file.id,
    configuration={"generate_additional_metadata": True},
)


# Print extracted regions
print(f"Found {len(result.regions)} regions")
for region in result.regions:
    print(f"  - {region.region_id}: {region.title} ({region.location})")
```

Copy as agent context

```
import LlamaCloud from '@llamaindex/llama-cloud';
import fs from 'fs';


const client = new LlamaCloud();


// Upload a spreadsheet
const file = await client.files.create({
  file: fs.createReadStream('spreadsheet.xlsx'),
  purpose: 'parse',
});


// Extract tables and regions
const result = await client.beta.sheets.parse({
  file_id: file.id,
  configuration: { generate_additional_metadata: true },
});


// Print extracted regions
console.log(`Found ${result.regions?.length || 0} regions`);
for (const region of result.regions || []) {
  console.log(`  - ${region.region_id}: ${region.title} (${region.location})`);
}
```

[Full Guide](sheets/) | [Examples](sheets/examples/coding_agent/)

Ingest, chunk, and embed into searchable indexes. Power RAG and retrieval for document agents. Index is designed for UI-first setup with SDK integration. Start in the LlamaCloud dashboard to create your index, then integrate:

Python (python)

Copy as agent context

```
from llama_cloud import LlamaCloud


client = LlamaCloud()  # Uses LLAMA_CLOUD_API_KEY env var


# Retrieve relevant nodes from the index
results = client.pipelines.retrieve(
    pipeline_id="your-pipeline-id",
    query="Your query here",
    # -- Customize search behavior --
    # dense_similarity_top_k=20,
    # sparse_similarity_top_k=20,
    # alpha=0.5,
    # -- Control reranking behavior --
    # enable_reranking=True,
    # rerank_top_n=5,
)


for n in results.retrieval_nodes:
    print(f"Score: {n.score}, Text: {n.node.text}")
```

Copy as agent context

```
import LlamaCloud from '@llamaindex/llama-cloud';


const client = new LlamaCloud(); // Uses LLAMA_CLOUD_API_KEY env var


// Retrieve relevant nodes from the index
const results = await client.pipelines.retrieve('your-pipeline-id', {
  query: 'Your query here',
  // -- Customize search behavior --
  // dense_similarity_top_k: 20,
  // sparse_similarity_top_k: 20,
  // alpha: 0.5,
  // -- Control reranking behavior --
  // enable_reranking: true,
  // rerank_top_n: 5,
});


for (const node of results.retrieval_nodes || []) {
  console.log(`Score: ${node.score}, Text: ${node.node?.text}`);
}
```

[Full Guide](cloud-index/getting_started/) | [Examples](cloud-index/examples/)

---

## LlamaParse Agent Skills

[Download Skills](https://github.com/run-llama/llamaparse-agent-skills/releases/download/latest/skills-latest.zip)

### Available Skills

- **llamaparse**: Advanced parsing for PDFs, docs, presentations and images (charts, tables, embedded visuals). Requires `LLAMA_CLOUD_API_KEY` and Node 18+.
- **liteparse**: Local-first, fast parsing for text-dense PDFs and docs. No API key needed, requires `@llamaindex/liteparse` globally installed and Node 18+.

### Installation

You can install LlamaParse Agent Skills using the [`skills`](https://skills.sh) CLI:

Terminal window

```
npx skills add run-llama/llamaparse-agent-skills
```

Or, if you wish to download only one skill:

Terminal window

```
npx skills add run-llama/llamaparse-agent-skills --skill llamaparse # or the name of another skill
```

You can also download the skills folder in `.zip` format from [GitHub Releases](https://github.com/run-llama/llamaparse-agent-skills/releases/download/latest/skills-latest.zip).

---

## Resources

[Python SDK ](https://github.com/run-llama/llama-cloud-py)pip install llama-cloud

[TypeScript SDK ](https://github.com/run-llama/llama-cloud-ts)npm install @llamaindex/llama-cloud
