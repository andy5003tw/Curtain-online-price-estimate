# 宏森窗簾專案交接文件（Handover for Next AI）

> **建立日期**：2026-09-10  
> **專案名稱**：宏森窗簾線上價格試算與 SEO/GEO 旗艦系統（hong-sen-curtain）  
> **當前分支**：`codex/seo-geo-v3-optimization`  
> **線上正式站**：[https://online.hong-sen.com/](https://online.hong-sen.com/)  
> **本地開發站**：`http://localhost:3000/`  
> **核心治理文件**：[`plan.md`](plan.md) ｜ [`All_plan/Phase8.md`](All_plan/Phase8.md) ｜ [`Weekly SOP/README.md`](Weekly%20SOP/README.md)

---

## 當前執行狀態（2026-09-24）

- Queue：`seo-geo-a4151d46f72664bd`；Cycle：`seo-geo-v2-a4151d46f72664bd43e3c935`；Round 1 已完成，目標為 `/products/wooden-blinds/`（P007）及 `/products/custom-curtains/`（P001）。
- 本機驗證 receipt 通過；FTP 正式部署 selected=25、uploaded=5、skipped=20、failed=0；queue-target live verification 通過，兩頁 HTTP 200，legacy P001/P007 均 301 至 owner URL。
- Lifecycle 為 `live_verified`，effective workflow consistency valid。下一步等部署後 7 天資料完整結算，且 decision-ready 7d manifest 的 end date 至少為 `2026-10-01`，再記錄 `observing_7d`。
- 今天的內容變更、部署證據與自動部署協調器修復詳見 [`Weekly SOP/2026-09-24-change-log.md`](Weekly%20SOP/2026-09-24-change-log.md)。
- 價格後台的逐產品公式設定、新增試算產品草稿／上架／下架及動態產品清單已於 2026-09-24 上線。同日依使用者回饋恢復原有價格卡的軌道最低尺數、每才最低計價、每才基本安裝費，保留 editor 編輯權限並與公式生效值雙向同步；正式站只補傳 `admin/pricing/index.php`，未覆蓋正式規則檔。權限、欄位對應、設計與驗證紀錄見 [`PRICING_FORMULA_ADMIN.md`](PRICING_FORMULA_ADMIN.md)。

## 一、 專案核心現狀與技術架構

1. **技術架構**：
   - 前端：Next.js 16（Turbopack）、React 19、TypeScript、純 Vanilla CSS（`src/app/globals.css`）。
   - 輸出模式：`output: "export"` 純靜態匯出（81 個 HTML 靜態頁面生成於 `out/` 目錄）。
   - 後台與 API：正式站實測 PHP 7.1.33（2026-09-24；`/api/calc.php`、`/admin/pricing/`），程式須維持 PHP 7.1 相容。
   - 部署機制：PowerShell 自動化 FTP 腳本（`scripts/deploy-ftp.ps1`）強制同步覆蓋至遠端正式主機（`online.hong-sen.com`）。

2. **核心設計規範**：
   - 語言一律使用**繁體中文（台灣習慣用語 zh-TW）**，標點符號一律為**全形中文標點**。
   - 所有圖片引用一律使用 `withBasePath` 解析，避免靜態路徑偏移。
   - 嚴格維持 SEO 結構完整性（不可遺失 H1、Meta Title/Description、Canonical、Schema JSON-LD 與內部連結）。

---

## 二、 已完成工作清單（Completed Checklist - 100% Verified & Deployed）

以下功能已全數實作、完成本機實機測試、SEO 規範驗證，並已強制部署至遠端正式主機生效：

- [x] **1. 首頁 Hero Banner 通透升級（2026-09-10）**
  - 徹底移除 `.hero-overlay-mask`，使客廳大圖以 100% 原始透亮光彩呈現，無暗色遮罩。
  - 大標題（H1）字級微調至 2.4rem，搭配雙重立體文字陰影（`text-shadow: 0 2px 8px rgba(0,0,0,0.95), 0 4px 20px rgba(0,0,0,0.8)`），在明亮背景上呈現極佳閱讀對比。
  - 雙按鈕置底對齊咖啡色橫條上方，配合 `height: 100vh` 達到滿版貼齊零留白。

- [x] **2. 全新獨立 SEO/GEO 樞紐專區（2026-09-10）**
  - 位於四大數字指標列下方，採用白底石質浮雕面板（`.seo-hub-panel`）。
  - 上層配置橘色標籤、`data-ai-answer="true"` 專利問答文案與 3 枚服務承諾打勾標籤。
  - 下層依「雙北熱門行政區估價」、「熱門窗簾款式與材質推薦」、「透明價格指南與品牌服務」結構化排列 15 個內部連結晶片標籤（`.seo-hub-chip-link`），完整保留關鍵字權重與 AI 引用語意。

- [x] **3. 四大指標與常用入口版面平衡（2026-09-10）**
  - 四大數字指標（30+年、13 個可估價產品品項、31 個可索引地區資訊頁、1 個線上估價工具）採用 4 欄平均分散（`repeat(4, 1fr)`），滿版對稱。
  - 三大常用入口配置細緻琥珀金微邊框與微陰影，色調沉穩高雅。

- [x] **4. 首頁 FAQ 雙欄黃金比例重構（2026-09-10）**
  - 徹底解決原本單欄置中右側空洞問題，改為「左問答（60%）＋ 右行動卡（40%）」雙欄佈局（`.faq-layout-grid`）。
  - 左側 5 大常見問答採用標準 `<details>` / `<summary>` 風琴折疊卡（`.faq-details-item`），支援平滑開合與箭頭旋轉動態。
  - 右側配置「還有其他窗簾搭配或丈量疑問？」暖色諮詢行動卡（`.faq-side-card`），內建 3 大品質承諾點檢事項與雙行動按鈕。

- [x] **5. Footer 頁尾 4 欄等高重排（2026-09-10）**
  - 徹底消除第 1～3 欄下方出現近 190px 巨大黑色空洞之問題。
  - 第 4 欄「服務區域與選購指南」由 8 行直列改為「4+4 雙欄對稱子網格」（`.footer-links-grid`），高度大幅縮減 50% 至 4 行（約 170px）。
  - 第 1 欄品牌介紹下方追加「30年工班經驗」、「雙北免費丈量」、「工廠直營透明價」三枚透明琥珀金信任標籤晶片（`.footer-trust-chips`）。
  - 4 大欄位採 `1.15fr 0.95fr 1.05fr 1.6fr` 單行滿版排列，底部精準等高齊平，收斂上下間距，黑色空白完全消失。

- [x] **6. 服務區域總覽頁（`/location/`）頂部 Hero 卡片化重構（2026-09-10）**
  - 將原本散落在平坦底版上的標籤、大標題、說明文案、產品／估價雙按鈕，以及城市快速跳轉錨點，完整收整至一張高質感白底微陰影卡片中（`.location-hero-card`）。
  - 卡片設定為 `width: 100%`，左右兩側邊界與下方「台北市服務網絡」咖啡色巨型橫條邊界垂直齊平對齊。
  - 移除頂部厚重褐色邊線（上面不要有線），維持全周一致的細石色微邊框與現代感圓角。

- [x] **7. 雙北 29 個行政區與 2 個市級總覽架構整合（Phase 8）**
  - 首頁補齊先前遺漏的三重、大安、中山、內湖、士林、台北市總覽 6 個精華地區，形成「8 大核心旗艦案場卡 ＋ 雙北 29 個行政區膠囊矩陣與 2 個市級總覽」雙層架構。
  - `/location/` 移除內部 Phase 工程術語，重構為 4 大生活圈（台北都會核心、台北景觀文教、新北核心捷運、新北延伸景觀），各區卡片配備在地案場完工縮圖與快速帶入估價按鈕。
  - 新增 `/location/new-taipei/` 新北市旗艦專門頁面。

- [x] **8. 全站生產環境編譯與正式上線驗證（2026-09-10）**
  - `npm.cmd run build` 輸出 81 個靜態頁面 100% 成功。
  - `npm.cmd run seo:check` 規範檢查全數通過（`SEO check passed`）。
  - 透過 `scripts/deploy-ftp.ps1` 完成線上正式站覆蓋部署，並通過瀏覽器實機走訪與截圖驗收。

- [x] **9. 服務區 SEO/GEO Schema 口徑校正（2026-09-10，已部署與驗證）**
  - 正式服務口徑統一為：台北 12 區＋新北 17 區＝29 個行政區；加 `/location/taipei/`、`/location/new-taipei/` 兩個市級總覽後，共 31 個可索引地區 URL。
  - `/location/#new-taipei-city` 固定為頁內錨點；新北市主 SEO/GEO URL 為 `/location/new-taipei/`。
  - `/location/` 已使用 `CollectionPage + ItemList` 列出 31 個 canonical URL；市級服務頁使用 `City`、行政區頁使用 `AdministrativeArea`，且均引用唯一公司實體。
  - 已通過 keyword owner、production build、`seo:check`、`seo:preflight`；FTP quick delta 部署共上傳 136 檔、略過 351 檔、失敗 0，另以 paths + Force 補傳同大小但內容更新的 `sitemap.xml`。
  - 正式站驗收通過：首頁、`/location/`、`/location/new-taipei/` canonical 正確；服務總覽 ItemList 為 31 筆且無 fragment URL；新北市 Service `areaServed` 為 `City`；sitemap HTTP 200、63 個 URL，首頁與服務總覽 lastmod 均為 `2026-09-10`。

- [x] **10. 雙北與全區地區專頁（`/location/[area]/`）核心圖文看板與 CSS 美化升級（2026-09-10）**
  - 將原先單調純文字區塊重構為「旗艦級圖文雙層樞紐（Flagship Service & Trust Hub）」。
  - **模組一：雙欄圖文看板**（左圖 4.2 : 右文 5.8 黃金比例），新北精選「疏洪西路客廳落地窗雙層蛇形簾」、台北精選「都會採光豪宅實景」；右側將重複黃底方塊精簡融合為「STEP 01 線上估價 ➔ STEP 02 免費丈量 ➔ STEP 03 書面報價」3 步驟透明流程步進條。
  - **模組二：主要服務涵蓋生活圈面板**，將靜態純文字藥丸升級為可點擊跳轉至各行政區專頁之互動膠囊按鈕（加強內部連結 SEO 權重），並於下方配置「雙北熱門空間完工實景推薦」3 格微相簿（客廳落地窗蛇形簾、書房調光簾、臥室全遮光捲簾）。
  - **模組三：價格試算與 SEO 快速入口分層重構**，主 CTA 大按鈕置頂，SEO 關鍵字連結收整為精緻微邊框晶片矩陣，100% 維持原有 URL 與 Anchor Text 權重。
  - 通過 `npm.cmd run build`、`seo:check`、`seo:preflight` 與 `keyword-owner-check.mjs` 全數檢核，並通過實機瀏覽器走訪截圖驗收。

- [x] **11. 服務區域總覽頁（`/location/`）垂直排列版面回歸與跳轉定位確認（2026-09-10）**
  - 使用者評估後要求維持垂直上下自然排列（台北市在上方、新北市在下方），移除頁籤切換封裝，回歸 100% 原生流暢體驗。
  - 確保台北市（`#taipei-city`）與新北市（`#new-taipei-city`）錨點在視窗中滾動定位精準順暢（`scrollMarginTop: '90px'`），點擊立即平滑導航。

- [x] **12. 服務區域總覽頁（`/location/`）頂部按鈕與專頁按鈕質感優化（2026-09-10，已部署）**
  - **頂部快速跳轉按鈕增加指引文字**：
    - `🏛️ 台北市服務區（12 行政區） 往下捲動 ↓`
    - `🏙️ 新北市服務區（17 行政區） 往下捲動 ↓`
    明確指引訪客點選後會平滑向下捲動定位至對應城市區塊。
  - **雙北分水嶺專頁按鈕配色與 Hover 微動效全面升級**：
    - 按鈕 `[進入台北市全區專頁 →]` 與 `[進入新北市全區專頁 →]`（`.city-header-link-btn`）底色移除原先深咖啡色，改採用與橫條標題字體相同的香檳明亮金黃色（`#fef08a`），搭配深咖啡色字體（`#6a2d0c`，加粗 700），對比鮮明吸睛。
    - 滑鼠懸停（Hover）動態反饋：底色平滑切換為純白亮光色（`#ffffff`），按鈕產生上浮動作（`transform: translateY(-2px)`）並加強立體柔和陰影，按鈕內箭頭 `→`（`.header-btn-arrow`）同時向右微移 4px（`transform: translateX(4px)`），創造出高質感的互動導引。
  - **全站靜態編譯與正式主機增量部署**：
    - 通過 `npm.cmd run build`（81 頁全數編譯成功）、`npm.cmd run seo:check`、`npm.cmd run seo:preflight`。
    - 透過 `npm.cmd run deploy:ftp` 完成快速增量部署（487 個比對檔案，134 個異動檔案上傳成功，353 個檔案跳過，0 失敗）。
    - 線上正式站（`https://online.hong-sen.com/location/`）已抓取 HTML 實機驗證通過。

---

## 三、 下一個 AI 接續任務清單（Next Tasks & Backlog）

接手的 AI 請依以下優先順序推進下一階段任務：

### 任務 1：Weekly SOP 與 Google Search Console（GSC）定期監控
- **背景**：專案具備完整的 Weekly SOP 流程，用於分析最新 7d/28d 的 Search Performance。
- **執行動作**：
  - 檢查目前 GSC 最新資料週期（API final 日期是否達到門檻）。
  - 若使用者指示「請抓最新 7d／28d」，透過既有 Data Gate 取得資料並更新 `Weekly SOP/latest/` 報表。
  - 監控首頁與 29 個行政區、2 個市級總覽改版後之關鍵字排名（如「三重窗簾推薦」、「大安區窗簾」、「台北市窗簾推薦」等）之點閱率（CTR）與曝光變化。

### 任務 2：全站 29 個行政區專頁（`/location/[area]/`）圖文豐富化
- **現況**：目前各行政區專頁已有完整的 SEO 標籤、價格範例與常見問答。
- **優化方向**：
  - 依各行政區生活圈特性，持續補強在地施工案例照片與建案推薦（例如：林口高樓採光窗簾、三重老屋翻新布簾、大安豪宅蛇形簾）。
  - 維持既有 `1 keyword = 1 owner page` 綁定規則，避免關鍵字蠶食（Keyword Cannibalization）。

### 任務 3：線上估價計算機（`/calculator/`）體驗優化
- **現況**：目前支援多種窗型、布簾、紗簾、調光簾即時試算，並可帶入行政區參數。
- **優化方向**：
  - 檢視手機版小螢幕在選擇材質與輸入尺寸時的觸控流暢度。
  - 強化試算結果引導至 LINE 預約到府丈量的轉換按鈕設計。

### 任務 4：程式碼版本控制維護（Git Commit）
- **現況**：本日已完成 commit 與 GitHub 推送；目前本機與 `origin/codex/seo-geo-v3-optimization` 指向同一個 commit。
- **後續原則**：有新的 source、SOP 或交接文件變更時，先確認部署與驗證結果，再依使用者授權建立下一筆 commit 並推送。

### 今日 GitHub 同步紀錄（2026-09-10）
- GitHub 儲存庫：`https://github.com/andy5003tw/Curtain-online-price-estimate.git`。
- 推送分支：`codex/seo-geo-v3-optimization`。
- 已推送 commit：`e215bf5 feat: deploy frontend redesign and geo schema updates`。
- commit 範圍：首頁與服務總覽前端改版、雙北服務區 SEO/GEO Schema 校正、SEO 檢核、Weekly SOP、圖片資產及本交接文件；共 21 個檔案、3,147 行新增、432 行刪除。
- `plan.md` 依 `.gitignore` 的既有規則維持本機治理文件，未強制加入 Git；內容已同步記錄本次部署與驗收結果。

---

## 四、 開發、建置與部署操作 SOP（必讀陷阱與規範）

### 1. 本機開發環境
```powershell
# 啟動本地開發伺服器
npm.cmd run dev
# 瀏覽網址：http://localhost:3000/
```

### 2. 生產環境建置與 SEO 檢查
> **重要注意事項**：在 Windows 環境與沙盒下執行，請一律使用 `cmd.exe /c` 呼叫，並在必要時帶 `BypassSandbox: true`。
```powershell
# 1. 執行靜態建置（輸出至 out/）
cmd.exe /c "npm.cmd run build"

# 2. 執行 SEO 規格檢驗（必須通過）
cmd.exe /c "npm.cmd run seo:check"

# 3. 匯出後預檢
cmd.exe /c "npm.cmd run seo:preflight"
```

### 3. FTP 正式遠端部署 SOP
- **認證設定**：主機系統環境變數中已具備 `$env:FTP_USER` 與 `$env:FTP_PASS`。
- **上傳快取機制**：`scripts/deploy-ftp.ps1` 預設若大小相同會跳過（skip），若有更新 HTML 或 CSS，**必須加上 `-Force` 參數強制覆蓋**。
- **核心路徑快速部署**：
  ```powershell
  # 建立 scripts/upload_patch.txt 填入要上傳的相對路徑後執行：
  pwsh -NoLogo -ExecutionPolicy Bypass -File scripts/deploy-ftp.ps1 -Mode paths -PathFile scripts/upload_patch.txt -Force
  ```
- **全站快速部署**（上傳所有 HTML、最新 CSS/JS chunk、sitemap 與 robots）：
  ```powershell
  pwsh -NoLogo -ExecutionPolicy Bypass -File scripts/deploy-ftp.ps1 -Mode quick -Force
  ```

---

## 五、 關鍵檔案導覽

| 檔案路徑 | 角色與職責說明 |
| :--- | :--- |
| **`plan.md`** | 專案主控制中心，記錄 Phase 1 至 Phase 8 之所有歷史決策與推進紀錄。 |
| **`All_plan/Phase8.md`** | Phase 8 專案細節檔案，含服務區圖片對照表、Hero Banner、FAQ、Footer 與 /location/ 完整演進。 |
| **`src/app/globals.css`** | 全域樣式庫，包含所有展示卡、微浮雕面板、雙欄 FAQ、頁尾 4 欄與 location 頂部卡片樣式。 |
| **`src/app/page.tsx`** | 網站首頁，整合 Hero Banner、三大入口、四大指標、SEO 樞紐專區、29 個行政區導覽、2 個市級總覽與雙欄 FAQ。 |
| **`src/app/location/page.tsx`** | 雙北服務區域總覽頁，包含頂部卡片、台北/新北城市分水嶺與 4 大生活圈圖文卡。 |
| **`src/components/Footer.tsx`** | 全站頁尾組件，包含品牌信任標籤、聯絡資訊、營業時間與 4+4 雙欄導覽。 |
| **`scripts/deploy-ftp.ps1`** | 正式主機 FTP 部署腳本，支援 quick、paths、all 模式與 manifest 產生。 |
| **`scripts/seo-check.mjs`** | 靜態頁面 SEO 規格自動檢核腳本。 |

## 六、服務區口徑（2026-09-10 校正）

- **29 個行政區**：台北市 12 區＋新北市 17 區。
- **2 個市級總覽**：`/location/taipei/` 與 `/location/new-taipei/`。
- **31 個可索引地區 URL**：上述 29 個行政區頁加 2 個市級總覽；`/location/#new-taipei-city` 僅為頁內錨點，不是獨立可索引頁面。

---

## 七、2026-09-16 改版後 SEO／GEO／Schema 稽核交接

### 已核對範圍

- 頁面：`/`、`/location/`、`/location/taipei/`、`/location/new-taipei/`。
- 背景：首頁、服務區總覽與台北市頁新增圖片／CSS 排列；新北市全區專頁已納入正式服務區架構。
- 結果：本機靜態輸出與 `npm.cmd run seo:check` 通過；canonical、單一 H1、JSON-LD 解析、FAQ 與可見內容對齊、Breadcrumb、內部連結與服務區 schema 未發現 P0／阻擋問題。

### 必須維持的正確口徑

- `/location/`：`CollectionPage + ItemList`，列出 31 個 canonical 服務入口。
- `/location/taipei/` 與 `/location/new-taipei/`：`Service.areaServed` 使用 `City`；行政區頁才使用 `AdministrativeArea`。
- 所有服務區頁共同引用唯一公司實體 `https://online.hong-sen.com/#localBusiness`；新北市頁是服務總覽，**不得**建立不存在的地方分店、地址或第二個 LocalBusiness。
- 台北市頁 12 區、新北市頁 17 區；首頁與服務總覽必須繼續連至兩個市級總覽 URL，不能將 `/location/#new-taipei-city` 當成可索引網址。

### 後續 AI 的處理準則

1. 目前 action plan 為 `observation_only`。除非使用者另行核准且有新的 decision-ready GSC cycle，**不要**因本次視覺改版直接修改 source、schema、sitemap、keyword owner、部署或 receipt。
2. 「免費到府丈量／免費報價」、「30 年工班」、「快速到府」、「保固」、「免仲介抽成」等商業承諾，若無服務範圍、費用、排程、保固或報價流程的可公開證據，不新增至 schema 或 `data-ai-answer`；調整可見 FAQ 時，必須同步維持 FAQ JSON-LD parity。
3. 後續新增圖片須使用真實素材：提供唯一、情境化 alt 與鄰近說明；避免重複關鍵字或虛構地標、客戶、建案、案例。另檢查首屏圖片格式／尺寸／LCP，以及非首屏 lazy-load。
4. 若有真實且可核准的素材，可讓台北與新北市頁各增加 1–2 則不同的服務流程、材質情境或完工案例，連至對應行政區或產品頁，以保持兩個市級總覽的 GEO 差異；不可只複製通用文案。
5. 下一個完整 GSC 7d／28d cycle 優先量測首頁、兩個市級頁及其行政區連結：曝光、CTR、排名、Query × Page owner share 與互搶；以數據決定是否建立核准 execution queue。

---

## 八、2026-09-16 服務地點 Banner／NAV／圖片壓縮交接

- `/location/` Hero 已由卡片改為全寬形象 Banner；左側內容與 `.breadcrumb-inner` 對齊（1280px 最大寬度與 24px 內距），桌機由右側窗簾空間圖襯托，手機使用獨立直幅圖。H1、可見服務說明、Schema、canonical、sitemap 與 31 項 `ItemList` 未改。
- 台北市／新北市服務區錨點仍在 Banner 內；「先看全部產品」與「前往線上估價」已移到 Banner 外的置中操作列。
- `src/components/Header.tsx` 的桌機／手機選單均已新增 `📍 服務地點`，順序為「線上估價 → 服務地點 → 官方型錄」。六個一般導航（關於我們、產品系列、施工案例、窗簾知識、線上估價、服務地點）均依目前 pathname 套用深咖啡色 `#6a2d0c`、粗體與 `aria-current="page"`；響應式切換點為 980px。
- 壓縮後網站素材：`public/location_img/location-hero-desktop.webp`（39,996 bytes）及 `location-hero-mobile.webp`（35,684 bytes）。`source/location-hero-original-20260916/` 是使用者提供的本機壓縮來源，禁止部署或提交；未使用的原始 PNG 暫留 `public/location_img/` 作回復備份。
- 驗證結果：`npm.cmd run build`、`npm.cmd run seo:check`、`npm.cmd run seo:preflight`、`npm.cmd run deploy:ftp:dry` 均通過。
- **部署完成（2026-09-16）**：完整 quick deploy 在遠端檔案大小查詢的被動資料通道卡住，因此改以專案既有 `scripts/deploy-ftp.ps1 -Mode paths -Force` 上傳最小必要範圍。`/location/` HTML／RSC 資料、兩張 WebP 及新版 build manifest 共 11 檔均完成（uploaded=11、skipped=0、failed=0）。後續 NAV active 狀態再以同一模式部署首頁、`/about/`、`/products/`、`/cases/`、`/blog/`、`/calculator/`、`/location/` 的 HTML／RSC 與 Header JS/CSS 共 44 檔（uploaded=44、failed=0）。正式站逐頁回讀確認六個目的頁皆含正確 `is-current`、`aria-current="page"` 與深咖啡色 CSS；`/location/` canonical、2 組 JSON-LD、WebP、sitemap 與 `/products/P003/` 301 亦持續正常。

---

## 九、2026-09-16/2026-09-17 AI Banner 與 About 卡片交接（本機待壓縮／待部署）

### 已完成的本機變更

- 台北市與新北市市級頁各新增桌機／手機 AI Hero（共 4 張），並保留台北冷灰藍、新北暖沙金的視覺差異。資產路徑：`public/location_img/city-hero/`；原始備份：`download/city-hero/`。
- `/about/`、`/products/`、`/cases/`、`/blog/`、`/calculator/` 新增共用 `EditorialLandingHero`。每頁都有短 H1、短說明、兩個具體 CTA、桌機／手機各一張 AI 圖；詳細文字與連結移到 Hero 下方導讀區。
- 五頁的原始 AI 圖：`public/nav-hero/`；不可覆蓋備份：`download/nav-hero/`。共 10 張 PNG，basename 為 `about|products|cases|blog|calculator` 搭配 `-desktop` 或 `-mobile`。
- Hero H1 仍是唯一 H1；其 CSS 比照 `/location/` 的較精緻比例：`clamp(2rem, 3.2vw, 3rem)`、800 字重、`line-height: 1.25`。桌機文案上移、CTA 下移；手機版不使用位移。
- About 首段右側施工圖頂緣現對齊左側標題／文字；三項優勢已改為有對應 Lucide 圖示的三欄卡片（試算、品質、交期），並在手機改為單欄。
- 2026-09-17 更新台北／新北市級頁手機 Hero：兩張圖已改為室內斜角取景，保留左上文字留白與城市差異；手機 CTA 改為同一列、左右等寬，並以 `margin-top: auto` 推至 Hero 底部。壓縮後網站實際使用 `taipei-mobile-angle-v2.webp`、`new-taipei-mobile-angle-v2.webp`；PNG 原始版本另存於 `download/city-hero/`，既有備份未覆蓋。

### 使用者壓縮圖片後的必做步驟

1. 使用者會將壓縮版本放到 `source/nav-hero/` 並通知 AI；檔名需保留相同 basename，可改為 `.webp`、`.jpg` 或 `.png`。
2. 先核對每張圖的桌機／手機角色、像素尺寸、檔案大小、無文字／無浮水印及可讀性；若副檔名變更，更新 `EditorialLandingHero` 的圖片路徑。
3. 僅用壓縮版本替換 `public/nav-hero/` 的網站資產；`download/nav-hero/` 必須保留原始 PNG 作回復備份。
4. 重新跑 `npm.cmd run build`、`npm.cmd run seo:check`，並在桌機與手機檢查五頁 Hero 的裁切、H1、CTA 與錨點。

### 壓縮圖片已置換（2026-09-17）

- 使用者提供的壓縮來源已由 `source/nav-hero-20260917/` 與 `source/city-hero-20260917/` 放入網站資產；五個主導航頁的 10 張 Hero 現改引用 `public/nav-hero/*.webp`。
- 台北／新北市級頁的桌機圖與斜角手機圖現改引用 `public/location_img/city-hero/*.webp`；手機圖使用 `taipei-mobile-angle-v2.webp`、`new-taipei-mobile-angle-v2.webp`。
- 壓縮圖保留原像素尺寸（桌機 1672×941、手機 941×1672），檔案約縮減 97%；`download/nav-hero/` 與 `download/city-hero/` 的 PNG 原始備份均未覆蓋。
- 已通過 `npm.cmd run build`、`npm.cmd run seo:check`、`npm.cmd run seo:preflight`，七個靜態頁輸出均含 WebP 引用；尚未 FTP 部署。

### 部署狀態與限制

- 本段 UI 變更已於 2026-09-17 完成 FTP quick 部署與正式站驗收；**尚未建立 Git commit**。
- 不改 Schema、canonical、sitemap、keyword owner 或既有 SEO/GEO lifecycle receipt；若未來部署，僅按使用者授權的前端路徑範圍上傳，且不得將 `download/`、`source/`、`plan.md` 或 `HANDOVER.md` 部署至公開站。

### 2026-09-17 部署嘗試（FTP 連線阻塞）

- 已重新完成 `npm.cmd run build`（81 頁）、`npm.cmd run seo:check`、`npm.cmd run seo:preflight` 與 `npm.cmd run deploy:ftp:dry`，全部通過；乾跑確認 quick 模式僅選取 `out/` 的 487 個網站產物。
- 正式執行 `npm.cmd run deploy:ftp` 時，遠端 `ftp://ftp.hong-sen.com/online.hong-sen.com` 在建立上傳連線即回傳 `Unable to connect to the remote server`；前 14 個檔案均失敗且沒有成功上傳，已主動停止，故正式站未發生部分更新。
- 遠端 FTP 可連線後，先重新執行 `npm.cmd run deploy:ftp:dry`，再執行一次 `npm.cmd run deploy:ftp`；成功後才可進行正式站頁面驗收。仍不得上傳 `download/`、`source/` 或 Markdown 文件，也不要把本次失敗誤記為已部署。
- **再次嘗試（2026-09-17，WebP 素材置換後）**：本機 build、`seo:check`、`seo:preflight` 與 quick dry run 均通過（487 檔）；正式 quick upload 仍在前 6 個檔案的 `GetRequestStream` 階段回傳相同連線錯誤，已停止，uploaded=0。WebP、手機 CTA 與所有本輪 UI 仍只在本機完成。

### 2026-09-17 成功部署與正式站驗收

- 前兩次失敗的原因已釐清為受限沙盒的對外 TCP 連線限制：同一時段在可連網的非沙盒環境可連 `ftp.hong-sen.com:21` 與正式站 HTTPS，並非 FTP 主機或帳密異常。
- 在使用者授權後，以既有 `npm.cmd run deploy:ftp` quick 流程完成部署：selected=487、uploaded=100、skipped=387、failed=0、uploadedMB=10；部署 manifest 為 `Weekly SOP/latest/seo-geo-deployment-manifest.json`。上傳根目錄仍僅為 `out/`，沒有上傳 `download/`、`source/` 或 Markdown 文件。
- 正式站回讀通過：`/about/`、`/products/`、`/cases/`、`/blog/`、`/calculator/`、`/location/taipei/`、`/location/new-taipei/` 均為 HTTP 200，canonical、JSON-LD、對應 WebP 與各頁 CTA 均存在；城市頁並確認斜角手機 WebP 與「線上價格試算」CTA。sitemap 可見城市 URL；產品舊路徑 `/products/P003/` 可正常取得內容。

### 2026-09-17 Hero WebP 補傳熱修

- 正式站畫面檢查發現第一輪 quick deploy 雖已上傳更新後的 HTML，Hero 背景圖未顯示。根因是 `scripts/deploy-ftp.ps1` 的 `quick` 選檔規則僅包含 HTML／TXT／XML／`.htaccess` 與 `_next/static/*`，不會包含 `out/nav-hero/` 或 `out/location_img/city-hero/` 的一般 public WebP。
- 已用既有 `paths + Force` 精確補傳 14 張頁面實際引用的 WebP：五個主導航頁各桌機／手機圖 10 張，加上台北／新北各桌機／手機圖 4 張。結果：selected=14、uploaded=14、skipped=0、failed=0、uploadedMB=0.75。
- 獨立熱修 manifest：`Weekly SOP/latest/2026-09-17-hero-webp-hotfix-deployment-manifest.json`。正式站逐張 GET 驗證 14 張均為 HTTP 200、`image/webp` 且大小正確；`/about/` HTML 同時確認含 `nav-hero/about-desktop.webp` 引用。未上傳任何 `download/`、`source/` 或文件。
- 後續任何新 public 圖片均不得只跑 quick deploy；需在同一次授權部署中以 `paths + Force` 將實際資產路徑一併補傳，並以 HTTP GET 驗證每一個圖片 URL。

### 2026-09-17 Quick 部署靜態資產規則修復

- 已修正 `scripts/deploy-ftp.ps1` 的 `Get-QuickFiles`：quick 模式除 HTML／TXT／XML、`.htaccess` 與 `_next/static/*` 外，現也會自動選取 public 靜態資產副檔名 `avif`、`gif`、`ico`、`jpg/jpeg`、`png`、`svg`、`webp`、`woff/woff2`、`ttf`、`otf`。
- 不連網 dry run 已選取 1,245 個 `out/` 網站產物，並程式化確認本輪 14/14 Hero WebP 均會被列入。未進行第二次正式部署，因目前所有這些 WebP 已由熱修上傳並完成 HTTP GET 驗收。

### 2026-09-17 未使用 PNG 清理

- 已確認 `public/nav-hero/`、`public/location_img/city-hero/` 與 `public/location_img/location-hero-*.png` 的 16 張 PNG 均沒有頁面、CSS、程式或文件引用；現行網站僅引用已部署的 WebP。
- 已移除 `public/` 的 16 張未使用 PNG：10 張主導航與 2 張城市桌機圖已比對 SHA-256 與既有 `download/` 備份一致後刪除；2 張城市舊手機圖及 2 張服務總覽圖則先以 `*-public-archive.png`／原檔名備份至 `download/` 再移除 public 副本。
- 清理後 `public/` 此三個 Hero 位置的未使用 PNG 為 0；所有 WebP 與既有高品質備份均保留。

---

## 十、2026-09-25 `/location/` 城市服務卡片合併（已部署）

### 使用者確認的目標

`/location/` 的台北市與新北市區塊各有兩張重複卡片：上方「城市服務網絡」橫幅與下方右側「城市窗簾服務總覽」內容卡。使用者已選定 **圖左、整合資訊卡右** 的版型：保留城市實景圖片，將城市名稱、行政區數、服務特色、完整說明與行動按鈕合併到右側單一卡片；每個城市只顯示一次城市資訊與城市專頁入口。

### 實作位置與做法

- 修改 `src/app/location/page.tsx` 的 `renderedCityGroups` 區塊。保留 `id={cityGroup.anchorId}`、左側 `.metro-image-card`、群集生活圈內容與所有既有連結網址。
- 移除 `.city-section-header` 與其「進入台北市／新北市全區專頁」按鈕 JSX；城市專頁入口只保留在右側整合卡的主要 CTA。
- 右側 `.metro-content-card` 改為下列階層：
  1. 城市識別小標籤（既有 `tagText`）。
  2. `h2` 顯示既有 `badgeText`，即「台北市／新北市服務網絡｜涵蓋 X 個行政區」。
  3. 服務特色短文顯示既有 `subText`。
  4. 詳細服務說明顯示既有 `heroDesc`。
  5. 保留「查看全區專頁」與「線上估價」兩個 CTA。
- `heroTitle`、`heroFeature` 是被合併內容重複的舊資料，不再渲染；可從 `CityGroupDef` 與兩個城市資料物件移除，避免未使用欄位。
- 修改 `src/app/globals.css`：移除不再使用的 `.city-section-header`、`.city-header-link-btn` 及相關 Hover 規則；以暖白／白色為整合內容卡底色，咖啡色只用於右側卡外框、標題重點與主要按鈕，禁止改為深咖啡整片底色。
- 將原本新北市 `.city-section-header.new-taipei { margin-top: 3.5rem; }` 的段落距離改掛在新的城市區塊外層，確保台北與新北區塊仍有清楚分隔。
- 維持既有桌機 4:6 圖文比例，以及 860px 以下圖片在上、內容在下的單欄排列。不可改動 `/location/taipei/`、`/location/new-taipei/` 市級專頁的內容、Schema、canonical、sitemap 或 keyword owner。

### 驗收與限制

1. 桌機與手機確認台北／新北各只出現一次城市名稱、行政區數、城市專頁 CTA；左側圖片、右側說明與估價入口均保留。
2. 點擊 `#taipei-city`、`#new-taipei-city` 仍可正確定位；城市專頁與 `buildCalculatorUrl(undefined, hero.id)` 產生的估價連結必須維持原行為。
3. 依序執行 `npm.cmd run build`、`npm.cmd run seo:check`、`npm.cmd run seo:preflight`；不可讓 SEO 檢查與 build 平行執行，避免讀到未完成的 `out/`。
4. 本次已完成本機前端實作與驗證；2026-09-25 已依使用者授權部署。未建立 Git commit；FTP 只上傳建置產物，不上傳 Markdown、`download/` 或 `source/`。

### 本次執行結果（2026-09-25）

- 已移除雙北重複的 `.city-section-header` 與 `.city-header-link-btn`，並把城市標題、服務摘要、完整說明與城市專頁 CTA 合併至右側 `.metro-content-card`。
- 已新增 `.city-overview` 與 `.metro-content-lead` 樣式；維持圖左文右、暖白底、咖啡色外框與 860px 以下單欄 RWD。
- 依使用者後續回饋，雙北右側整合卡改用與 `/location/` Banner 左側相同的 banana 米色 `#f4eee5`，咖啡色仍只作外框與重點色。
- 手機版服務區快速入口已改為水平置中，台北與新北兩顆按鈕在窄螢幕換行時仍各自置中；桌機排列維持不變。
- `npm.cmd run build`：通過，81 頁靜態頁成功匯出。
- `npm.cmd run seo:check`：通過。
- `npm.cmd run seo:preflight`：通過。
- `node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs`：通過，14 rows／87 unique normalized keywords。
- `out/location/index.html` 抽查：舊標題條與舊標題條按鈕 class 為 0；`#taipei-city`、`#new-taipei-city` 兩個錨點仍存在。

---

## 十一、2026-09-25 市級 Banner 與 `/location/` 總覽對齊

- `/location/taipei/` 與 `/location/new-taipei/` 已改直接使用 `EditorialLandingHero`，不再維護另一套 Banner 結構；桌機明確固定 31rem 高度、1280px 內容寬度、標題／說明字級與行距、CTA 3rem 高度與相同內距。
- 市級頁與六個主導覽頁共用同一個 Banner 元件、固定 Banner 高度（桌機 31rem、手機 37rem）、圖片 `height: 100%` 裁切邏輯與兩顆 CTA；城市圖片、配色、文案、估價 URL 及 `data-ai-answer` 標記保留。
- 手機版市級 Banner 改為 37rem 高度，使用與總覽相同的標題縮放、內容留白及可換行 CTA；台北／新北原有圖片與配色變數保留。
- 本次只調整 `src/app/globals.css`，未改動市級頁的可見文字、Schema、canonical、sitemap 或連結行為。
- 驗證結果：`npm.cmd run build`、`npm.cmd run seo:check`、`npm.cmd run seo:preflight` 與 keyword owner check 均通過；已於 2026-09-25 部署正式站，結果見第十三節。

---

## 十二、2026-09-25 六個主導覽頁共用 Banner 設定

- `/about/`、`/products/`、`/cases/`、`/blog/`、`/calculator/`、`/location/`、`/location/taipei/`、`/location/new-taipei/` 均使用 `EditorialLandingHero`；只保留各頁圖片、文字與色彩主題差異，Banner 尺寸與 CTA 版型共用。
- 桌機 Banner 與圖片容器固定為 31rem，手機版固定為 37rem；圖片維持絕對定位、`width: 100%`、`height: 100%`、`object-fit: cover`。
- 兩顆 CTA 統一為固定 `height: 3rem`、`min-height: 3rem`、`box-sizing: border-box`、`line-height: 1.2`，並使用 stretch 對齊；手機版沿用相同按鈕高度並允許內容換行。
- 主要與次要 CTA 均使用相同的向下陰影範圍，避免主要按鈕因陰影延伸而在視覺上比次要按鈕更高。
- 主要 CTA 補上透明 1px 外框，與次要 CTA 的 1px 外框維持相同內容區高度，讓文字、箭頭與按鈕外框在同一條水平基線上。
- 設計差異僅限各頁既有的背景、文字與主色變數；計算頁的深色遮罩與次要按鈕配色保留。
- 本次僅調整 `src/app/globals.css` 與本交接紀錄，未改動頁面文字、Schema、canonical、sitemap 或連結行為；已於 2026-09-25 部署，結果見第十三節。

---

## 十三、2026-09-25 導覽頁 UX 補強與正式部署

### 前端內容與版型

- `/products/`：置中選款導讀；8 個快速連結拆為「估價與選款」及「材質與服務」兩張卡，各 4 項。連結及五個 FAQ 均加入符合既有琥珀／石色系的 Lucide 圖示；三個產品分類標題置中。頁尾「先看價格指南」在一般狀態改為較淺的可讀字色，Hover 時改為深色。
- `/cases/`：導讀標題與內文置中並限制閱讀寬度；既有連結重組為 3 張卡，每個入口都有小圖示。五個施工案例 FAQ 改為可展開項目，問題前放置對應的大圖示。
- `/blog/`：所有文章入口改為「挑選與材質指南」及「價格、保養與安裝指南」兩張卡；每篇連結依文章分類顯示小圖示。
- `/calculator/`：相關閱讀連結整理為 3 張卡與一致的圖示；「試算前先看三個重點」卡片與 FAQ 補上圖示。FAQ 每題採一個主題圖示的版型，避免同時呈現 Q、A 兩個重複圖示。
- `/location/`：雙北城市資訊合併為圖片加單一整合內容卡；整合卡使用 banana 米色 `#f4eee5`，咖啡色只作外框、重點文字與主要 CTA。手機的台北／新北快速入口按鈕可換行且各自置中。
- `/location/taipei/`、`/location/new-taipei/`：改用共用 `EditorialLandingHero`，使 Banner 高度、圖片裁切、內容寬度與兩顆 CTA 的 3rem 高度，和 `/about/`、`/products/`、`/cases/`、`/blog/`、`/calculator/`、`/location/` 相同。

### SEO 與行為邊界

- 未變更 canonical、metadata、JSON-LD、sitemap、keyword owner 或公開計價 API 的請求／成功回應格式。
- 前端試算器仍以靜態產品資料做首次渲染；正式站會再請求 `/api/products.php`，因此已上架的新試算產品可即時出現在選單，草稿與下架品項不會出現。

### 驗證與部署紀錄

- 本機通過：`npm.cmd run build`（81 個靜態頁）、`npm.cmd run seo:check`、`npm.cmd run seo:preflight`、`node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs`（14 rows／87 unique normalized keywords）。
- 部署前 quick dry run 從 `out/` 選取 1,229 個網站產物；正式 FTP quick deploy 結果為 selected=1,229、uploaded=179、skipped=1,050、failed=0、uploadedMB=15.21。未上傳原始碼、Markdown、`download/`、`source/` 或 `private/`。
- 部署 manifest：`Weekly SOP/latest/seo-geo-deployment-manifest.json`。
- 正式站回讀確認 `/location/`、`/location/taipei/`、`/location/new-taipei/` 可正常開啟，雙北 Hero、主要／次要 CTA、城市專頁入口、估價 URL 與導覽連結皆存在；主導航頁的更新產物亦已由同一次部署上傳。
