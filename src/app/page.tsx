import type { Metadata } from 'next';
import Link from 'next/link';
import { Calculator, ChevronRight, CheckCircle2, ChevronDown, MessageSquare, MessageCircle } from 'lucide-react';
import FloatingCta from '@/components/FloatingCta';
import { products } from '@/data/products';
import { getGeoWaveGroups, getLocationCoverageSummary, locationPages, type LocationPage } from '@/data/locationPages';
import { buildCalculatorUrl, buildOgTwitterMeta, productPath } from '@/lib/seo';
import { withBasePath } from '@/lib/base-path';

const HOME_TITLE = '窗簾｜雙北免費到府丈量、線上價格試算｜宏森窗簾';
const HOME_DESCRIPTION = '找窗簾訂製、價格試算與雙北到府丈量？宏森窗簾首頁先協助比較布簾、紗簾、調光簾與百葉窗，再依窗型、採光與預算確認合適方案。';
const locationCoverage = getLocationCoverageSummary();

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
    image: '/about_img/about_01.webp',
    imageAlt: '宏森窗簾實體門市與多年窗簾展示',
    badge: '30年老字號',
  },
  {
    title: '免費到府丈量',
    desc: '現場評估採光、隱私與風格需求，提供可落地的搭配建議。',
    image: '/Curtain installation_img/Curtain_installation_trimmed.webp',
    imageAlt: '宏森專業師傅現場精準丈量窗型與軌道',
    badge: '專業工班到府',
  },
  {
    title: '工廠直營報價',
    desc: '先用窗簾價格試算抓區間，再由丈量確認材質、配件與安裝費。',
    image: '/Construction Cases_img/LINE_ALBUM_三和路三段_260414_2.webp',
    imageAlt: '宏森窗簾工廠直營加工與精細車縫五金工藝',
    badge: '廠辦合一透明價',
  },
  {
    title: '多品類一次比較',
    desc: '布簾、調光簾、百葉簾與功能簾可同場比較，決策更快速。',
    image: '/images/P001_curtain.webp',
    imageAlt: '宏森窗簾多品類同場比較布簾與調光簾',
    badge: '同尺寸跨材質比價',
  },
];

const flagshipGeoCards = [
  {
    id: 'sanchong',
    areaName: '三重區',
    badge: '旗艦發源工班',
    image: '/Construction Cases_img/LINE_ALBUM_20240813三重介壽路-蛇形簾_260414_1.webp',
    imageAlt: '宏森窗簾三重在地丈量與蛇形簾施工案例',
    desc: '宏森發源旗艦戰場，廠辦合一最速到府。客廳蛇形簾、調光簾與木百葉多款現貨透明比價。',
    tag: '快速看樣・老牌工班',
  },
  {
    id: 'daan',
    areaName: '大安區',
    badge: '豪宅精選',
    image: '/banner_img/banner_01.webp',
    imageAlt: '台北大安區頂級大面落地窗簾與調光簾案例',
    desc: '大安都會高質感住宅首選，專精高挑大窗、雙層蛇形紗簾與精緻電動窗簾落地方案。',
    tag: '大面採光・隱私美學',
  },
  {
    id: 'banqiao',
    areaName: '板橋區',
    badge: '熱門諮詢',
    image: '/Construction Cases_img/LINE_ALBUM_20240429板橋中正路379巷-捲簾_260414_1.webp',
    imageAlt: '宏森窗簾板橋區住宅捲簾與到府丈量案例',
    desc: '新板特區與舊市區高詢問度，先用 1 分鐘估價比較布簾、風琴簾與捲簾，極速預約丈量。',
    tag: '新成屋・中古翻新',
  },
  {
    id: 'xinyi',
    areaName: '信義區',
    badge: '高樓景觀',
    image: '/Construction Cases_img/LINE_ALBUM_民生東路三段-直立簾_260414_1.webp',
    imageAlt: '台北信義區商辦與景觀宅直立簾施工案例',
    desc: '信義高樓景觀宅與商用空間，常見大面採光與西曬降溫需求，兼顧開闊視野與隔熱。',
    tag: '西曬隔熱・防眩調光',
  },
  {
    id: 'xinzhuang',
    areaName: '新莊區',
    badge: '重劃特區',
    image: '/Construction Cases_img/LINE_ALBUM_新莊中正路-窗簾_260414_1.webp',
    imageAlt: '宏森窗簾新莊副都心與中正路窗簾施工案例',
    desc: '副都心與舊市區整合配置，客廳落地窗無縫紗簾搭配臥室全遮光捲簾，全室一次到位。',
    tag: '副都心・整室配置',
  },
  {
    id: 'neihu',
    areaName: '內湖區',
    badge: '科技商住',
    image: '/Construction Cases_img/LINE_ALBUM_20240628內湖金豐街-布簾及調光簾_260414_1.webp',
    imageAlt: '台北內湖區大面採光布簾與調光簾施工案例',
    desc: '科技園區商辦與住宅社區，螢幕防眩捲簾、會議室遮光與居家溫馨布簾快速到府規劃。',
    tag: '大面窗・防眩調光',
  },
  {
    id: 'zhonghe',
    areaName: '中和區',
    badge: '商住推薦',
    image: '/Construction Cases_img/LINE_ALBUM_中和建八路-鋁百葉_260414_1.webp',
    imageAlt: '新北中和區鋁百葉與遮光簾施工案例',
    desc: '景安、南勢角商住混合，同尺寸比價蛇形簾、鋁百葉與遮光布簾，高性價比耐用首選。',
    tag: '高CP值・耐用好清',
  },
  {
    id: 'zhongshan',
    areaName: '中山區',
    badge: '精品都會',
    image: '/Construction Cases_img/LINE_ALBUM_中山北路二段_260414_1.webp',
    imageAlt: '台北中山區精品住宅與店面窗簾施工案例',
    desc: '精品商辦、飯店宅與雅痞公寓，俐落調光簾與天然實木百葉營造精緻都會生活氛圍。',
    tag: '質感木百葉・調光簾',
  },
];

const trustNumbers = [
  { num: '30+', label: '年窗簾經驗' },
  { num: String(products.length), label: '可估價產品品項' },
  { num: String(locationCoverage.indexableLocationPageCount), label: '可索引地區資訊頁' },
  { num: '1', label: '線上估價工具' },
];

const homepageFaq = [
  {
    q: '窗簾要怎麼選，才不會只看款式？',
    a: '建議先從窗簾價格試算、2026 窗簾價格指南與所在地區頁開始，確認預算、採光、隱私需求與丈量流程，再比較布簾、紗簾、百葉或調光簾，讓選擇更貼近實際使用情境。',
  },
  {
    q: '搜尋窗簾或窗簾推薦，最快從哪裡開始？',
    a: '最快先用首頁進入窗簾價格試算，再看 2026 窗簾價格指南與台北、新北服務區域頁。先確認預算、合理價格與丈量流程，再挑產品頁會更有效率。',
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

// Keep the visible FAQ and FAQPage schema on the same focused 3–5 question set.
const homepageSeoFaq = homepageFaq.slice(0, 5);

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
      title: '台北核心服務區｜4 區到府丈量',
      desc: '台北市詢問度高的重點服務區，可先線上估價再安排丈量。',
      linkLabel: '查看台北服務',
      areas: waveA,
    },
    {
      key: 'wave-b',
      title: '新北熱門服務區｜4 區快速估價',
      desc: '新北主要住宅與商辦服務區，適合先比較價格再預約丈量。',
      linkLabel: '查看新北服務',
      areas: waveB,
    },
    {
      key: 'phase5-wave-a',
      title: '台北延伸服務區｜4 區價格試算',
      desc: '台北延伸生活圈入口，可依地區查看窗簾推薦與丈量流程。',
      linkLabel: '查看台北服務',
      areas: phase5WaveA,
    },
    {
      key: 'phase5-wave-b',
      title: '新北延伸服務區｜4 區到府丈量',
      desc: '新北延伸生活圈入口，適合比較窗簾價格、安裝費與產品搭配。',
      linkLabel: '查看新北服務',
      areas: phase5WaveB,
    },
    {
      key: 'phase6-wave-a',
      title: '新北核心服務區｜4 區窗簾推薦',
      desc: '新北核心住宅區入口，可快速進入地區頁與線上估價。',
      linkLabel: '查看新北服務',
      areas: phase6WaveA,
    },
    {
      key: 'phase6-wave-b',
      title: '新北外圍服務區｜4 區價格試算',
      desc: '新北外圍與延伸服務區，可先抓預算再安排到府丈量。',
      linkLabel: '查看新北服務',
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
    mainEntity: homepageSeoFaq.map(item => ({
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
          <h1>窗簾訂製與免費到府丈量：先比價格，再選合適方案</h1>
          <div className="hero-btns">
            <Link href={buildCalculatorUrl()} className="btn-primary">
              <Calculator size={18} />
              立即做窗簾價格試算
            </Link>
            <Link href="/blog/curtain-price-guide-2026/" className="btn-secondary">
              先看窗簾價格指南 <ChevronRight size={18} />
            </Link>
          </div>
        </div>
      </section>

      <section className="home-trust-bar">
        <div className="section-container">
          <div className="trust-grid">
            {trustNumbers.map(item => (
              <div key={item.label} className="trust-item">
                <div className="trust-item-num">{item.num}</div>
                <div className="trust-item-label">{item.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 獨立專屬導航區塊：雙北窗簾服務指引與熱門搜尋樞紐 */}
      <section className="home-seo-hub-section">
        <div className="section-container">
          <div className="seo-hub-panel">
            <div className="seo-hub-badge">
              宏森窗簾・先比價格，再安排雙北免費丈量
            </div>
            <p className="seo-hub-ai-text" data-ai-answer="true">
              宏森窗簾首頁提供窗簾訂製、價格試算與台北、新北免費到府丈量服務：先用尺寸比較布簾、遮光窗簾、紗簾、鋁百葉、捲簾與實木百葉的價格區間；再依窗型、採光、布料與安裝需求確認合適方案。若已鎖定單一產品，請直接查看對應產品頁的材質與安裝條件。
            </p>
            <div className="seo-hub-commitments">
              {['1 分鐘線上估價', '台北三重板橋鶯歌士林中正區丈量', '價格指南與產品入口同步比較'].map(item => (
                <span key={item} className="seo-hub-commitment-tag">
                  <CheckCircle2 size={15} style={{ color: 'var(--amber-600)' }} />
                  {item}
                </span>
              ))}
            </div>

            <div className="seo-hub-divider" />

            <div className="seo-hub-links-header">
              <h3>常用快速入口與核心指引</h3>
            </div>

            <div className="seo-hub-groups-container">
              {/* 分組 1：熱門行政區估價 */}
              <div className="seo-hub-group">
                <div className="seo-hub-group-title">
                  <span>🏙️</span>
                  <span>雙北熱門行政區估價</span>
                </div>
                <div className="seo-hub-chips-wrap">
                  <Link href="/location/sanchong/" className="seo-hub-chip-link">
                    三重窗簾價格試算
                  </Link>
                  <Link href="/location/taipei/" className="seo-hub-chip-link">
                    台北窗簾價格試算
                  </Link>
                  <Link href="/location/banqiao/" className="seo-hub-chip-link">
                    板橋窗簾推薦
                  </Link>
                  <Link href="/location/yingge/" className="seo-hub-chip-link">
                    鶯歌窗簾推薦
                  </Link>
                  <Link href="/location/shilin/" className="seo-hub-chip-link">
                    士林窗簾推薦
                  </Link>
                  <Link href="/location/zhongzheng/" className="seo-hub-chip-link">
                    中正區窗簾價格試算
                  </Link>
                </div>
              </div>

              {/* 分組 2：熱門款式推薦 */}
              <div className="seo-hub-group">
                <div className="seo-hub-group-title">
                  <span>🪟</span>
                  <span>熱門窗簾款式與材質推薦</span>
                </div>
                <div className="seo-hub-chips-wrap">
                  <Link href="/products/custom-curtains/" className="seo-hub-chip-link">
                    窗簾訂製與遮光布簾
                  </Link>
                  <Link href="/curtain/blackout/" className="seo-hub-chip-link">
                    遮光窗簾推薦
                  </Link>
                  <Link href="/products/seamless-sheer-curtains/" className="seo-hub-chip-link">
                    無縫紗簾推薦
                  </Link>
                  <Link href="/products/wooden-blinds/" className="seo-hub-chip-link">
                    實木百葉窗價格試算
                  </Link>
                  <Link href="/products/aluminum-blinds/" className="seo-hub-chip-link">
                    百葉窗價格試算
                  </Link>
                  <Link href="/products/bamboo-blinds/" className="seo-hub-chip-link">
                    竹簾訂製
                  </Link>
                </div>
              </div>

              {/* 分組 3：核心指南與工廠直營 */}
              <div className="seo-hub-group">
                <div className="seo-hub-group-title">
                  <span>📊</span>
                  <span>透明價格指南與品牌服務</span>
                </div>
                <div className="seo-hub-chips-wrap">
                  <Link href="/calculator/" className="seo-hub-chip-link">
                    窗簾價格試算
                  </Link>
                  <Link href="/blog/curtain-price-guide-2026/" className="seo-hub-chip-link">
                    窗簾價格指南
                  </Link>
                  <Link href="/about/" className="seo-hub-chip-link">
                    工廠直營窗簾與品牌服務
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="py-section bg-white">
        <div className="section-container">
          <div className="section-heading">
            <div className="tag">為什麼選宏森</div>
            <h2>可靠流程與透明價格</h2>
            <p>30 年工廠直營工班，標準化施工與同尺寸透明比價，讓窗簾配置安心又省心。</p>
          </div>
          <div className="feature-showcase-grid">
            {features.map(item => (
              <article key={item.title} className="feature-showcase-card">
                <div className="feature-img-wrapper">
                  <img
                    src={withBasePath(item.image)}
                    alt={item.imageAlt}
                    title={item.title}
                    loading="lazy"
                  />
                  <span className="feature-badge">
                    <CheckCircle2 size={13} style={{ color: 'var(--amber-400)' }} />
                    {item.badge}
                  </span>
                </div>
                <div className="feature-card-body">
                  <h3 className="feature-card-title">{item.title}</h3>
                  <p className="feature-card-desc">{item.desc}</p>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="py-section bg-stone-50">
        <div className="section-container">
          <div className="section-heading">
            <div className="tag">雙北到府丈量服務網</div>
            <h2>雙北 {locationCoverage.administrativeAreaCount} 區行政區服務入口｜真實案例與快速估價</h2>
            <p>宏森 30 年專業工班深耕雙北，精選 8 大核心生活圈案場實績，並提供完整 {locationCoverage.administrativeAreaCount} 個行政區到府丈量、同尺寸多材質透明比價與正式報價。</p>
          </div>

          {/* 層次一：精選 8 大核心旗艦案場實績卡 */}
          <div style={{ marginBottom: '1.75rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1rem', flexWrap: 'wrap', gap: '0.5rem' }}>
              <h3 style={{ fontSize: '1.15rem', fontWeight: 700, color: 'var(--stone-900)', margin: 0 }}>
                雙北 8 大核心服務生活圈・精選實績
              </h3>
              <span style={{ fontSize: '0.85rem', color: 'var(--stone-500)' }}>
                點擊查看在地真實案場與建議方案
              </span>
            </div>
            <div className="geo-flagship-grid">
              {flagshipGeoCards.map(item => (
                <Link
                  key={item.id}
                  href={`/location/${item.id}/`}
                  className="geo-flagship-card"
                >
                  <div className="geo-flagship-img">
                    <img
                      src={withBasePath(item.image)}
                      alt={item.imageAlt}
                      title={`${item.areaName}窗簾服務與丈量施工`}
                      loading="lazy"
                    />
                    <span className="geo-tag-pill">{item.badge}</span>
                  </div>
                  <div className="geo-flagship-body">
                    <h4 className="geo-flagship-title">{item.areaName}窗簾服務頁</h4>
                    <p className="geo-flagship-desc">{item.desc}</p>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 'auto', paddingTop: '0.5rem' }}>
                      <span style={{ fontSize: '0.78rem', color: 'var(--stone-500)', background: 'var(--stone-100)', padding: '0.15rem 0.5rem', borderRadius: '0.35rem' }}>
                        {item.tag}
                      </span>
                      <span className="geo-flagship-cta">
                        查看在地服務 <ChevronRight size={14} />
                      </span>
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          </div>

          {/* 層次二：行政區全域快速導覽矩陣（膠囊標籤） */}
          <div className="geo-matrix-container">
            <div className="geo-matrix-header">
              <div>
                <h3 style={{ margin: '0 0 0.25rem 0' }}>雙北生活圈全境快速導覽</h3>
                <p style={{ margin: 0, fontSize: '0.86rem', color: 'var(--stone-600)' }}>
                  宏森直營工班覆蓋雙北 {locationCoverage.administrativeAreaCount} 個行政區，全區免費到府丈量，點選直接前往專頁：
                </p>
              </div>
              <Link href="/location/" className="btn-outline" style={{ fontSize: '0.85rem', padding: '0.45rem 1rem' }}>
                查看 {locationCoverage.administrativeAreaCount} 區完整圖文總覽 <ChevronRight size={14} />
              </Link>
            </div>

            <div className="geo-matrix-group">
              <div className="geo-matrix-group-header">
                <div className="geo-matrix-group-title">
                  <span>📍 台北市行政區域（{locationCoverage.taipeiAdministrativeAreaCount} 區）</span>
                </div>
                <Link href="/location/taipei/" className="geo-matrix-flagship-btn" title="查看台北市全區窗簾推薦與價格總覽">
                  台北市全區總覽 <ChevronRight size={13} />
                </Link>
              </div>
              <div className="geo-pills-wrap">
                {locationPages
                  .filter(p => p.cityGroup === 'taipei' && p.id !== 'taipei')
                  .map(p => (
                    <Link key={p.id} href={`/location/${p.id}/`} className="geo-pill" title={`${p.areaName}窗簾推薦與價格試算`}>
                      <span className="geo-pill-dot" />
                      <span>{p.areaName}</span>
                    </Link>
                  ))}
              </div>
            </div>

            <div className="geo-matrix-group" style={{ marginTop: '1.5rem' }}>
              <div className="geo-matrix-group-header">
                <div className="geo-matrix-group-title">
                  <span>📍 新北市行政區域（{locationCoverage.newTaipeiAdministrativeAreaCount} 區）</span>
                </div>
                <Link href="/location/new-taipei/" className="geo-matrix-flagship-btn" title="查看新北市全區窗簾推薦與價格總覽">
                  新北市全區總覽 <ChevronRight size={13} />
                </Link>
              </div>
              <div className="geo-pills-wrap">
                {locationPages
                  .filter(p => p.cityGroup === 'new-taipei' && p.id !== 'new-taipei')
                  .map(p => (
                    <Link key={p.id} href={`/location/${p.id}/`} className="geo-pill" title={`${p.areaName}窗簾推薦與價格試算`}>
                      <span className="geo-pill-dot" />
                      <span>{p.areaName}</span>
                    </Link>
                  ))}
              </div>
            </div>
          </div>

          <div style={{ textAlign: 'center', marginTop: '2rem' }}>
            <Link
              href="/location/"
              className="btn-primary"
              style={{
                fontSize: '1rem',
                padding: '0.85rem 2.25rem',
                background: 'var(--amber-700)',
                color: 'white',
                boxShadow: '0 4px 12px rgba(180, 83, 9, 0.25)',
              }}
            >
              進入「雙北服務總覽」旗艦專頁 <ChevronRight size={16} />
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
        <div className="section-container">
          <div className="section-heading">
            <div className="tag">常見問題</div>
            <h2>首頁 FAQ</h2>
            <p>宏森 30 年老牌工班解答：挑選、丈量到報價的常見疑問全解析</p>
          </div>
          <div className="faq-layout-grid">
            {/* 左欄：5 大常見問題 Accordion */}
            <div className="faq-accordion-col">
              {homepageSeoFaq.map((item) => (
                <details key={item.q} className="faq-details-item">
                  <summary className="faq-summary-btn">
                    <span>{item.q}</span>
                    <ChevronDown size={18} className="faq-arrow-icon" />
                  </summary>
                  <div className="faq-answer-content">
                    {item.a}
                  </div>
                </details>
              ))}
            </div>

            {/* 右欄：填補空洞的核心：貼心諮詢與行動卡片 */}
            <aside className="faq-side-card">
              <div className="faq-side-badge">
                <MessageSquare size={13} />
                宏森專人線上為您解答
              </div>
              <h3 className="faq-side-title">還有其他窗簾搭配或丈量疑問？</h3>
              <p className="faq-side-desc">
                不確定窗型適合布簾、調光簾還是百葉窗？歡迎直接洽詢 30 年直營工班，依您的採光、隱私與預算提供可落地建議。
              </p>

              <div className="faq-side-promises">
                <div className="faq-side-promise-item">
                  <CheckCircle2 size={15} style={{ color: 'var(--amber-600)' }} />
                  <span>免費攜帶完整布樣到府評估</span>
                </div>
                <div className="faq-side-promise-item">
                  <CheckCircle2 size={15} style={{ color: 'var(--amber-600)' }} />
                  <span>同尺寸多材質現場透明比價</span>
                </div>
                <div className="faq-side-promise-item">
                  <CheckCircle2 size={15} style={{ color: 'var(--amber-600)' }} />
                  <span>雙北 29 個行政區快速排程到府</span>
                </div>
              </div>

              <div className="faq-side-actions">
                <Link href={buildCalculatorUrl()} className="faq-side-btn-calc">
                  <Calculator size={16} />
                  立即做窗簾價格試算
                </Link>
                <a
                  href="https://line.me/ti/p/~@663scubg"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="faq-side-btn-line"
                >
                  <MessageCircle size={16} />
                  加 LINE 預約到府丈量
                </a>
              </div>

              <div className="faq-side-contact-info">
                <div>📞 門市專線：02-8972-7322</div>
                <div style={{ marginTop: '0.2rem' }}>⏰ 服務時間：週一至週六 09:00 - 18:00</div>
              </div>
            </aside>
          </div>
        </div>
      </section>

      <section style={{ background: 'linear-gradient(135deg, var(--stone-900) 0%, #2d2520 100%)', color: 'white', padding: '4.5rem 0', textAlign: 'center' }}>
        <div className="section-container">
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
