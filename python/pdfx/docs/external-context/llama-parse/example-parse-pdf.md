---
title: Quick Start: Parse a PDF & Interpret Outputs | Developer Documentation
---

Use Parse to process a single PDF and interpret the most common output views: **text**, **markdown**, **items**, and **metadata**. In this example, we’re using the [2024 Executive Summary by the Bureau of the Fiscal Service](https://fiscal.treasury.gov/files/reports-statements/financial-report/2024/executive-summary-2024.pdf)

## 1. Setup & Connect to Parse

First, install the Python SDK and set your API key:

Terminal window

```
pip install llama-cloud>=1.0
```

```
import os
from getpass import getpass


os.environ["LLAMA_CLOUD_API_KEY"] = getpass("Llama Cloud API Key: ")
```

Next, we need to initialize a client. Here, we use the `AsyncLlamaCloud` client.

```
from llama_cloud import AsyncLlamaCloud


client = AsyncLlamaCloud()
```

## 2. Upload and Parse a PDF

Before we parse, we connect once to Parse with a client and choose a **tier**. Tiers control the quality/latency/cost trade-off of Parse:

- “fast” - the fastest tier with basic parsing capabilities.
- “cost\_effective” – lower cost and latency for simpler documents.
- “agentic” – default tier for most use cases.
- “agentic\_plus” – highest fidelity for very complex layouts.

Next we upload the PDF and parse it.\
The `expand` parameter tells Parse which output views to return **inline** with the job result. In this example we ask for:

- “text” – plain text per page
- “markdown” – markdown view
- “items” – structured layout tree
- “metadata” – page/job metadata (including confidence)

```
# 1) Upload the file
file_obj = await client.files.create(
    file="executive-summary-2024.pdf",  # use /content/executive-summary-2024.pdf if you are using Colab
    purpose="parse",
)


# 2) Create a parse job (Agentic tier, latest version)
result = await client.parsing.parse(
    file_id=file_obj.id,
    tier="agentic",
    version="latest",
    expand=["markdown", "text", "metadata", "items"],
)
```

The `result` object now contains multiple views of the same parsed document.

### Choosing `expand` outputs

You can request one or many `expand` values at once. More expand options mean a larger response and slightly higher latency, so in production you can request only what your pipeline needs (for example, “text” + “metadata or “markdown” only).

## 3. Interpreting the Outputs

### Text view (`result.text`)

The **text** view gives you clean, flattened text per page – good for basic search or feeding into downstream retrieval.

```
first_page_text = result.text.pages[0].text
print(first_page_text)
```

You’ll see the plain text from the first page:

```
1                  EXECUTIVE SUMMARY TO THE FY 2024 FINANCIAL REPORT OF THE U.S. GOVERNMENT


                                            NATION BY THE NUMBERS
                                                A Snapshot of
                               The Government's Financial Position & Condition             2023*
                                                                            2024
                                  Financial Measures (Dollars in Billions):
     Net Cost:
      Gross Costs                                                $          (7,772.2) $            (7,661.7)
      Less: Earned Revenue                                                  652.9 $                539.5
      Gain/(Loss) from Changes in Assumptions                    $          (283.6) $                (760.6)
     Total Net Cost                                              $          (7,402.9)              (7,882.8)
                                                                 $          4,977.9 $
     Less: Total Tax and Other Unearned Revenues                                      $     4,465.6
     Net Operating Cost                                          $          (2,425.0) $     (3,417.2)
     Budget Deficit                                              $          (1,832.8) $     (1,695.2)
     Assets, comprised of:                                      20          1,177.7                922.2
      Cash and Other Monetary Assets                                                 $
      Inventory and Related Property, Net                                   447.3 $                423.0
      Loans Receivable, Net                                      1,751.0 $                   1,695.1
      Property, Plant, and Equipment, Net                        1,313.0 $                   1,235.0
      Other                                                                 973.1     $      1,143.8
     Total Assets                                                $            5,662.1 $      5,419.1
     Less: Liabilities, comprised of:                                       (28,338.9) $     (26,347.7)
      Federal Debt and Interest Payable                          $
      Federal Employee and Veteran Benefits Payable             $ (15,033.4)$                     (14,347.6)
      Other                                                      $          (2,173.6)              (2,203.0)
                                                                                     $
     Total Liabilities                                           $ (45,545.9)$                    (42,898.3)
     Net Position                                                $         (39,883.8) $      (37,479.2)
                               Sustainability Measures (Dollars in Trillions):               (78.4)
     Social Insurance Net Expenditures                           $             (78.3) $
     Total Federal Non-Interest Net Expenditures                 $             (72.7) $      (73.2)
                                   Sustainability Measures as Percent GDP:                   (4.4%)
     Social Insurance Net Expenditures2                            (4.2%)
     Total Federal Non-Interest Net Expenditures                   (3.6%)                    (3.8%)
     Fiscal Gap3                                                   (4.3%)                    (4.5%)


      The government's net position is calculated in accordance with federal accounting standards. Per
      these standards, net position does not include the financial value of the government's sovereign power
      to tax, regulate commerce, or set monetary policy, or the value of nonoperational resources, such as
      national and natural resources, for which the government is a steward.
      Pursuant to federal accounting standards, for SOsl reporting, the federal government's social
      insurance programs include Social Security; Medicare Parts A, B, and D; DOL's Black Lung program;
      and the RRB.
      To prevent the debt-to-GDP ratio from rising over the next 75 years, a combination of non-interest
      spending reductions and receipts increases that amount to 4.3 percent of GDP on average is needed
      (4.5 percent of GDP on average in FY 2023). See Financial Statement Note 24.
      Change in presentation (see Financial Statement Note 1.W).
```

### Markdown view (`result.markdown`)

The **markdown** view preserves structure such as headings, lists, and tables. This is the most LLM-friendly representation in many RAG pipelines.

```
first_page_markdown = result.markdown.pages[0].markdown
print(first_page_markdown)
```

You’ll see content similar to the original document, but expressed as markdown (e.g. `# Headings`, bullet lists, and pipe tables).

```
# NATION BY THE NUMBERS
## A Snapshot of The Government's Financial Position & Condition


<table>
  <thead>
    <tr>
        <th colspan="3">Financial Measures (Dollars in Billions):</th>
    </tr>
    <tr>
        <th></th>
        <th>2024</th>
        <th>2023*</th>
    </tr>
  </thead>
  <tbody>
    <tr>
        <td>Net Cost:</td>
        <td></td>
        <td></td>
    </tr>
    <tr>
        <td>Gross Costs</td>
        <td>$ (7,772.2)</td>
        <td>$ (7,661.7)</td>
    </tr>
    <tr>
        <td>Less: Earned Revenue</td>
        <td>$ 652.9</td>
        <td>$ 539.5</td>
    </tr>
    <tr>
        <td>Gain/(Loss) from Changes in Assumptions</td>
        <td>$ (283.6)</td>
        <td>$ (760.6)</td>
    </tr>
    <tr>
        <td>Total Net Cost</td>
        <td>$ (7,402.9)</td>
        <td>$ (7,882.8)</td>
    </tr>
    <tr>
        <td>Less: Total Tax and Other Unearned Revenues</td>
        <td>$ 4,977.9</td>
        <td>$ 4,465.6</td>
    </tr>
    <tr>
        <td>Net Operating Cost</td>
        <td>$ (2,425.0)</td>
        <td>$ (3,417.2)</td>
    </tr>
    <tr>
        <td>Budget Deficit</td>
        <td>$ (1,832.8)</td>
        <td>$ (1,695.2)</td>
    </tr>
    <tr>
        <td>Assets, comprised of:</td>
        <td></td>
        <td></td>
    </tr>
    <tr>
        <td>Cash and Other Monetary Assets</td>
        <td>$ 1,177.7</td>
        <td>$ 922.2</td>
    </tr>
    <tr>
        <td>Inventory and Related Property, Net</td>
        <td>$ 447.3</td>
        <td>$ 423.0</td>
    </tr>
    <tr>
        <td>Loans Receivable, Net</td>
        <td>$ 1,751.0</td>
        <td>$ 1,695.1</td>
    </tr>
    <tr>
        <td>Property, Plant, and Equipment, Net</td>
        <td>$ 1,313.0</td>
        <td>$ 1,235.0</td>
    </tr>
    <tr>
        <td>Other</td>
        <td>$ 973.1</td>
        <td>$ 1,143.8</td>
    </tr>
    <tr>
        <td>Total Assets</td>
        <td>$ 5,662.1</td>
        <td>$ 5,419.1</td>
    </tr>
    <tr>
        <td>Less: Liabilities, comprised of:</td>
        <td></td>
        <td></td>
    </tr>
    <tr>
        <td>Federal Debt and Interest Payable</td>
        <td>$ (28,338.9)</td>
        <td>$ (26,347.7)</td>
    </tr>
    <tr>
        <td>Federal Employee and Veteran Benefits Payable</td>
        <td>$ (15,033.4)</td>
        <td>$ (14,347.6)</td>
    </tr>
    <tr>
        <td>Other</td>
        <td>$ (2,173.6)</td>
        <td>$ (2,203.0)</td>
    </tr>
    <tr>
        <td>Total Liabilities</td>
        <td>$ (45,545.9)</td>
        <td>$ (42,898.3)</td>
    </tr>
    <tr>
        <td>Net Position¹</td>
        <td>$ (39,883.8)</td>
        <td>$ (37,479.2)</td>
    </tr>
    <tr>
        <td colspan="3">Sustainability Measures (Dollars in Trillions):</td>
    </tr>
    <tr>
        <td>Social Insurance Net Expenditures</td>
        <td>$ (78.3)</td>
        <td>$ (78.4)</td>
    </tr>
    <tr>
        <td>Total Federal Non-Interest Net Expenditures</td>
        <td>$ (72.7)</td>
        <td>$ (73.2)</td>
    </tr>
    <tr>
        <td colspan="3">Sustainability Measures as Percent GDP:</td>
    </tr>
    <tr>
        <td>Social Insurance Net Expenditures²</td>
        <td>(4.2%)</td>
        <td>(4.4%)</td>
    </tr>
    <tr>
        <td>Total Federal Non-Interest Net Expenditures</td>
        <td>(3.6%)</td>
        <td>(3.8%)</td>
    </tr>
    <tr>
        <td>Fiscal Gap³</td>
        <td>(4.3%)</td>
        <td>(4.5%)</td>
    </tr>
  </tbody>
</table>


> ¹ The government's net position is calculated in accordance with federal accounting standards. Per these standards, net position does not include the financial value of the government's sovereign power to tax, regulate commerce, or set monetary policy, or the value of nonoperational resources, such as national and natural resources, for which the government is a steward.
>
> ² Pursuant to federal accounting standards, for SOSI reporting, the federal government's social insurance programs include Social Security; Medicare Parts A, B, and D; DOL's Black Lung program; and the RRB.
>
> ³ To prevent the debt-to-GDP ratio from rising over the next 75 years, a combination of non-interest spending reductions and receipts increases that amount to 4.3 percent of GDP on average is needed (4.5 percent of GDP on average in FY 2023). See Financial Statement Note 24.
>
> \* Change in presentation (see Financial Statement Note 1.W).
```

### Items view (`result.items`)

The **items** view is a structured tree of elements on each page: paragraphs, tables, figures, etc. Use this when you need fine-grained layout-aware processing.

```
first_page_items = result.items.pages[0].items


for item in first_page_items[:5]:
    print(item.type, item)
```

Typical `item.type` values include `header`, `text`, `table`, and `figure`. Tables carry row data; figures can reference images or charts.

```
header HeaderItem(items=[TextItem(md='1 EXECUTIVE SUMMARY TO THE FY 2024 FINANCIAL REPORT OF THE U.S. GOVERNMENT', value='1 EXECUTIVE SUMMARY TO THE FY 2024 FINANCIAL REPORT OF THE U.S. GOVERNMENT', bbox=[BBox(h=8.0, w=384.0, x=113.0, y=37.0, confidence=0.95, end_index=73, label='header', start_index=0)], type='text')], md='1 EXECUTIVE SUMMARY TO THE FY 2024 FINANCIAL REPORT OF THE U.S. GOVERNMENT', bbox=[BBox(h=8.0, w=384.0, x=113.0, y=37.0, confidence=None, end_index=None, label=None, start_index=None)], type='header')
heading HeadingItem(level=1, md='# NATION BY THE NUMBERS', value='NATION BY THE NUMBERS', bbox=[BBox(h=10.0, w=145.0, x=233.0, y=72.0, confidence=0.8, end_index=20, label='paragraph_title', start_index=0)], type='heading')
heading HeadingItem(level=2, md="## A Snapshot of The Government's Financial Position & Condition", value="A Snapshot of The Government's Financial Position & Condition", bbox=[BBox(h=26.24, w=260.93, x=175.78, y=85.1, confidence=0.4, end_index=60, label='heading', start_index=0)], type='heading')
table TableItem(csv='"Financial Measures (Dollars in Billions):","Financial Measures (Dollars in Billions):<br/>2024","Financial Measures (Dollars in Billions):<br/>2023*"\n"Net Cost:",,\n"Gross Costs","$ (7,772.2)","$ (7,661.7)"\n"Less: Earned Revenue","$ 652.9","$ 539.5"\n"Gain/(Loss) from Changes in Assumptions","$ (283.6)","$ (760.6)"\n"Total Net Cost","$ (7,402.9)","$ (7,882.8)"\n"Less: Total Tax and Other Unearned Revenues","$ 4,977.9","$ 4,465.6"\n"Net Operating Cost","$ (2,425.0)","$ (3,417.2)"\n"Budget Deficit","$ (1,832.8)","$ (1,695.2)"\n"Assets, comprised of:",,\n"Cash and Other Monetary Assets","$ 1,177.7","$ 922.2"\n"Inventory and Related Property, Net","$ 447.3","$ 423.0"\n"Loans Receivable, Net","$ 1,751.0","$ 1,695.1"\n"Property, Plant, and Equipment, Net","$ 1,313.0","$ 1,235.0"\n"Other","$ 973.1","$ 1,143.8"\n"Total Assets","$ 5,662.1","$ 5,419.1"\n"Less: Liabilities, comprised of:",,\n"Federal Debt and Interest Payable","$ (28,338.9)","$ (26,347.7)"\n"Federal Employee and Veteran Benefits Payable","$ (15,033.4)","$ (14,347.6)"\n"Other","$ (2,173.6)","$ (2,203.0)"\n"Total Liabilities","$ (45,545.9)","$ (42,898.3)"\n"Net Position¹","$ (39,883.8)","$ (37,479.2)"\n"Sustainability Measures (Dollars in Trillions):",,\n"Social Insurance Net Expenditures","$ (78.3)","$ (78.4)"\n"Total Federal Non-Interest Net Expenditures","$ (72.7)","$ (73.2)"\n"Sustainability Measures as Percent GDP:",,\n"Social Insurance Net Expenditures²","(4.2%)","(4.4%)"\n"Total Federal Non-Interest Net Expenditures","(3.6%)","(3.8%)"\n"Fiscal Gap³","(4.3%)","(4.5%)"', html='<table>\n  <thead>\n    <tr>\n        <th colspan="3">Financial Measures (Dollars in Billions):</th>\n    </tr>\n    <tr>\n        <th></th>\n        <th>2024</th>\n        <th>2023*</th>\n    </tr>\n  </thead>\n  <tbody>\n    <tr>\n        <td>Net Cost:</td>\n        <td></td>\n        <td></td>\n    </tr>\n    <tr>\n        <td>Gross Costs</td>\n        <td>$ (7,772.2)</td>\n        <td>$ (7,661.7)</td>\n    </tr>\n    <tr>\n        <td>Less: Earned Revenue</td>\n        <td>$ 652.9</td>\n        <td>$ 539.5</td>\n    </tr>\n    <tr>\n        <td>Gain/(Loss) from Changes in Assumptions</td>\n        <td>$ (283.6)</td>\n        <td>$ (760.6)</td>\n    </tr>\n    <tr>\n        <td>Total Net Cost</td>\n        <td>$ (7,402.9)</td>\n        <td>$ (7,882.8)</td>\n    </tr>\n    <tr>\n        <td>Less: Total Tax and Other Unearned Revenues</td>\n        <td>$ 4,977.9</td>\n        <td>$ 4,465.6</td>\n    </tr>\n    <tr>\n        <td>Net Operating Cost</td>\n        <td>$ (2,425.0)</td>\n        <td>$ (3,417.2)</td>\n    </tr>\n    <tr>\n        <td>Budget Deficit</td>\n        <td>$ (1,832.8)</td>\n        <td>$ (1,695.2)</td>\n    </tr>\n    <tr>\n        <td>Assets, comprised of:</td>\n        <td></td>\n        <td></td>\n    </tr>\n    <tr>\n        <td>Cash and Other Monetary Assets</td>\n        <td>$ 1,177.7</td>\n        <td>$ 922.2</td>\n    </tr>\n    <tr>\n        <td>Inventory and Related Property, Net</td>\n        <td>$ 447.3</td>\n        <td>$ 423.0</td>\n    </tr>\n    <tr>\n        <td>Loans Receivable, Net</td>\n        <td>$ 1,751.0</td>\n        <td>$ 1,695.1</td>\n    </tr>\n    <tr>\n        <td>Property, Plant, and Equipment, Net</td>\n        <td>$ 1,313.0</td>\n        <td>$ 1,235.0</td>\n    </tr>\n    <tr>\n        <td>Other</td>\n        <td>$ 973.1</td>\n        <td>$ 1,143.8</td>\n    </tr>\n    <tr>\n        <td>Total Assets</td>\n        <td>$ 5,662.1</td>\n        <td>$ 5,419.1</td>\n    </tr>\n    <tr>\n        <td>Less: Liabilities, comprised of:</td>\n        <td></td>\n        <td></td>\n    </tr>\n    <tr>\n        <td>Federal Debt and Interest Payable</td>\n        <td>$ (28,338.9)</td>\n        <td>$ (26,347.7)</td>\n    </tr>\n    <tr>\n        <td>Federal Employee and Veteran Benefits Payable</td>\n        <td>$ (15,033.4)</td>\n        <td>$ (14,347.6)</td>\n    </tr>\n    <tr>\n        <td>Other</td>\n        <td>$ (2,173.6)</td>\n        <td>$ (2,203.0)</td>\n    </tr>\n    <tr>\n        <td>Total Liabilities</td>\n        <td>$ (45,545.9)</td>\n        <td>$ (42,898.3)</td>\n    </tr>\n    <tr>\n        <td>Net Position¹</td>\n        <td>$ (39,883.8)</td>\n        <td>$ (37,479.2)</td>\n    </tr>\n    <tr>\n        <td colspan="3">Sustainability Measures (Dollars in Trillions):</td>\n    </tr>\n    <tr>\n        <td>Social Insurance Net Expenditures</td>\n        <td>$ (78.3)</td>\n        <td>$ (78.4)</td>\n    </tr>\n    <tr>\n        <td>Total Federal Non-Interest Net Expenditures</td>\n        <td>$ (72.7)</td>\n        <td>$ (73.2)</td>\n    </tr>\n    <tr>\n        <td colspan="3">Sustainability Measures as Percent GDP:</td>\n    </tr>\n    <tr>\n        <td>Social Insurance Net Expenditures²</td>\n        <td>(4.2%)</td>\n        <td>(4.4%)</td>\n    </tr>\n    <tr>\n        <td>Total Federal Non-Interest Net Expenditures</td>\n        <td>(3.6%)</td>\n        <td>(3.8%)</td>\n    </tr>\n    <tr>\n        <td>Fiscal Gap³</td>\n        <td>(4.3%)</td>\n        <td>(4.5%)</td>\n    </tr>\n  </tbody>\n</table>', md='| Financial Measures (Dollars in Billions):       | Financial Measures (Dollars in Billions):<br/>2024 | Financial Measures (Dollars in Billions):<br/>2023\\* |\n| ----------------------------------------------- | -------------------------------------------------- | ---------------------------------------------------- |\n| Net Cost:                                       |                                                    |                                                      |\n| Gross Costs                                     | $ (7,772.2)                                        | $ (7,661.7)                                          |\n| Less: Earned Revenue                            | $ 652.9                                            | $ 539.5                                              |\n| Gain/(Loss) from Changes in Assumptions         | $ (283.6)                                          | $ (760.6)                                            |\n| Total Net Cost                                  | $ (7,402.9)                                        | $ (7,882.8)                                          |\n| Less: Total Tax and Other Unearned Revenues     | $ 4,977.9                                          | $ 4,465.6                                            |\n| Net Operating Cost                              | $ (2,425.0)                                        | $ (3,417.2)                                          |\n| Budget Deficit                                  | $ (1,832.8)                                        | $ (1,695.2)                                          |\n| Assets, comprised of:                           |                                                    |                                                      |\n| Cash and Other Monetary Assets                  | $ 1,177.7                                          | $ 922.2                                              |\n| Inventory and Related Property, Net             | $ 447.3                                            | $ 423.0                                              |\n| Loans Receivable, Net                           | $ 1,751.0                                          | $ 1,695.1                                            |\n| Property, Plant, and Equipment, Net             | $ 1,313.0                                          | $ 1,235.0                                            |\n| Other                                           | $ 973.1                                            | $ 1,143.8                                            |\n| Total Assets                                    | $ 5,662.1                                          | $ 5,419.1                                            |\n| Less: Liabilities, comprised of:                |                                                    |                                                      |\n| Federal Debt and Interest Payable               | $ (28,338.9)                                       | $ (26,347.7)                                         |\n| Federal Employee and Veteran Benefits Payable   | $ (15,033.4)                                       | $ (14,347.6)                                         |\n| Other                                           | $ (2,173.6)                                        | $ (2,203.0)                                          |\n| Total Liabilities                               | $ (45,545.9)                                       | $ (42,898.3)                                         |\n| Net Position¹                                   | $ (39,883.8)                                       | $ (37,479.2)                                         |\n| Sustainability Measures (Dollars in Trillions): |                                                    |                                                      |\n| Social Insurance Net Expenditures               | $ (78.3)                                           | $ (78.4)                                             |\n| Total Federal Non-Interest Net Expenditures     | $ (72.7)                                           | $ (73.2)                                             |\n| Sustainability Measures as Percent GDP:         |                                                    |                                                      |\n| Social Insurance Net Expenditures²              | (4.2%)                                             | (4.4%)                                               |\n| Total Federal Non-Interest Net Expenditures     | (3.6%)                                             | (3.8%)                                               |\n| Fiscal Gap³                                     | (4.3%)                                             | (4.5%)                                               |', rows=[['Financial Measures (Dollars in Billions):', 'Financial Measures (Dollars in Billions):<br/>2024', 'Financial Measures (Dollars in Billions):<br/>2023*'], ['Net Cost:', '', ''], ['Gross Costs', '$ (7,772.2)', '$ (7,661.7)'], ['Less: Earned Revenue', '$ 652.9', '$ 539.5'], ['Gain/(Loss) from Changes in Assumptions', '$ (283.6)', '$ (760.6)'], ['Total Net Cost', '$ (7,402.9)', '$ (7,882.8)'], ['Less: Total Tax and Other Unearned Revenues', '$ 4,977.9', '$ 4,465.6'], ['Net Operating Cost', '$ (2,425.0)', '$ (3,417.2)'], ['Budget Deficit', '$ (1,832.8)', '$ (1,695.2)'], ['Assets, comprised of:', '', ''], ['Cash and Other Monetary Assets', '$ 1,177.7', '$ 922.2'], ['Inventory and Related Property, Net', '$ 447.3', '$ 423.0'], ['Loans Receivable, Net', '$ 1,751.0', '$ 1,695.1'], ['Property, Plant, and Equipment, Net', '$ 1,313.0', '$ 1,235.0'], ['Other', '$ 973.1', '$ 1,143.8'], ['Total Assets', '$ 5,662.1', '$ 5,419.1'], ['Less: Liabilities, comprised of:', '', ''], ['Federal Debt and Interest Payable', '$ (28,338.9)', '$ (26,347.7)'], ['Federal Employee and Veteran Benefits Payable', '$ (15,033.4)', '$ (14,347.6)'], ['Other', '$ (2,173.6)', '$ (2,203.0)'], ['Total Liabilities', '$ (45,545.9)', '$ (42,898.3)'], ['Net Position¹', '$ (39,883.8)', '$ (37,479.2)'], ['Sustainability Measures (Dollars in Trillions):', '', ''], ['Social Insurance Net Expenditures', '$ (78.3)', '$ (78.4)'], ['Total Federal Non-Interest Net Expenditures', '$ (72.7)', '$ (73.2)'], ['Sustainability Measures as Percent GDP:', '', ''], ['Social Insurance Net Expenditures²', '(4.2%)', '(4.4%)'], ['Total Federal Non-Interest Net Expenditures', '(3.6%)', '(3.8%)'], ['Fiscal Gap³', '(4.3%)', '(4.5%)']], bbox=[BBox(h=435.0, w=380.0, x=115.0, y=66.0, confidence=0.95, end_index=4798, label='table', start_index=0)], merged_from_pages=None, merged_into_page=None, type='table')
text TextItem(md="¹ The government's net position is calculated in accordance with federal accounting standards. Per these standards, net position does not include the financial value of the government's sovereign power to tax, regulate commerce, or set monetary policy, or the value of nonoperational resources, such as national and natural resources, for which the government is a steward.", value="¹ The government's net position is calculated in accordance with federal accounting standards. Per these standards, net position does not include the financial value of the government's sovereign power to tax, regulate commerce, or set monetary policy, or the value of nonoperational resources, such as national and natural resources, for which the government is a steward.", bbox=[BBox(h=39.0, w=366.0, x=124.0, y=514.0, confidence=0.94, end_index=372, label='text', start_index=0)], type='text')
```

### Metadata view (`result.metadata`)

The **metadata** view exposes page-level and job-level metadata, such as confidence scores and presentation-specific data.

```
first_page_meta = result.metadata.pages[0]


print("Page number:", first_page_meta.page_number)
print("Confidence:", first_page_meta.confidence)
print("Additional metadata:", first_page_meta)
```

- **`page_number`** tells you which page the metadata corresponds to.
- **`confidence`** is a relative score (0–1) for how confident the parser is about that page.
- Other fields (e.g. slide `speaker_notes` for presentations) are available depending on the input type.

```
Page number: 1
Confidence: 0.985
Additional metadata: MetadataPage(page_number=1, confidence=0.985, cost_optimized=False, original_orientation_angle=0, printed_page_number=None, slide_section_name=None, speaker_notes=None, triggered_auto_mode=False)
```

Together, these four views let you:

- Use **text** or **markdown** directly in LLM pipelines.
- Use **items** when you need tables, figures, or explicit layout.
- Use **metadata** for quality checks, routing low-confidence pages to humans, or analytics.
