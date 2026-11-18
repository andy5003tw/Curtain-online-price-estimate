# 手機無障礙與價格表更新紀錄（2026-11-11）

## 已完成

- 估價頁兩段重要提示調整字級與對比（白底對比約 10.27:1）；產品選單及寬、高欄位補上可存取名稱。
- 價格指南依容器寬度顯示橫向滑動提示；需橫滑時固定品項欄，並保留不支援容器查詢的後備樣式。320／390px 可見三欄，表格內容與原生語意不變。
- 車資說明與計價邏輯未變更。

## 驗證與正式發布

- Build 產生 81 頁，`seo:check`、`seo:preflight`、FTP 隔離整合測試、Owner 14/14 及目標檔案 lint 通過；lint 有 2 項既有圖片警告。
- 台北時間 **2026-11-11 19:48:38** 完成正式 FTP 發布。quick 因逐檔比對緩慢，在處理 40 個候選後停止，當時已上傳 18 個；改用 paths 清單，納入前段候選及估價頁、文章與共用靜態資源。paths 選取 121 檔，更新 79、相同 SHA 略過 42、失敗 0；兩階段共上傳 97 個不同檔案。
- 公開 HTTP 可回讀的 120 個檔案 SHA 全數相符。`.htaccess` 的 FTP SHA 與本機相同而略過；公開 HTTP 回應 403，因此不列為公開回讀通過。
- 正式站以 Chromium 模擬 320／390px 驗收估價流程及一般窗簾、捲簾正式 API（150 × 150 公分）；並檢查可存取名稱、提示、頁面導覽、canonical、JSON-LD、FAQ 可見內容與 schema（7/7）、sitemap／robots 及 P005 舊址 301。500px 觸控與鍵盤表格捲動通過。未以真實 iPhone／Safari 驗收，也未實際撥電話或傳送 LINE。

## SEO/GEO 工作流程紀錄

本次手動部署的 manifest、中斷日誌、公開回讀及 `release-context.json` 獨立保存在 `Weekly SOP/history/curtain-online/manual-deployments/2026-11-11-mobile-ux-release/`；此操作資料依 `.gitignore` 僅保留本機。現有 `manual-deploy-evidence-reader` 尚未自動納入這批證據：它要求 manifest 每項都能 HTTP 200 回讀，而受保護的 `.htaccess` 回應 403。下一輪 SEO 決策前須核對本次發布與逐頁觀察影響，不可假定既有自動觀察／冷卻狀態已包含本次發布。本次未覆寫 queue、registry 或舊 lifecycle。
