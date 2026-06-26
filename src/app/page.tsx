import type { Metadata } from 'next';
import Link from 'next/link';
import { Calculator, ChevronRight, CheckCircle2, Star } from 'lucide-react';
import FloatingCta from '@/components/FloatingCta';
import { products } from '@/data/products';
import { getGeoWaveGroups, type LocationPage } from '@/data/locationPages';
import { buildCalculatorUrl, buildOgTwitterMeta, productPath } from '@/lib/seo';
import { withBasePath } from '@/lib/base-path';

const HOME_TITLE = '窗簾推薦｜宏森窗簾、價格試算與雙北丈量';
const HOME_DESCRIPTION = '找窗簾或窗簾推薦、想先做窗簾價格試算？宏森提供 1 分鐘線上估價、百葉窗價格試算、價格指南與台北新北到府丈量入口。';

export const metadata: Metadata = {
  title: HOME_TITLE,
  description: HOME_DESCRIPTION,
  keywords: ['窗簾', '窗簾推薦', '窗簾價格試算', '窗簾線上估價', '窗簾估價工具', '百葉窗價格試算', '工廠直營窗簾', '三重窗簾', '三重窗簾推薦', '板橋窗簾推薦', '台北窗簾價格試算', '鶯歌窗簾推薦', '中正區窗簾價格試算', '無縫紗簾', '實木百葉窗價格試算', '窗簾訂製', '窗簾安裝', '到府丈量'],
  ...buildOgTwitterMeta({
    title: HOME_TITLE,
    description: HOME_DESCRIPTION,
    path: '/',
    image: '/banner_img/banner_01.webp',
    imageAlt: '宏森窗簾門市與窗簾展示',
  }),
};

const features = [
  {
    title: '30年窗簾經驗',
    desc: '深耕台北與新北窗簾訂製，提供穩定工班與標準化施工流程。',
  },
  {
    title: '免費到府丈量',
    desc: '現場評估採光、隱私與風格需求，提供可落地的搭配建議。',
  },
  {
    title: '工廠直營報價',
    desc: '先用窗簾價格試算抓區間，再由丈量確認材質、配件與安裝費。',
  },
  {
    title: '多品類一次比較',
    desc: '布簾、調光簾、百葉簾與功能簾可同場比較，決策更快速。',
  },
];

const trustNumbers = [
  { num: '30+', label: '年窗簾經驗' },
  { num: '1,284+', label: '客戶評價回饋' },
  { num: '5,000+', label: '累積安裝案例' },
  { num: '13+', label: '主要產品品項' },
];

const homepageFaq = [
  {
    q: '窗簾推薦要怎麼選，才不會只看款式？',
    a: '建議先從窗簾價格試算、2026 窗簾價格指南與所在地區頁開始，確認預算、採光隱私需求與丈量流程，再挑選布簾、紗簾、百葉或調光簾。',
  },
  {
    q: '宏森窗簾有提供免費到府丈量嗎？',
    a: '有，台北與新北主要服務區域提供免費到府丈量與初步配置建議。',
  },
  {
    q: '窗簾價格試算後多久可正式報價？',
    a: '先用窗簾線上估價輸入尺寸後，通常可立即看到預算區間；安排到府丈量後即可確認正式報價，特殊材質與大面積案件會再補充細項。',
  },
  {
    q: '搜尋窗簾推薦時，首頁先看哪三個入口？',
    a: '建議先看窗簾價格試算、2026 窗簾價格指南與所在服務區域頁。這三個入口能先確認預算、合理價格與到府丈量流程。',
  },
  {
    q: '三重窗簾要先估價還是先丈量？',
    a: '建議先用窗簾價格試算抓預算，再看三重窗簾服務頁與實木百葉窗價格試算內容，比對品項後再預約丈量，決策會更快。',
  },
  {
      q: '板橋、台北或鶯歌窗簾也可以先做線上估價嗎？',
      a: '可以，先用窗簾價格試算輸入尺寸，再切到台北、板橋或鶯歌地區頁確認到府丈量流程，能更快收斂到正式報價；若要先比行情，也可先看窗簾價格指南。',
  },
  {
    q: '百葉窗價格試算適合先比哪幾種？',
    a: '建議先用同一尺寸比較鋁百葉、實木百葉與風琴簾，再依防潮、木質感、隔熱與安裝條件縮小到 1 到 2 個方案。',
  },
  {
    q: '窗簾訂製或遮光窗簾，首頁先從哪個入口開始最快？',
    a: '若你先想抓預算，可直接進窗簾價格試算帶入一般窗簾或捲簾；若想先看窗簾價格、百葉窗價格與安裝費差異，可先讀價格指南，再回到試算器比較。',
  },
  {
    q: '可以同時比較多種窗簾款式嗎？',
    a: '可以，現場可比較布簾、調光簾、百葉簾與功能簾，協助你依空間需求決策。',
  },
  {
    q: '從丈量到安裝通常要多久？',
    a: '常規案件約 5-7 個工作天，特殊客製案約 7-14 個工作天。',
  },
];

function mapAreaCards(areas: LocationPage[], linkLabel: string) {
  return areas.map(item => ({
    href: `/location/${item.id}/`,
    title: `${item.areaName}窗簾服務頁`,
    desc: item.shortDescription,
    linkLabel,
  }));
}

export default function HomePage() {
  const { waveA, waveB, phase5WaveA, phase5WaveB, phase6WaveA, phase6WaveB } = getGeoWaveGroups();
  const geoGroups = [
    {
      key: 'wave-a',
      title: '波次 A｜台北核心 4 區',
      desc: '優先服務量最高的台北核心區。',
      linkLabel: '查看台北核心服務',
      areas: waveA,
    },
    {
      key: 'wave-b',
      title: '波次 B｜新北轉單 4 區',
      desc: '承接核心需求的新北高詢問區。',
      linkLabel: '查看新北轉單服務',
      areas: waveB,
    },
    {
      key: 'phase5-wave-a',
      title: 'Phase 5 Wave A｜台北延伸 4 區',
      desc: '第二輪擴張的台北延伸區域入口。',
      linkLabel: '查看台北延伸服務',
      areas: phase5WaveA,
    },
    {
      key: 'phase5-wave-b',
      title: 'Phase 5 Wave B｜新北延伸 4 區',
      desc: '第二輪擴張的新北延伸區域入口。',
      linkLabel: '查看新北延伸服務',
      areas: phase5WaveB,
    },
    {
      key: 'phase6-wave-a',
      title: 'Phase 6 Wave A｜新北核心 4 區',
      desc: '第三輪擴張的第一波核心區入口。',
      linkLabel: '查看新北核心服務',
      areas: phase6WaveA,
    },
    {
      key: 'phase6-wave-b',
      title: 'Phase 6 Wave B｜新北延伸 4 區',
      desc: '第三輪擴張的第二波延伸區入口。',
      linkLabel: '查看新北延伸服務',
      areas: phase6WaveB,
    },
  ];

  const websiteSchema = {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: '宏森窗簾',
    url: 'https://online.hong-sen.com/',
  };

  const faqSchema = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: homepageFaq.map(item => ({
      '@type': 'Question',
      name: item.q,
      acceptedAnswer: { '@type': 'Answer', text: item.a },
    })),
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(websiteSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />

      <FloatingCta />

      <section className="hero-section">
        <img src={withBasePath('/banner_img/banner_01.webp')} alt="宏森窗簾展示" className="hero-bg-img" fetchPriority="high" />
        <div className="hero-content">
          <p
            style={{
              display: 'inline-block',
              background: '#D97706',
              color: 'white',
              fontWeight: 700,
              fontSize: '0.875rem',
              padding: '0.4rem 1rem',
              borderRadius: '999px',
              marginBottom: '1rem',
            }}
          >
            宏森窗簾推薦・價格試算・台北新北丈量入口
          </p>
          <h1>宏森窗簾推薦：窗簾價格試算與線上估價入口</h1>
          <p>先用尺寸比較窗簾訂製、遮光窗簾、鋁百葉、捲簾、無縫紗簾與實木百葉價格區間；再依台北、三重、板橋、鶯歌、士林或中正區服務頁安排丈量，確認窗型、布料與安裝費。</p>
          <div className="hero-btns">
            <Link href={buildCalculatorUrl()} className="btn-primary">
              <Calculator size={18} />
              立即做窗簾價格試算
            </Link>
            <Link href="/blog/curtain-price-guide-2026/" className="btn-secondary">
              先看窗簾價格指南 <ChevronRight size={18} />
            </Link>
          </div>
          <div
            style={{
              display: 'flex',
              flexWrap: 'wrap',
              gap: '0.5rem',
              marginTop: '1rem',
              color: 'rgba(255,255,255,0.9)',
              fontSize: '0.9rem',
            }}
          >
                {['1 分鐘線上估價', '台北三重板橋鶯歌士林中正區丈量', '價格指南與產品入口同步比較'].map(item => (
              <span
                key={item}
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.35rem',
                  padding: '0.35rem 0.65rem',
                  border: '1px solid rgba(255,255,255,0.28)',
                  borderRadius: '999px',
                  background: 'rgba(0,0,0,0.22)',
                }}
              >
                <CheckCircle2 size={14} />
                {item}
              </span>
            ))}
          </div>
          <p style={{ marginTop: '0.85rem', fontSize: '0.9rem', color: 'rgba(255,255,255,0.85)' }}>
            常用入口：
            <Link href="/calculator/" style={{ marginLeft: '0.25rem', color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              窗簾價格試算
            </Link>
            {' · '}
            <Link href="/location/sanchong/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              三重窗簾價格試算
            </Link>
            {' · '}
            <Link href="/location/taipei/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              台北窗簾價格試算
            </Link>
            {' · '}
            <Link href="/location/banqiao/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              板橋窗簾推薦
            </Link>
            {' · '}
            <Link href="/location/yingge/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              鶯歌窗簾推薦
            </Link>
            {' · '}
            <Link href="/location/shilin/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              士林窗簾推薦
            </Link>
            {' · '}
            <Link href="/location/zhongzheng/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              中正區窗簾價格試算
            </Link>
            {' · '}
            <Link href="/blog/curtain-price-guide-2026/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              窗簾價格指南
            </Link>
            {' · '}
            <Link href="/products/custom-curtains/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              窗簾訂製與遮光布簾
            </Link>
            {' · '}
            <Link href="/curtain/blackout/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              遮光窗簾推薦
            </Link>
            {' · '}
            <Link href="/products/seamless-sheer-curtains/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              無縫紗簾推薦
            </Link>
            {' · '}
            <Link href="/products/wooden-blinds/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              實木百葉窗價格試算
            </Link>
            {' · '}
            <Link href="/products/aluminum-blinds/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              百葉窗價格試算
            </Link>
            {' · '}
            <Link href="/products/bamboo-blinds/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              竹簾訂製
            </Link>
            {' · '}
            <Link href="/about/" style={{ color: '#FCD34D', fontWeight: 700, textDecoration: 'underline' }}>
              工廠直營窗簾與品牌服務
            </Link>
          </p>
        </div>
      </section>

      <section style={{ background: 'var(--amber-700)', color: 'white', padding: '2.5rem 0' }}>
        <div className="section-container">
          <div className="trust-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '1.5rem' }}>
            {trustNumbers.map(item => (
              <div key={item.label} style={{ textAlign: 'center' }}>
                <div style={{ fontSize: 'clamp(2rem, 4vw, 2.8rem)', fontWeight: 900, lineHeight: 1 }}>{item.num}</div>
                <div style={{ fontSize: '0.85rem', opacity: 0.85, marginTop: '0.35rem' }}>{item.label}</div>
              </div>
            ))}
          </div>
        </div>
        <style dangerouslySetInnerHTML={{ __html: '@media (min-width: 640px) { .trust-grid { grid-template-columns: repeat(4, 1fr) !important; } }' }} />
      </section>

      <section className="py-section bg-white">
        <div className="section-container">
          <div className="section-heading">
            <div className="tag">為什麼選宏森</div>
            <h2>可靠流程與透明價格</h2>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: '1.25rem' }}>
            {features.map(item => (
              <article key={item.title} style={{ padding: '1.5rem', background: 'var(--stone-50)', borderRadius: '1rem', border: '1px solid var(--stone-100)' }}>
                <CheckCircle2 size={24} style={{ color: 'var(--amber-600)', marginBottom: '0.75rem' }} />
                <h3 style={{ marginBottom: '0.5rem' }}>{item.title}</h3>
                <p style={{ margin: 0, fontSize: '0.9rem', color: 'var(--stone-600)', lineHeight: 1.7 }}>{item.desc}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="py-section bg-stone-50">
        <div className="section-container">
          <div className="section-heading">
            <div className="tag">雙北熱門服務區域</div>
            <h2>24 區服務入口快速導覽</h2>
            <p>首頁與產品頁同步擴充到 24 個 GEO 入口，依六組波次快速找到對應地區頁，並直接導回價格試算與價格指南。</p>
          </div>

          {geoGroups.map((group, index) => {
            const cards = mapAreaCards(group.areas, group.linkLabel);
            if (cards.length === 0) {
              return null;
            }
            return (
              <div key={group.key} style={{ marginBottom: index === geoGroups.length - 1 ? 0 : '1.5rem' }}>
                <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: '0.45rem', color: 'var(--stone-900)' }}>{group.title}</h3>
                <p style={{ margin: '0 0 0.8rem 0', color: 'var(--stone-600)', fontSize: '0.88rem' }}>{group.desc}</p>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '1rem' }}>
                  {cards.map(area => (
                    <Link
                      key={area.href}
                      href={area.href}
                      style={{
                        background: 'white',
                        border: '1px solid var(--stone-200)',
                        borderRadius: '1rem',
                        padding: '1.1rem 1rem',
                        textDecoration: 'none',
                        color: 'inherit',
                        display: 'block',
                      }}
                    >
                      <h3 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: '0.35rem', color: 'var(--stone-900)' }}>{area.title}</h3>
                      <p style={{ margin: 0, color: 'var(--stone-600)', fontSize: '0.88rem', lineHeight: 1.6 }}>{area.desc}</p>
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem', marginTop: '0.7rem', color: 'var(--amber-700)', fontWeight: 700, fontSize: '0.84rem' }}>
                        {area.linkLabel} <ChevronRight size={14} />
                      </span>
                    </Link>
                  ))}
                </div>
              </div>
            );
          })}
          <div style={{ textAlign: 'center', marginTop: '1.2rem' }}>
            <Link href="/location/" className="btn-secondary" style={{ fontSize: '0.95rem' }}>
              查看完整 30 區服務總覽
            </Link>
          </div>
        </div>
      </section>

      <section className="py-section bg-white">
        <div className="section-container">
          <div className="section-heading">
            <div className="tag">熱門產品</div>
            <h2>快速進入產品詳情頁</h2>
          </div>
          <div className="product-grid">
            {products.map(product => (
              <article key={product.id} className="product-card">
                <div className="product-card-img">
                  <img src={withBasePath(product.image)} alt={product.image_alt || product.name} title={product.image_title || product.name} loading="lazy" />
                </div>
                <div className="product-card-body">
                  <h3>{product.name}</h3>
                  <p>{product.description}</p>
                  <Link href={productPath(product)} className="btn-outline">
                    了解更多 <ChevronRight size={14} />
                  </Link>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container" style={{ maxWidth: '860px' }}>
          <div className="section-heading">
            <div className="tag">常見問題</div>
            <h2>首頁 FAQ</h2>
          </div>
          <div style={{ display: 'grid', gap: '1rem' }}>
            {homepageFaq.map((item, index) => (
              <details key={item.q} style={{ background: 'var(--stone-50)', border: '1px solid var(--stone-200)', borderRadius: '0.75rem', overflow: 'hidden' }}>
                <summary style={{ padding: '1rem 1.25rem', fontWeight: 700, cursor: 'pointer', listStyle: 'none' }}>{item.q}</summary>
                <div style={{ padding: '0 1.25rem 1rem', color: 'var(--stone-600)', lineHeight: 1.7 }}>
                  {item.a}
                </div>
              </details>
            ))}
          </div>
        </div>
      </section>

      <section style={{ background: 'linear-gradient(135deg, var(--stone-900) 0%, #2d2520 100%)', color: 'white', padding: '4.5rem 0', textAlign: 'center' }}>
        <div className="section-container">
          <div style={{ display: 'flex', justifyContent: 'center', gap: '0.3rem', marginBottom: '1rem', color: '#FCD34D' }}>
            {[1, 2, 3, 4, 5].map(i => <Star key={i} size={22} fill="#FCD34D" />)}
          </div>
          <div className="tag" style={{ background: 'rgba(255,255,255,0.1)', color: 'var(--stone-200)' }}>快速估價</div>
          <h2 style={{ fontSize: 'clamp(1.75rem, 4vw, 2.4rem)', fontWeight: 700, marginBottom: '1rem' }}>立即預約到府丈量</h2>
          <p style={{ color: 'var(--stone-300)', marginBottom: '2rem', maxWidth: '520px', margin: '0 auto 2rem' }}>
            先估價、再看價格指南與服務區入口，流程清楚，快速確認你的窗簾方案。
          </p>
          <div style={{ display: 'flex', justifyContent: 'center', gap: '0.8rem', flexWrap: 'wrap' }}>
            <Link href={buildCalculatorUrl()} className="btn-primary" style={{ display: 'inline-flex', background: 'var(--amber-600)', fontSize: '1rem', padding: '0.9rem 2rem' }}>
              <Calculator size={20} />
              前往線上估價
            </Link>
            <Link href="/blog/curtain-price-guide-2026/" className="btn-secondary" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.45rem', padding: '0.9rem 2rem' }}>
              <ChevronRight size={18} />
              先看價格指南
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
