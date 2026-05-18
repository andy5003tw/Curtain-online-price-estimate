# SEO Batch Workflow

Use this reference for Google ranking pushes, GSC analysis, keyword pools, and 6-page execution batches.

Chinese task terms: `關鍵字詞池`, `主攻詞`, `綁定主頁`, `產品 + 地區`, `詞頁對齊`, `6頁批次`, and `排名前10` all refer to this workflow.

## Baseline First

Start with complete-day GSC baseline data:

- 7-day query baseline: `Weekly SOP/history/7d/current_query_baseline.normalized.csv`
- 7-day page baseline: `Weekly SOP/history/7d/current_page_baseline.normalized.csv`
- 28-day query baseline: `Weekly SOP/history/28d/current_query_baseline.normalized.csv`
- 28-day page baseline: `Weekly SOP/history/28d/current_page_baseline.normalized.csv`

Use 7d for quick movement and micro-adjustments. Use 28d for formal decisions about keeping, replacing, or expanding keywords.

## Keyword Ownership

- Maintain `1 keyword = 1 owner page` (`1 個主攻詞 = 1 個綁定主頁`).
- Prefer existing GSC roots with impressions and average position around 10-30.
- Use `產品 + 地區` and transaction-intent long-tail terms before attacking broad words like `窗簾`.
- Do not let product pages, GEO pages, calculator pages, and blog pages compete for the same exact owner keyword.
- Before editing pages, run:
  `node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs`

## Six-Page Batch Rule

Default ranking work is one complete 6-page batch. Do not split into smaller batches unless the user explicitly asks.

For each selected page, align:

- title and meta description
- H1 and first-screen copy
- FAQ questions and answers
- internal-link anchors
- CTA path to calculator or area/product route
- schema and visible content
- Chinese business intent: keep `主攻詞`, `首屏文案`, `FAQ`, `估價導流`, and `內鏈錨文字` pointed at the same owner-page intent.

## Batch Selection

Use the latest `Weekly SOP/12-keyword-pool-v*.md` unless the user specifies another file.

When creating the next pool:

- Start from 7d/28d query and page baselines.
- Map each keyword to exactly one owner page.
- Group owner pages into the next 6-page execution order.
- Prefer pages that can support stronger visible content, FAQ, and internal-link intent without becoming thin or off-topic.
- Do not add a keyword to the pool only because it sounds useful; it needs either GSC evidence, clear service value, or a deliberate expansion reason.

## Post-Launch Review

After each batch goes live:

- After 7 complete days: review CTR, impressions, average position, and obvious page/query mismatches.
- After 28 complete days: decide whether to keep, replace, or expand each keyword cluster.
- Keep `plan.md` compact by updating current state and next steps; move detailed completed evidence into phase/history files when needed.
