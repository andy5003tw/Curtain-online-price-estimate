# 12 詞池 + 6 頁優化順序（V2）

更新日期：2026-05-16  
資料來源：
- `Weekly SOP/history/7d/current_query_baseline.normalized.csv`
- `Weekly SOP/history/7d/current_page_baseline.normalized.csv`
- `Weekly SOP/history/28d/current_query_baseline.normalized.csv`
- `Weekly SOP/history/28d/current_page_baseline.normalized.csv`

## 1) 這版目的

- 承接 V1（已完成的 6 頁）後，擴張到下一組「可拉升排名」詞群。
- 維持 `1 keyword = 1 owner page`，避免詞意分散與頁面互搶。
- 以「現有有曝光根詞」優先，先衝前 10，再做大詞擴寫。

## 2) 選詞規則（V2）

1. 根詞必須來自現有 GSC 28 天資料（如：`鋁百葉窗價格試算`、`百葉窗價格試算`、`風琴簾價格`、`訂製窗簾價格`、`窗簾計算機`）。
2. 每個詞綁 1 個主頁，不交叉指派。
3. 下一批固定 6 頁，不拆小批次。
4. 優先把 `position 10~30` 先往前推；`position 1~5` 的詞只做穩定維護。

## 3) 第二版 12 詞池（每詞 1 主頁）

| # | 主攻詞（產品+地區/交易意圖） | 依據根詞（GSC） | 28d 曝光/排名 | 綁定主頁 |
| --- | --- | --- | --- | --- |
| 1 | 台北鋁百葉窗價格 | 鋁百葉窗價格試算 | 2 / 22.50 | `https://online.hong-sen.com/products/aluminum-blinds/` |
| 2 | 三重鋁百葉窗價格 | 鋁百葉窗價格試算 | 2 / 22.50 | `https://online.hong-sen.com/products/aluminum-blinds/` |
| 3 | 台北風琴簾價格 | 風琴簾價格 | 1 / 1.00 | `https://online.hong-sen.com/products/honeycomb-blinds/` |
| 4 | 三重風琴簾價格 | 風琴簾價格 | 1 / 1.00 | `https://online.hong-sen.com/products/honeycomb-blinds/` |
| 5 | 訂製窗簾價格 | 訂製窗簾價格 | 2 / 28.00 | `https://online.hong-sen.com/blog/curtain-price-guide-2026/` |
| 6 | 窗簾訂做價格 | 窗簾訂做價格 | 2 / 28.50 | `https://online.hong-sen.com/blog/curtain-price-guide-2026/` |
| 7 | 訂做窗簾價格 | 訂做窗簾價格 | 1 / 25.00 | `https://online.hong-sen.com/blog/curtain-price-guide-2026/` |
| 8 | 窗簾報價 | 窗簾 報價 | 1 / 27.00 | `https://online.hong-sen.com/blog/curtain-price-guide-2026/` |
| 9 | 窗簾計算機 | 窗簾計算機 | 3 / 15.67 | `https://online.hong-sen.com/calculator/` |
| 10 | 窗簾估價工具 | 窗簾估價 | 2 / 15.00 | `https://online.hong-sen.com/calculator/` |
| 11 | 板橋窗簾推薦 | （地區長尾擴寫） | - | `https://online.hong-sen.com/location/banqiao/` |
| 12 | 新莊窗簾推薦 | （地區長尾擴寫） | - | `https://online.hong-sen.com/location/xinzhuang/` |

註記：
- `-` 表示本輪 baseline 尚未明確出現該詞，屬於 V2 擴張詞，由相同詞型與服務區頁先佈局。
- `風琴簾價格` 雖排名已高，但曝光量低，V2 目標是擴大曝光與點擊，不是硬推排名。

## 4) 第 3 步：6 頁優化順序（V2）

1. `https://online.hong-sen.com/products/aluminum-blinds/`
2. `https://online.hong-sen.com/products/honeycomb-blinds/`
3. `https://online.hong-sen.com/blog/curtain-price-guide-2026/`
4. `https://online.hong-sen.com/calculator/`
5. `https://online.hong-sen.com/location/banqiao/`
6. `https://online.hong-sen.com/location/xinzhuang/`

## 5) 每頁固定製作模板（V2）

1. `title`：主詞在前（地區 + 產品/意圖），避免模糊標題。
2. `meta description`：加入估價、施工、到府丈量、保固等交易訊號。
3. `H1`：與主攻詞同向，不混多主詞。
4. FAQ 3-5 題：只回答該頁主詞，不混其他產品頁詞。
5. 內鏈至少 3 條：產品頁 <-> 地區頁 <-> 估價頁。
6. Schema 與可見文字一致（FAQPage / Product / WebPage）。

## 6) 驗收節奏（V2）

1. 6 頁改完後先 `build + seo:check`。
2. 以 `out/` 全量上傳上線。
3. 上線後第 7 天看 7d（CTR、排名變化）。
4. 上線後第 28 天看 28d，決定保留詞/替換詞/加碼頁。
