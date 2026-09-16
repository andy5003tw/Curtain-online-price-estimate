# 宏森窗簾專案交接文件（Handover for Next AI）

> **建立日期**：2026-09-10  
> **專案名稱**：宏森窗簾線上價格試算與 SEO/GEO 旗艦系統（hong-sen-curtain）  
> **當前分支**：`codex/seo-geo-v3-optimization`  
> **線上正式站**：[https://online.hong-sen.com/](https://online.hong-sen.com/)  
> **本地開發站**：`http://localhost:3000/`  
> **核心治理文件**：[`plan.md`](plan.md) ｜ [`All_plan/Phase8.md`](All_plan/Phase8.md) ｜ [`Weekly SOP/README.md`](Weekly%20SOP/README.md)

---

## 一、 專案核心現狀與技術架構

1. **技術架構**：
   - 前端：Next.js 16（Turbopack）、React 19、TypeScript、純 Vanilla CSS（`src/app/globals.css`）。
   - 輸出模式：`output: "export"` 純靜態匯出（81 個 HTML 靜態頁面生成於 `out/` 目錄）。
   - 後台與 API：PHP 8.x（`/api/calc.php`、`/admin/pricing/`）。
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
- **部署完成（2026-09-16）**：完整 quick deploy 在遠端檔案大小查詢的被動資料通道卡住，因此改以專案既有 `scripts/deploy-ftp.ps1 -Mode paths -Force` 上傳最小必要範圍。`/location/` HTML／RSC 資料、兩張 WebP 及新版 build manifest 共 11 檔均完成（uploaded=11、skipped=0、failed=0）。正式站 live verification 通過：`https://online.hong-sen.com/location/` HTTP 200、canonical 正確、2 組 JSON-LD 可解析、服務地點連結與兩張 WebP 均存在；sitemap 包含 `/location/`，`/products/P003/` 仍 301 至 `/products/s-fold-curtains/`。
