# Phase 5：GEO 第二輪 8 頁擴張（雙波分批上線）

- 狀態：已完成（2026-05-13 live 補證完成）
- 執行日期：2026-05-13
- 最後更新：2026-05-13
- 來源章節："2026-05-13 Phase 5：GEO 第二輪 8 頁擴張（雙波分批上線）"

## 原始章節內容
## 2026-05-13 Phase 5：GEO 第二輪 8 頁擴張（雙波分批上線）

### 目標與範圍（站內-only）
- 本輪主軸為 GEO 再擴頁，維持站內 SEO/GEO/Schema 範圍，不納入站外 SEO 與 GBP。
- 新增 8 個 GEO 頁，採雙波分批上線與驗收：Wave A（台北延伸 4 區）先過 Gate，再進 Wave B（新北延伸 4 區）。
- 首頁與產品頁 GEO 入口同步擴到 16，Footer 維持 6 入口不擴張。

### 本次決策
- 採中等 Gate：Wave A 必須先通過 `build + 主要 URL 200`，再進 Wave B。
- GEO 入口由資料層集中管理：以 `locationPages` + helper 常數驅動首頁與產品頁，避免手寫散落連結。
- 產品舊路徑 `Pxxx -> slug` 的 301 維持現狀，不在本輪改寫規則。

### 實作清單
#### P0（已完成）
- `src/data/locationPages.ts`
  - 新增 8 個地區頁資料：
    - Wave A（台北延伸4）：`wenshan`、`nangang`、`wanhua`、`datong`
    - Wave B（新北延伸4）：`yonghe`、`xindian`、`tucheng`、`linkou`
  - 每頁補齊必填欄位：`title`、`shortDescription`、`keywords`、`districts`、`serviceHighlights`、`featuredProductIds`、`faqs`、`cityGroup`、`relatedAreaIds`、`lastModified`。
  - 擴充波次常數：
    - `geoPhase5WaveAIds`
    - `geoPhase5WaveBIds`
    - `geoExpansionIds`（由 8 擴為 16）
  - `getGeoWaveGroups()` 回傳 Phase 5 四組資料（舊 2 組 + 新 2 組）。
- `src/app/page.tsx`
  - 首頁「台北熱門服務區域」改為 4 組卡片：
    - 波次 A｜台北核心 4 區
    - 波次 B｜新北轉單 4 區
    - Phase 5 Wave A｜台北延伸 4 區
    - Phase 5 Wave B｜新北延伸 4 區
  - 總入口擴為 16，文案同步更新。
- `src/app/products/page.tsx`
  - 持續使用 `getGeoExpansionPages()`，因資料層已擴為 16，產品總覽「地區服務快選」自動輸出 16 頁。
- `src/app/products/[slug]/page.tsx`
  - 維持「可服務區域快速入口」與雙估價 CTA，資料來源保持 `getServiceAreasForProduct()`，可自動帶入新增 GEO。

#### P1（已完成）
- `plan.md` 追加本章節，不覆蓋既有 Phase 歷史章節。

#### P2（驗證）
- Wave A Gate：
  - `npm.cmd run build` 成功。
  - `wenshan/nangang/wanhua/datong` 主要 URL 應為 `200`。
  - 首頁與產品頁需能導入 Wave A 4 頁。
- Wave B 總驗收：
  - 再次 `build` 成功。
  - 8 新頁皆 `200`，`out/sitemap.xml` 含全部新增 URL。
  - 抽測產品新舊網址（新網址 `200`、舊網址 `301 -> slug`）。
  - 抽測產品頁「可服務區域快速入口」與 2 組估價 CTA 字串。
  - metadata/schema（title/description/canonical/OG/Twitter/JSON-LD）可解析。
  - `robots.txt` sitemap 指向維持正確。

### 驗收標準
- `locationPages` 總數由 14 擴到 22。
- 首頁 GEO 區塊呈現 4 組共 16 個入口。
- 產品總覽 GEO 快選呈現完整 16 個入口。
- 產品詳頁仍保留「可服務區域快速入口」與雙估價 CTA。
- sitemap 不含 legacy `Pxxx`，robots 仍指向單一 sitemap。

### 2026-05-13 Live 驗收補證結果
- `npm.cmd run build` 成功。
- `npm.cmd run seo:check` 成功（`SEO check passed`）。
- Phase 5 新增 8 頁皆 `HTTP 200`：`wenshan`、`nangang`、`wanhua`、`datong`、`yonghe`、`xindian`、`tucheng`、`linkou`。
- 上述 8 頁 metadata/schema 抽測通過：canonical、`og:title`、`twitter:card`、JSON-LD 可解析。
- 產品詳頁抽測（`/products/custom-curtains/`）保留關鍵字串：
  - `可服務區域快速入口`
  - `直接估價此產品`
  - `前往整體估價頁`
  - 並存在 `product + area` 估價導流連結。
- `robots.txt` sitemap 指向正確；live `sitemap.xml` 未出現 legacy `Pxxx`。
- legacy 舊網址抽測維持 `301 -> slug`（樣本：`P001`、`P006`、`P010`、`P013`）。

### 風險與回滾
- 風險：GEO 資料量擴張後，若任一頁內容欄位缺漏，可能導致 metadata/schema 或頁面區塊缺值。
- 風險：若 `relatedAreaIds` 指向不存在 ID，會造成地區詳頁鄰近區塊連結缺失。
- 回滾：可先回退本輪新增 8 筆 `locationPages` 與 Phase 5 常數，再重跑 build 並重新上傳 `out`。
- 回滾不影響既有 `Pxxx -> slug` 301 規則。

### 執行日期
- 2026-05-13

