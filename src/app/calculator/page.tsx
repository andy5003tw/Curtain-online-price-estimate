'use client';

import { useEffect, useState, Suspense } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { Calculator, CheckCircle2, ChevronRight } from 'lucide-react';
import ProductScrollMenu from '@/components/ProductScrollMenu';
import { products } from '@/data/products';
import { buildCalculatorUrl } from '@/lib/seo';

interface CalcResult {
  material_cost: number;
  install_cost: number;
  total_price: number;
}

interface CalcApiSuccess {
  ok: true;
  data: CalcResult;
}

interface CalcApiError {
  ok: false;
  error_code: string;
  message: string;
}

type CalcApiResponse = CalcApiSuccess | CalcApiError;

function CalculatorForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const isGitHubPages =
    typeof window !== 'undefined' && window.location.hostname.endsWith('github.io');
  const selectedProduct = searchParams.get('product') || products[0].id;
  const selectedArea = searchParams.get('area') || undefined;
  const [width, setWidth] = useState<number | ''>('');
  const [height, setHeight] = useState<number | ''>('');
  const [result, setResult] = useState<CalcResult | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [apiError, setApiError] = useState<string | null>(null);

  useEffect(() => {
    const widthValue = Number(width);
    const heightValue = Number(height);
    if (!selectedProduct || !widthValue || !heightValue) {
      setResult(null);
      setApiError(null);
      setIsLoading(false);
      return;
    }

    if (isGitHubPages) {
      setResult(null);
      setApiError('此 GitHub Pages 展示站未啟用 PHP API，估價功能請到正式站使用。');
      setIsLoading(false);
      return;
    }

    const controller = new AbortController();
    setIsLoading(true);
    setApiError(null);

    fetch('/api/calc.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        product_id: selectedProduct,
        width_cm: widthValue,
        height_cm: heightValue,
        area_id: selectedArea,
      }),
      signal: controller.signal,
    })
      .then(async (res) => {
        const contentType = res.headers.get('content-type') || '';
        if (!contentType.includes('application/json')) {
          throw new Error('估價服務目前不可用，請改用正式站。');
        }
        const payload = (await res.json()) as CalcApiResponse;
        if (!res.ok || !payload.ok) {
          const message = payload && !payload.ok ? payload.message : '目前無法計算，請稍後再試。';
          throw new Error(message);
        }
        setResult(payload.data);
      })
      .catch((error: unknown) => {
        if (error instanceof Error && error.name === 'AbortError') {
          return;
        }
        setResult(null);
        setApiError(error instanceof Error ? error.message : '目前無法計算，請稍後再試。');
      })
      .finally(() => setIsLoading(false));

    return () => controller.abort();
  }, [width, height, selectedProduct, selectedArea, isGitHubPages]);

  const activeProduct = products.find((product) => product.id === selectedProduct);

  return (
    <div className="calculator-box">
      <div className="calc-grid">
        <div>
          <div className="form-group">
            <div className="step-label">
              <div className="step-num">1</div>
              <h3>選擇產品</h3>
            </div>
            <select
              value={selectedProduct}
              onChange={(e) => router.push(buildCalculatorUrl(e.target.value, selectedArea), { scroll: false })}
              className="form-select"
            >
              {products.map((product) => (
                <option key={product.id} value={product.id}>
                  {product.name}
                </option>
              ))}
            </select>
            {activeProduct?.requires_track && (
              <p className="form-hint" style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', color: 'var(--amber-600)' }}>
                <CheckCircle2 size={14} />
                此品項會自動納入軌道與安裝估算。
              </p>
            )}
          </div>

          <div className="form-group">
            <div className="step-label">
              <div className="step-num">2</div>
              <h3>輸入尺寸（cm）</h3>
            </div>
            <div style={{ marginBottom: '1rem', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
              <button type="button" onClick={() => { setWidth(150); setHeight(150); }} className="preset-btn">
                小窗範例 150 x 150
              </button>
              <button type="button" onClick={() => { setWidth(200); setHeight(240); }} className="preset-btn">
                落地窗範例 200 x 240
              </button>
            </div>
            <div className="dim-grid">
              <div>
                <label>寬度</label>
                <input
                  type="number"
                  min="0"
                  value={width}
                  onChange={(e) => setWidth(e.target.value ? Number(e.target.value) : '')}
                  className="form-input"
                  placeholder="例如 150"
                />
              </div>
              <div>
                <label>高度</label>
                <input
                  type="number"
                  min="0"
                  value={height}
                  onChange={(e) => setHeight(e.target.value ? Number(e.target.value) : '')}
                  className="form-input"
                  placeholder="例如 200"
                />
              </div>
            </div>
            <p className="form-hint">建議先以大約尺寸估算，正式報價仍以現場丈量與施工條件為準。</p>
          </div>
        </div>

        <div className="result-box">
          <div className="step-label">
            <div className="step-num">3</div>
            <h3>估價結果</h3>
          </div>

          {isLoading ? (
            <div className="result-empty">
              <Calculator size={48} style={{ opacity: 0.2 }} />
              <p>正在計算報價...</p>
            </div>
          ) : result ? (
            <>
              <div className="result-row">
                <span>產品</span>
                <span>{activeProduct?.name}</span>
              </div>
              <div className="result-row">
                <span>材料費</span>
                <span>NT$ {result.material_cost.toLocaleString()}</span>
              </div>
              <div className="result-row">
                <span>安裝費</span>
                <span>NT$ {result.install_cost.toLocaleString()}</span>
              </div>
              <div className="result-total">
                <span>總估價</span>
                <span>NT$ {result.total_price.toLocaleString()}</span>
              </div>
              <p className="form-hint" style={{ marginTop: '0.75rem' }}>
                此為線上估價，現場若有特殊窗型、配件、施工條件會再微調。
              </p>
              <a href="#contact" className="btn-primary" style={{ marginTop: '1.25rem', width: '100%' }}>
                預約現場丈量 <ChevronRight size={16} />
              </a>
            </>
          ) : (
            <div className="result-empty">
              <Calculator size={48} style={{ opacity: 0.2 }} />
              <p>請輸入完整寬高尺寸後即可查看估價結果。</p>
              {isGitHubPages && (
                <p className="form-hint" style={{ marginTop: '0.75rem', color: 'var(--amber-700)' }}>
                  GitHub Pages 為靜態展示環境，無法執行 PHP 後端估價 API。
                </p>
              )}
              {apiError && (
                <p className="form-hint" style={{ marginTop: '0.75rem', color: 'var(--red-600)' }}>
                  {apiError}
                </p>
              )}
              {isGitHubPages && (
                <a
                  href="https://online.hong-sen.com/calculator/"
                  className="btn-outline"
                  style={{ marginTop: '0.75rem' }}
                >
                  前往正式站估價
                </a>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function CalculatorContent() {
  const searchParams = useSearchParams();
  const selectedProduct = searchParams.get('product') || products[0].id;
  const selectedArea = searchParams.get('area') || undefined;
  const menuBasePath = selectedArea
    ? `/calculator/?product={productId}&area=${encodeURIComponent(selectedArea)}`
    : '/calculator/?product={productId}';

  return (
    <>
      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>/</span>
          <span>線上估價</span>
        </div>
      </nav>

      <ProductScrollMenu products={products} currentProductId={selectedProduct} basePath={menuBasePath} />

      <div className="page-hero">
        <div className="section-container">
          <div className="tag" style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}>
            窗簾估價工具
          </div>
          <h1>輸入尺寸，快速估算窗簾價格區間</h1>
          <p>支援多種窗簾品項，先做窗簾價格試算與窗簾安裝費用估算，再安排免費到府丈量與正式報價。</p>
        </div>
      </div>

      <section className="py-section bg-stone-50">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <h2>快速估算 + 現場確認，流程更省時</h2>
            <p>先用線上工具掌握窗簾價格與安裝費用區間，再由專人到府確認窗型與施工條件。</p>
          </div>
          <div style={{ marginBottom: '1.25rem', display: 'grid', gap: '0.5rem' }}>
            <Link href="/products/roller-blinds/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              捲簾產品介紹
            </Link>
            <Link href="/products/zebra-blinds/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              調光簾產品介紹
            </Link>
            <Link href="/products/wooden-blinds/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              木百葉產品介紹
            </Link>
            <Link href="/blog/curtain-price-guide-2026/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              訂製窗簾價格、窗簾報價與安裝費用怎麼看？
            </Link>
            <Link href="/location/banqiao/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              板橋窗簾推薦與線上估價入口
            </Link>
            <Link href="/location/xinzhuang/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              新莊窗簾推薦與線上估價入口
            </Link>
          </div>
          <Suspense fallback={<div style={{ textAlign: 'center', padding: '3rem', color: 'var(--stone-400)' }}>載入中...</div>}>
            <CalculatorForm />
          </Suspense>
        </div>
      </section>

      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <h2>窗簾價格試算前，先看三個重點</h2>
          </div>
          <div style={{ display: 'grid', gap: '1rem' }}>
            {[
              '先輸入接近實際的寬高尺寸，可先抓窗簾價格區間，再由現場丈量微調。',
              '窗簾安裝費用會受窗型、配件與施工難度影響，估價頁可先看大方向預算。',
              '若要比較不同產品，建議切換同一尺寸再看價差，判斷更直覺。',
            ].map((text, index) => (
              <div key={index} style={{ padding: '1rem 1.25rem', background: 'var(--stone-50)', borderRadius: '0.75rem', border: '1px solid var(--stone-100)', color: 'var(--stone-700)', lineHeight: 1.75 }}>
                {text}
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <h2>常見問題</h2>
          </div>
          {[
            {
              q: '線上估價和正式報價會差很多嗎？',
              a: '通常差異不大，但窗型、配件與施工條件會影響最終金額，仍以現場丈量為準。',
            },
            {
              q: '可以先估價再決定是否預約丈量嗎？',
              a: '可以，建議先完成線上估價再聯絡，溝通效率會更高。',
            },
            {
              q: '估價結果會包含安裝費嗎？',
              a: '會。系統會依品項規則估算材料費與安裝費，並回傳總價。',
            },
            {
              q: '窗簾價格試算後，多久可以拿到正式報價？',
              a: '通常可先看線上試算結果，再安排丈量，丈量後即可提供更完整的正式報價與施工建議。',
            },
          ].map((item, index) => (
            <div key={index} style={{ marginBottom: '1rem', padding: '1rem 1.25rem', background: 'white', borderRadius: '0.75rem', border: '1px solid var(--stone-100)' }}>
              <h3 style={{ marginBottom: '0.5rem', fontSize: '1.05rem' }}>Q: {item.q}</h3>
              <p style={{ margin: 0, color: 'var(--stone-600)' }}>A: {item.a}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container">
          <div className="section-heading">
            <h2>所有可估價品項</h2>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: '0.75rem' }}>
            {products.map((product) => (
              <Link
                key={product.id}
                href={buildCalculatorUrl(product.id, selectedArea)}
                style={{
                  padding: '1rem',
                  background: 'var(--stone-50)',
                  borderRadius: '0.75rem',
                  border: '1px solid var(--stone-200)',
                  textAlign: 'center',
                  fontWeight: 600,
                  fontSize: '0.925rem',
                  color: 'var(--stone-700)',
                  textDecoration: 'none',
                }}
              >
                {product.name}
              </Link>
            ))}
          </div>
        </div>
      </section>

      <style
        dangerouslySetInnerHTML={{
          __html: `
            .preset-btn {
              display: inline-flex;
              justify-content: center;
              align-items: center;
              padding: 0.75rem;
              background: white;
              border: 1px solid var(--stone-200);
              border-radius: 0.5rem;
              cursor: pointer;
              font-weight: 600;
              color: var(--stone-700);
              transition: all 0.2s;
            }
            .preset-btn:hover {
              background: var(--amber-50);
              border-color: var(--amber-300);
              color: var(--amber-700);
            }
          `,
        }}
      />
    </>
  );
}

export default function CalculatorPage() {
  return (
    <Suspense fallback={<div style={{ textAlign: 'center', padding: '5rem', color: 'var(--stone-400)' }}>載入中...</div>}>
      <CalculatorContent />
    </Suspense>
  );
}
