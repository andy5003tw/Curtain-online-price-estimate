# Weekly SOP（改版後正式版）

## 用途

`Weekly SOP` 用來固定產出 GSC 成效對比報表，分為：

1. `7天`：每週觀察與微調。
2. `28天`：正式成效判定。

## 正式入口與執行檔

1. 正式入口：`Open Weekly SOP UI.cmd`
2. UI：`Weekly SOP Launcher.hta`
3. 核心執行腳本：`run-weekly-window.ps1`

## 使用方法（實際操作）

1. 雙擊 `Open Weekly SOP UI.cmd`
2. 在 UI 點其中一顆上傳按鈕：
   - `上傳 7天成效 ZIP 並產生報表`
   - `上傳 28天成效 ZIP 並產生報表`
3. 產生完成後可直接點：
   - `開啟最新 7天查詢 HTML`
   - `開啟最新 7天網頁 HTML`
   - `開啟最新 28天查詢 HTML`
   - `開啟最新 28天網頁 HTML`
   - `開啟 KPI 報表總覽頁（7天 + 28天）`

## 上傳檔案規格

請上傳 GSC「成效」ZIP，ZIP 內必須有：

1. `查詢.csv`
2. `網頁.csv`
3. `篩選器.csv`

區間檢查規則：

1. `前 7 天` 只能跑 7天按鈕。
2. `前 28 天` 只能跑 28天按鈕。

若區間不符會直接中止，不會覆蓋錯誤區間的 `latest` 報表。

## 目前版本重點（2026-05-14）

1. UI 為連結外開模式（不嵌入 UI）。
2. 已有區間防呆（7d/28d 誤傳會擋下）。
3. 執行批次 ID 使用「毫秒 + PID」，避免同秒暫存碰撞。
4. 最新報表固定分區輸出到 `latest/7d`、`latest/28d`。

## 輸出位置

1. 每次執行報表：
   - `Weekly SOP/reports/YYYY-MM-DD_HHMMSS_*`
2. 最新快捷報表：
   - `Weekly SOP/latest/7d/`
   - `Weekly SOP/latest/28d/`
3. 總覽頁：
   - `Weekly SOP/latest/report-dashboard.html`
4. 最近日誌：
   - `Weekly SOP/latest/weekly-sop-7d-last-run.log`
   - `Weekly SOP/latest/weekly-sop-28d-last-run.log`

## Baseline 位置

1. 7天：
   - `Weekly SOP/history/7d/current_query_baseline.normalized.csv`
   - `Weekly SOP/history/7d/current_page_baseline.normalized.csv`
2. 28天：
   - `Weekly SOP/history/28d/current_query_baseline.normalized.csv`
   - `Weekly SOP/history/28d/current_page_baseline.normalized.csv`
