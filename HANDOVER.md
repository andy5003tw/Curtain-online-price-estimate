# 宏森窗簾專案交接

> 交接狀態核對：2026-10-29（台灣時間）。本文件是摘要；接手時請重新讀取本機 `plan.md` 與 `Weekly SOP/latest/`，勿把指定日期的數據當成即時狀態。

## 專案入口

- 正式網站：[online.hong-sen.com](https://online.hong-sen.com/)。本機開發使用 `npm.cmd run dev`。
- 現行工作分支：`codex/seo-geo-v3-optimization`。GitHub 同步與網站部署是兩件事；實際狀態應分別查核。
- [plan.md](plan.md) 是本機最新控制摘要；[今日變更紀錄](Weekly%20SOP/2026-10-29-change-log.md) 與 [SOP UI 設計交接](curtain-weekly-sop-ui-update-design.md) 記錄本輪實作與驗證。
- `plan.md`、`Weekly SOP/latest/` 與部分操作資料依 `.gitignore` 留在本機，GitHub 不包含它們；不可為交接而擅自公開或強制加入。

## 截至 2026-10-29 的狀態

- P001 [一般窗簾產品頁](https://online.hong-sen.com/products/custom-curtains/)詞頁對齊已實作，10/29 02:39 上線並公開驗收。當時 queue `seo-geo-3bbc4c26c0342d93` 的標準 lifecycle 仍為 `local_validated`，缺少 queue-bound 的 `deployed`／`live_verified` 收據。先核對既有部署與公開驗收證據能否被標準 writer 接受；不重做網頁修改、不手寫狀態或收據。
- 本機最新正式 GSC 資料：7 天為 10/20–10/26，28 天為 9/29–10/26；六題 OpenAI 測試已做 AI 輔助審核。GSC 曝光、Bing AI 引用與 OpenAI 測試的計算口徑不同，不能直接相加或互推。
- Bing sitemap 在使用者 10/29 畫面顯示成功、發現 63 個網址，0 錯誤／警告；發現不等於已索引。P001 的 IndexNow 提交回應 HTTP 202，仍待後台確認 key 驗證與抓取狀態。
- FTP 同大小檔案已改為遠端內容 SHA-256 比對；SOP 主按鈕與佇列面板共用 Round receipt gate。本機離線測試已有通過紀錄；Windows HTA 實際點擊及這批 FTP 修正在正式主機的驗收仍未完成。
- 專案清理部分完成：三個未引用元件、`src/index.css` 與 `tmp-calc.json` 已刪除並納入先前 Git 提交。`framer-motion` 仍由 `src/components/FloatingCta.tsx` 使用，必須保留。

## 後續優先事項

1. 確認當前 queue、receipt 與 P001 既有部署證據，再依標準流程處理 lifecycle；舊的 `PLEASE IMPLEMENT` 指令不可重複實作。
2. 用隔離測試資料實際驗收 Windows HTA；其他流程提示與六區面板若要遷移，先補等價契約及回歸測試。正式 FTP 的遠端讀取能力與耗時留待下次部署觀察。
3. Bing 有資料後建立 Search Performance 基準並檢查 Site Explorer；確認 IndexNow 狀態，勿重複通知未變更頁面。Bing Places 等客服回覆，再核對商家 85／89 號地址差異。
4. 捲簾／調光簾固定 7 天需完整 final 資料涵蓋 10/22–10/28；P001 固定觀察窗為 10/30–11/05 與 10/30–11/26。日期到期不代表資料完整；首頁固定窗至 11/08。
5. 清理尚未結束：2026-10-29 稽核時 `.next/` 約 705.2 MiB、`.tmp/` 為空、`.upload-out-files.txt` 尚在。清理前重新確認 Next dev／build 與手動上傳需求；`src/app/globals.css` 的疑似城市頁籤樣式需先查共用情況及驗證畫面。歷史報表、history、圖片原檔與備份尚未逐項核定可刪。
6. 五頁手機體驗目前只做過桌面 viewport 模擬，真機／觸控驗收尚未完成。

## 持續適用的維護規範

- 前端為 Next.js 靜態匯出至 `out/`；只修改 source，不直接編輯生成的 `out/`。正式站 PHP 曾於 2026-09-24 實測為 7.1.33；涉及後台或 API 時先核對現況並維持相容，詳見 [價格後台文件](PRICING_FORMULA_ADMIN.md)。
- 關鍵字遵守一詞一 Owner，以 `Weekly SOP/config/target-registry.json` 為準。使用有效的 decision-ready 資料與現行 queue；不可把舊 action plan、單一畫面或本交接摘要當作新的執行授權。
- 保持 H1、metadata、canonical、JSON-LD、可見 FAQ 與 schema 一致，以及既有內鏈與估價入口。商業承諾或案例沒有可公開證據時，不新增至 schema 或 `data-ai-answer`。
- 服務區口徑為台北 12 區、新北 17 區，加上兩個市級總覽共 31 個地區 URL；`/location/#new-taipei-city` 是頁內錨點。市級 `Service.areaServed` 為 `City`，行政區為 `AdministrativeArea`；共用既有公司實體，不虛構分店或地址。
- 服務區總覽保留台北／新北的錨點、城市專頁與估價入口；版面變更應尊重使用者已選定的城市資訊整合卡與手機可用性。施工案例與客戶素材須真實、可追溯；AI 裝飾圖不可冒充施工實績，圖片應有適當 alt。原始備份和壓縮來源不能視為無用資料逕行刪除。
- 不將 `plan.md`、`Weekly SOP`、`scripts`、`download`、`source`、原始資料或其他本機文件上傳至公開網站。價格規則與 PHP 後台變更需依各自範圍和驗證流程處理。

## 本機檢查與部署

Windows 使用 `npm.cmd`。涉及 SEO／網頁 source 時，依序執行以下檢查，避免 SEO 檢查讀到尚未完成的 build：

```powershell
node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs
npm.cmd run build
npm.cmd run seo:check
npm.cmd run seo:preflight
```

正式部署依 [FTP 驗證與部署指引](.agents/skills/curtain-online-seo-geo/references/validation-deploy.md)及當前 queue 契約進行：先執行 dry-run，再依授權範圍部署並公開驗收。同大小檔案只有遠端 SHA-256 一致才略過；比對失敗則上傳，`-Force` 用於確需強制上傳的情況。

## 歷史查證

已完成的舊 queue、部署嘗試與頁面改版細節不再放在本交接摘要中。需要查證時，可查看 [2026-09-17 紀錄](Weekly%20SOP/2026-09-17-change-log.md)、[2026-09-24 紀錄](Weekly%20SOP/2026-09-24-change-log.md)、[2026-09-25 紀錄](Weekly%20SOP/2026-09-25-change-log.md) 或 [Phase 8 歷史](All_plan/Phase8.md)；清理前的完整交接可用 `git show 8ee5e32:HANDOVER.md` 讀取。
