'use client';

import { useState, useEffect, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { products } from '@/data/products';
import { CurtainCalculator, PricingParams } from '@/lib/calculator';
import { buildCalculatorUrl } from '@/lib/seo';
import { Calculator, CheckCircle2, ChevronRight } from 'lucide-react';

function CalculatorForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const selectedProduct = searchParams.get('product') || products[0].id;
  const selectedArea = searchParams.get('area') || undefined;
  const [width, setWidth] = useState<number | ''>('');
  const [height, setHeight] = useState<number | ''>('');
  const [result, setResult] = useState<{ material_cost: number; install_cost: number; total_price: number } | null>(null);



  useEffect(() => {
    if (width && height && selectedProduct) {
      const product = products.find(p => p.id === selectedProduct);
      if (product) {
        const formula = CurtainCalculator[product.formula_type];
        if (formula) {
          setResult(formula(Number(width), Number(height), product.pricing as PricingParams));
          return;
        }
      }
    }
    setResult(null);
  }, [width, height, selectedProduct]);

  const activeProduct = products.find(p => p.id === selectedProduct);

  return (
    <div className="calculator-box">
      <div className="calc-grid">
        {/* Input */}
        <div>
          {/* Step 1 */}
          <div className="form-group">
            <div className="step-label">
              <div className="step-num">1</div>
              <h3>選擇窗簾款式</h3>
            </div>
            <select
              value={selectedProduct}
              onChange={e => router.push(buildCalculatorUrl(e.target.value, selectedArea), { scroll: false })}
              className="form-select"
            >
              {products.map(p => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </select>
            {activeProduct?.requires_track && (
              <p className="form-hint" style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', color: 'var(--amber-600)' }}>
                <CheckCircle2 size={14} /> 此款式包含專用軌道與配件費用
              </p>
            )}
          </div>

          {/* Step 2 */}
          <div className="form-group">
            <div className="step-label">
              <div className="step-num">2</div>
              <h3>輸入窗戶尺寸</h3>
            </div>
            
            <div style={{ marginBottom: '1.5rem', display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
              <span style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--stone-700)', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                <svg viewBox="0 0 24 24" width="16" height="16" stroke="var(--amber-500)" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon></svg>
                懶人尺寸一鍵帶入
              </span>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <button type="button" onClick={() => { setWidth(150); setHeight(150); }} className="preset-btn">
                  <div style={{ fontWeight: 700, fontSize: '0.95rem', marginBottom: '0.15rem' }}>標準半腰窗</div>
                  <div style={{ fontSize: '0.8rem', opacity: 0.8 }}>寬 150 × 高 150 cm</div>
                </button>
                <button type="button" onClick={() => { setWidth(200); setHeight(240); }} className="preset-btn">
                  <div style={{ fontWeight: 700, fontSize: '0.95rem', marginBottom: '0.15rem' }}>標準落地窗</div>
                  <div style={{ fontSize: '0.8rem', opacity: 0.8 }}>寬 200 × 高 240 cm</div>
                </button>
              </div>
            </div>

            <div className="dim-grid">
              <div>
                <label>寬度 (cm)</label>
                <input
                  type="number"
                  min="0"
                  value={width}
                  onChange={e => setWidth(e.target.value ? Number(e.target.value) : '')}
                  className="form-input"
                  placeholder="例如: 150"
                />
              </div>
              <div>
                <label>高度 (cm)</label>
                <input
                  type="number"
                  min="0"
                  value={height}
                  onChange={e => setHeight(e.target.value ? Number(e.target.value) : '')}
                  className="form-input"
                  placeholder="例如: 200"
                />
              </div>
            </div>
            <p className="form-hint">
              * 建議測量窗框外緣，寬度左右各加 10cm，高度下擺加 15-20cm 遮光效果更佳。
            </p>
          </div>
        </div>

        {/* Result */}
        <div className="result-box">
          <div className="step-label">
            <div className="step-num">3</div>
            <h3>估價結果</h3>
          </div>

          {result ? (
            <>
              <div className="result-row">
                <span>款式</span>
                <span>{activeProduct?.name}</span>
              </div>
              <div className="result-row">
                <span>材料與車工</span>
                <span>NT$ {result.material_cost.toLocaleString()}</span>
              </div>
              <div className="result-row">
                <span>基本施工費</span>
                <span>NT$ {result.install_cost.toLocaleString()}</span>
              </div>
              <div className="result-total">
                <span>總計估價</span>
                <span>NT$ {result.total_price.toLocaleString()}</span>
              </div>
              <p className="form-hint" style={{ marginTop: '0.75rem' }}>
                * 包含基本才數限制、車工與施工。材料以基本款計算，最低施工費1300，其他款式另計。實際價格以現場丈量為準。
              </p>
              <a
                href="#contact"
                className="btn-primary"
                style={{ marginTop: '1.25rem', width: '100%' }}
              >
                聯絡預約丈量 <ChevronRight size={16} />
              </a>
            </>
          ) : (
            <div className="result-empty">
              <Calculator size={48} style={{ opacity: 0.2 }} />
              <p>請選擇款式並輸入尺寸<br />即可即時查看估價結果</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

import ProductScrollMenu from '@/components/ProductScrollMenu';

function CalculatorContent() {
  const searchParams = useSearchParams();
  const selectedProduct = searchParams.get('product') || products[0].id;
  const selectedArea = searchParams.get('area') || undefined;
  const menuBasePath = selectedArea
    ? `/calculator?product={productId}&area=${encodeURIComponent(selectedArea)}`
    : '/calculator?product={productId}';

  return (
    <>
      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>›</span>
          <span>線上估價</span>
        </div>
      </nav>

      {/* Product Selection Menu */}
      <ProductScrollMenu 
        products={products} 
        currentProductId={selectedProduct} 
        basePath={menuBasePath}
      />

      <div className="page-hero">
        <div className="section-container">
          <div className="tag" style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}>窗簾計算機 / 窗簾估價工具</div>
          <h1>窗簾計算機：台北、三重窗簾估價工具即時試算</h1>
          <p>輸入尺寸即可快速完成窗簾價格試算，先抓預算再安排丈量，適用捲簾、鋁百葉、風琴簾等熱門品項。</p>
        </div>
      </div>

      <section className="py-section bg-stone-50">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <h2>窗簾估價工具（台北、三重）</h2>
            <p>簡單三步驟，先完成線上試算，再安排免費到府丈量確認最終報價。</p>
          </div>
          <div style={{ marginBottom: '1.75rem', display: 'grid', gap: '0.65rem' }}>
            <Link href="/products/roller-blinds/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              台北捲簾價格、三重捲簾價格專頁
            </Link>
            <Link href="/products/zebra-blinds/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              台北調光簾價格、三重調光簾價格專頁
            </Link>
            <Link href="/products/wooden-blinds/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              台北實木百葉窗價格、三重實木百葉窗價格專頁
            </Link>
            <Link href="/location/taipei/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              台北窗簾推薦服務入口
            </Link>
            <Link href="/location/sanchong/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              三重窗簾推薦服務入口
            </Link>
          </div>
          <Suspense fallback={<div style={{ textAlign: 'center', padding: '3rem', color: 'var(--stone-400)' }}>載入中...</div>}>
            <CalculatorForm />
          </Suspense>

          {/* CTA Banner */}
          <div style={{ marginTop: '2.5rem', background: 'var(--amber-50)', border: '1.5px dashed var(--amber-500)', borderRadius: '1rem', padding: '2rem', textAlign: 'center' }}>
            <h3 style={{ fontSize: '1.25rem', fontWeight: 700, color: 'var(--stone-900)', marginBottom: '0.5rem' }}>怕自己量錯尺寸？或者窗型太複雜？</h3>
            <p style={{ color: 'var(--stone-600)', marginBottom: '1.5rem', fontSize: '0.95rem' }}>宏森窗簾提供「大台北地區」免費到府丈量服務，由專業師傅親自為您規劃最能防漏光、最美觀的安裝方式！</p>
            <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap' }}>
              <a href="https://line.me/ti/p/fDWxUXkiZb" className="btn-line-inline" target="_blank" rel="noopener noreferrer">
                 客服一 0980 (加 LINE 預約)
              </a>
              <a href="https://line.me/ti/p/nS1XQ4-flk" className="btn-line-inline" target="_blank" rel="noopener noreferrer" style={{ background: '#05b04b' }}>
                 客服二 0973 (加 LINE 預約)
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* Measurement Guide (SEO Content) */}
      <section className="py-section bg-white border-t border-stone-100">
        <div className="section-container" style={{ maxWidth: '900px' }}>
           <div className="section-heading">
              <div className="tag">專業教學</div>
              <h2>如何正確丈量窗簾尺寸？</h2>
              <p>掌握這兩個訣竅，確保窗簾安裝後完美遮光、不漏縫隙。</p>
           </div>
           
           <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '2rem' }}>
              <div style={{ padding: '2rem', background: 'var(--stone-50)', borderRadius: '1rem', border: '1px solid var(--stone-100)' }}>
                <h3 style={{ fontSize: '1.15rem', fontWeight: 700, marginBottom: '1rem', color: 'var(--stone-900)' }}>1. 落地窗 (落地門)</h3>
                <ul style={{ listStyle: 'none', padding: 0 }}>
                  <li style={{ marginBottom: '0.75rem', position: 'relative', paddingLeft: '1.5rem', color: 'var(--stone-600)', lineHeight: '1.6' }}><span style={{ position: 'absolute', left: 0, color: 'var(--amber-600)' }}>■</span> <strong>寬度：</strong> 測量窗框左右兩側總寬後，再<strong>各加 10~15 公分</strong>，有效避免側邊漏光。</li>
                  <li style={{ marginBottom: '0.75rem', position: 'relative', paddingLeft: '1.5rem', color: 'var(--stone-600)', lineHeight: '1.6' }}><span style={{ position: 'absolute', left: 0, color: 'var(--amber-600)' }}>■</span> <strong>高度：</strong> 從天花板上方(或窗簾盒頂端)量到底，再<strong>往上扣減 1~2 公分</strong>，避免布料拖地弄髒或磨損。</li>
                </ul>
              </div>
              <div style={{ padding: '2rem', background: 'var(--stone-50)', borderRadius: '1rem', border: '1px solid var(--stone-100)' }}>
                <h3 style={{ fontSize: '1.15rem', fontWeight: 700, marginBottom: '1rem', color: 'var(--stone-900)' }}>2. 半腰窗 (一般窗台)</h3>
                <ul style={{ listStyle: 'none', padding: 0 }}>
                  <li style={{ marginBottom: '0.75rem', position: 'relative', paddingLeft: '1.5rem', color: 'var(--stone-600)', lineHeight: '1.6' }}><span style={{ position: 'absolute', left: 0, color: 'var(--amber-600)' }}>■</span> <strong>寬度：</strong> 與落地窗相同，建議左右各加 10~15 公分。</li>
                  <li style={{ marginBottom: '0.75rem', position: 'relative', paddingLeft: '1.5rem', color: 'var(--stone-600)', lineHeight: '1.6' }}><span style={{ position: 'absolute', left: 0, color: 'var(--amber-600)' }}>■</span> <strong>高度：</strong> 窗框下方建議<strong>往下延伸 15~20 公分</strong>，確保下擺能完全遮蓋防漏光。若窗下方有書桌或系統櫃，則依實際高度量至檯面上方。</li>
                </ul>
                <p style={{ marginTop: '1.25rem', fontSize: '0.9rem', padding: '0.75rem', background: 'var(--amber-100)', borderRadius: '0.5rem', color: 'var(--amber-900)', fontWeight: 500 }}>
                  👉 猶豫該選哪一種窗簾？立即閱讀 <Link href="/blog" style={{ fontWeight: 700, color: 'var(--amber-700)', textDecoration: 'underline' }}>窗簾款式完全解析</Link> 找出最佳搭配！
                </p>
              </div>
           </div>

           <div style={{ marginTop: '3rem', padding: '2.5rem', border: '1px solid var(--stone-200)', borderRadius: '1rem', background: 'white', boxShadow: '0 4px 12px rgba(0,0,0,0.02)' }}>
              <h3 style={{ fontSize: '1.3rem', fontWeight: 700, marginBottom: '1rem', color: 'var(--stone-900)' }}>價格結構完全透明化：我們的報價包含什麼？</h3>
              <p style={{ color: 'var(--stone-600)', lineHeight: '1.8', fontSize: '0.95rem' }}>
                市場上有許多「低價攬客、事後加價」的手法。宏森窗簾堅持<strong>工廠直營</strong>，我們的線上估價即為您的真實參考成本。
                線上估價總額已完整涵蓋：<strong>精選窗簾布料(基本款) + 專屬定製軌道與零配件 + 專業車工 + 雙北地區專業師傅基本安裝工資</strong>。
                我們承諾絕不在完工後巧立名目收取不合理的週邊耗材費，讓您的裝修預算精準不超支！
              </p>
              <p style={{ marginTop: '1rem', fontSize: '0.95rem' }}>
                👉 想看看我們的真實施工品質？歡迎參觀我們的 <Link href="/cases" style={{ fontWeight: 700, color: '#06C755', textDecoration: 'none', borderBottom: '2px solid #06C755' }}>大台北百大精選施工案例</Link>。
              </p>
           </div>
        </div>
      </section>

      {/* Silo Content - Room Scenarios */}
      <section className="py-section bg-stone-50 border-t border-stone-200">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <div className="tag">空間指南</div>
            <h2>依據空間情境推薦窗簾款式</h2>
            <p>不知道該選哪一種？參考最熱門的居家空間窗簾搭配，精準鎖定預算。</p>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '1.5rem' }}>
            <div style={{ padding: '1.5rem', borderRadius: '1rem', background: 'white', border: '1px solid var(--stone-200)', boxShadow: '0 2px 8px rgba(0,0,0,0.02)' }}>
               <h3 style={{ fontSize: '1.15rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--stone-900)' }}>客廳窗簾推薦</h3>
               <p style={{ fontSize: '0.9rem', color: 'var(--stone-600)', marginBottom: '1.25rem' }}>客廳是居家門面，需要大器且具備豐富調光靈活性的款式。</p>
               <ul style={{ listStyle: 'none', padding: 0, fontSize: '0.95rem', color: 'var(--stone-800)', lineHeight: '1.8' }}>
                 <li>✨ <strong>大器首選：</strong> 蛇形簾配透光紗簾</li>
                 <li>✨ <strong>高 CP 值：</strong> 斑馬簾 (調光簾)</li>
                 <li>✨ <strong>設計質感：</strong> 實木百葉窗</li>
               </ul>
            </div>
            <div style={{ padding: '1.5rem', borderRadius: '1rem', background: 'white', border: '1px solid var(--stone-200)', boxShadow: '0 2px 8px rgba(0,0,0,0.02)' }}>
               <h3 style={{ fontSize: '1.15rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--stone-900)' }}>臥室窗簾推薦</h3>
               <p style={{ fontSize: '0.9rem', color: 'var(--stone-600)', marginBottom: '1.25rem' }}>睡眠品質首重避光，必備高遮光率與隔音隔熱功能。</p>
               <ul style={{ listStyle: 'none', padding: 0, fontSize: '0.95rem', color: 'var(--stone-800)', lineHeight: '1.8' }}>
                 <li>✨ <strong>遮光首選：</strong> 100% 遮光三明治打摺簾</li>
                 <li>✨ <strong>降溫極品：</strong> 全遮光風琴簾</li>
                 <li>✨ <strong>防污抗敏：</strong> 遮光捲簾</li>
               </ul>
            </div>
            <div style={{ padding: '1.5rem', borderRadius: '1rem', background: 'white', border: '1px solid var(--stone-200)', boxShadow: '0 2px 8px rgba(0,0,0,0.02)' }}>
               <h3 style={{ fontSize: '1.15rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--stone-900)' }}>浴室與辦公室推薦</h3>
               <p style={{ fontSize: '0.9rem', color: 'var(--stone-600)', marginBottom: '1.25rem' }}>極端潮濕或日照環境，需要防水防霉或好清潔的特殊材質。</p>
               <ul style={{ listStyle: 'none', padding: 0, fontSize: '0.95rem', color: 'var(--stone-800)', lineHeight: '1.8' }}>
                 <li>✨ <strong>浴室必備：</strong> 防水鋁百葉窗</li>
                 <li>✨ <strong>辦公商用：</strong> 防焰陽光捲簾</li>
                 <li>✨ <strong>和室茶室：</strong> 復古日式竹簾</li>
               </ul>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container" style={{ maxWidth: '720px' }}>
          <div className="section-heading">
            <h2>窗簾計算機常見問題</h2>
          </div>
          {[
            { q: '窗簾計算機與窗簾估價工具的結果準確嗎？', a: '系統會依尺寸與品項即時計算材料與基本施工費，適合先抓預算範圍。最終金額仍以現場丈量窗型、布料等級與安裝條件為準。' },
            { q: '估價是否包含施工費？', a: '是的，線上估價已包含基本施工費，但不含偏遠區或特殊高風險施工的加價項目。' },
            { q: '可以比較鋁百葉、風琴簾等不同品項價格嗎？', a: '可以，頁面可快速切換不同窗簾品項，比較各尺寸下的估價差異，再決定後續丈量與施工順序。' },
            { q: '量尺及估價需要收費嗎？', a: '宏森開發提供台北市與三重區免費到府量尺服務，先估價再安排丈量，流程透明無隱藏費用。' },
          ].map((item, i) => (
            <div key={i} style={{ marginBottom: '1.5rem', padding: '1.25rem 1.5rem', background: 'white', borderRadius: '0.75rem', border: '1px solid var(--stone-100)', boxShadow: '0 2px 4px rgba(0,0,0,0.02)' }}>
              <h3 style={{ fontWeight: 700, marginBottom: '0.5rem', fontSize: '1.05rem', color: 'var(--stone-800)' }}>Q: {item.q}</h3>
              <p style={{ color: 'var(--stone-600)', fontSize: '0.95rem', lineHeight: 1.7, margin: 0 }}>A: {item.a}</p>
            </div>
          ))}
        </div>
      </section>

      {/* All products */}
      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container">
          <div className="section-heading">
            <h2>所有可估價的窗簾款式</h2>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: '0.75rem' }}>
            {products.map(p => (
              <Link
                key={p.id}
                href={buildCalculatorUrl(p.id, selectedArea)}
                style={{ padding: '1rem', background: 'var(--stone-50)', borderRadius: '0.75rem', border: '1px solid var(--stone-200)', textAlign: 'center', fontWeight: 600, fontSize: '0.925rem', color: 'var(--stone-700)', transition: 'all 0.2s', textDecoration: 'none' }}
                onMouseOver={(e) => { e.currentTarget.style.background = 'var(--stone-100)'; e.currentTarget.style.borderColor = 'var(--amber-300)'; }}
                onMouseOut={(e) => { e.currentTarget.style.background = 'var(--stone-50)'; e.currentTarget.style.borderColor = 'var(--stone-200)'; }}
              >
                {p.name}
              </Link>
            ))}
          </div>
        </div>
        <style dangerouslySetInnerHTML={{__html: `
          .btn-line-inline {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            background: #06C755;
            color: white;
            padding: 0.75rem 2rem;
            border-radius: 2rem;
            font-weight: 700;
            text-decoration: none;
            transition: all 0.3s;
            box-shadow: 0 4px 12px rgba(6,199,85,0.3);
          }
          .btn-line-inline:hover {
            transform: scale(1.05);
            box-shadow: 0 6px 16px rgba(6,199,85,0.4);
          }
          .preset-btn {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 0.85rem 0.5rem;
            background: white;
            border: 1.5px solid var(--stone-200);
            border-radius: 0.5rem;
            color: var(--stone-500);
            cursor: pointer;
            transition: all 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275);
            text-align: center;
          }
          .preset-btn:hover {
            background: var(--amber-50);
            border-color: var(--amber-400);
            color: var(--amber-800);
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(245, 158, 11, 0.15);
          }
          .preset-btn:active {
            transform: translateY(0);
            box-shadow: none;
          }
        `}} />
      </section>

      {/* Local SEO Block */}
      <section className="bg-stone-50 border-t border-stone-200" style={{ padding: '3rem 1.5rem 1rem 1.5rem' }}>
        <div className="section-container" style={{ maxWidth: '900px', textAlign: 'center' }}>
           <h3 style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--stone-800)', marginBottom: '0.5rem' }}>大台北地區窗簾估價與免費到府丈量服務網</h3>
           <p style={{ fontSize: '0.8rem', color: 'var(--stone-500)', lineHeight: '1.8' }}>
             宏森窗簾工廠直營專車服務範圍涵蓋全大台北地區。<br/>
             <strong>台北市：</strong> 大安區、信義區、中山區、內湖區、中正區、松山區、大同區、萬華區、文山區、士林區、北投區、南港區窗簾估價與安裝。<br/>
             <strong>新北市：</strong> 板橋區、三重區、中和區、永和區、新莊區、新店區、土城區、蘆洲區、汐止區、樹林區、林口區、三峽區窗簾推薦。<br/>
             若您的所在地區不在列表內，也歡迎隨時聯繫 LINE 客服為您專案評估！
           </p>
        </div>
      </section>
    </>
  );
}

export default function CalculatorPage() {
  return (
    <Suspense fallback={<div style={{ textAlign: 'center', padding: '5rem', color: 'var(--stone-400)' }}>載入試算系統中...</div>}>
      <CalculatorContent />
    </Suspense>
  );
}
