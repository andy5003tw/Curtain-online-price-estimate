'use client';

import { createContext, useContext, useEffect, useState, Suspense, type ReactNode } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
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

type CatalogState = { products: CalculatorProduct[]; error: boolean };
const CatalogContext = createContext<CatalogState | null>(null);

export function CalculatorCatalogProvider({ bootstrapProducts, children }: { bootstrapProducts: CalculatorProduct[]; children: ReactNode }) {
  const [products, setProducts] = useState(bootstrapProducts);
  const [catalogError, setCatalogError] = useState(false);

  useEffect(() => {
    if (window.location.hostname.endsWith('github.io')) return;
    const controller = new AbortController();
    fetch('/api/products.php', { cache: 'no-store', signal: controller.signal })
      .then(async response => {
        if (!response.ok) throw new Error('無法載入產品清單');
        const payload = await response.json() as { ok: boolean; data?: CalculatorProduct[] };
        if (!payload.ok || !Array.isArray(payload.data)) throw new Error('產品清單格式無效');
        return payload.data.filter(item => item && typeof item.id === 'string' && /^P\d{3,}$/.test(item.id) && typeof item.name === 'string' && typeof item.requires_track === 'boolean');
      })
      .then(setProducts)
      .catch(error => {
        if (error instanceof Error && error.name === 'AbortError') return;
        // Existing static products remain usable when only the catalog endpoint is unavailable.
        setCatalogError(true);
      });
    return () => controller.abort();
  }, []);

  return <CatalogContext.Provider value={{ products, error: catalogError }}>{children}</CatalogContext.Provider>;
}

function useCatalog(fallback: CalculatorProduct[]): CatalogState {
  return useContext(CatalogContext) ?? { products: fallback, error: false };
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
type QuoteResponse = { key: string; data: CalcResult | null; error: string | null };
type ProductOverride = { urlProduct: string; selectedProduct: string };

const CALCULATOR_PRODUCT_CHANGE_EVENT = 'calculator-product-change';

function updateCalculatorProductUrl(productId: string, area?: string) {
  const nextUrl = buildCalculatorUrl(productId, area);
  window.history.pushState(null, '', nextUrl);
  window.dispatchEvent(new CustomEvent(CALCULATOR_PRODUCT_CHANGE_EVENT, { detail: productId }));
}

export function CalculatorForm({ products: bootstrapProducts }: CalculatorClientProps) {
  const catalog = useCatalog(bootstrapProducts);
  const products = catalog.products;
  const searchParams = useSearchParams();
  const isGitHubPages =
    typeof window !== 'undefined' && window.location.hostname.endsWith('github.io');
  const productFromUrl = searchParams.get('product') || products[0]?.id || '';
  const selectedArea = searchParams.get('area') || undefined;
  const [productOverride, setProductOverride] = useState<ProductOverride | null>(null);
  const selectedProduct = productOverride?.urlProduct === productFromUrl ? productOverride.selectedProduct : productFromUrl;
  const [width, setWidth] = useState<number | ''>('');
  const [height, setHeight] = useState<number | ''>('');
  const [quoteResponse, setQuoteResponse] = useState<QuoteResponse | null>(null);
  const widthValue = Number(width);
  const heightValue = Number(height);
  const validRequest = !!selectedProduct && products.some(product => product.id === selectedProduct) && widthValue > 0 && heightValue > 0;
  const quoteKey = `${selectedProduct}|${widthValue}|${heightValue}|${selectedArea || ''}`;
  const currentResponse = quoteResponse?.key === quoteKey ? quoteResponse : null;
  const result = validRequest ? currentResponse?.data ?? null : null;
  const apiError = isGitHubPages && validRequest
    ? '此 GitHub Pages 展示站未啟用 PHP API，估價功能請到正式站使用。'
    : currentResponse?.error ?? null;
  const isLoading = validRequest && !isGitHubPages && currentResponse === null;

  useEffect(() => {
    const handleProductChange = (event: Event) => {
      const productId = (event as CustomEvent<string>).detail;
      if (products.some((product) => product.id === productId)) setProductOverride({ urlProduct: productFromUrl, selectedProduct: productId });
    };
    const handleHistoryNavigation = () => {
      setProductOverride(null);
    };

    window.addEventListener(CALCULATOR_PRODUCT_CHANGE_EVENT, handleProductChange);
    window.addEventListener('popstate', handleHistoryNavigation);
    return () => {
      window.removeEventListener(CALCULATOR_PRODUCT_CHANGE_EVENT, handleProductChange);
      window.removeEventListener('popstate', handleHistoryNavigation);
    };
  }, [products, productFromUrl]);

  const changeProduct = (productId: string) => {
    if (productId === selectedProduct) return;
    setProductOverride({ urlProduct: productFromUrl, selectedProduct: productId });
    updateCalculatorProductUrl(productId, selectedArea);
  };

  useEffect(() => {
    if (!validRequest || isGitHubPages) return;

    const controller = new AbortController();

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
        setQuoteResponse({ key: quoteKey, data: payload.data, error: null });
      })
      .catch((error: unknown) => {
        if (error instanceof Error && error.name === 'AbortError') {
          return;
        }
        setQuoteResponse({ key: quoteKey, data: null, error: error instanceof Error ? error.message : '目前無法計算，請稍後再試。' });
      });

    return () => controller.abort();
  }, [widthValue, heightValue, selectedProduct, selectedArea, isGitHubPages, validRequest, quoteKey]);

  const activeProduct = products.find((product) => product.id === selectedProduct);
  const selectedProductExists = !!activeProduct;

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
              value={selectedProductExists ? selectedProduct : ''}
              onChange={(e) => changeProduct(e.target.value)}
              className="form-select"
            >
              <option value="" disabled>請選擇產品</option>
              {products.map((product) => (
                <option key={product.id} value={product.id}>
                  {product.name}
                </option>
              ))}
            </select>
            {!selectedProductExists && <p className="form-hint">此產品目前未上架或不存在，請重新選擇。</p>}
            {catalog.error && <p className="form-hint">目前無法更新產品清單，新增品項暫時不會顯示，請稍後重試。</p>}
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
                此為線上估價，現場若有特殊窗型、配件、施工條件會再微調。(總安裝費最低以1300計算)
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

export function CalculatorProductMenu({ products: bootstrapProducts }: CalculatorClientProps) {
  const products = useCatalog(bootstrapProducts).products;
  const searchParams = useSearchParams();
  const productFromUrl = searchParams.get('product') || products[0]?.id || '';
  const selectedArea = searchParams.get('area') || undefined;
  const [productOverride, setProductOverride] = useState<ProductOverride | null>(null);
  const selectedProduct = productOverride?.urlProduct === productFromUrl ? productOverride.selectedProduct : productFromUrl;
  const menuBasePath = selectedArea
    ? `/calculator/?product={productId}&area=${encodeURIComponent(selectedArea)}`
    : '/calculator/?product={productId}';

  useEffect(() => {
    const handleProductChange = (event: Event) => {
      const productId = (event as CustomEvent<string>).detail;
      if (products.some((product) => product.id === productId)) setProductOverride({ urlProduct: productFromUrl, selectedProduct: productId });
    };
    const handleHistoryNavigation = () => {
      setProductOverride(null);
    };

    window.addEventListener(CALCULATOR_PRODUCT_CHANGE_EVENT, handleProductChange);
    window.addEventListener('popstate', handleHistoryNavigation);
    return () => {
      window.removeEventListener(CALCULATOR_PRODUCT_CHANGE_EVENT, handleProductChange);
      window.removeEventListener('popstate', handleHistoryNavigation);
    };
  }, [products, productFromUrl]);

  const changeProduct = (productId: string) => {
    if (productId === selectedProduct) return;
    setProductOverride({ urlProduct: productFromUrl, selectedProduct: productId });
    updateCalculatorProductUrl(productId, selectedArea);
  };

  return (
    <ProductScrollMenu
      products={products}
      currentProductId={selectedProduct}
      basePath={menuBasePath}
      onProductSelect={(product) => changeProduct(product.id)}
    />
  );
}

export function CalculatorProductsList({ products: bootstrapProducts }: CalculatorClientProps) {
  const products = useCatalog(bootstrapProducts).products;
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: '0.75rem' }}>
      {products.map(product => (
        <Link key={product.id} href={buildCalculatorUrl(product.id)} style={{ padding: '1rem', background: 'var(--stone-50)', borderRadius: '0.75rem', border: '1px solid var(--stone-200)', textAlign: 'center', fontWeight: 600, fontSize: '0.925rem', color: 'var(--stone-700)', textDecoration: 'none' }}>
          {product.name}
        </Link>
      ))}
    </div>
  );
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
