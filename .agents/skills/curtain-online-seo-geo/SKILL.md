---
name: curtain-online-seo-geo
description: Use for Curtain Online / Curtain-online-price-estimate SEO, GEO, schema, GSC 7d/28d ranking batches, keyword-owner mapping, Next.js static export validation, FTP upload/deploy SOP, Windows sandbox troubleshooting, and out/ deploy-boundary checks. Also use for Chinese requests mentioning 窗簾SEO, 關鍵字詞池, 主攻詞, 綁定主頁, 排名前10, 6頁批次, 詞頁對齊, GSC 7/28天, 上線驗收, 上傳, FTP, 部署, sandbox, PowerShell sandbox, CreateProcessAsUserW 1312, os error 740. Guides Codex to inspect minimal project truth sources, use shared SEO helpers, run build/seo checks, follow quick/delta FTP deploy, handle known Windows sandbox failures, and keep plan.md/Phase*.md governance.
---

# Curtain Online SEO/GEO

Use this skill to work on `Curtain-online-price-estimate` SEO, GEO, schema, ranking batches, and deploy validation without re-learning the project each time.

中文任務若提到窗簾網站、SEO/GEO/schema、關鍵字排名、詞池、主攻詞、綁定主頁、GSC 7/28 天、6 頁優化、詞頁對齊、上線驗收、上傳、FTP、部署、sandbox 或 PowerShell sandbox，也使用此 skill。

## Fast Start

Default to Slim Implementation Mode. Escalate to Strategy, Deploy, or Troubleshooting mode only when the task explicitly needs it.

### Slim Implementation Mode (default)

Use this for requests like "implement the latest SEO/GEO action plan", "依最新報告優化 6 頁", or "照 AI 執行指令修改".

1. Read only:
   - `plan.md`
   - `Weekly SOP/latest/seo-geo-action-plan.ai.md`
2. Do not reselect pages or keywords when the AI action plan exists, unless the user explicitly asks for strategy/reselection.
3. Read only the source files for the action-plan target pages plus the needed source truth:
   - Product pages: `src/data/products.ts` and `src/app/products/[slug]/page.tsx`
   - GEO pages: `src/data/locationPages.ts` and `src/app/location/[area]/page.tsx`
   - Blog pages: `src/data/knowledgePosts.ts` and `src/app/blog/[id]/page.tsx`
   - Calculator/home/cross-cutting SEO: read the specific page file and `src/lib/seo.ts` only if canonical, URL, OG/Twitter, or calculator URL behavior is touched.
4. Before finishing source edits, run:
   `node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs`
5. Validate with the fixed loop in `Validation Loop`.

### Strategy / Re-selection Mode

Use this only when the user asks to analyze 7d/28d data, create or replace a keyword pool, choose the next 6 pages, or decide whether to keep/replace/expand keywords.

1. Read `references/seo-batch-workflow.md`.
2. Read the latest `Weekly SOP/12-keyword-pool-v*.md`.
3. Read only the needed latest 7d/28d summaries or current baseline CSV files. Do not recursively scan `Weekly SOP/reports/` or old history files.
4. Run `keyword-owner-check.mjs` after proposing or editing owner mappings.

### Deploy / Validation Mode

Use this when the user asks to validate, upload, deploy, or live-check SEO/GEO/schema changes.

1. Read `references/validation-deploy.md`.
2. Run the fixed validation/deploy commands requested by the task.
3. Report summaries only: pass/fail, selected/uploaded/skipped/failed counts, and concrete errors. Do not paste full per-file FTP logs unless needed to diagnose a failure.

### Troubleshooting Mode

Read `references/windows-sandbox-troubleshooting.md` only after sandbox, permission, PowerShell, `os error 740`, or `CreateProcessAsUserW failed: 1312` symptoms appear.

`curtain-snapshot.mjs` is optional. Use it for orientation or audits, not as a mandatory first step for routine SEO implementation.

## Reference Routing

- Project map and ownership: read `references/repo-map.md` only when source ownership, moved docs, or repo boundaries are unclear.
- GSC, keyword-owner, and 6-page ranking batch work: read `references/seo-batch-workflow.md` only in Strategy / Re-selection Mode.
- Content, FAQ, AI-answer, and schema alignment: read `references/content-schema-standards.md` only when changing visible FAQ/content/schema contracts or resolving schema/content mismatch.
- Build, SEO check, FTP upload SOP, export, deploy, and live verification: read `references/validation-deploy.md` only in Deploy / Validation Mode or before a real upload.
- Windows sandbox failures such as `os error 740` or `CreateProcessAsUserW failed: 1312`: read `references/windows-sandbox-troubleshooting.md` only after those failures appear.

## Core Rules

- Treat `plan.md` as the compact live control file; treat `All_plan/` and `Phase*.md` as completed history for tracebacks only.
- In routine implementation, prefer `Weekly SOP/latest/seo-geo-action-plan.ai.md` over raw 7d/28d data. Begin from raw 7d/28d baselines only in Strategy / Re-selection Mode.
- Maintain `1 keyword = 1 owner page`.
- Execute ranking work in complete 6-page batches unless the user explicitly changes the batch size.
- If `Weekly SOP/latest/seo-geo-action-plan.ai.md` exists, do not reselect pages, reselect keywords, or redo strategy analysis unless the user explicitly requests it.
- Use shared SEO helpers in `src/lib/seo.ts` for canonical, product paths, absolute URLs, OG/Twitter, and calculator URLs.
- Edit source files only. Do not edit generated `out/` files directly.
- Do not read `All_plan/`, `Phase*.md`, raw GSC CSV baselines, or `Weekly SOP/reports/` by default.
- Do not add unrelated UI, libraries, pages, or schema types while performing SEO/GEO/schema work.
- On Windows, use `npm.cmd`, not `npm`, when running project scripts.
- For upload/deploy requests, follow the FTP quick/delta SOP in `references/validation-deploy.md`; default to `npm.cmd run deploy:ftp`, not a full 916-file reupload.
- If non-escalated shell commands fail with Windows sandbox setup/runner errors, follow `references/windows-sandbox-troubleshooting.md`; after repeated `1312`, continue project work with `sandbox_permissions: "require_escalated"` instead of retrying the broken sandbox.

## Boundaries

- Do not turn SEO/GEO/schema tasks into PHP admin, pricing-rule, credential, or backend business-logic changes.
- Do not upload `plan.md`, `All_plan`, `Phase*.md`, `Weekly SOP`, `.agents`, raw CSV baselines, or local scripts to the public static site.
- Do not create extra planning files unless the user asks for a standalone document.
- Do not translate code identifiers, file paths, commands, schema field names, or URL paths into Chinese.

## Example Prompts

- `Use $curtain-online-seo-geo 檢查目前 SEO/GEO 進度與下一批 6 頁。`
- `Use $curtain-online-seo-geo 依 GSC 7d/28d 建立下一版 keyword pool。`
- `Use $curtain-online-seo-geo 驗證這次 SEO/schema 修改是否可以上線。`

## Validation Loop

For source changes that affect SEO, GEO, schema, sitemap, routing, or generated HTML, run:

```powershell
npm.cmd run build
npm.cmd run seo:check
```

If deployment is included, upload only the contents of `out/` for the static site and verify live HTTP 200, canonical, JSON-LD, sitemap, and legacy product redirects.

For FTP upload, use the project deploy script:

```powershell
npm.cmd run deploy:ftp:dry
npm.cmd run deploy:ftp
```

Use `deploy:ftp:all` only when a full asset refresh is explicitly needed. Use `scripts/deploy-ftp.ps1 -Mode paths` for small page-only corrections.
