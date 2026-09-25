# Curtain Online Weekly SOP UI 更新規劃設計書

> 文件用途：定義 Curtain Online Weekly SOP 的下一版 UI、互動與技術邊界。此文件是設計規格，不改變既有 GSC、queue、receipt、FTP 或 lifecycle 行為。

## 1. 目標與成功標準

### 目標

保留 Curtain 現有「日常操作成本低、狀態可見性高、主次操作清楚」的優點，並將狀態判斷從大型 HTA 逐步移到可測試的 PowerShell projection。

### 成功標準

- 使用者開啟 UI 後五秒內可理解目前狀態、阻擋原因與唯一安全下一步。
- 主畫面同一時間只有一個 state-changing primary action。
- 所有 disabled 按鈕都顯示不可用原因；不以顏色或猜測讓使用者判讀流程。
- UI 不再自行推導 queue、receipt、lifecycle 或 deploy eligibility；只呈現後端 projection。
- 任何不一致、資料過期或 projection 讀取失敗時，所有會改變 workflow 的操作 fail closed。
- 既有 GSC、queue provenance、validation receipt、FTP、live verify、7d／28d lifecycle gate 行為不變。

## 2. 使用者與操作情境

| 使用者 | 高頻工作 | UI 應提供的答案 |
| --- | --- | --- |
| 日常操作者 | 更新 GSC、處理本輪 SEO/GEO 工作 | 資料是否新鮮？現在唯一要做什麼？ |
| 審核者 | 查看 queue、receipt、blocker | 目前資料是否一致？為何可／不可前進？ |
| 部署人員 | dry-run、正式部署、live verify | 是否已 local_validated？部署前還缺什麼？ |
| 成效檢視者 | 7d／28d review、AI Visibility | 目前量測到哪一階段？結果與證據在哪裡？ |

## 3. 資訊架構與版面

### 主畫面配置

```text
┌────────────────────────────────────────────────────────────────────┐
│ Curtain Online Weekly SOP      字體 90 100 110 125 140              │
│ GSC API／7d + 28d／最後更新／環境健康摘要                           │
├────────────────────────────────────────────────────────────────────┤
│ Workflow Hero                                                        │
│ 狀態：Round 1/2 可複製                                               │
│ 原因：尚未取得通過的 validation receipt                             │
│ [ 複製本輪 AI 工作指令 ]  [ 查看 SEO/GEO 優化報表 ]                  │
├──────────────────────┬──────────────────────┬──────────────────────┤
│ 資料可信度           │ 工作佇列與 Round     │ 驗證／部署            │
│ 7d/28d freshness     │ queue、receipt、next │ lifecycle、dry-run    │
├──────────────────────┼──────────────────────┼──────────────────────┤
│ 優化策略             │ 7d／28d 成效量測     │ 環境健康              │
│ action plan 摘要     │ review／decision     │ pwsh、node、npm       │
├────────────────────────────────────────────────────────────────────┤
│ 每月 AI Visibility（收合）                                          │
│ 執行狀態摘要                                         [展開明細]     │
└────────────────────────────────────────────────────────────────────┘
```

### 區塊規則

- 頁首：保留標題、字體縮放與資料來源標籤，不放高風險操作。
- Workflow Hero：固定置頂，是唯一展示 primary action 的位置。
- 六張摘要卡：桌面三欄、窄視窗單欄；標題可展開，收合時只顯示關鍵事實和狀態徽章。
- AI Visibility：預設收合，避免低頻或有 API 成本的功能干擾每日流程。
- 執行明細：預設收合，只顯示執行摘要、最後更新時間與結果；詳細 command/log 由使用者明確展開。

### MSHTA 相容性

- 使用現有 `display: table`／`table-cell` 或 `inline-block` 實作三欄卡片，窄視窗切回 block。
- 不新增 CSS Grid、CSS 自訂屬性、ES6 module、`fetch` 或不受 IE 文件模式支援的 API。
- 既有字體縮放繼續使用 `document.body.style.zoom` 與 `localStorage`，失敗時回退到 110%。

## 4. 視覺系統

| 元件 | 規格 | 目的 |
| --- | --- | --- |
| Workflow Hero | 7px 左側色條、20px 內距、26px 狀態標題、16px 原因文字 | 第一眼辨識目前 gate 與下一步 |
| Ready | 淺綠 `#edf8f1`、深綠 `#287257` | 資料與 receipt 完整、可安全前進 |
| Warning | 淺米黃 `#fff7dd`、金色 `#96752f` | 等待資料、receipt、review 或使用者核准 |
| Error / inconsistent | 淺紅 `#fff0ec`、深紅 `#b44836` | provenance、hash、設定或資料一致性失敗 |
| Measuring | 淺藍 `#eef7fb`、深藍 `#34769b` | 已上線、正在 7d／28d 量測 |
| Primary button | 深綠 `#087f6b`、白字、最少 54px 高 | 唯一能推進當前 workflow 的操作 |
| Secondary button | 白／淺藍底、藍灰邊框 | 開啟報表或查看非寫入性資料 |
| Disabled button | 42% 不透明度、保留原因文字 | 解釋 gate，而不是隱藏流程 |

- 不可只使用顏色傳達狀態；每個色彩都必須搭配狀態名稱、短原因與可行動說明。
- 內文使用 `Microsoft JhengHei, Segoe UI, sans-serif`，基準 16px、狀態標題 26px、按鈕 17px；行高至少 1.55。
- 所有按鈕和可展開標題可用 Tab 聚焦，焦點外框需清楚可見。

## 5. 互動與按鈕規格

### 主操作

`primaryAction` 由 PowerShell projection 產生，HTA 僅顯示。可能值如下：

| 狀態條件 | Primary action | 前端顯示原因 |
| --- | --- | --- |
| 缺少 pwsh 或必要設定 | 無可執行動作 | 顯示缺少元件與修復方式 |
| 無 queue 或 queue stale | 更新／開啟 SEO/GEO 行動報告 | 需先有 current strategy snapshot |
| projection 不一致 | 無可執行動作 | 顯示 workflow consistency 未通過 |
| `observation_only` 且有已核准單頁 review | 核准單頁優化並建立 Round | 顯示 review 數量與需填寫的核准資訊 |
| active Round、receipt 未通過 | 複製本輪 AI 工作指令 | 顯示 Round 與 receipt 缺口 |
| active Round、receipt 通過 | 驗證通過並前進 | 顯示 receipt 已通過 |
| `local_validated` | dry-run、部署或 lifecycle 下一步 | 依後端 deployment gate 決定 |
| `deployed` | 驗證網站已正確上線 | 顯示尚缺 live verification |
| 量測／review 階段 | 記錄下一 lifecycle evidence | 顯示須提供的 evidence 與到期日 |

### 次要與進階操作

- `更新最新 GSC 資料` 固定在 Hero 下方第一個次要區，成功後自動刷新 projection。
- `查看目前 SEO/GEO 優化報表` 為唯讀 secondary action，不得修改 queue。
- 「展開工作佇列明細」與「展開明細」只改變視覺狀態，不改變 workflow。
- AI Visibility、Luna 對照、GSC Generative AI XLSX 分析放在「每月 AI Visibility」收合區，展開時標示 API key、模型成本與資料不會覆蓋正式 baseline 的規則。
- 正式 FTP 部署保留明確確認對話框；按鈕文案必須含「正式上傳」，禁止使用模糊詞彙如「執行」。

### Busy 與錯誤處理

1. 使用者點擊 state-changing action 後，HTA 設定 `isUiBusy=true`，所有寫入型按鈕 disabled。
2. Workflow Hero 顯示黃色 running 樣式及「處理中…」。
3. 命令完成後，不依 exit code 直接推論下一步；必須重新取得 projection。
4. projection 成功時重新渲染全部按鈕與摘要卡；失敗時保留畫面結構、鎖定寫入型按鈕並顯示修復方式。
5. log 只顯示截短內容；不得顯示 OAuth、API key、FTP 密碼或敏感環境變數。

## 6. 技術設計：薄 HTA 與 Projection

### PowerShell UI Projection

新增 `scripts/get-seo-geo-ui-projection.ps1`。它讀取 strategy snapshot、approved queue、queue state、validation receipt、lifecycle receipt、部署／live verification manifest、GSC freshness 與環境健康度，輸出唯一 JSON projection。

最小資料契約：

```json
{
  "schemaVersion": 1,
  "generatedAt": "ISO-8601 UTC",
  "consistent": true,
  "state": "active",
  "primaryAction": { "id": "COPY_ROUND_PROMPT", "enabled": true, "label": "...", "reason": "..." },
  "actions": { "FETCH_GSC": { "enabled": true, "reason": "..." } },
  "panels": { "dataTrust": {}, "queue": {}, "deployment": {}, "measurement": {}, "health": {} }
}
```

既有 `get-seo-geo-effective-workflow.ps1` 的 strategy snapshot、approved queue、lifecycle state 與 consistency 判定是 projection 的基礎；不可建立第二套相互矛盾的資料規則。

### HTA 職責

保留：JSON 讀取、DOM 渲染、字體縮放、收合面板、busy 顯示、狀態 log 與固定 action ID 事件綁定。

移出：`getQueueSnapshot`、receipt／provenance 驗證、`getSmartReportDecision`、`getLifecycleNextInspection`、`configureSmartSeoGeoControls` 與 `updateWorkflowControls` 內的 enablement 推論。

### Dispatcher 與二次驗證

HTA 僅能傳送白名單 action ID：`FETCH_GSC`、`GENERATE_PLAN`、`OPEN_PLAN`、`COPY_ROUND_PROMPT`、`ADVANCE_ROUND`、`APPROVE_SINGLE_PAGE`、`DEPLOY_DRY_RUN`、`DEPLOY`、`LIVE_VERIFY`、`ADVANCE_LIFECYCLE`、`RUN_AI_VISIBILITY`、`RUN_LUNA_COMPARISON`、`ANALYZE_GSC_GENERATIVE_AI`。

Dispatcher 每次執行前重新建立 projection，確認該 action 仍 enabled 才可呼叫既有 writer。前端不得傳入 queue ID、lifecycle state、檔案路徑或 deploy eligibility；完成後必須重新輸出 projection。

## 7. 遷移計畫

### Phase 1：建立可測試的 Projection

- 實作 projection script 與 schema version。
- 以 fixture 覆蓋缺少 pwsh、queue stale、資料不一致、observation-only、active Round、receipt 通過、local_validated、deployed、live verified、7d／28d review、completed。
- 不改動 HTA 行為。

### Phase 2：Shadow Mode

- HTA 同時執行現有判斷與 projection。
- 比較 primary action、每個按鈕 enablement、reason 與 lifecycle label。
- 僅將差異寫入本機診斷 log，不改變使用者可點擊的按鈕。

### Phase 3：切換 UI 渲染

- 按鈕與 Workflow Hero 改由 projection 渲染。
- 舊的 HTA 狀態推論移除或降為純 DOM helper。
- 實作六張摘要卡、收合行為、統一 busy 與 error 呈現。

### Phase 4：驗收與清理

- 確認舊／新 UI 在所有 fixture 的流程結論一致。
- 保留 PowerShell writer 的 hash、receipt、deploy 與 live verification 二次驗證。
- 移除 shadow mode 與未使用的 HTA 判斷函式。

## 8. 測試與驗收

| 類別 | 驗收項目 |
| --- | --- |
| Projection | 每個 fixture 只有一個 primary action；每個 action 都有 enabled 與 reason |
| 安全性 | `consistent=false` 時所有 state-changing action 停用；stale UI 無法繞過 dispatcher 二次驗證 |
| 功能回歸 | GSC、queue、receipt、部署、live verify、AI Visibility 與 lifecycle 的既有 PowerShell 測試維持通過 |
| 前端 | 90%–140% 縮放不裁切；窄視窗單欄；Tab 焦點可見；收合區不觸發 workflow 寫入 |
| 操作理解 | 每個 workflow state 顯示狀態、原因、下一步和 disabled 原因，不需閱讀詳細 log 才能判斷 |

## 9. 不在本次範圍

- 不更改 GSC target registry、queue schema、receipt schema、FTP 環境變數或 lifecycle 規則。
- 不新增背景排程觸發部署；部署仍由使用者在 UI 主動啟動一次。
- 不將 Curtain 的流程或設定搬到 twyesn 專案。
- 不更換 HTA 容器；本次先在現有 MSHTA 相容範圍內完成架構與 UI 改善。

## 10. 一鍵自動部署至上線驗證

### 自動化邊界

使用者在 `local_validated` 狀態按一次「開始自動部署至上線驗證」後，系統自動完成 dry-run、FTP 上傳、deployment manifest 驗證、`deployed` receipt、live verification 與 `live_verified` receipt。

流程完成於 `live_verified`；後續 7 天／28 天資料觀察與 28 天 `keep`／`refine`／`expand`／`replace` 策略決策保持人工。系統不排程、不自行偵測狀態後上傳，也不新增未經使用者啟動的外部部署。

```text
local_validated
→ preflight
→ dry-run
→ FTP deploy
→ deployment manifest PASS
→ record deployed
→ live verification PASS
→ record live_verified
→ 等待完整 7d 資料
```

任何一步失敗即停止；不得寫入下一個 lifecycle stage。

### 協調器與 UI

- 新增 `scripts/invoke-seo-geo-autodeploy.ps1` 作為唯一協調器，取代 HTA 依序直接呼叫 dry-run、FTP、lifecycle writer 與 live verification 的做法。
- UI 主按鈕僅在 projection 顯示 `state=local_validated`、`consistent=true` 且 auto-deploy preflight 通過時啟用。
- 按下後不再要求 dry-run、FTP、deployed、live verify 的多次確認；UI 顯示六個唯讀進度階段及目前結果。
- 主按鈕文案為「開始自動部署至上線驗證」；執行中顯示「自動部署處理中…」，失敗時顯示「重新執行失敗步驟」。
- 協調器與現有 action dispatcher 共用 projection；HTA 不可自行決定是否能跳過任一 gate。

### 部署白名單與前置 gate

自動流程開始前，協調器必須重新驗證：

- `local_validated`、strategy snapshot、approved queue、lifecycle state 與 validation receipt 的 queue ID、cycle key、action IDs 和 source fingerprint 完全一致。
- FTP host 與 remote root 位於明確設定的正式白名單；憑證只從既有環境變數讀取，絕不輸出到 UI 或 log。
- 新增由 current queue、validation receipt 與輸出 hash 產生的受驗證 deploy plan。
- 自動部署只可透過 `deploy-ftp.ps1 -Mode paths` 使用 deploy plan；不得使用廣泛的 `-Mode quick`。
- deploy plan 必須列出相對路徑、SHA-256、對應 action ID 與目標 host；任何 hash 漂移、未列入檔案或敏感資料夾皆拒絕上傳。
- 禁止納入 `Weekly SOP`、`scripts`、設定、憑證、log 與任何不在 approved output 白名單的檔案。

### 自動 stage 轉換

1. 執行 dry-run 並驗證其 manifest 綁定 current queue／cycle／action IDs。
2. 執行 FTP 上傳；要求 deployment manifest 為 `success`、failed files 為零且所有上傳檔案符合 deploy plan。
3. 呼叫既有 lifecycle writer 記錄 `deployed` evidence；evidence 必須引用 deployment manifest path 與 SHA-256。
4. 執行 `write-seo-geo-live-verification.ps1`，驗證 HTTP、title、meta、H1、FAQ、schema、內鏈、CTA、robots、sitemap 與 redirects。
5. 僅在 live verification manifest 完全通過且仍綁定 current queue 時，記錄 `live_verified` evidence。

### 失敗、恢復與稽核

- 使用 atomic `latest/seo-geo-autodeploy-journal.json` 記錄 queue ID、cycle key、source fingerprint、各階段時間、manifest hash、執行結果與錯誤摘要。
- 同一 queue 重跑只可從最後一個已驗證階段繼續；queue、cycle 或 source fingerprint 改變時拒絕續跑。
- FTP 部分失敗時，保留 deployment manifest 和 journal，停止於目前 stage，不記錄 `deployed`。
- live verification 失敗時，保留 `deployed`，不記錄 `live_verified`；重試只重新執行驗證與未完成 stage。
- 不實作自動 rollback。FTP 沒有可靠交易語意，未經明確回滾設計的自動覆寫可能擴大影響。

### 測試與 rollout

新增 fixture／mock FTP 測試，至少覆蓋：正常全流程、hash 漂移、queue／receipt 不一致、缺少 FTP 憑證、部分檔案上傳失敗、deployment manifest 不一致、live verification 失敗、中斷後恢復與並發重複啟動。

導入順序：

1. Shadow mode：產生 deploy plan、預檢和 journal，不連線、不上傳。
2. Dry-run mode：驗證 deploy plan 與 manifest 契約。
3. Feature flag 啟用：限定正式 host、current queue 與一鍵觸發，保留完整本機 audit log。

---

## 11. 實作紀錄（2026-09-11）

> 本節是交接用實際變更紀錄。以下程式已實作在 `D:\projects\Curtain-online-price-estimate`；本文件可一併複製到該專案的 `Weekly SOP\` 資料夾保存。

### 實作範圍與未執行事項

- 已修改本機程式碼與測試；**未執行真實 FTP 上傳、未寫入 deployed／live_verified receipt、未呼叫正式 live verification**。
- 此次不更改 GSC target registry、queue schema、validation receipt schema、FTP 環境變數名稱或既有 lifecycle state machine。
- 不新增排程或背景自動部署。外部上傳只能由使用者在 UI 按下主按鈕後啟動。
- Curtain 專案既有的使用者修改（`HANDOVER.md`、`src/app/*`、`LocationCityTabs.tsx`）未觸碰。

### 已新增檔案

| 檔案 | 作用 |
| --- | --- |
| `scripts/get-seo-geo-ui-projection.ps1` | 唯讀 UI projection。以既有 effective workflow 為基礎，輸出 `consistent`、state、primary action、各 action enabled/reason 與五個摘要 panel。 |
| `scripts/new-seo-geo-deploy-plan.ps1` | 在 `local_validated` 時建立受驗證 deploy plan；綁定 queue、cycle、action IDs、validation receipt SHA-256、輸出檔案 SHA-256 與正式 FTP 目標。 |
| `scripts/invoke-seo-geo-autodeploy.ps1` | 一鍵部署協調器；持有 lock、寫入 atomic journal，執行 preflight、dry-run、FTP、deployed receipt、live verify、live_verified receipt。 |

### 已修改檔案

| 檔案 | 實際變更 |
| --- | --- |
| `Weekly SOP/Weekly SOP Launcher.hta` | 新增 `getSeoGeoUiProjection`、action ID 對應、主按鈕二次 projection 驗證，以及 `runSeoGeoAutoDeploy`。主按鈕在 `local_validated` 且 preflight 通過時顯示「開始自動部署至上線驗證」。 |
| `scripts/deploy-ftp.ps1` | 新增 `-DeployPlanPath`。使用時強制 `-Mode paths`，驗證 target、queue/cycle/action IDs、檔案清單與每一個 SHA-256；任一漂移即拒絕上傳。deployment manifest 會記錄 deploy plan 路徑與 SHA-256。 |
| `scripts/invoke-seo-geo-lifecycle-next.ps1` | deployed lifecycle evidence 在存在 deploy plan 時，記錄 `-Mode paths -DeployPlanPath ...`，否則保留舊的 quick mode evidence。 |
| `scripts/test-weekly-sop-ui.ps1` | 增加 UI projection、deploy plan、auto-deploy 協調器存在性與 projection schema/action 契約驗證。 |

### UI Projection 設定

`get-seo-geo-ui-projection.ps1` 使用既有 `get-seo-geo-effective-workflow.ps1`，不重建第二套 lifecycle 判斷規則。

- 一致性失敗：所有會改變 workflow 的操作停用，primary action 為 `NONE`。
- `active`：validation receipt 未通過時顯示複製 Round 指令；通過時顯示驗證並前進。
- `local_validated`：重新產生 deploy plan 的 inspect preflight；只有 FTP 帳號密碼、host／remote root 白名單、輸出檔與 receipt 全部通過時才啟用 `AUTO_DEPLOY`。
- `deployed`：顯示 live verification。
- `implemented`、`live_verified`、`observing_7d`、`reviewed_28d` 等狀態：使用既有 lifecycle inspection 顯示下一個 evidence 操作。

HTA 仍保留原有次要按鈕邏輯，以降低遷移風險；**唯一 primary action 已由 projection 覆寫，且點擊前會再重新讀取 projection**。因此目前屬於「primary action 已切換」的漸進式遷移，而不是完全刪除舊 DOM helper。

### 自動部署設定

正式白名單目前硬編碼為：

| 設定 | 允許值 |
| --- | --- |
| 公開目標 host | `online.hong-sen.com` |
| FTP host | `ftp.hong-sen.com` |
| FTP remote root | `online.hong-sen.com` |
| 憑證來源 | `FTP_USER` 與 `FTP_PASS`；`FTP_PASSWORD` 可作為密碼相容 fallback |

deploy plan 僅可選取：

- current queue target 對應的 `out/<route>/index.html`；
- `out/_next/static/**`；
- 若存在的 `robots.txt`、`sitemap.xml`、`.htaccess`。

計畫會拒絕 `Weekly SOP`、`scripts`、`config`、`latest`、`inbox`、`log` 及 `.ps1`、`.cmd`、`.hta`、`.json` 等非公開輸出／敏感路徑。

協調器寫入：

- `Weekly SOP/latest/seo-geo-deploy-plan.json`
- `Weekly SOP/latest/seo-geo-deployment-dry-run-manifest.json`
- `Weekly SOP/latest/seo-geo-deployment-manifest.json`
- `Weekly SOP/latest/seo-geo-autodeploy-journal.json`
- `Weekly SOP/latest/.seo-geo-autodeploy.lock`（執行期間存在，結束後移除）

失敗時不會前進未通過的 lifecycle stage；journal 會保存 queue、cycle、action IDs、validation receipt SHA、已完成 stage 與錯誤摘要。queue、cycle 或 receipt SHA 改變時拒絕使用舊 journal。現版本在相同驗證輸入下可安全重新執行，但「依 journal 自動跳過已完成外部 stage」仍應在 mock FTP fixture 通過後再啟用，避免把過期 remote 狀態誤判為已完成。

### 驗證結果

已完成：

- 新增／修改的 PowerShell 腳本語法解析通過。
- `scripts/test-weekly-sop-ui.ps1 -SkipBehaviorFixtures` 通過。
- `git diff --check` 通過（僅顯示既有檔案的 CRLF 提示，沒有 whitespace error）。
- 實際 Curtain workflow projection 可讀取，當時狀態為 `live_verified`，primary action 正確為「等待 7 天完整資料」且 disabled。

未完成／交接後應執行：

1. 在隔離 fixture 建立 mock FTP，覆蓋 hash 漂移、部分上傳失敗、journal 恢復、並發 lock、deployment manifest 不一致與 live verification 失敗。
2. 執行完整 `scripts/test-weekly-sop-ui.ps1`；本次完整 fixture 的子程序未在此環境正常收束，因此不把它列為通過。
3. 在正式使用前先以 `invoke-seo-geo-autodeploy.ps1 -Mode Inspect` 於 `local_validated` runtime 檢查 preflight；不得以測試為名執行 `-Mode Execute`。
4. 首次正式使用必須確認 `FTP_HOST=ftp.hong-sen.com`、`FTP_REMOTE_DIR=online.hong-sen.com`，並由使用者主動點擊 UI 的一鍵部署按鈕。

### 交接摘要

給下一位維護者：

1. 不要將 Curtain 的檔案、FTP 值或 queue 規則搬到 twyesn；這是 `online.hong-sen.com` 專案的專用實作。
2. 若要新增 action，先擴充 PowerShell projection 的 action contract，再讓 HTA 只處理固定 action ID；不要在 HTA 重新推導 lifecycle eligibility。
3. 不可移除 `DeployPlanPath` 的 SHA-256、identity 或 target 驗證，也不可讓 auto-deploy 回退到 `-Mode quick`。
4. journal 不是 rollback；FTP 未提供可靠交易語意。不要在沒有另行設計與測試下加入自動回滾。
5. 每次完成 state-changing 操作後，UI 必須重新讀取 projection；exit code 不能單獨作為 workflow 已前進的依據。
