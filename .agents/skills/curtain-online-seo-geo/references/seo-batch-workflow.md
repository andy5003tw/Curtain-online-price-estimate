# SEO Batch Workflow

Use this reference for Google ranking pushes, GSC analysis, keyword pools, and 6-page execution batches.

Chinese task terms: `關鍵字詞池`, `主攻詞`, `綁定主頁`, `產品 + 地區`, `詞頁對齊`, `6頁批次`, and `排名前10` all refer to this workflow.

## Baseline First

Use complete-day GSC baseline data only for Strategy / Re-selection Mode: creating a new pool, choosing/replacing the next 6 pages, or formally deciding keep/replace/expand.

- Resolve the current query/page baseline paths from `Weekly SOP/latest/<window>/weekly-sop-last-run.json`.
- For the current site these normally live under `Weekly SOP/history/curtain-online/<window>/current_*_baseline.normalized.csv`.
- Read the complete normalized current baselines, not a thresholded Markdown/HTML report table.

Use 7d for quick movement and micro-adjustments. Use 28d for formal decisions about keeping, replacing, or expanding keywords.

If either required snapshot is `monitor_only`, bootstrapped without a prior comparison, or not `decision_ready`, stop at observation. Do not create source implementation tasks from that cycle.

For routine implementation, do not reread raw baselines when `Weekly SOP/latest/seo-geo-action-plan.ai.md` already exists. Execute the action plan and preserve its selected pages/keywords unless the user explicitly asks to redo strategy.

## Keyword Ownership

- Maintain `1 keyword = 1 owner page` (`1 個主攻詞 = 1 個綁定主頁`).
- Prefer existing GSC roots with impressions and average position around 10-30.
- Use `產品 + 地區` and transaction-intent long-tail terms before attacking broad words like `窗簾`.
- Do not let product pages, GEO pages, calculator pages, and blog pages compete for the same exact owner keyword.
- Before editing pages, run:
  `node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs`
- Running the owner check is required; reading the script source is not required unless debugging the script.

## Focused Batch Rule

Default ranking work is one focused 2-5 page batch, with 6 pages as the hard maximum. Do not add low-value pages merely to fill a fixed batch size.

For each selected page, align:

- title and meta description
- H1 and first-screen copy
- FAQ questions and answers
- internal-link anchors
- CTA path to calculator or area/product route
- schema and visible content
- Chinese business intent: keep `主攻詞`, `首屏文案`, `FAQ`, `估價導流`, and `內鏈錨文字` pointed at the same owner-page intent.

## Batch Selection

Use `Weekly SOP/config/target-registry.json` as the canonical owner portfolio. Legacy `12-keyword-pool-v*.md` files are historical evidence only and must not drive a new queue.

If a decision-ready `Weekly SOP/latest/seo-geo-action-plan.ai.md` has already selected the pages, do not reselect during implementation. If the current source already satisfies the requested state or the owner is inside its 28-day cooldown, keep it in observation instead of issuing the same implementation action again.

When creating the next pool:

- Start from 7d/28d query and page baselines.
- Map each keyword to exactly one owner page.
- Group eligible owner pages into focused 2-5 page Rounds, with 6 as the hard maximum; do not add filler pages.
- Prefer pages that can support stronger visible content, FAQ, and internal-link intent without becoming thin or off-topic.
- Do not add a keyword to the pool only because it sounds useful; it needs either GSC evidence, clear service value, or a deliberate expansion reason.

## Post-Launch Review

After each batch goes live:

- Persist the validated action fingerprints and use both action history and registry `lastChangedAt` as 28-day cooldown evidence.
- After 7 complete days: review CTR, impressions, average position, and obvious page/query mismatches.
- After 28 complete days: decide whether to keep, replace, or expand each keyword cluster.
- Keep `plan.md` compact by updating current state and next steps; move detailed completed evidence into `All_plan/` or dedicated history files when needed.
