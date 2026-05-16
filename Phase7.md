# Phase 7：30 頁 GEO 品質收斂（內鏈 + 轉換）與 plan.md 編碼修復

- 狀態：已完成（2026-05-13 Wave A/B live 驗收完成）
- 執行日期：2026-05-13
- 最後更新：2026-05-13
- 來源章節："2026-05-13 Phase 7：30 頁 GEO 品質收斂（內鏈 + 轉換）與 plan.md 編碼修復"

## 原始章節內容
## 2026-05-13 Phase 7：30 頁 GEO 品質收斂（內鏈 + 轉換）與 plan.md 編碼修復

### 目標與範圍（站內-only）
- 在不再擴頁前提下，收斂既有 30 頁 GEO 的內鏈、估價導流與路徑一致性。
- 修復 `plan.md` 全檔 UTF-8 可讀性，保留歷史章節順序與語意。

### 固定決策
- 首頁維持 24 GEO 精選入口，本輪不改首頁區塊結構。
- 新增 `/location/` 作為 30 頁完整樞紐索引頁。
- `/calculator` 支援 `area=<locationId>` 參數，與 `product` 參數可並存。
- 採雙波 Gate：Wave A 完整驗收通過後再進 Wave B。

### 實作清單
#### P0（已完成）
- `plan.md` Phase 6 亂碼章節改寫為 UTF-8 正常可讀內容。
- 本章節追加至 `plan.md`，保留原有歷史不覆蓋。

#### Wave A（架構與高影響路徑）
- 新增 `/location/` 樞紐頁：
  - 30 頁分組入口（台北/新北 + 波次分組）
  - metadata：canonical、OG、Twitter
  - schema：`CollectionPage + BreadcrumbList`
- SEO helper 新增 `buildCalculatorUrl(productId?, areaId?)`，統一產生估價連結 query。
- `/calculator` 導流鏈路支援 `area`（不影響估價公式）。
- 先套用導流一致化於高影響入口：
  - Wave A/B 最新 8 頁 GEO（`xizhi/taishan/wugu/shulin/yingge/sanxia/danshui/bali`）
  - `/location/` 樞紐頁
  - 首頁與產品總覽關鍵估價入口
- GEO 詳頁補齊三段導流：產品導流、估價導流（含 area）、回鏈 `/location/`。

#### Wave B（全量收斂）
- Wave A 導流規格擴展至全 30 頁 GEO。
- 產品詳頁「可服務區域快速入口」保留，並補齊帶 `product + area` 的估價入口。
- `seo:check` 擴充檢查：
  - `/location/` 可達與頁面 metadata/schema 正常
  - GEO 頁存在 `area` 參數估價鏈路
  - sitemap/robots 與 legacy URL 規則一致。

### 驗收標準
- `npm.cmd run build` 成功。
- `npm.cmd run seo:check` 成功。
- `/location/`、30 個 GEO 頁、`/products/`、`/calculator?product=P001&area=xizhi` 可正常開啟。
- 產品新舊網址抽測：新網址 200、舊網址維持 301 -> slug。
- `out/sitemap.xml` 含 `/location/` 與 30 個 `/location/<id>/`，且不含 legacy `Pxxx`。
- 產品詳頁關鍵字串保留：`可服務區域快速入口`、`直接估價此產品`、`前往整體估價頁`。

### 2026-05-13 Wave A/B Live 驗收補證結果
- `npm.cmd run build` 成功。
- `npm.cmd run seo:check` 成功（`SEO check passed`）。
- `/location/`、`/products/`、`/calculator/?product=P001&area=xizhi` 皆 `HTTP 200`。
- `/location/` 樞紐頁 metadata/schema 抽測通過：
  - canonical 正確
  - `og:title` 存在
  - `twitter:card` 存在
  - JSON-LD 可解析
- Wave A 指定 8 頁導流一致化抽測通過：
  - `xizhi`、`taishan`、`wugu`、`shulin`、`yingge`、`sanxia`、`danshui`、`bali`
  - 每頁皆含回鏈 `/location/` 與 `area` 參數估價連結。
- Wave B 全量 30 頁導流一致化抽測通過（`PASS_COUNT=30/30`）：
  - 每頁 `HTTP 200`
  - 每頁皆含回鏈 `/location/`
  - 每頁皆含 `area=<locationId>` 估價導流連結
- 產品詳頁抽測（`/products/custom-curtains/`）關鍵字串保留且含 `product + area` 導流連結。
- legacy 舊網址抽測維持 `301 -> slug`（樣本：`P001`、`P006`、`P010`、`P013`）。

### 風險與回滾
- 風險：導流連結分散修改，若局部遺漏可能造成 `area` 參數鏈路不一致。
- 風險：新增 `/location/` 後若 sitemap 未同步，可能出現收錄訊號不完整。
- 回滾：先回退 `buildCalculatorUrl` 相關鏈路改動與 `/location/` 頁，保留既有 GEO 詳頁主內容；重建並重新上傳 `out`。

### 執行日期
- 2026-05-13

