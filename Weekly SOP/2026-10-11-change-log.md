# 2026-10-11 變更紀錄：首頁、產品頁與 GEO 內容部署

## 範圍

- 公開頁面：首頁 `/`、產品總覽 `/products/`、無縫紗簾 P002 `/products/seamless-sheer-curtains/`、鋁百葉 P006 `/products/aluminum-blinds/`。
- GEO 內容：估價器 `/calculator/`、價格指南 `/blog/curtain-price-guide-2026/`、材質說明文章 `/blog/material-and-style-deep-dive/`、醫院隔簾 P012 `/products/hospital-curtains/`。
- 本紀錄描述 2026-10-11 使用者授權的公開內容與部署；不建立新的 GSC SEO Round，也不以部署當日資料推論排名或 AI 成效。

## 已上線的頁面調整

### 首頁、產品總覽、P002 與 P006

- 首頁保留「立即做窗簾價格試算」主按鈕，新增「先比較窗簾款式」導向產品總覽，並整理為五題選款、諮詢、丈量、報價與丈量準備 FAQ。
- 產品總覽補上品牌選簾／丈量服務回首頁連結，並將內行的關鍵字競爭 FAQ 改為顧客確認規格與預算的問題。
- P002 將價格表前移，說明線上初估包含內容、丈量後才確認的條件，分清無縫紗簾與柔紗簾，並提供兩個正確的 P002 試算入口。
- P006 補充鋁合金葉片與施工條件；說明材料費、單窗安裝費與整筆工程最低施工費 NT$1,300 的差異；兩個按鈕分別為「試算鋁百葉價格」與「用我的尺寸試算鋁百葉」，均維持 `/calculator/?product=P006`。

### GEO 三項內容

- 估價器明示 NT$1,300 是整筆工程最低施工費，不是每窗最低安裝費；P006 150×180 cm 的材料 NT$1,680、單窗安裝 NT$390、總計 NT$2,070 與既有公式保持不變。
- 價格指南新增醫院、診所與護理之家隔簾的條件說明，導向醫院隔簾頁與 `/calculator/?product=P012`，未新增未核實價格。
- P012 的 metadata、價格說明、比較表、圖片 alt 與支援文章均改為依實際選用材料的標示及供應商文件核對防焰、抗菌與耐洗條件；不宣稱未佐證的認證、檢測數值或洗滌保證。

## 本機驗證

- Keyword Owner check：14/14 通過。
- `npm.cmd run build`：81 個靜態頁成功。
- `npm.cmd run seo:check`、`npm.cmd run seo:preflight`：通過。
- Lint：0 errors；保留 29 個既有 `no-img-element` warnings。

## 正式部署與公開驗收

- GEO target-paths 批次：24/24 成功，涵蓋 4 個 HTML 與 20 個必要靜態資產。
- 四頁頁面與相依 JS/CSS：17/17 成功。
- 四頁 Next.js 導覽 `.txt` 產物：20/20 成功。這一批補齊後，首頁、產品總覽、P002 與 P006 的 HTML、前端資產與導覽資料版本一致。
- 上述批次之間有重複資產，不能將 24、17、20 相加當成唯一遠端檔案數。
- 公開站驗收：四頁皆 HTTP 200、canonical 與 JSON-LD 正確；首頁 CTA／FAQ、產品總覽服務連結與 FAQ、P002 價格區與 CTA、P006 價格施工條件與 CTA 均可見。`/products/P002/`、`/products/P006/` 各自導向對應語意 URL。
- GEO 驗收：價格指南含 P012 產品與試算入口；P012 顯示材料文件限定且無未佐證用語；估價器試算結果顯示新提示。

## 部署邊界與後續觀察

- 只上傳 `out/` 內的公開網站產物。SOP 腳本、Markdown、GSC 資料、來源程式與本機設定沒有上傳公開網站。
- 未改價格公式、Owner 對應、關鍵字清單、GSC baseline 或 P001／P007 冷卻觀察狀態；target registry 僅將首頁、P002、P006 的 `lastChangedAt` 與 `updatedAt` 更新為 `2026-10-11`，作為這三頁變更後的觀察起點。
- P001／P007 仍須等固定 post-28d `2026-09-25~2026-10-22` 由 GSC final 完整涵蓋後再評估。
- 本次尚無變更後 GSC 或 direct-AI 成效資料；後續需以完整 final 觀察窗與本次部署分開判讀。

## 證據

- `Weekly SOP/latest/geo-content-implementation.json`
- `Weekly SOP/latest/geo-content-deployment-manifest.assets-a.json`
- `Weekly SOP/latest/geo-content-deployment-manifest.assets-b.json`
- `Weekly SOP/latest/geo-content-deployment-manifest.pages.json`
- `Weekly SOP/latest/seo-delta-pages-deployment-manifest.final.json`
- `Weekly SOP/latest/seo-delta-pages-navigation-deployment-manifest.final.json`
