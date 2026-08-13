# Weekly SOP 一鍵執行 UI 操作指南

這份文件只說明 `Weekly SOP/Curtain online SOP UI.cmd` 開啟後如何操作 UI。

## 每週先做這一步

1. 從 Google Search Console 匯出成效 ZIP，需包含查詢、網頁、篩選器。
2. 按 **上傳成效 ZIP 並自動產生報表（7d/28d）**，選取 ZIP。
3. 匯入完成後看「流程狀態」；若顯示重複檔案，代表資料沒有更新，請重新從 GSC 匯出。

## SEO/GEO 三個主要按鈕

### 1. 更新／開啟 SEO/GEO 行動報告

- 尚無報告或有安全的新 GSC snapshot：產生新報告後開啟。
- 目前有進行中的 executable queue：只開啟既有報告，不會覆寫 Round 或 lifecycle。
- 報告顯示 `observation_only`：本輪只需觀察；等待下一期資料或 UI 出現唯一單頁核准項目。

### 2. 執行目前下一步

這個按鈕會自動改變名稱，每次只做一件事。正常順序可能是：

1. 複製本輪 AI 工作指令。
2. receipt 通過後前進 Round。
3. 記錄已完成修改。
4. 記錄本機檢查通過。
5. 執行部署預演；只檢查內容，不連線、不上傳。
6. dry-run 通過後，要求你確認再正式 FTP 上傳。
7. 自動驗證正式 deployment manifest，再記錄網站已上傳。
8. 執行 live verify，檢查 HTTP、canonical、JSON-LD、sitemap 與舊網址 redirects。
9. live verify 通過後記錄網站已上線驗證。
10. 等到部署後完整 7 日且 7d 資料 decision-ready，再記錄開始觀察 7 天。
11. 等到完整 28 日且 28d 資料 decision-ready，再由你選擇策略並輸入摘要。
12. 沿用同一份 28d 決策與摘要，記錄本次優化完成。

按鈕灰色時，將滑鼠移到按鈕或看「流程狀態」，會顯示缺少的資料與最早可操作日期。系統不會自動等待日期，也不會一次跳過多個階段。

28 天策略選項：

- `keep`：維持目前做法
- `refine`：小幅調整
- `expand`：擴大優化
- `replace`：更換策略

策略與摘要必須由你決定，系統不會自行猜測。

### 3. 匯入 AI 能見度測試結果（AI Visibility）

1. 用同一個 AI／model 跑固定 6 題。
2. 每題保存原始回答、是否提到「宏森」、引用網址與正確性。
3. 按此按鈕，直接選取完整 observation JSON。

AI Visibility 與 GSC 分開；系統不會操作外部 AI，也不會用 GSC 的排名、曝光、CTR 或 position 推論 AI 能見度。

## 進階／故障排除操作

平常不需展開。只有智慧按鈕顯示資料異常，且需要工程人員檢查單一原始步驟時才使用。進階按鈕不會繞過 queue、cycle、action IDs、manifest SHA、日期 gate、rollback 或 recovery journal。

## 簡單原則

- 日常只要：**上傳 GSC ZIP → 更新／開啟報告 → 執行目前下一步**。
- 正式 FTP 一定會再次要求人工確認。
- 按鈕灰色：先補齊畫面提示的 evidence，不要從進階區強行跳關。
- 出現錯誤：先看「執行狀態」與「展開明細」，確認原因後再重試。
