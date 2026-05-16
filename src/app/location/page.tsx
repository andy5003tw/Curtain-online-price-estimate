import type { Metadata } from 'next';
import Link from 'next/link';
import {
  geoPhase5WaveAIds,
  geoPhase5WaveBIds,
  geoPhase6WaveAIds,
  geoPhase6WaveBIds,
  geoWaveAIds,
  geoWaveBIds,
  getLocationPagesByIds,
  locationPages,
} from '@/data/locationPages';
import { absoluteUrl, buildCalculatorUrl, buildOgTwitterMeta } from '@/lib/seo';
import { ChevronRight } from 'lucide-react';

const HUB_TITLE = '服務區域總覽 | 台北新北 30 區窗簾丈量與估價入口';
const HUB_DESCRIPTION = '一次查看宏森窗簾在台北與新北 30 個服務區域頁，快速進入各地區的窗簾建議、熱門產品與估價入口。';

export const metadata: Metadata = {
  title: HUB_TITLE,
  description: HUB_DESCRIPTION,
  keywords: ['台北窗簾服務區域', '新北窗簾服務區域', '窗簾到府丈量', '窗簾地區頁索引'],
  ...buildOgTwitterMeta({
    title: HUB_TITLE,
    description: HUB_DESCRIPTION,
    path: '/location/',
    image: '/banner_img/banner_01.webp',
    imageAlt: '宏森窗簾地區服務總覽',
  }),
};

const sectionDefs: Array<{
  key: string;
  title: string;
  desc: string;
  ids: readonly string[];
}> = [
  {
    key: 'taipei-base',
    title: '台北基礎頁',
    desc: '第一階段已上線的台北核心基礎頁。',
    ids: ['taipei', 'daan', 'zhongshan', 'shilin', 'neihu'],
  },
  {
    key: 'phase3-wave-a',
    title: 'Phase 3 Wave A｜台北核心 4 區',
    desc: '第一輪台北核心擴頁。',
    ids: geoWaveAIds,
  },
  {
    key: 'phase5-wave-a',
    title: 'Phase 5 Wave A｜台北延伸 4 區',
    desc: '第二輪台北延伸擴頁。',
    ids: geoPhase5WaveAIds,
  },
  {
    key: 'newtaipei-base',
    title: '新北基礎頁',
    desc: '第一階段已上線的新北基礎頁。',
    ids: ['sanchong'],
  },
  {
    key: 'phase3-wave-b',
    title: 'Phase 3 Wave B｜新北轉單 4 區',
    desc: '第一輪新北轉單擴頁。',
    ids: geoWaveBIds,
  },
  {
    key: 'phase5-wave-b',
    title: 'Phase 5 Wave B｜新北延伸 4 區',
    desc: '第二輪新北延伸擴頁。',
    ids: geoPhase5WaveBIds,
  },
  {
    key: 'phase6-wave-a',
    title: 'Phase 6 Wave A｜新北核心 4 區',
    desc: '第三輪新北核心擴頁。',
    ids: geoPhase6WaveAIds,
  },
  {
    key: 'phase6-wave-b',
    title: 'Phase 6 Wave B｜新北延伸 4 區',
    desc: '第三輪新北延伸擴頁。',
    ids: geoPhase6WaveBIds,
  },
];

export default function LocationHubPage() {
  const groupedSections = sectionDefs
    .map(section => ({ ...section, pages: getLocationPagesByIds(section.ids) }))
    .filter(section => section.pages.length > 0);

  const locationHubSchema = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'CollectionPage',
        '@id': `${absoluteUrl('/location/')}#collection`,
        url: absoluteUrl('/location/'),
        name: HUB_TITLE,
        description: HUB_DESCRIPTION,
        inLanguage: 'zh-TW',
        hasPart: locationPages.map(page => ({
          '@type': 'WebPage',
          name: page.title,
          url: absoluteUrl(`/location/${page.id}/`),
        })),
      },
      {
        '@type': 'BreadcrumbList',
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: '首頁', item: absoluteUrl('/') },
          { '@type': 'ListItem', position: 2, name: '服務區域總覽', item: absoluteUrl('/location/') },
        ],
      },
    ],
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(locationHubSchema) }} />

      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>›</span>
          <span>服務區域總覽</span>
        </div>
      </nav>

      <section className="py-section bg-white">
        <div className="section-container">
          <div className="section-heading">
            <div className="tag">大台北 GEO 樞紐</div>
            <h1>台北與新北 30 區服務入口</h1>
            <p>依波次與城市分組整理，快速進入各地區頁或直接帶入地區參數進行線上估價。</p>
          </div>
          <div style={{ display: 'flex', justifyContent: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
            <Link href="/products/" className="btn-outline">先看全部產品</Link>
            <Link href={buildCalculatorUrl()} className="btn-primary">
              前往線上估價 <ChevronRight size={16} />
            </Link>
          </div>
        </div>
      </section>

      <section className="py-section bg-stone-50 border-t border-stone-200">
        <div className="section-container">
          {groupedSections.map((section, index) => (
            <div key={section.key} style={{ marginBottom: index === groupedSections.length - 1 ? 0 : '2rem' }}>
              <h2 style={{ fontSize: '1.2rem', fontWeight: 700, color: 'var(--stone-900)', marginBottom: '0.45rem' }}>
                {section.title}
              </h2>
              <p style={{ margin: '0 0 0.9rem 0', color: 'var(--stone-600)', fontSize: '0.9rem' }}>{section.desc}</p>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '0.9rem' }}>
                {section.pages.map(page => (
                  <article
                    key={page.id}
                    style={{
                      background: 'white',
                      border: '1px solid var(--stone-200)',
                      borderRadius: '0.95rem',
                      padding: '1rem',
                    }}
                  >
                    <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: 'var(--stone-900)' }}>
                      {page.areaName}窗簾服務
                    </h3>
                    <p style={{ margin: '0.4rem 0 0.8rem 0', fontSize: '0.85rem', color: 'var(--stone-600)', lineHeight: 1.6 }}>
                      {page.shortDescription}
                    </p>
                    <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                      <Link href={`/location/${page.id}/`} className="btn-outline" style={{ flex: 1, justifyContent: 'center' }}>
                        查看地區頁
                      </Link>
                      <Link href={buildCalculatorUrl(undefined, page.id)} className="btn-primary" style={{ flex: 1, justifyContent: 'center' }}>
                        帶入地區估價
                      </Link>
                    </div>
                  </article>
                ))}
              </div>
            </div>
          ))}
        </div>
      </section>
    </>
  );
}
