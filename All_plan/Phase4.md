# Phase 4：GEO 收錄強化與轉換優化

- 狀態：已完成
- 執行日期：2026-05-13
- 最後更新：2026-05-13
- 來源章節："2026-05-13 Phase 4：GEO 收錄強化與轉換優化"

## 原始章節內容
## 2026-05-13 Phase 4：GEO 收錄強化與轉換優化

### 目標與範圍（站內-only）
- 目標：強化既有 GEO 頁收錄訊號一致性，並提升 GEO → 產品/估價導流效率。
- 範圍：僅站內 SEO/GEO/Schema；不含站外 SEO、GBP。

### 本輪實作重點
- GEO 資料層強化（集中化來源）
  - `src/data/locationPages.ts` 新增共用 helper：
    - `geoWaveAIds` / `geoWaveBIds` / `geoExpansionIds`
    - `getLocationPagesByIds()`
    - `getGeoWaveGroups()`
    - `getGeoExpansionPages()`
    - `getServiceAreasForProduct(productId, limit)`
  - 目的：首頁、產品頁、產品詳頁統一由 `locationPages` 驅動，避免手寫散落連結。

- 首頁 GEO 入口與文案優化
  - `src/app/page.tsx` 重建首頁內容與 metadata，保留雙組 GEO 入口：
    - 波次 A：台北核心 4 區
    - 波次 B：新北轉單 4 區
  - GEO 卡片 CTA 文案分流：台北/新北入口文案明確區分。
  - 首頁 FAQ 可見內容與 `FAQPage` JSON-LD 同步。

- 產品總覽 GEO 快選資料化
  - `src/app/products/page.tsx` 改用 `getGeoExpansionPages()`，不再手寫 8 筆 ID。
  - 快選卡片新增地區屬性文案（台北服務頁 / 新北服務頁）。

- 產品詳頁導流與 Schema 風險清理
  - `src/app/products/[slug]/page.tsx`：
    - 新增「可服務區域快速入口」區塊（3~6 筆資料層導流）。
    - 保留產品估價 CTA（產品參數估價 + 整體估價頁）。
    - 移除 `aggregateRating` 殘留欄位，保留可驗證 `Review`。

- 驗證腳本（P1）
  - 新增 `scripts/seo-check.mjs` 與 `npm.cmd run seo:check`：
    - canonical 檢查
    - JSON-LD parse 檢查
    - sitemap URL 可達性（對應 `out` 檔案）
    - robots sitemap 指向檢查
    - legacy `Pxxx` canonical + `.htaccess` 301 規則檢查
    - sitemap 不含 legacy `Pxxx` URL

### 驗證結果
- `npm.cmd run build`：成功（Static pages: 64）。
- `npm.cmd run seo:check`：`SEO check passed.`
- `src` 全域檢索確認高風險欄位已清空：
  - `aggregateRating` / `shippingDetails` / `hasMerchantReturnPolicy` / `returnPolicy` 無殘留。

### 風險與回滾
- 風險：首頁文案與區塊改版後，若需回到舊視覺需以 git 版控回退 `src/app/page.tsx`。
- 回滾最小集合：
  - `src/app/page.tsx`
  - `src/app/products/page.tsx`
  - `src/app/products/[slug]/page.tsx`
  - `src/data/locationPages.ts`
  - `scripts/seo-check.mjs`
  - `package.json`

### 執行日期
- 2026-05-13

