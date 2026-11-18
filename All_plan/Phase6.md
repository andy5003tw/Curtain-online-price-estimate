# Phase 6：新北核心 8 頁 GEO 擴展（雙波 Gate + 首頁 24 入口）

- 狀態：已完成（2026-05-13 live 補證完成）
- 執行日期：2026-05-13
- 最後更新：2026-05-13
- 來源章節："2026-05-13 Phase 6：新北核心 8 頁 GEO 擴展（雙波 Gate + 首頁 24 入口）"

## 原始章節內容
## 2026-05-13 Phase 6：新北核心 8 頁 GEO 擴展（雙波 Gate + 首頁 24 入口）

### 目標與範圍（站內-only）
- 本輪主軸為 GEO 再擴頁，維持站內 SEO/GEO/Schema 範圍，不納入站外 SEO 與 GBP。
- 新增新北 8 頁，採雙波 Gate 上線：Wave A 先通過驗收，再進 Wave B。
- 首頁與產品頁 GEO 入口由 16 擴為 24；Footer 維持 6 入口不擴張。

### 本次決策
- 波次規劃：
  - Wave A：`xizhi`、`taishan`、`wugu`、`shulin`
  - Wave B：`yingge`、`sanxia`、`danshui`、`bali`
- 每波上線後都執行完整 live 驗收（build、FTP、HTTP、metadata/schema、sitemap/robots）。
- 產品舊路徑 `Pxxx -> slug` 301 規則維持現狀，不在本輪調整策略。

### 實作清單
#### P0（已完成）
- `locationPages` 新增 8 筆新北 GEO 資料，完整填入：
  - `title`、`shortDescription`、`keywords`、`districts`、`serviceHighlights`、`featuredProductIds`、`faqs`、`cityGroup`、`relatedAreaIds`、`lastModified`
- 新增 Phase 6 常數與群組：
  - `geoPhase6WaveAIds`
  - `geoPhase6WaveBIds`
  - `geoExpansionIds` 擴為 24 頁
- `getGeoWaveGroups()` 新增回傳：`phase6WaveA`、`phase6WaveB`。
- 首頁 GEO 區塊擴為 6 組卡片，總入口 24。

#### P1（已完成）
- 產品總覽維持由 `getGeoExpansionPages()` 驅動，地區快選自動擴為 24。
- 產品詳頁保留「可服務區域快速入口」與估價 CTA，資料層可自動帶入新增 GEO。

#### P2（驗證）
- `npm.cmd run build` 成功。
- `npm.cmd run seo:check` 成功。
- `out/sitemap.xml` 已收錄 8 個新增 GEO URL，且不含 legacy `Pxxx`。

### 驗收標準
- `locationPages` 資料量由 22 增至 30。
- 首頁 GEO 區塊呈現 24 入口（6 組 x 4）。
- 產品總覽「地區服務快選」輸出完整 24 入口。
- `robots.txt` sitemap 指向維持正確。

### 2026-05-13 Live 驗收補證結果
- `npm.cmd run build` 成功。
- `npm.cmd run seo:check` 成功（`SEO check passed`）。
- Phase 6 新增 8 頁皆 `HTTP 200`：`xizhi`、`taishan`、`wugu`、`shulin`、`yingge`、`sanxia`、`danshui`、`bali`。
- 上述 8 頁 metadata/schema 抽測通過：canonical、`og:title`、`twitter:card`、JSON-LD 可解析。
- 首頁與產品總覽 GEO 快選 24 入口抽測通過（`HOME_GEO24_OK=True`、`PRODUCTS_GEO24_OK=True`）。
- live `robots.txt` sitemap 指向正確；live `sitemap.xml` 未出現 legacy `Pxxx`。
- legacy 舊網址回歸抽測維持 `301 -> slug`（樣本：`P001`、`P006`、`P010`、`P013`）。

### 風險與回滾
- 風險：`relatedAreaIds` 若指向不存在 ID，會導致地區詳頁鄰近連結缺失。
- 風險：大批量 GEO 文案若同質性過高，可能影響搜尋區分度。
- 回滾：可先移除本輪新增 8 筆 `locationPages` 與 Phase 6 常數，重建後重新上傳 `out`。

### 執行日期
- 2026-05-13

