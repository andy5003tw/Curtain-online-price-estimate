'use client';

import { useEffect, useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Calculator, CheckCircle2, ChevronRight } from 'lucide-react';
import ProductScrollMenu from '@/components/ProductScrollMenu';
import { buildCalculatorUrl } from '@/lib/seo';

type CalculatorProduct = {
  id: string;
  name: string;
  slug?: string;
  canonicalSlug?: string;
  requires_track?: boolean;
};

interface CalculatorClientProps {
  products: CalculatorProduct[];
}

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

export function CalculatorForm({ products }: CalculatorClientProps) {
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

export function CalculatorProductMenu({ products }: CalculatorClientProps) {
  const searchParams = useSearchParams();
  const selectedProduct = searchParams.get('product') || products[0].id;
  const selectedArea = searchParams.get('area') || undefined;
  const menuBasePath = selectedArea
    ? `/calculator/?product={productId}&area=${encodeURIComponent(selectedArea)}`
    : '/calculator/?product={productId}';

  return <ProductScrollMenu products={products} currentProductId={selectedProduct} basePath={menuBasePath} />;
}

export default function CalculatorClient({ products }: CalculatorClientProps) {
  return (
    <>
      <Suspense fallback={null}>
        <CalculatorProductMenu products={products} />
      </Suspense>
      <Suspense fallback={<div style={{ textAlign: 'center', padding: '3rem', color: 'var(--stone-400)' }}>載入估價工具...</div>}>
        <CalculatorForm products={products} />
      </Suspense>
    </>
  );
}
