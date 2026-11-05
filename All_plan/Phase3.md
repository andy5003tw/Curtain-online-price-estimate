# Phase 3：8頁 GEO 擴張（雙波上線）

- 狀態：已完成
- 執行日期：2026-05-12
- 最後更新：2026-05-13
- 來源章節："2026-05-12 Phase 3：8頁 GEO 擴張（雙波上線）"

## 原始章節內容
## 2026-05-12 Phase 3：8頁 GEO 擴張（雙波上線）

### 目標與範圍

- 主軸：站內 GEO 擴頁收斂（不含站外 SEO / GBP）。
- 規模：新增 `8` 個 GEO 頁，採雙波次上線。
- 波次 A（台北核心 4 區）：`xinyi`、`songshan`、`zhongzheng`、`beitou`。
- 波次 B（新北轉單 4 區）：`banqiao`、`xinzhuang`、`luzhou`、`zhonghe`。

### 本輪實作變更

- `locationPages` 擴充為型別化資料源，新增欄位並全頁補齊：
  - `cityGroup: 'taipei' | 'new-taipei'`
  - `relatedAreaIds: string[]`（固定 3 筆）
- 既有 GEO 頁（`taipei`、`sanchong`、`daan`、`zhongshan`、`shilin`、`neihu`）同步補上 `cityGroup` 與 `relatedAreaIds`。
- 新增 8 頁完整內容欄位（`title`、`shortDescription`、`keywords`、`districts`、`serviceHighlights`、`featuredProductIds`、`faqs`、`lastModified`）：
  - `/location/xinyi/`
  - `/location/songshan/`
  - `/location/zhongzheng/`
  - `/location/beitou/`
  - `/location/banqiao/`
  - `/location/xinzhuang/`
  - `/location/luzhou/`
  - `/location/zhonghe/`
- 首頁「台北熱門服務區域」改為雙波次卡片：
  - 波次 A｜台北核心 4 區
  - 波次 B｜新北轉單 4 區
- 產品總覽頁新增「地區服務快選」區塊，資料由 `locationPages` 驅動（不再手寫散落連結）。
- GEO 詳頁新增「鄰近服務區域」區塊，依 `relatedAreaIds` 輸出內鏈。
- Footer 維持既有 6 個 GEO 入口，不擴張。
- Schema / Metadata / Sitemap 沿用既有邏輯，未新增高風險 schema 欄位；sitemap 由 `locationPages` 自動收錄。

### 波次 A 執行與驗證（台北 4 頁）

- Build 成功：`npm.cmd run build`，輸出靜態頁數 `60`。
- `out/sitemap.xml` 已收錄：
  - `/location/xinyi/`
  - `/location/songshan/`
  - `/location/zhongzheng/`
  - `/location/beitou/`
- 全量 FTP 上傳完成：`UPLOAD_DONE count=873`。
- Live HTTP 檢查：
  - 4 新頁皆 `200`。
  - legacy 5 條抽測皆維持 `301 -> slug`：
    - `P001`、`P002`、`P003`、`P010`、`P013`。
- Live metadata / schema 抽測：
  - 4 新頁 `title/description/canonical/OG/Twitter/JSON-LD` 全部通過。

### 波次 B 執行與驗證（新北 4 頁）

- Build 成功：`npm.cmd run build`，輸出靜態頁數 `64`。
- `out/sitemap.xml` 新增並收錄：
  - `/location/banqiao/`
  - `/location/xinzhuang/`
  - `/location/luzhou/`
  - `/location/zhonghe/`
- 全量 FTP 上傳完成：`UPLOAD_DONE count=881`。
- Live HTTP 檢查：
  - 8 新頁（A+B）皆 `200`。
  - legacy 5 條抽測皆維持 `301 -> slug`。
- Live metadata / schema 抽測：
  - `/`、`/products/`、`/location/xinyi/`、`/location/banqiao/` 之 canonical / OG / Twitter / JSON-LD 全部通過。
- 內鏈檢查：
  - 首頁已含 8 個新 GEO 連結（A/B 兩組）。
  - 產品總覽頁已含 8 個新 GEO 連結。

### 風險與回滾

- 風險：
  - 雙波全量上傳期間若中斷，可能短暫出現 HTML 與 `_next` 混版。
  - 若後續新增更多 GEO 頁，首頁卡片區塊可能需要分頁或折疊策略。
- 回滾：
  - 若需回退 Phase 3，先回復 `locationPages` 新增 8 頁與新欄位，再 `build + 全量上傳`。
  - 若僅需停用單一地區頁，可移除對應資料列並重新建置上傳。

### 執行日期

- `2026-05-12`

