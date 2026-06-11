---
title: Tiers | Developer Documentation
---

**Parse offers four tiers** that trade off cost, latency, and accuracy. You pick a tier on every parse request, plus a `version` so the behavior stays reproducible. This page is the canonical reference for what each tier does, when to pick it, and how the versioning model works.

## Which tier should I pick?

Use this as a starting point. You can always re-parse the same file with a different tier — there’s no setup cost to switching.

| My document looks like…                                                                           | Pick                                                                                                                                                            |
| ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Plain text, single column, no tables — and I just need raw text or layout-preserving spatial text | **[Fast](#fast)**                                                                                                                                               |
| Mostly text with simple tables, need clean markdown, want to keep cost down                       | **[Cost Effective](#cost-effective)**                                                                                                                           |
| Scanned pages, multi-column layouts, real tables, embedded charts                                 | **[Agentic](#agentic)**                                                                                                                                         |
| Dense financial reports, complex tables, charts and diagrams, mission-critical accuracy           | **[Agentic Plus](#agentic-plus)**                                                                                                                               |
| Mixed — most pages are simple but a few are complex                                               | **[Agentic](#agentic)** or **[Agentic Plus](#agentic-plus)** with [Cost Optimizer](/llamaparse/parse/guides/configuring-parse/#cost-optimizer/index.md) enabled |

### Mixed-complexity documents: use Cost Optimizer

If your document has a mix of simple prose pages and a few complex pages with tables or charts, the most cost-effective choice is usually **not** picking a single tier — it’s enabling [**Cost Optimizer**](/llamaparse/parse/guides/configuring-parse/#cost-optimizer/index.md) on top of `agentic` or `agentic_plus`. Cost Optimizer routes each page to the right tier automatically and runs both groups in parallel, so you get premium quality where it matters and `cost_effective` prices on the easy pages — without latency penalty.

## Credit cost per page

Credit costs increase with tier capability — Fast is the cheapest and Agentic Plus is the most expensive. See the [Pricing page](/llamaparse/general/pricing/index.md) for current rates, volume discounts, and pricing for other Parse output options (e.g. layout extraction).

> **Caching is free.** Re-parsing the same file within 48 hours costs zero credits — Parse caches results by default. See [Cache Control](/llamaparse/parse/guides/configuring-parse/#cache-control/index.md) for how to opt out of cache when you need a fresh parse.

## Versioning and reproducibility

Tiers in Parse v2 are **versioned**. When you specify a tier with a specific dated version like `"agentic"` with `version="2026-01-08"`, the parsing behavior is locked: the same model, the same prompts, the same configuration, every time. This is the contract that makes Parse safe to use in production — your output won’t shift under you because we shipped a new model.

Use `"version": "latest"` during development to always get the most recent stable release. **For production, pin a published version date.** Only dates that correspond to an actual release are accepted — arbitrary dates will return a validation error.

```
{
  "tier": "agentic",
  "version": "2026-01-08"
}
```

When a newer version ships, you decide when (and whether) to bump. We don’t break existing pinned versions — they stay available for the foreseeable future, so you can upgrade on your own schedule and roll back if a new version doesn’t suit your workload.

`tier` and `version` are both **required** on every parse request. Forgetting either will return a validation error.

## Available tiers

Each tier is a snapshot of a particular model + prompt + configuration combo. Tiers don’t share models — picking `agentic_plus` doesn’t just turn on extra options on top of `agentic`, it’s a different parsing pipeline.

For complete API request examples, see [Getting Started](/llamaparse/parse/getting_started/index.md) or the [REST API Guide](/llamaparse/parse/guides/api-reference/index.md).

### Agentic Plus

**Best for:** the hardest documents — dense financial reports, scientific papers with equations and figures, complex multi-column layouts, and anything where accuracy is mission-critical.

**Notable defaults:** [Specialized chart parsing](/llamaparse/parse/guides/configuring-parse/#specialized-chart-parsing/index.md) is **on by default** at this tier — no extra configuration needed.

```
{
  "tier": "agentic_plus",
  "version": "latest"
}
```

With explicit version pinning for production:

```
{
  "tier": "agentic_plus",
  "version": "2026-01-08"
}
```

### Agentic

**Best for:** complex but not extreme documents — most real-world PDFs with tables, scanned pages, multi-column layouts, charts and diagrams. This is the default recommendation for most use cases that need high-quality structured output.

Pair with [Cost Optimizer](/llamaparse/parse/guides/configuring-parse/#cost-optimizer/index.md) on long mixed-complexity documents to drop the per-page cost on simple pages.

```
{
  "tier": "agentic",
  "version": "latest"
}
```

### Cost Effective

**Best for:** text-heavy documents with simple tables and minimal visual structure — content where you still want clean markdown and table preservation, but can trade off the deepest layout reasoning for a cheaper run.

```
{
  "tier": "cost_effective",
  "version": "latest"
}
```

### Fast

**Best for:** plain-text documents at high volume where you only need text and layout-preserving spatial text. The fastest tier, with the lowest per-page cost.

**Important limitation:** the `fast` tier **does not support markdown output**. Requesting `expand=["markdown"]` on a fast-tier job returns a validation error. If you need markdown, structured items, or chart data, use [Cost Effective](#cost-effective) or higher. Fast is also the only tier that does not support [`agentic_options`](/llamaparse/parse/guides/configuring-parse/#custom-prompt/index.md) (custom prompts and other agentic-model controls), since it doesn’t run an agentic model.

```
{
  "tier": "fast",
  "version": "latest"
}
```

## Example API request

Here’s a complete request showing the tier + version pattern:

- [Python](#tab-panel-196)
- [TypeScript](#tab-panel-197)
- [cURL](#tab-panel-198)

```
from llama_cloud import LlamaCloud


client = LlamaCloud(api_key="llx-...")


result = client.parsing.parse(
    upload_file="example_file.pdf",
    tier="agentic_plus",
    version="latest"
)
```

```
import fs from "fs";
import { LlamaCloud } from "@llamaindex/llama-cloud";


const client = new LlamaCloud({ apiKey: "llx-..." });


const result = await client.parsing.parse({
  upload_file: fs.createReadStream("example_file.pdf"),
  tier: "agentic_plus",
  version: "latest"
});
```

Terminal window

```
curl -X 'POST' \
  'https://api.cloud.llamaindex.ai/api/v2/parse' \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $LLAMA_CLOUD_API_KEY" \
  --data '{
    "file_id": "<file_id>",
    "tier": "agentic_plus",
    "version": "latest"
  }'
```

## What’s new

Parse uses dated tier versions — a release is typically a new dated version of one of the four tiers. Pinned versions stay available so you can upgrade on your own schedule.

> The Parse team ships new tier versions roughly monthly. **The source of truth for what `"latest"` resolves to is the API itself** — make a parse request with `"version": "latest"` and inspect `metadata.version` on the response.

### Notable feature releases

- **Cost Optimizer** — per-page tier routing on `agentic` or `agentic_plus`. See [Cost Optimizer](/llamaparse/parse/guides/configuring-parse/#cost-optimizer/index.md).
- **Agent Skill** — native document parsing for coding agents. See [Getting Started → Agent Skill](/llamaparse/parse/getting_started/#alternative-use-a-coding-agent/index.md).
- **Chart parsing default-on at Agentic Plus** — `specialized_chart_parsing` is enabled by default on `agentic_plus`. See [Specialized Chart Parsing](/llamaparse/parse/guides/configuring-parse/#specialized-chart-parsing/index.md).
- **v2 API** — replaced v1’s flat 70+ form parameters with structured JSON. `tier` and `version` are now required. See the [REST API Guide](/llamaparse/parse/guides/api-reference/index.md).

## See also

- [Cost Optimizer](/llamaparse/parse/guides/configuring-parse/#cost-optimizer/index.md) — the per-page tier router for mixed-complexity documents
- [Pricing](/llamaparse/general/pricing/index.md) — canonical credit costs and volume discounts
- [Configuring Parse](/llamaparse/parse/guides/configuring-parse/index.md) — where every option lives in the request shape
- [Getting Started](/llamaparse/parse/getting_started/index.md) — install the SDK and run your first parse
- [Specialized Chart Parsing](/llamaparse/parse/guides/configuring-parse/#specialized-chart-parsing/index.md) — default-on with Agentic Plus, opt-in elsewhere
