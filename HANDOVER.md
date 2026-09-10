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
- **現況**：目前工作目錄下所有程式碼與樣式已編譯並部署上線，工作目錄包含：
  - 修改檔案：`src/app/page.tsx`、`src/app/globals.css`、`src/app/location/page.tsx`、`src/components/Footer.tsx` 等。
  - 新增紀錄文件：`All_plan/Phase8.md`、`plan.md`、`HANDOVER.md`。
- **建議動作**：經使用者同意後，可建立清楚的 Git commit（例如：`feat: upgrade homepage hero/seo-hub/faq/footer and location hub card layout`）並推播至遠端分支。

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
