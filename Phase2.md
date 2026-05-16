# Phase 2：301 上線與台北 GEO 擴頁 + 執行補登

- 狀態：已完成
- 執行日期：2026-05-12
- 最後更新：2026-05-13
- 來源章節："2026-05-12 Phase 2：301 上線與台北 GEO 擴頁"、"2026-05-12 執行補登（部署與驗證）"

## 原始章節內容
## 2026-05-12 Phase 2：301 上線與台北 GEO 擴頁

### 目標與範圍

- 正式啟用產品舊網址 `Pxxx -> slug` 的 HTTP 301 收斂。
- 擴充台北核心 GEO 服務頁：`daan`、`zhongshan`、`shilin`、`neihu`。
- 完成站內入口、sitemap、build、FTP 上線與前台 HTTP 驗證。
- 範圍維持站內 SEO/GEO/Schema，不含站外 SEO 或 GBP。

### 本輪實作變更

- `public/.htaccess` 新增 13 條 301 規則，且放在 fallback rewrite 之前：
  - `^products/P001/?$ -> /products/custom-curtains/`
  - `^products/P002/?$ -> /products/seamless-sheer-curtains/`
  - `^products/P003/?$ -> /products/s-fold-curtains/`
  - `^products/P004/?$ -> /products/roman-shades/`
  - `^products/P005/?$ -> /products/roller-blinds/`
  - `^products/P006/?$ -> /products/aluminum-blinds/`
  - `^products/P007/?$ -> /products/wooden-blinds/`
  - `^products/P008/?$ -> /products/bamboo-blinds/`
  - `^products/P009/?$ -> /products/honeycomb-blinds/`
  - `^products/P010/?$ -> /products/zebra-blinds/`
  - `^products/P011/?$ -> /products/soft-sheer-blinds/`
  - `^products/P012/?$ -> /products/hospital-curtains/`
  - `^products/P013/?$ -> /products/vertical-blinds/`
- `locationPages` 新增 4 筆台北核心頁資料：
  - `/location/daan/`
  - `/location/zhongshan/`
  - `/location/shilin/`
  - `/location/neihu/`
- 每頁均填入獨立內容欄位：`title`、`shortDescription`、`keywords`、`districts`、`serviceHighlights`、`featuredProductIds`、`faqs`、`lastModified`。
- Footer「服務區域與選購指南」擴充為 6 個 GEO 入口（`taipei`、`sanchong` + 新增 4 頁）。
- 首頁新增「台北熱門服務區域」區塊，直接連到 4 個新 GEO 頁，避免孤頁。

### 驗證與結果

- Build 成功：`npm.cmd run build`，本輪輸出 `56` 個靜態頁。
- `out/.htaccess` 已包含 13 條 301 規則，位置在 fallback rewrite 之前。
- `out/sitemap.xml` 與 live sitemap 已收錄：
  - `https://online.hong-sen.com/location/daan/`
  - `https://online.hong-sen.com/location/zhongshan/`
  - `https://online.hong-sen.com/location/shilin/`
  - `https://online.hong-sen.com/location/neihu/`
  - 以上 `lastmod` 均為 `2026-05-12`。
- 前台 HTTP 驗證（live）：
  - `https://online.hong-sen.com/` -> `200`
  - `https://online.hong-sen.com/products/custom-curtains/` -> `200`
  - `https://online.hong-sen.com/products/P001/` -> `301` -> `/products/custom-curtains/`
  - `https://online.hong-sen.com/products/P002/` -> `301` -> `/products/seamless-sheer-curtains/`
  - `https://online.hong-sen.com/products/P003/` -> `301` -> `/products/s-fold-curtains/`
  - `https://online.hong-sen.com/products/P010/` -> `301` -> `/products/zebra-blinds/`
  - `https://online.hong-sen.com/products/P013/` -> `301` -> `/products/vertical-blinds/`
  - `https://online.hong-sen.com/location/daan/` -> `200`
  - `https://online.hong-sen.com/location/zhongshan/` -> `200`
  - `https://online.hong-sen.com/location/shilin/` -> `200`
  - `https://online.hong-sen.com/location/neihu/` -> `200`
- Live 抽查 metadata：
  - 首頁、`/products/P001/`、4 個新 GEO 頁 canonical/OG/Twitter 均存在且正確。
  - `/products/P001/` canonical 指向 `/products/custom-curtains/`。
- JSON-LD 抽查（首頁、產品頁、新 GEO 頁）可解析通過。
- 4 個新 GEO 頁內鏈驗證：
  - 每頁皆含產品詳頁導流連結。
  - 每頁皆含估價頁導流連結（`/calculator/`）。

### 部署紀錄

- 已執行 `out` 全量 FTP 上傳至 `ftp.hong-sen.com` 的 `online.hong-sen.com/`。
- 本輪上傳檔案總數：`865` 檔（含 `_next` 與靜態資源）。
- 上傳腳本採 URL 編碼與失敗中止機制，確保含空白/中括號檔名可正確上傳。

### 風險與回滾

- 風險：
  - 若主機 rewrite 規則受其他目錄設定影響，可能出現局部 301 失效。
  - 大量靜態資源上傳若中途中斷，可能造成前台短暫混合版本。
- 回滾：
  - 301 異常時，先從 `.htaccess` 移除新增 13 條規則並重新上傳。
  - 若 GEO 新頁需暫退，可回復 `locationPages` 新增項並重新 build/upload。

### 執行日期

- `2026-05-12`

## 2026-05-12 執行補登（部署與驗證）

### 補登目的

- 補記今日先前未寫入 `plan.md` 的部署與驗證步驟。
- 確保「實作完成 -> 上傳 -> 前台驗證」有完整落地紀錄可追蹤。

### 今日補登執行清單

- 依最新建置結果將 `out` 全量上傳至 FTP 遠端目錄：`online.hong-sen.com/`。
- 實際上傳檔案總數：`857` 檔。
- 上傳後執行 FTP 端抽查：
  - 根目錄 `index.html`、`sitemap.xml`、`robots.txt` 存在。
  - `blog/`、`location/` 目錄存在。
  - `products/custom-curtains/index.html`（新語意網址）存在。
  - `products/P001/index.html`（legacy 相容頁）存在。
  - `_next/static/chunks/app/products/[slug]/` 資源存在。

### 前台 HTTP 驗證結果

- 以下網址狀態碼皆為 `200`：
  - `/`
  - `/products/custom-curtains/`
  - `/products/P001/`
  - `/products/vertical-blinds/`
  - `/products/P013/`
  - `/location/taipei/`
  - `/location/sanchong/`
  - `/robots.txt`
  - `/sitemap.xml`
- Canonical 抽查：
  - `/products/P001/` -> canonical 指向 `/products/custom-curtains/`（正確）。
  - `/products/P013/` -> canonical 指向 `/products/vertical-blinds/`（正確）。
  - `/location/taipei/` -> canonical 自指（正確）。

### 補登日期

- `2026-05-12`

