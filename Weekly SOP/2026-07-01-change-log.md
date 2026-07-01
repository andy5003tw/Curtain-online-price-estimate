# 2026-07-01 變更紀錄

## SEO/GEO

- Queue：`seo-geo-20260701-111040`
- 狀態：completed
- 本輪頁面：`/products/`、`/about/`、`/cases/`
- 已上線頁面：`/`、`/blog/curtain-price-guide-2026/`、`/calculator/`、`/products/wooden-blinds/`、`/products/seamless-sheer-curtains/`、`/location/taipei/`、`/products/`、`/about/`、`/cases/`

## 驗證

- `keyword-owner-check` passed
- `npm.cmd run build` passed
- `npm.cmd run seo:check` passed
- `npm.cmd run seo:preflight` passed
- Live HTTP / canonical / JSON-LD / sitemap checks passed

## 上傳

- FTP quick deploy：uploaded 106、skipped 84、failed 0
- GitHub：`7ef933b Apply SEO GEO content updates`
- GitHub：`3695661 Update Weekly SOP queue workflow`

## 流程變更

- 修正 V6 keyword pool 解析，queue 可正常產生。
- SOP UI 新增 Queue 狀態面板：Round 1 / Round 2 / Round 3 / Technical Queue。
- 複製 Slim AI 指令時，會顯示目前 Round、完成狀態與下一步。
- SOP UI 新增流程狀態條，顯示目前下一步。
- 7d 或 keyword pool 不完整時，停用 `產生 SEO/GEO 優化建議`。
- 已有 queue 時，重新產生前會要求確認。
- `run-seo-geo-cycle.ps1` 執行改為 PowerShell fallback：優先 `pwsh`，缺少時用 `powershell`。
- Round 操作拆成兩顆：`複製目前 Round`、`標記完成前進`。
- `.gitignore` 改為追蹤 `Weekly SOP/` 根目錄 `.cmd` / `.hta` / `.ps1` 與 `*change-log.md`，不追蹤 reports/latest/raw data。

## 備註

- `action/action.md` 只保留操作流程說明。
- `Weekly SOP/` 僅開放根目錄工具檔與 change log 進 Git；報表、latest、raw data 仍維持本機。
