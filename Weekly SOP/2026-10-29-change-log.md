# 網站 SEO／GEO 與 Bing 變更紀錄（2026-10-29）

## 已完成

- 根目錄 `HANDOVER.md` 已整理為現行交接、待辦與持續適用的維護規範；移除已完成的舊 queue、舊部署嘗試及過時任務明細，避免誤認現況。舊版完整內容可由 `git show 8ee5e32:HANDOVER.md` 查證，既有日期變更紀錄及本機 receipt 未刪除；2026-09-25 變更紀錄中的舊章節指向已修正。
- SOP Round receipt 與佇列面板遷移：新增共用後端 gate，核對 Round、action／fingerprint、來源、registry、snapshot 與必要驗證；projection 與 HTA 共用結果與精簡 queue snapshot，移除 HTA 重複 gate。來源過期、讀取失敗或 identity／Round 不符時停用操作；保留 writer 最終重驗。離線 fixture 涵蓋錯誤 receipt 與 UI／面板一致性，未操作正式網站或 Windows HTA。
- SOP HTA 流程合併第一階段：盤點後移除主按鈕中會被 UI projection 覆寫的舊分支，當時仍供佇列、面板及手動操作使用的 helper 先保留；其中 Round receipt 與佇列重複判斷已於第二階段遷移。自動部署補上畫面原已承諾的上傳確認。部署計畫增加來源 provenance 檢查，dry-run 後再核對來源與 queue／receipt，以阻擋過期資料上傳。離線測試涵蓋按鈕／提示、取消確認、實際 projection 狀態、來源漂移及 dry-run 期間變更；未進行真實 FTP 或 Windows HTA 點擊驗收。
- SOP UI projection：查核後移除未接線的 `RUN_AI_VISIBILITY`、`RUN_LUNA_COMPARISON`、`ANALYZE_GSC_GENERATIVE_AI` 欄位；AI 可見度與 GSC Excel 的現有按鈕仍沿用直接 handler，Luna 手動對照 runner／fixture 與既有報告顯示保留。更新設計文件與 UI 契約測試；本機 UI 靜態／projection 檢查、auto-deploy 唯讀 Inspect 及 Luna 離線 fixture 均通過。專案外的 JSON 消費者無法由 repo 搜尋確認，若有依賴這三個欄位需同步更新。
- FTP 部署安全修正：同大小檔案須進一步以遠端內容 SHA-256 比對，相同才略過；讀取或比對失敗時上傳，`-Force` 維持強制上傳。新部署收據與流程檢查不再接受僅按大小略過；本機 FTP 整合測試涵蓋同大小不同內容、相同內容、遠端讀取失敗、Force 與 DryRun，lifecycle 測試亦通過。此次未連正式 FTP 或部署。
- 一般窗簾 P001 詞頁對齊：審查查詢與內鏈後，調整產品頁首屏，說明一般布簾、估價條件及丈量報價流程；保留 Owner 與價格公式。10/29 上線並公開核對；Owner check、build、SEO check 與 preflight 通過。標準 queue lifecycle 仍為 `local_validated`，部署及公開驗收收據待以既有流程補齊。
- IndexNow：根目錄驗證檔已上線，內容與公開 HTTPS 回應已核對；僅提交已上線的 P001 正式網址，HTTP 202 表示已收到、key 驗證待處理，不表示已抓取或索引。自動建立實際變更網址清單與後續提交機制尚未實作。
- Bing sitemap：主機商調整 Bingbot 防火牆限制後，使用者 10/29 畫面顯示 sitemap 處理成功、發現 63 個網址、0 錯誤／警告。發現網址不代表已全部索引；不能僅由時間先後判定原逾時的直接原因。
- OpenAI 固定六題觀察已匯入並完成 AI 輔助審核，六題保守判為部分正確，包含待核實內容；這不是人工審核或整體市場正確率。GSC 生成式 AI 曝光、OpenAI 觀測與 Bing AI 引用維持分開判讀。
- 五頁以 390×844 桌面視窗模擬檢查，未見整頁水平溢位；價格指南表格換行較多列為低優先級觀察，尚未做真機觸控驗收。

## 專案清理狀態稽核（2026-10-29 17:46，台灣時間）

- `src/components/BrandStory.tsx`、`src/components/LocationCityTabs.tsx`、`src/components/MotionWrapper.tsx`、`src/index.css` 與 `tmp-calc.json` 在 17:46 稽核時已從工作樹刪除，當時 Git 顯示為尚未提交的刪除；`debug.log` 當時不存在。這次稽核只核對狀態，沒有再刪檔。
- `.next/` 仍存在約 705.2 MiB，屬可重建建置快取；10/29 13:03 有建置產物，但不能僅憑時間判斷先前是否刪除後重建。稽核時未見 Next dev/build 行程，實際清理前仍須重新確認。`.tmp/` 目前為空；`.upload-out-files.txt` 有 58,136 bytes，先確認是否仍有待完成的手動上傳。
- `src/app/globals.css` 仍有 `city-tabs-*`／`city-tab-*` 等樣式；目前在其他 `src` 與已匯出 HTML 未找到上述城市頁籤 class，但相關 `.tab-*` 等選擇器仍須逐項確認是否共用，再決定清理與驗證。`framer-motion` 仍被 `src/components/FloatingCta.tsx` 引用，不能因刪除 `MotionWrapper.tsx` 而移除。
- 舊報表、history、圖片原檔及備份未逐項核定可刪；保留中的歷史資料不等於無用資料。最新 Owner 檢查 14/14 與對現有 `out/` 的 `npm.cmd run seo:check` 通過，該 SEO 檢查不是重新 build 或正式網站全站驗收。

## SOP Round gate 測試與交接（2026-10-29）

- 共用 gate 位於 `scripts/seo-geo-round-gate.mjs`；UI projection 輸出 `panels.queue.receipt_gate` 與同一次讀取的 state／queue 摘要，HTA 保留 `getQueueSnapshot` 作相容介面。writer 前進時仍重新檢查，不能只根據 UI 或程序 exit code 判定已完成。
- `node scripts/test-seo-geo-round-gate.mjs`：61 個案例通過，其中 10 個為更嚴格的拒絕案例。刪除舊 HTA gate 前，51 個共同情境與舊結果比對通過；移除後重跑會顯示 parity 跳過，固定預期案例仍執行。
- `node scripts/test-weekly-sop-controls.mjs`：主／次按鈕、佇列面板及來源過期、讀取失敗、queue／Round 不符等 Node VM 測試通過。`pwsh -NoLogo -NoProfile -File scripts/test-weekly-sop-ui.ps1 -SkipBehaviorFixtures` 通過；此命令有跳過其餘行為 fixture，不能記為完整 UI suite 通過。
- `pwsh -NoLogo -NoProfile -File scripts/test-seo-geo-cycle.ps1` 獨立執行通過，包含有效／錯誤 receipt、不同狀態、來源漂移及 gate 缺失時停用；`scripts/test-sop-autodeploy-stale.ps1` 的離線來源／receipt 漂移測試亦通過。相關 Node 腳本 ESLint 與 `git diff --check` 通過。
- 下一步：準備隔離測試資料，在 Windows HTA 實際核對 observation-only、active 等待／通過 receipt、資料不一致及按鈕／面板顯示。其他流程提示與六區面板的獨立判斷須另建立等價契約與測試；不要因此移除手動部署、live verification 或 AI／GSC runner。
- 版本庫交接：10/29 17:46 稽核時 SOP／FTP 後續變更尚未提交，新增 gate 與測試腳本也尚未追蹤。本批同步須連同引用它們的修改一起納入，包括 `scripts/seo-geo-round-gate.mjs`、`scripts/test-seo-geo-round-gate.mjs`、`scripts/test-weekly-sop-controls.mjs`、`scripts/test-sop-autodeploy-stale.ps1` 和 `scripts/test-deploy-ftp.mjs`。`plan.md` 依 `.gitignore` 留在本機，不應因交接而強制加入；實際同步狀態以 Git 為準。

## 待完成與交接

- HTA 後續遷移：佇列 receipt gate 已統一；其他流程提示與六區面板仍有各自的新鮮度、重複匯入及 registry 判斷，若要遷移應先建立等價契約及回歸測試。尚待 Windows HTA 實際點擊驗收。
- 下次經授權部署時觀察正式 FTP 的遠端讀取是否可用及耗時；同大小比對需下載遠端檔案，若讀取失敗會改為上傳，部署後仍須公開驗收。舊的同大小略過紀錄保留作歷史資料，但不能單獨用來建立新的 deployed 收據。
- 等 GSC final 完整涵蓋捲簾／調光簾 10/22–10/28 的固定 7 天；P001 實際部署後固定觀察窗為 10/30–11/05 及 10/30–11/26。日期到期不代表資料已完整。
- Bing Site Explorer 有資料後彙整索引、抓取及 canonical 狀態；Search Performance 有資料後建立獨立搜尋基準。IndexNow 後台確認 key、抓取與索引狀態，避免重複通知同一未變更頁面。
- Bing Places 既有商家認領的電話驗證待客服回覆；商家顯示地址與官網有門牌差異，確認後修正，避免建立重複檔案。
- 本機 `plan.md` 與 `Weekly SOP/latest/` 依專案 `.gitignore` 保留操作資料，不作公開部署或版本庫資料來源；最新進度及收據以本機文件為準。
