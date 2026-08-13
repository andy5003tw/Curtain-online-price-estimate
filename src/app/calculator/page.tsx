import Link from 'next/link';
import { Suspense } from 'react';
import { CalculatorForm, CalculatorProductMenu } from './CalculatorClient';
import { products } from '@/data/products';
import { calculatorFaq } from '@/data/calculatorFaq';
import { buildCalculatorUrl } from '@/lib/seo';

const calculatorProducts = products.map((product) => ({
  id: product.id,
  name: product.name,
  slug: product.slug,
  canonicalSlug: product.canonicalSlug,
  requires_track: product.requires_track,
}));

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
            1 分鐘窗簾價格試算 / 線上估價
          </div>
          <h1>窗簾價格試算與窗簾線上估價：1 分鐘比較安裝費</h1>
          <p>輸入尺寸即可做窗簾價格試算與窗簾線上估價，比較鋁百葉、實木百葉、捲簾、紗簾、調光簾與風琴簾價格，系統先估材料與基本安裝費；再用同尺寸比較差異，安排三重、板橋或台北到府丈量確認正式報價。</p>
        </div>
      </div>

      <section className="py-section bg-stone-50">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <h2>先試算，再丈量：窗簾報價流程一次完成</h2>
            <p>先用線上工具掌握窗簾價格與安裝費用區間，再由專人到府確認窗型、配件與施工條件。</p>
          </div>
          <div style={{ marginBottom: '1.25rem', display: 'grid', gap: '0.5rem' }}>
            <Link href="/products/roller-blinds/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              已鎖定捲簾：先看捲簾產品、遮光與安裝條件
            </Link>
            <Link href="/products/aluminum-blinds/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              已鎖定鋁百葉：先看防潮需求、葉片與安裝條件
            </Link>
            <Link href="/calculator/?product=P002" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              紗簾價格試算：透光不透人紗簾與安裝費同尺寸比較
            </Link>
            <Link href={buildCalculatorUrl('P007')} style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              實木百葉窗價格試算：直接帶入木百葉品項
            </Link>
            <Link href={buildCalculatorUrl('P009')} style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              風琴簾價格試算：比較隔熱與臥室控溫預算
            </Link>
            <Link href={buildCalculatorUrl('P010')} style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              調光簾價格試算：比較客廳與臥室控光預算
            </Link>
            <Link href="/blog/curtain-price-guide-2026/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              窗簾價格多少合理？先看 2026 價格指南與安裝費
            </Link>
            <Link href="/location/taipei/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              台北窗簾價格試算：估價後安排到府丈量
            </Link>
            <Link href="/products/seamless-sheer-curtains/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              紗簾價格與透光不透人紗簾怎麼比？
            </Link>
            <Link href="/products/wooden-blinds/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              實木百葉價格怎麼算？看木種、葉片與安裝條件
            </Link>
            <Link href="/curtain/living-room/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              客廳窗簾價格試算與落地窗款式建議
            </Link>
            <Link href="/location/sanchong/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              三重窗簾推薦與三重窗簾價格試算入口
            </Link>
            <Link href="/location/banqiao/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              板橋窗簾推薦與板橋窗簾價格試算入口
            </Link>
            <Link href="/location/zhongzheng/" style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
              中正區窗簾推薦與中正區窗簾價格試算入口
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
              '窗簾安裝費用會受窗型、配件與施工難度影響，估價頁可先看材料與基本安裝費的大方向預算。',
              '想判斷窗簾價格多少合理，請用同一組尺寸比較 2 到 3 種品項，避免只看單才價格。',
              '若要比較不同產品，建議固定同一尺寸切換捲簾、鋁百葉、實木百葉、調光簾與風琴簾，判斷更直覺。',
              '若你想先做「百葉窗價格試算」，可先比較鋁百葉與實木百葉，再依防潮、木質感與安裝條件挑選。',
              '若你想先比較「紗簾價格」，可用同尺寸切換無縫紗簾與遮光布簾，確認透光不透人、雙層搭配與安裝費差異。',
              '若你想先衝「實木百葉窗價格試算」，可先切換木百葉品項再套用三重或台北區域，會更接近實際報價條件。',
              '若你正在搜尋「三重窗簾」或「板橋窗簾」，可直接從本頁快速切到對應地區頁比對在地方案與交期。',
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
