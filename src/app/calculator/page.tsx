import Link from 'next/link';
import { Suspense } from 'react';
import { CalculatorForm, CalculatorProductMenu } from './CalculatorClient';
import { products } from '@/data/products';
import { buildCalculatorUrl } from '@/lib/seo';

const calculatorProducts = products.map((product) => ({
  id: product.id,
  name: product.name,
  slug: product.slug,
  canonicalSlug: product.canonicalSlug,
  requires_track: product.requires_track,
}));

const calculatorFaq = [
  {
    q: '窗簾價格試算和正式報價會差很多嗎？',
    a: '通常差異不大，但窗型、配件與施工條件會影響最終金額；建議先做窗簾價格試算，再以現場丈量確認正式報價。',
  },
  {
    q: '可以先估價再決定是否預約丈量嗎？',
    a: '可以，建議先完成線上估價再聯絡，溝通效率會更高。',
  },
  {
    q: '三重窗簾價格試算後如何比價最有效率？',
    a: '建議固定同一尺寸比較捲簾、調光簾、實木百葉窗三個品項，再切到三重窗簾服務頁確認在地丈量流程。',
  },
  {
    q: '窗簾價格試算要先看價格指南還是直接輸入尺寸？',
    a: '如果已經有寬高尺寸，可直接用本頁線上估價；若還在比款式，可先看 2026 窗簾價格指南，再回來用同尺寸比較各品項。',
  },
  {
    q: '實木百葉窗價格試算適合從哪裡開始？',
    a: '建議先切到木百葉品項並套用三重或台北區域，再到實木百葉產品頁確認木種、葉片與安裝條件。',
  },
  {
    q: '估價結果會包含安裝費嗎？',
    a: '會。系統會依品項規則估算材料費與安裝費，並回傳總價。',
  },
  {
    q: '板橋窗簾價格試算後，下一步怎麼安排最快？',
    a: '建議先用同尺寸比較布簾、捲簾或風琴簾，再帶著試算結果安排板橋到府丈量，通常能更快收斂到正式報價。',
  },
];

export default function CalculatorPage() {
  return (
    <>
      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>/</span>
          <span>線上估價</span>
        </div>
      </nav>

      <Suspense fallback={null}>
        <CalculatorProductMenu products={calculatorProducts} />
      </Suspense>

      <div className="page-hero">
        <div className="section-container">
          <div className="tag" style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}>
            窗簾價格試算 / 線上估價
          </div>
          <h1>1 分鐘完成窗簾價格試算與安裝費估算</h1>
          <p>支援多種窗簾品項，先做窗簾線上估價與窗簾價格試算，再安排免費到府丈量與正式報價。</p>
        </div>
      </div>

      <section className="py-section bg-stone-50">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <h2>先試算，再丈量：窗簾報價流程一次完成</h2>
            <p>先用線上工具掌握窗簾價格與安裝費用區間，再由專人到府確認窗型、配件與施工條件。</p>
          </div>
          <div style={{ marginBottom: '1.25rem', display: 'grid', gap: '0.5rem' }}>
            <Link href="/calculator/?product=P005" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              捲簾價格試算：用同尺寸快速抓入門預算
            </Link>
            <Link href="/calculator/?product=P006" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              鋁百葉窗價格試算：廚房與浴室防潮方案
            </Link>
            <Link href="/products/wooden-blinds/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              實木百葉窗價格試算入口與產品重點
            </Link>
            <Link href="/blog/curtain-price-guide-2026/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              訂製窗簾價格、窗簾報價與安裝費用怎麼看？
            </Link>
            <Link href="/location/sanchong/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              三重窗簾推薦與三重窗簾價格試算入口
            </Link>
            <Link href="/location/zhongzheng/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              中正區窗簾推薦與中正區窗簾價格試算入口
            </Link>
            <Link href={buildCalculatorUrl('P009', 'banqiao')} style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              板橋風琴簾價格試算與到府丈量流程
            </Link>
            <Link href={buildCalculatorUrl('P007', 'sanchong')} style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              三重實木百葉窗價格試算（快速入口）
            </Link>
          </div>
          <Suspense fallback={<div style={{ textAlign: 'center', padding: '3rem', color: 'var(--stone-400)' }}>載入估價工具...</div>}>
            <CalculatorForm products={calculatorProducts} />
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
              '若要比較不同產品，建議固定同一尺寸切換捲簾、鋁百葉與實木百葉，判斷更直覺。',
              '若你想先衝「實木百葉窗價格試算」，可先切換木百葉品項再套用三重區域，會更接近實際報價條件。',
              '若你正在搜尋「三重窗簾」或「中正區窗簾價格試算」，可直接從本頁快速切到對應地區頁比對在地方案。',
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
          {calculatorFaq.map((item, index) => (
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
            {calculatorProducts.map((product) => (
              <Link
                key={product.id}
                href={buildCalculatorUrl(product.id)}
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
