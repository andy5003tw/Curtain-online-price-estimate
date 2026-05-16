# 12 詞池 + 6 頁優化順序（V1）

更新日期：2026-05-14  
資料來源：
- `Weekly SOP/history/7d/current_query_baseline.normalized.csv`
- `Weekly SOP/history/7d/current_page_baseline.normalized.csv`
- `Weekly SOP/history/28d/current_query_baseline.normalized.csv`
- `Weekly SOP/history/28d/current_page_baseline.normalized.csv`

## 1) 先確認：你說的「先補齊 7/28 天 KPI 基線」已完成

- 7 天與 28 天已成功匯入並產生 `latest/7d`、`latest/28d` 報表。
- 後續詞池判斷以 28 天為主（趨勢較穩定），7 天用來看短期波動。

## 2) 選詞規則（這版）

1. 主軸用「產品 + 地區」詞型。
2. 以現有 GSC 根詞有曝光者優先（根詞含：窗簾線上估價、三重窗簾、台北窗簾推薦、捲簾一才價格、調光簾一才價格、實木百葉窗價格試算）。
3. 每個詞只綁 1 個主頁，避免關鍵字分散。
4. 先做 6 頁（第 2 步）以便集中資源衝前 10。

## 3) 第一版 12 詞池（每詞 1 主頁）

| # | 主攻詞（產品+地區） | 依據根詞（GSC） | 7d 曝光/排名 | 28d 曝光/排名 | 綁定主頁 |
| --- | --- | --- | --- | --- | --- |
| 1 | 三重窗簾線上估價 | 窗簾線上估價 | 12 / 5.17 | 24 / 7.38 | `https://online.hong-sen.com/calculator/` |
| 2 | 台北窗簾線上估價 | 窗簾線上估價 | 12 / 5.17 | 24 / 7.38 | `https://online.hong-sen.com/calculator/` |
| 3 | 三重窗簾推薦 | 三重窗簾 | 1 / 9.00 | 3 / 10.67 | `https://online.hong-sen.com/location/sanchong/` |
| 4 | 三重窗簾訂製 | 三重窗簾 | 1 / 9.00 | 3 / 10.67 | `https://online.hong-sen.com/location/sanchong/` |
| 5 | 台北窗簾推薦 | 台北窗簾推薦 | - | 1 / 22.00 | `https://online.hong-sen.com/location/taipei/` |
| 6 | 台北窗簾訂製 | 台北窗簾推薦 | - | 1 / 22.00 | `https://online.hong-sen.com/location/taipei/` |
| 7 | 台北捲簾價格 | 捲簾一才價格 | 2 / 10.00 | 3 / 11.00 | `https://online.hong-sen.com/products/roller-blinds/` |
| 8 | 三重捲簾價格 | 捲簾一才價格 | 2 / 10.00 | 3 / 11.00 | `https://online.hong-sen.com/products/roller-blinds/` |
| 9 | 台北調光簾價格 | 調光簾一才價格 | 1 / 2.00 | 1 / 2.00 | `https://online.hong-sen.com/products/zebra-blinds/` |
| 10 | 三重調光簾價格 | 調光簾一才價格 | 1 / 2.00 | 1 / 2.00 | `https://online.hong-sen.com/products/zebra-blinds/` |
| 11 | 台北實木百葉窗價格 | 實木百葉窗價格試算 | 3 / 15.00 | 12 / 15.50 | `https://online.hong-sen.com/products/wooden-blinds/` |
| 12 | 三重實木百葉窗價格 | 實木百葉窗價格試算 | 3 / 15.00 | 12 / 15.50 | `https://online.hong-sen.com/products/wooden-blinds/` |

註記：
- `-` 代表 7 天資料中未出現該根詞（但 28 天有資料）。
- 上表為 V1 詞池，已符合「產品+地區」與「每詞只綁 1 主頁」。

## 4) 第 2 步：6 頁優化順序（照這個做）

1. `https://online.hong-sen.com/calculator/`
2. `https://online.hong-sen.com/location/sanchong/`
3. `https://online.hong-sen.com/location/taipei/`
4. `https://online.hong-sen.com/products/roller-blinds/`
5. `https://online.hong-sen.com/products/zebra-blinds/`
6. `https://online.hong-sen.com/products/wooden-blinds/`

## 5) 每頁要做的固定模板（6 頁都一樣）

1. `title`：主詞放前（產品+地區），控制可讀長度。
2. `meta description`：放「到府丈量/估價/工廠直營/保固」等交易訊號。
3. `H1`：與主攻詞一致，不要一頁多個主詞。
4. 首屏前 120-180 字：直接回答「價格區間 + 施工流程 + 可服務地區」。
5. FAQ 3-5 題：全部對應該頁主詞，不要混到其他頁主詞。
6. 內鏈：每頁至少 3 條導向相關產品頁/地區頁/估價頁。
7. Schema：`WebPage + FAQPage (+ Product/Service)` 與可見文字一致。

## 6) 執行節奏（建議）

1. 先完成 6 頁 on-page（本週）。
2. 上線後第 7 天看 7d：看 CTR 與排名是否上升。
3. 上線後第 28 天看 28d：決定保留詞、替換詞、加碼頁。
