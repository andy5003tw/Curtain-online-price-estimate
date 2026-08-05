# SEO/GEO Queue 動態流程

## 先看資料狀態

1. 在 Codex 對話中說：`請抓最新 7d／28d`。
2. Codex 以已授權的 Google Search Console API，在台北時區依 `dataLagDays` 計算最後一個完整資料日，直接取得 Query、Page 與 Query × Page。
3. 系統會建立可驗證的內部 ZIP，並沿用 Weekly SOP 的 host、window、hash、row counts、日期完整度、資料延遲及 query-page Data Gate 匯入。
4. 若尚無比 current baseline 更新的完整資料日，流程只回報「尚無新資料」，不會覆蓋 baseline 或重產生舊 cycle。手動 ZIP 上傳保留為 API 暫時不可用時的備援，不是日常操作。
5. 路徑以 `Weekly SOP` 相對位置保存；不要把 `D:\...` 或 `_tmp_window_*` 路徑當成可重用來源。

資料狀態決定後續流程：

- `monitor_only`／`decision_ready=false`：只產生 observation／watchlist，`total_rounds=0`，不得出現 `PLEASE IMPLEMENT`，也沒有可標記完成的 Round。
- `decision_ready=true`：才允許產生 action queue；Round 數量依實際合格任務動態為 `0..N`，不是固定 Round 1／2／3，也不為湊頁數建立任務。

合格任務分為「內容缺口」與「成效優化」兩類。即使 source 已合規，只要 28d 頁面至少 250 曝光、排名介於 6–15，且 CTR 比同排名目標低至少 0.4 個百分點，也可建立成效優化 Round；registry 與 action-history 的 28 天 cooldown 仍不可跳過。

目前 `online.hong-sen.com` 的 7d／28d 已有完整日期及 Query × Page，資料狀態為 `decision_ready=true`。最新行動報告暫時為 observation，原因是 Owner 都符合既有內容要求或仍在 28 天 cooldown；這不是資料不足。

## 產生建議時

`產生 SEO/GEO 優化建議` 每個 snapshot family 只執行一次。Generator 必須：

- 以 `target-registry.json` 的 Owner mapping 為準，不再用舊 V6 詞池選頁。
- 從完整 normalized current baseline 讀取指標，不從截斷摘要回填數字。
- 先做 source compliance 檢查；已符合的內容不重複排入。
- 以不含浮動 metrics／action type 的穩定 action fingerprint 去重；registry `lastChangedAt` 與 action history 都會執行完整 28d cooldown。
- 將 7d／28d input、manifest、normalized baseline SHA、registry version／SHA、action-history SHA 與 source files／fingerprint 綁進 queue provenance。

若 provenance 與目前資料或 source 不一致，舊 queue 必須失效並重新審核，不能繼續標記 Round。

## 執行動態 Round

只有 `decision_ready=true` 且 `total_rounds > 0` 時才執行：

1. 按 `複製目前 Round`，貼給 AI 實作該 Round。
2. AI 完成 source 修改與指定的本機檢查後，必須透過 `scripts/write-seo-geo-validation-receipt.ps1` 產生 receipt，不可手寫 JSON。
3. Receipt 必須對得上 queue／cycle／Round、action IDs／fingerprints、7d／28d snapshot、registry、source before／after 與 validation 結果。
4. UI 驗證 receipt 成功後，才可按 `標記完成前進`；前進時先寫 action history，`implemented` 再更新 registry `lastChangedAt`。
5. History、registry 或 queue state 任一寫入失敗都不得前進。
6. 若仍有下一個 Round，active round 前進；若沒有，只代表本輪實作 Round 已處理完，不代表整個 SEO cycle 已完成。

複製 prompt、AI 口頭回報、人工勾選或只有 source 已修改，都不能代替 receipt。

## 狀態與 Receipt 不可混用

狀態順序固定為：

`data_validated → strategy_approved → implemented → local_validated → deployed → live_verified → observing_7d → reviewed_28d → completed`

- `local_validated`：只證明本機檢查通過，不代表已部署。
- `deployed`：必須有實際 deploy receipt；不代表線上內容正確。
- `live_verified`：必須有正式網址的驗證 receipt；不代表已完成觀察期。
- `completed`：只能在有效 28d review 已寫入決策後成立。

部署、live verification 與 7d／28d review 都是分開步驟；產生建議或完成 local validation 不會自動部署。

## Optional Opportunities

小幅可優化參考清單只供判斷，不自動加入 queue：

- `monitor_only` 時只看 observation，不要求 AI 實作。
- 有候選頁時，可用 `複製小幅優化參考指令` 請 AI 判斷是否值得另開一輪。
- 使用者明確指定頁面後，才建立獨立的小幅優化工作；不要擴大成固定 6 頁。

## 執行環境

Weekly SOP 一律使用 PowerShell 7 `pwsh`。找不到 `pwsh` 時 UI 應明確中止；不得 fallback 到 Windows PowerShell 5.1。
