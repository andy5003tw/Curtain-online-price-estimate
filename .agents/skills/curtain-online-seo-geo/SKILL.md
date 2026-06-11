---
name: curtain-online-seo-geo
description: Use for Curtain Online / Curtain-online-price-estimate SEO, GEO, schema, GSC 7d/28d ranking batches, keyword-owner mapping, Next.js static export validation, FTP upload/deploy SOP, Windows sandbox troubleshooting, and out/ deploy-boundary checks. Also use for Chinese requests mentioning 窗簾SEO, 關鍵字詞池, 主攻詞, 綁定主頁, 排名前10, 6頁批次, 詞頁對齊, GSC 7/28天, 上線驗收, 上傳, FTP, 部署, sandbox, PowerShell sandbox, CreateProcessAsUserW 1312, os error 740. Guides Codex to inspect minimal project truth sources, use shared SEO helpers, run build/seo checks, follow quick/delta FTP deploy, handle known Windows sandbox failures, and keep plan.md/Phase*.md governance.
---

# Curtain Online SEO/GEO

Use this skill to work on `Curtain-online-price-estimate` SEO, GEO, schema, ranking batches, and deploy validation without re-learning the project each time.

中文任務若提到窗簾網站、SEO/GEO/schema、關鍵字排名、詞池、主攻詞、綁定主頁、GSC 7/28 天、6 頁優化、詞頁對齊、上線驗收、上傳、FTP、部署、sandbox 或 PowerShell sandbox，也使用此 skill。

## Fast Start

1. Run the read-only snapshot first when repo access is available:
   `node .agents/skills/curtain-online-seo-geo/scripts/curtain-snapshot.mjs`
2. For keyword/ranking work, also run:
   `node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs`
3. Read only the smallest needed source set before editing:
   `plan.md`, latest `Weekly SOP/12-keyword-pool-v*.md`, `src/lib/seo.ts`, `src/data/products.ts`, and `scripts/seo-check.mjs`.

## Reference Routing

- Project map and ownership: read `references/repo-map.md`.
- GSC, keyword-owner, and 6-page ranking batch work: read `references/seo-batch-workflow.md`.
- Content, FAQ, AI-answer, and schema alignment: read `references/content-schema-standards.md`.
- Build, SEO check, FTP upload SOP, export, deploy, and live verification: read `references/validation-deploy.md`.
- Windows sandbox failures such as `os error 740` or `CreateProcessAsUserW failed: 1312`: read `references/windows-sandbox-troubleshooting.md`.

## Core Rules

- Treat `plan.md` as the compact live control file; treat `Phase*.md` as completed history.
- Begin ranking work from 7d/28d GSC baseline and `1 keyword = 1 owner page`.
- Execute ranking work in complete 6-page batches unless the user explicitly changes the batch size.
- Use shared SEO helpers in `src/lib/seo.ts` for canonical, product paths, absolute URLs, OG/Twitter, and calculator URLs.
- Edit source files only. Do not edit generated `out/` files directly.
- Do not add unrelated UI, libraries, pages, or schema types while performing SEO/GEO/schema work.
- On Windows, use `npm.cmd`, not `npm`, when running project scripts.
- For upload/deploy requests, follow the FTP quick/delta SOP in `references/validation-deploy.md`; default to `npm.cmd run deploy:ftp`, not a full 916-file reupload.
- If non-escalated shell commands fail with Windows sandbox setup/runner errors, follow `references/windows-sandbox-troubleshooting.md`; after repeated `1312`, continue project work with `sandbox_permissions: "require_escalated"` instead of retrying the broken sandbox.

## Boundaries

- Do not turn SEO/GEO/schema tasks into PHP admin, pricing-rule, credential, or backend business-logic changes.
- Do not upload `plan.md`, `Phase*.md`, `Weekly SOP`, `.agents`, raw CSV baselines, or local scripts to the public static site.
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
