import type { Metadata } from 'next';
import Link from 'next/link';
import { products } from '@/data/products';
import { getGeoExpansionPages } from '@/data/locationPages';
import { absoluteUrl, buildCalculatorUrl, COMPANY_NAME, productPath } from '@/lib/seo';
import { ChevronRight } from 'lucide-react';
import ProductScrollMenu from '@/components/ProductScrollMenu';

export const metadata: Metadata = {
  title: '全系列窗簾產品 | 捲簾・蛇形簾・百葉窗・羅馬簾',
  description: '宏森開發提供13種以上窗簾款式：一般窗簾、無縫紗簾、蛇形窗簾、捲簾、羅馬簾、鋁百葉、木百葉、風琴簾、調光簾、柔紗簾、直立簾。工廠直營、大台北地區免費丈量線上估價。',
  keywords: ['台北窗簾種類', '窗簾款式推薦', '客製化窗簾', '客廳布簾', '木百葉窗', '防焰窗簾'],
  alternates: { canonical: absoluteUrl('/products/') },
  openGraph: {
    title: '全系列窗簾產品 | 捲簾・蛇形簾・百葉窗 | 宏森窗簾',
    description: '13種以上熱門窗簾款式總覽。30年工廠直營，大台北免費到府丈量，找對窗簾，改變家裡的氛圍！',
    url: absoluteUrl('/products/'),
    siteName: '宏森開發窗簾規劃',
    images: [{ url: absoluteUrl('/Curtain%20installation_img/Curtain%20installation_02.webp'), width: 1200, height: 630 }],
    locale: 'zh_TW',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: '全系列窗簾產品總覽 | 宏森窗簾',
    description: '30年工廠直營，大台北免費到府丈量，各式客製化機能窗簾齊全。',
    images: [absoluteUrl('/Curtain%20installation_img/Curtain%20installation_02.webp')],
  },
};

const productListSchema = {
  '@context': 'https://schema.org',
  '@type': 'ItemList',
  name: '宏森開發窗簾產品系列',
  url: absoluteUrl('/products/'),
  itemListElement: products.map((p, i) => ({
    '@type': 'ListItem',
    position: i + 1,
    url: absoluteUrl(productPath(p)),
    name: p.name,
  })),
};

const breadcrumbSchema = {
  '@context': 'https://schema.org',
  '@type': 'BreadcrumbList',
  itemListElement: [
    { '@type': 'ListItem', position: 1, name: '首頁', item: absoluteUrl('/') },
    { '@type': 'ListItem', position: 2, name: '產品系列', item: absoluteUrl('/products/') }
  ]
};

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: [
    {
      '@type': 'Question',
      name: '我要如何挑選適合我家的窗簾種類？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '這取決於空間需求：客廳建議選擇大氣的蛇形簾或透光的紗簾；臥室需要睡眠品質，推薦 100% 遮光的三明治布或遮光捲簾；浴室或廚房則建議防水防霉的鋁百葉窗。'
      }
    },
    {
      '@type': 'Question',
      name: '家裡有嚴重過敏兒，推薦哪一種款式？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '強烈推薦「捲簾」或「調光簾」，因為它們表面平整、不易累積灰塵塵蟎，且材質可以使用濕布擦拭，對於過敏體質的家庭非常友善。'
      }
    },
    {
      '@type': 'Question',
      name: '特殊造型窗戶或西曬房有推薦的款式嗎？',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '西曬房非常推薦「風琴簾 (蜂巢簾)」，其中空蜂巢結構能大幅隔絕熱氣，有效降低室內溫度與冷氣耗電。如果您窗戶較小，摺疊收納的羅馬簾也是絕佳選擇。'
      }
    }
  ]
};

const microTags: Record<string, string[]> = {
  'P001': ['#高遮光', '#基本款百搭', '#可水洗'],
  'P002': ['#無縫工藝', '#視覺通透', '#增加隱私'],
  'P003': ['#完美S型', '#落地窗必備', '#五星級飯店愛用'],
  'P004': ['#層次分明', '#適合小窗', '#節省空間'],
  'P005': ['#好清潔', '#防潑水', '#辦公室首選'],
  'P006': ['#防水防霉', '#精確調光', '#浴室必備'],
  'P007': ['#天然實木', '#溫潤禪風', '#提升質感'],
  'P008': ['#日式和風', '#通風透氣', '#古樸韻味'],
  'P009': ['#極致斷熱', '#節能省電', '#西曬房救星'],
  'P010': ['#自由調光', '#現代時尚', '#不易積灰塵'],
  'P011': ['#夢幻唯美', '#高端質感', '#兩層過濾光線'],
  'P012': ['#CNS防焰', '#抗菌處理', '#通風網格'],
  'P013': ['#180度調光', '#俐落線條', '#大面積隔間'],
};

// SILO Categories
const categorySoft = ['P001', 'P002', 'P003', 'P004', 'P011'];
const categoryHard = ['P005', 'P006', 'P007', 'P010'];
const categoryFunc = ['P009', 'P012', 'P013', 'P008'];

export default function ProductsPage() {
  const getProductsBySilo = (ids: string[]) => products.filter(p => ids.includes(p.id));
  const geoQuickAreas = getGeoExpansionPages();

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(productListSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />

      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>›</span>
          <span>產品系列</span>
        </div>
      </nav>
      <ProductScrollMenu products={products} />

      <section className="py-section bg-white">
        <div className="section-container" style={{ maxWidth: '800px', margin: '0 auto' }}>
          <div className="tag" style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}>客製化窗簾材質與款式總覽</div>
          <h1>專業窗簾款式・任您挑選</h1>
          
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.4rem', margin: '1rem 0 1.5rem 0' }}>
            <div style={{ display: 'flex', color: '#FCD34D' }}>
              {'★★★★★'.split('').map((star, i) => <span key={i} style={{ fontSize: '1.25rem' }}>{star}</span>)}
            </div>
            <span style={{ fontSize: '1rem', fontWeight: 600, color: 'white' }}>4.9/5 星評價</span>
            <span style={{ fontSize: '0.9rem', color: 'rgba(255,255,255,0.8)', marginLeft: '0.2rem' }}>(累計 1,284 則服務好評)</span>
          </div>
          <p style={{ lineHeight: '1.8' }}>
            宏森窗簾工廠直營 30 年，提供大台北地區最齊全的窗簾種類。從優雅柔和的經典布簾、紗簾，到現代俐落的木百葉窗、調光簾，甚至具備隔熱與防焰特性的機能型窗簾，我們為您的客廳、臥室、辦公室等各種空間打造專屬的完美光影。滿足各種預算，保證平價且高質感。
          </p>
        </div>
      </section>

      <section className="py-section bg-stone-50">
        <div className="section-container">
          
          {/* Silo 1: Soft Treatments */}
          <div style={{ marginBottom: '5rem' }}>
            <div className="section-heading" style={{ textAlign: 'left', marginBottom: '2.5rem' }}>
              <div className="tag">Soft Treatments</div>
              <h2 style={{ fontSize: '2rem' }}>優雅布質軟裝系列</h2>
              <p>強調布料垂墜感與柔和光線過濾，為客廳與臥室營造極致溫馨與高遮光的舒眠環境。</p>
            </div>
            <div className="product-grid">
              {getProductsBySilo(categorySoft).map(product => (
                <ProductCard key={product.id} product={product} />
              ))}
            </div>
          </div>

          {/* Silo 2: Hard Treatments */}
          <div style={{ marginBottom: '5rem' }}>
            <div className="section-heading" style={{ textAlign: 'left', marginBottom: '2.5rem' }}>
              <div className="tag">Hard Treatments</div>
              <h2 style={{ fontSize: '2rem' }}>現代硬體百葉系列</h2>
              <p>不佔空間、精準調光且線條俐落，不論是辦公室捲簾或營造北歐風的木百葉窗，皆是超人氣選擇。</p>
            </div>
            <div className="product-grid">
              {getProductsBySilo(categoryHard).map(product => (
                <ProductCard key={product.id} product={product} />
              ))}
            </div>
          </div>

          {/* Silo 3: Functional */}
          <div style={{ marginBottom: '2rem' }}>
            <div className="section-heading" style={{ textAlign: 'left', marginBottom: '2.5rem' }}>
              <div className="tag">Functional</div>
              <h2 style={{ fontSize: '2rem' }}>特殊機能與場域系列</h2>
              <p>針對西曬斷熱、醫療防焰抗菌，或是日式和風、大面積落地窗等特殊需求量身打造。</p>
            </div>
            <div className="product-grid">
              {getProductsBySilo(categoryFunc).map(product => (
                <ProductCard key={product.id} product={product} />
              ))}
            </div>
          </div>

        </div>
      </section>

      {/* Embedded FAQ for Category Page */}
      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container" style={{ maxWidth: '800px' }}>
          <div className="section-heading">
            <h2 style={{ fontSize: '2.2rem' }}>窗簾選購常見問答</h2>
            <p>不知道該選哪一款？看看我們的專家建議</p>
          </div>
          {faqSchema.mainEntity.map((item, i) => (
            <div key={i} style={{ marginBottom: '1.25rem', padding: '1.5rem', background: 'var(--stone-50)', borderRadius: '1rem', border: '1px solid var(--stone-100)' }}>
              <h3 style={{ fontWeight: 700, marginBottom: '0.75rem', fontSize: '1.1rem', color: 'var(--amber-800)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span style={{ background: 'var(--amber-100)', color: 'var(--amber-700)', padding: '0.15rem 0.5rem', borderRadius: '0.5rem', fontSize: '0.85rem' }}>Q</span>
                {item.name}
              </h3>
              <p style={{ color: 'var(--stone-700)', fontSize: '0.95rem', lineHeight: 1.8, margin: 0, paddingLeft: '2.25rem' }}>{item.acceptedAnswer.text}</p>
            </div>
          ))}
          <p style={{ marginTop: '2rem', textAlign: 'center', fontSize: '0.95rem', color: 'var(--stone-600)' }}>
            想看這些款式的實際完工樣子嗎？立即前往 <Link href="/cases" style={{ color: '#06C755', fontWeight: 700, textDecoration: 'underline' }}>大台北百大精選施工案例</Link> 👀
          </p>
        </div>
      </section>

      {/* Local & Scenario SEO Keyword Matrix */}
      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container" style={{ maxWidth: '1000px' }}>
          <div className="section-heading" style={{ marginBottom: '2.5rem' }}>
            <h2 style={{ fontSize: '1.8rem' }}>依需求與空間快速探索</h2>
            <p style={{ fontSize: '0.95rem' }}>透過快速分類，精準找到符合您環境的完美窗簾</p>
          </div>
          
          <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr)', gap: '3rem' }} className="matrix-grid">
            <div>
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1.25rem', color: 'var(--amber-800)', borderBottom: '2px solid var(--amber-100)', paddingBottom: '0.5rem', display: 'inline-block' }}>熱門空間情境推薦</h3>
              <ul className="matrix-list">
                {['客廳質感大窗簾', '主臥室 100% 遮光窗簾', '書房透氣木百葉', '廚房防水防油捲簾', '浴室防霉鋁百葉', '西曬房隔熱蜂巢簾', '辦公室大面積調光簾', '頂樓西曬斷熱設計', '兒童房防塵蟎窗簾'].map((kw, i) => (
                  <li key={i}><Link href="/cases" className="matrix-link">{kw}</Link></li>
                ))}
              </ul>
            </div>
            
            <div>
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1.25rem', color: 'var(--amber-800)', borderBottom: '2px solid var(--amber-100)', paddingBottom: '0.5rem', display: 'inline-block' }}>大台北專業服務分區</h3>
              <ul className="matrix-list">
                {['台北市窗簾訂製', '新北市窗簾工廠', '三重窗簾推薦', '蘆洲平價窗簾', '板橋客製化窗簾', '新莊窗簾丈量', '中和窗簾施工', '永和遮光窗簾', '林口別墅窗簾設計', '五股窗簾安裝'].map((kw, i) => (
                  <li key={i}><Link href="/about" className="matrix-link">{kw}</Link></li>
                ))}
              </ul>
            </div>
          </div>
        </div>
        <style dangerouslySetInnerHTML={{__html: `
          .matrix-list { list-style: none; display: flex; flex-wrap: wrap; gap: 0.75rem; }
          .matrix-link { display: block; font-size: 0.9rem; color: var(--stone-600); background: var(--stone-50); padding: 0.5rem 1rem; border-radius: 0.5rem; transition: all 0.2s; border: 1px solid var(--stone-100); text-decoration: none; }
          .matrix-link:hover { color: var(--amber-700); border-color: var(--amber-200); background: var(--amber-50); box-shadow: 0 2px 4px rgba(0,0,0,0.02); }
          @media (min-width: 768px) { .matrix-grid { grid-template-columns: 1fr 1fr !important; gap: 4rem !important; } }
        `}} />
      </section>

      {geoQuickAreas.length > 0 && (
        <section className="py-section bg-stone-50 border-t border-stone-200">
          <div className="section-container" style={{ maxWidth: '1000px' }}>
            <div className="section-heading">
              <h2 style={{ fontSize: '1.8rem' }}>地區服務快選</h2>
              <p style={{ fontSize: '0.95rem' }}>依所在地區快速查看專屬窗簾建議與免費丈量服務</p>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '0.9rem' }}>
              {geoQuickAreas.map(area => (
                <article
                  key={area.id}
                  style={{
                    background: 'white',
                    border: '1px solid var(--stone-200)',
                    borderRadius: '0.85rem',
                    padding: '0.9rem 1rem',
                  }}
                >
                  <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: 'var(--stone-900)' }}>
                    {area.areaName}窗簾服務
                  </h3>
                  <p style={{ margin: '0.35rem 0 0 0', color: 'var(--stone-600)', fontSize: '0.84rem', lineHeight: 1.55 }}>
                    {area.title}
                  </p>
                  <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.8rem', flexWrap: 'wrap' }}>
                    <Link href={`/location/${area.id}/`} className="btn-outline" style={{ flex: 1, justifyContent: 'center' }}>
                      查看地區頁
                    </Link>
                    <Link href={buildCalculatorUrl(undefined, area.id)} className="btn-primary" style={{ flex: 1, justifyContent: 'center' }}>
                      帶入估價
                    </Link>
                  </div>
                </article>
              ))}
            </div>
            <div style={{ textAlign: 'center', marginTop: '1rem' }}>
              <Link href="/location/" className="btn-secondary" style={{ fontSize: '0.95rem' }}>
                查看完整 30 區服務總覽
              </Link>
            </div>
          </div>
        </section>
      )}

      <section style={{ background: 'var(--stone-900)', color: 'white', padding: '4.5rem 0', textAlign: 'center' }}>
        <div className="section-container">
          <h2 style={{ fontSize: '1.8rem', fontWeight: 700, marginBottom: '0.75rem' }}>仍找不到適合的款式嗎？</h2>
          <p style={{ color: 'var(--stone-300)', marginBottom: '2.5rem', fontSize: '1.05rem' }}>歡迎聯絡我們，由專業人員帶著型錄與樣本為您現場解說推薦。</p>
          <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link href={buildCalculatorUrl()} className="btn-primary" style={{ background: 'var(--amber-600)', padding: '0.8rem 2rem' }}>
              直接線上估價 <ChevronRight size={18} />
            </Link>
            <a href="https://line.me/ti/p/fDWxUXkiZb" target="_blank" rel="noopener noreferrer" className="btn-secondary" style={{ padding: '0.8rem 2rem', background: '#06C755', borderColor: '#06C755', color: 'white' }}>
              客服一 0980 (加 LINE)
            </a>
            <a href="https://line.me/ti/p/nS1XQ4-flk" target="_blank" rel="noopener noreferrer" className="btn-secondary" style={{ padding: '0.8rem 2rem', background: '#05b04b', borderColor: '#05b04b', color: 'white' }}>
              客服二 0973 (加 LINE)
            </a>
          </div>
        </div>
      </section>
    </>
  );
}

// Subcomponent for Product Card to avoid messy mapping code
function ProductCard({ product }: { product: any }) {
  const tags = microTags[product.id] || [];
  return (
    <article id={product.id} className="product-card" style={{ scrollMarginTop: '100px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div className="product-card-img">
        <img
          src={product.image}
          alt={product.image_alt || product.name}
          title={product.image_title || product.name}
          loading="lazy"
        />
      </div>
      <div className="product-card-body" style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        <h3 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--stone-900)' }}>{product.name}</h3>
        {/* Micro Tags */}
        <div style={{ display: 'flex', gap: '0.4rem', flexWrap: 'wrap', marginBottom: '0.75rem' }}>
          {tags.map((t, idx) => (
            <span key={idx} style={{ background: '#FFFFFF', color: '#D97706', border: '1px solid #D97706', padding: '0.25rem 0.6rem', borderRadius: '2rem', fontSize: '0.75rem', fontWeight: 700 }}>{t}</span>
          ))}
        </div>
        <p style={{ fontSize: '0.9rem', color: 'var(--stone-600)', lineHeight: '1.6', marginBottom: '1.5rem', flex: 1 }}>{product.description}</p>
        <div style={{ display: 'flex', gap: '0.5rem', marginTop: 'auto' }}>
          <Link href={productPath(product)} className="btn-outline" style={{ flex: 1, justifyContent: 'center' }}>
            了解更多
          </Link>
          <Link
            href={buildCalculatorUrl(product.id)}
            className="btn-primary"
            style={{ flex: 1, justifyContent: 'center', fontSize: '0.85rem', padding: '0.6rem 0.75rem' }}
          >
            立即估價
          </Link>
        </div>
      </div>
    </article>
  );
}
