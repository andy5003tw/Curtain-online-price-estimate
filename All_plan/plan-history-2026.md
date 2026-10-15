# Curtain Online 2026 歷史執行紀錄

本檔由根目錄 plan.md 抽出已完成與補登紀錄，用於保留證據與降低日常 AI 任務 token 消耗。

## 本輪執行紀錄（2026-05-16）

- [x] 6 頁詞頁對齊改寫完成（metadata/H1/FAQ/內鏈）。
- [x] `npm.cmd run build` 成功。
- [x] `npm.cmd run seo:check` 顯示 `SEO check passed`。
- [x] `out/` 全量 FTP 上傳至 `online.hong-sen.com/`（完成上傳 `916` 檔）。
- [x] live 驗收完成（6 目標頁 `HTTP 200`、canonical、JSON-LD、sitemap、legacy 301）。

## 下一批啟動清單（V2）

- [x] 依 [12-keyword-pool-v2-2026-05-16.md](../Weekly%20SOP/12-keyword-pool-v2-2026-05-16.md) 完成第 3 步 6 頁詞頁對齊。
- [x] 完成後執行 `npm.cmd run build` 與 `npm.cmd run seo:check`。
- [x] `out/` 全量 FTP 上傳至 `online.hong-sen.com/`（含 URL encode 路徑重跑，`FAIL=0`）。
- [x] 完成 live 驗收（6 目標頁 200、canonical、JSON-LD、sitemap、legacy 301）。

## 本輪執行紀錄（2026-05-16，V2）

- [x] 6 頁詞頁對齊改寫完成（`/calculator/`、`/location/banqiao/`、`/location/xinzhuang/`、`/products/aluminum-blinds/`、`/products/honeycomb-blinds/`、`/blog/curtain-price-guide-2026/`）。
- [x] `npm.cmd run build` 成功。
- [x] `npm.cmd run seo:check` 顯示 `SEO check passed`。
- [x] `out/` 全量 FTP 上傳至 `online.hong-sen.com/`（`TOTAL=916`、`FAIL=0`）。
- [x] live 驗收完成（6 目標頁 `HTTP 200`、canonical、JSON-LD、sitemap、legacy `P006/P009` 301 正常）。

## 本輪執行紀錄（2026-05-16，固定 6 頁輪轉）

- [x] 固定 6 頁改寫完成（`/calculator/`、`/location/sanchong/`、`/location/taipei/`、`/products/roller-blinds/`、`/products/zebra-blinds/`、`/products/wooden-blinds/`）。
- [x] `npm.cmd run build` 成功。
- [x] `npm.cmd run seo:check` 顯示 `SEO check passed`。
- [x] `out/` 全量 FTP 上傳至 `online.hong-sen.com/`（URL encode 路徑重跑，`TOTAL=916`、`FAIL=0`）。
- [x] live 驗收完成（6 目標頁 `HTTP 200`、canonical、JSON-LD、sitemap 正常）。
- [x] legacy 301 驗收完成（`P005 -> roller-blinds`、`P007 -> wooden-blinds`、`P010 -> zebra-blinds`）。

## 本輪執行紀錄（2026-05-17，估價後台與安全上傳）

- [x] 同網域估價後台骨架上線：`/admin/pricing/login.php`、`/admin/pricing/`、`/admin/pricing/users.php`、`/admin/pricing/logout.php`。
- [x] 前台估價改為呼叫後端 API：`POST /api/calc.php`（前台不再持有公式計算邏輯）。
- [x] 後台介面完成繁體中文化（登入、規則管理、人員管理、提示訊息）。
- [x] 產品顯示補齊中英對照：`P001~P013` 於後台顯示 `英文（中文）`。
- [x] `README.md` 已改為繁體中文版本，並更新部署與後台操作說明。
- [x] 已完成 FTP 上線補檔（`admin/pricing/*`、`api/calc.php`、`private/lib/*`、`private/.htaccess`），並確認端點回應正常。

## GitHub 安全上傳邊界（2026-05-17）

- 敏感檔不上傳 GitHub：
  - `private/users.php`（帳號與密碼雜湊）
  - `private/pricing-rules.php`（實際商業計價規則）
  - `private/runtime/*`、`private/logs/*.log`、`private/backups/*`
- 已更新 `.gitignore` 強化排除規則（含 `*.pid` 與 `private/runtime/*.pid`）。
- GitHub 僅提交「程式碼、後台頁面、API、文件與非敏感設定」。

## 本週可執行週計畫（2026-05-28 ~ 2026-06-03）

### 本週基準（2026-05-28 最新報表）

- 7d 與 28d 匯入已完成，報表已更新到：
  - `Weekly SOP/latest/7d/`
  - `Weekly SOP/latest/28d/`
- 28d 重點頁（all queries）：
  - `/calculator/`：`impr=284`、`CTR=7.04%`、`position=12.31`
  - `/blog/curtain-price-guide-2026/`：`impr=127`、`CTR=3.15%`、`position=5.56`
  - `/location/sanchong/`：`impr=76`、`CTR=1.32%`、`position=9.13`
  - `/`：`impr=47`、`CTR=0%`、`position=7.64`
- 28d 重點 query：
  - `窗簾價格試算`：`impr=15`、`position=11.33`
  - `三重窗簾`：`impr=12`、`position=10.75`
  - `實木百葉窗價格試算`：`impr=11`、`position=16.27`

### 目標（本週只做 6 件事）

1. 以 `窗簾價格試算`、`三重窗簾`、`實木百葉窗價格試算` 為主軸，完成 6 頁 title / FAQ / 內鏈強化。
2. 優先救 `CTR` 頁：`/`、`/blog/curtain-price-guide-2026/`。
3. 優先推 `前 10 邊緣` 頁：`/location/sanchong/`、`/location/zhongzheng/`、`/location/taipei/`。
4. 固定完整 6 頁批次執行，不拆小批次。
5. 每輪固定執行 `npm.cmd run build`、`npm.cmd run seo:check`、`npm.cmd run seo:preflight`。
6. 完成 `out/` 全量上傳與 live 驗收（200 / canonical / JSON-LD / title / 目標內鏈）。

### 本週固定 6 頁（owner page）

- `/`
- `/calculator/`
- `/blog/curtain-price-guide-2026/`
- `/location/sanchong/`
- `/location/zhongzheng/`
- `/location/taipei/`

### 頁面執行規格（標題 / FAQ / 內鏈 / 驗收）

| 頁面 | 標題調整 | FAQ 調整 | 內鏈調整 | 驗收欄位 |
| --- | --- | --- | --- | --- |
| `/` | 首屏標題加入「窗簾價格試算 / 線上估價」意圖詞；維持品牌詞在尾端。 | 新增 1 題：「窗簾價格試算後多久可正式報價？」 | 新增到 `/calculator/`、`/blog/curtain-price-guide-2026/`、`/location/sanchong/` 的明確錨文字。 | 200、title 生效、FAQ JSON-LD 可解析、首頁內鏈可點擊。 |
| `/calculator/` | 強化「1 分鐘試算」與「安裝費」承諾；保留台北/三重地區詞。 | 新增 1 題：「三重窗簾價格試算後如何比價？」 | 產品區與導覽區固定連到 `/location/sanchong/`、`/location/zhongzheng/`、價格指南。 | 200、canonical 固定 `/calculator/`、title/description 生效、FAQ JSON-LD 正常。 |
| `/blog/curtain-price-guide-2026/` | 標題前段放「2026 窗簾價格指南」+「1 分鐘看懂」提升 CTR。 | 新增 1 題：「同尺寸為何報價不同（窗型/配件/施工）？」 | 強化到 `/calculator/`、`/location/sanchong/`、`/location/zhongzheng/` 的上下文內鏈。 | 200、title 生效、文章內至少 3 個目標內鏈、FAQ JSON-LD 正常。 |
| `/location/sanchong/` | 標題保留「三重窗簾推薦」+「三重窗簾價格試算」。 | 新增 1 題：「搜尋三重窗簾後最快比價流程」。 | 首屏與服務重點區加強連到 `/calculator/`、`/products/wooden-blinds/`。 | 200、title 生效、FAQ 命中三重主詞、內鏈可點擊。 |
| `/location/zhongzheng/` | 標題加入「中正區窗簾價格試算」。 | 新增 1 題：「中正區先比較哪三種品項最有效率？」 | 加強到 `/calculator/`、`/products/zebra-blinds/`、價格指南。 | 200、title 生效、FAQ 命中中正區主詞、內鏈可點擊。 |
| `/location/taipei/` | 標題加入「台北窗簾價格試算」字樣（不改掉既有品牌語意）。 | 新增 1 題：「台北窗簾線上估價後多久可丈量？」 | 新增到 `/calculator/`、`/blog/curtain-price-guide-2026/`、`/location/sanchong/` 比價導流。 | 200、title 生效、FAQ JSON-LD 正常、曝光回升觀察。 |

### Query Owner 對齊（本週固定）

- `窗簾價格試算` -> `/calculator/`
- `三重窗簾` -> `/location/sanchong/`
- `實木百葉窗價格試算` -> `/products/wooden-blinds/`（輔助導流 `/calculator/`）

### 執行日程（可直接照跑）

1. `2026-05-28`：7d / 28d 匯入與報表更新（已完成）。  
2. `2026-05-28`：完成 `/`、`/calculator/`、`/blog/curtain-price-guide-2026/`、`/location/sanchong/`、`/location/zhongzheng/`、`/location/taipei/` 改寫（本次執行）。  
3. `2026-05-28`：執行 `npm.cmd run build`、`npm.cmd run seo:check`、`npm.cmd run seo:preflight`。  
4. `2026-05-28`：`out/` 全量 FTP 上傳至 `online.hong-sen.com/`。  
5. `2026-05-28`：live 驗收（200 / canonical / JSON-LD / title / 目標內鏈）。  
6. `2026-06-03`：回看 7d（微調）與 28d（保留詞 / 替換詞）決策。

### 結案標準（本週）

- 技術面：`build` / `seo:check` / `seo:preflight` 全綠。  
- 上線面：6 頁 live 驗收全部通過。  
- 內容面：6 頁都完成「標題 + FAQ + 內鏈」三件套。  
- 數據面：
  - `窗簾價格試算`、`三重窗簾`、`實木百葉窗價格試算` 至少 2 詞排名向前。
  - 下一輪 7d 至少看到「`/` 或價格指南」其中 1 頁 CTR 回升。

## 2026-05-29 補充執行紀錄（補登）

- [x] `/blog/curtain-price-guide-2026/` 已接 `SEO_SNIPPET_VARIANT`，新增 snippet A/B（title + meta description）並只套用 price-guide。
- [x] `實木百葉窗價格試算` owner page `/products/wooden-blinds/` 已完成新一輪強化（P007 meta、Hero 文案、FAQ、LSI 段落、內鏈）。
- [x] 三詞導流內鏈補強已完成（`/location/taipei/`、`/location/sanchong/`、`/location/zhongzheng/`、`/calculator/`、`/blog/curtain-price-guide-2026/`、首頁入口）。
- [x] 技術驗收（2026-05-29 重跑）已全綠：`npm.cmd run build`（Static pages: 81）、`npm.cmd run seo:check`、`npm.cmd run seo:preflight`。
- [ ] 上線補證待補：本地目前未見 2026-05-29 專屬 FTP / live 驗收 log；若已完成上線，需把證據檔補存到 `Weekly SOP/latest/`。

## 2026-06-04 GSC 7d / 28d 微調與上線紀錄

- [x] 已檢查新匯入 7d / 28d 報表，本輪不重做整套詞池，維持既有 owner page。
- [x] `/blog/curtain-price-guide-2026/`：28 天曝光 `127 -> 189`，但 CTR `3.15% -> 1.06%`、排名 `5.56 -> 7.55`；已優先救 CTR，調整 title / meta / 首屏摘要與 FAQ、內鏈。
- [x] `/`：28 天曝光 `47 -> 69`，CTR 仍 `0%`、排名 `7.64 -> 11.00`；已強化首頁首屏與摘要，補「窗簾價格試算 / 線上估價 / 三重窗簾」語意與 CTA。
- [x] `/calculator/`：28 天曝光 `299`、CTR `7.02%`，主詞「窗簾價格試算」排名約 `11.41`；已小幅補 FAQ / 內鏈，並拆出 `CalculatorClient`、延後 QR 載入以改善首屏載入負擔，未大改估價流程。
- [x] `/products/wooden-blinds/`：28 天曝光 `21 -> 87`、排名 `53.67 -> 27.08`，7 天「實木百葉窗價格試算」約 `11.40`；已加碼 title / meta / Hero / FAQ / 價格說明與導向試算器內鏈。
- [x] `/location/sanchong/`：28 天曝光 `81`、排名 `9.16`，CTR `1.23%`；維持 owner 不換詞，已微調三重頁 title / meta 摘要 / 服務重點 / FAQ，估價 CTA 帶入 `area=sanchong`。
- [x] 額外候選 `/products/seamless-sheer-curtains/`：28 天曝光增至 `31`、排名 `7.94`，但 CTR `16.67% -> 3.23%`；已列入下一輪 CTR 修正候選，本輪不改頁面內容。
- [x] 舊索引檢查：`/calculator/?product=P009` live `200` 且 canonical 收斂到 `/calculator/`；`/products/P001/` live `301 -> /products/custom-curtains/`，不建立新優化頁。
- [x] 技術驗收已通過：`npm.cmd run build`、`npm.cmd run seo:check`、`npm.cmd run seo:preflight`。
- [x] 已完成相關 `out/` 靜態檔 FTP 上傳與 live 驗收：價格指南、首頁、試算器、實木百葉、三重頁皆確認 `HTTP 200`、canonical、title / meta、FAQ / 目標內鏈生效。

## 2026-06-17 固定 SEO/GEO V3 流程落地紀錄

- [x] 已依最新 `2026-06-17` 7d / 28d 報表建立 V3 詞池：[12-keyword-pool-v3-2026-06-17.md](../Weekly%20SOP/12-keyword-pool-v3-2026-06-17.md)。
- [x] 已選定固定 6 頁：`/blog/curtain-price-guide-2026/`、`/calculator/`、`/products/wooden-blinds/`、`/products/seamless-sheer-curtains/`、`/`、`/location/taipei/`。
- [x] 已完成 source 內容調整：title / meta description / H1 或首屏 / FAQ / 內鏈錨文字 / JSON-LD 可見內容對齊。
- [x] `node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs` 通過。
- [x] `npm.cmd run build` 成功（Static pages: 81）。
- [x] `npm.cmd run seo:check` 顯示 `SEO check passed`。
- [x] `npm.cmd run seo:preflight` 顯示 `SEO preflight passed`。
- [x] `npm.cmd run deploy:ftp:dry` 成功，quick mode 選取 190 個部署關鍵檔案。
- [x] `npm.cmd run deploy:ftp` 已完成 quick mode 上線；重跑後 190 個檔案皆顯示 remote same-size、failed=0，遠端已與本次 build 收斂。
- [x] Live 驗收完成：6 頁皆 `HTTP 200`，canonical 正確，title 存在，FAQ JSON-LD 存在，sitemap 包含目標 URL，`/products/P007/` 維持 `301 -> /products/wooden-blinds/`。
