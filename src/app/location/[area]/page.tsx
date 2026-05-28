import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import { getLocationPageById, locationPages } from '@/data/locationPages';
import { products } from '@/data/products';
import { absoluteUrl, buildCalculatorUrl, buildOgTwitterMeta, productPath } from '@/lib/seo';
import { withBasePath } from '@/lib/base-path';
import { ChevronRight, MapPin, CheckCircle2 } from 'lucide-react';

export async function generateStaticParams() {
  return locationPages.map(page => ({ area: page.id }));
}

export async function generateMetadata({ params }: { params: Promise<{ area: string }> }): Promise<Metadata> {
  const { area } = await params;
  const pageData = getLocationPageById(area);
  if (!pageData) return { title: '找不到頁面' };

  const title = `${pageData.title} | 宏森開發窗簾`;
  const description = pageData.shortDescription;
  const pagePath = `/location/${pageData.id}/`;

  return {
    title,
    description,
    keywords: pageData.keywords,
    ...buildOgTwitterMeta({
      title,
      description,
      path: pagePath,
      image: pageData.heroImage,
      imageAlt: pageData.title,
    }),
  };
}

export default async function LocationPage({ params }: { params: Promise<{ area: string }> }) {
  const { area } = await params;
  const pageData = getLocationPageById(area);
  if (!pageData) notFound();
  const relatedAreas = pageData.relatedAreaIds
    .map(areaId => getLocationPageById(areaId))
    .filter((item): item is NonNullable<typeof item> => Boolean(item));

  const displayProducts = pageData.featuredProductIds
    .map(productId => products.find(product => product.id === productId))
    .filter((product): product is (typeof products)[number] => Boolean(product));

  const ownerBoostLinksByArea: Record<string, Array<{ href: string; label: string }>> = {
    taipei: [
      { href: '/location/sanchong/', label: '三重窗簾比價入口' },
      { href: buildCalculatorUrl('P007', 'taipei'), label: '台北實木百葉窗價格試算' },
    ],
    sanchong: [
      { href: buildCalculatorUrl('P007', 'sanchong'), label: '三重實木百葉窗價格試算' },
      { href: '/products/wooden-blinds/', label: '實木百葉窗產品與價格重點' },
    ],
    zhongzheng: [
      { href: buildCalculatorUrl('P010', 'zhongzheng'), label: '中正區調光簾價格試算' },
      { href: '/products/zebra-blinds/', label: '調光簾產品與價格重點' },
    ],
  };
  const ownerBoostLinks = ownerBoostLinksByArea[pageData.id] ?? [];

  const localBusinessSchema = {
    '@context': 'https://schema.org',
    '@type': 'LocalBusiness',
    '@id': `${absoluteUrl(`/location/${pageData.id}/`)}#local-business`,
    name: `宏森開發窗簾 - ${pageData.areaName}服務據點`,
    image: absoluteUrl(pageData.heroImage),
    url: absoluteUrl(`/location/${pageData.id}/`),
    telephone: '+886-2-8972-7322',
    areaServed: {
      '@type': 'AdministrativeArea',
      name: pageData.areaName
    },
    description: pageData.shortDescription,
    dateModified: pageData.lastModified,
  };

  const breadcrumbSchema = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: '首頁', item: absoluteUrl('/') },
      { '@type': 'ListItem', position: 2, name: '服務區域總覽', item: absoluteUrl('/location/') },
      { '@type': 'ListItem', position: 3, name: `${pageData.areaName}服務`, item: absoluteUrl(`/location/${pageData.id}/`) }
    ]
  };

  const faqSchema = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: pageData.faqs.map(faq => ({
      '@type': 'Question',
      name: faq.q,
      acceptedAnswer: {
        '@type': 'Answer',
        text: faq.a,
      },
    })),
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(localBusinessSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />

      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>›</span>
          <Link href="/location/">服務區域總覽</Link>
          <span>›</span>
          <span>{pageData.areaName}服務</span>
        </div>
      </nav>

      <div className="page-hero" style={{ backgroundImage: `linear-gradient(rgba(0,0,0,0.7), rgba(0,0,0,0.7)), url(${withBasePath(pageData.heroImage)})`, backgroundSize: 'cover', backgroundPosition: 'center' }}>
        <div className="section-container">
          <div className="tag" style={{ background: 'rgba(255,255,255,0.15)', color: 'white', display: 'flex', alignItems: 'center', gap: '0.4rem', margin: '0 auto 1.5rem auto' }}>
            <MapPin size={16} /> 專屬在地服務
          </div>
          <h1>{pageData.title}</h1>
          <p style={{ maxWidth: '800px', margin: '0 auto', color: 'rgba(255,255,255,0.9)' }}>{pageData.shortDescription}</p>
        </div>
      </div>

      <section className="py-section bg-white">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '3rem' }}>
            <div>
              <h2 style={{ fontSize: '1.8rem', fontWeight: 700, marginBottom: '1.5rem', color: 'var(--stone-900)' }}>為什麼{pageData.areaName}鄉親都推薦我們？</h2>
              <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
                {pageData.advantages.map((adv, i) => (
                  <li key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: '0.75rem', fontSize: '1.05rem', color: 'var(--stone-700)', lineHeight: 1.6 }}>
                    <CheckCircle2 size={24} style={{ color: 'var(--amber-600)', flexShrink: 0, marginTop: '0.1rem' }} />
                    {adv}
                  </li>
                ))}
              </ul>
            </div>
            <div style={{ background: 'var(--stone-50)', padding: '2rem', borderRadius: '1.5rem', border: '1px solid var(--stone-200)' }}>
              <h3 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '1.25rem', color: 'var(--stone-900)', borderBottom: '2px solid var(--amber-200)', paddingBottom: '0.75rem', display: 'inline-block' }}>主要服務涵蓋區域</h3>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem' }}>
                {pageData.districts.map((d, i) => (
                  <span key={i} style={{ background: 'white', border: '1px solid var(--stone-200)', padding: '0.5rem 1rem', borderRadius: '2rem', fontSize: '0.95rem', color: 'var(--stone-700)' }}>
                    {d}
                  </span>
                ))}
              </div>
            </div>
          </div>

          <div style={{ marginTop: '2rem', background: 'var(--amber-50)', borderRadius: '1rem', border: '1px solid var(--amber-100)', padding: '1.5rem' }}>
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, color: '#92400E', marginBottom: '1rem' }}>{pageData.areaName}服務重點</h3>
            <ul style={{ listStyle: 'none', display: 'grid', gap: '0.75rem' }}>
              {pageData.serviceHighlights.map((highlight, i) => (
                <li key={i} style={{ color: 'var(--stone-700)', lineHeight: 1.7, display: 'flex', gap: '0.5rem' }}>
                  <span style={{ color: '#B45309' }}>•</span>
                  <span>{highlight}</span>
                </li>
              ))}
            </ul>
          </div>

          <div style={{ marginTop: '1rem', background: 'white', borderRadius: '1rem', border: '1px solid var(--stone-200)', padding: '1.2rem' }}>
            <h3 style={{ fontSize: '1.05rem', fontWeight: 700, color: 'var(--stone-900)', marginBottom: '0.75rem' }}>
              {pageData.areaName} 窗簾價格與估價快速入口
            </h3>
            <p style={{ margin: '0 0 0.85rem 0', color: 'var(--stone-600)', fontSize: '0.9rem', lineHeight: 1.7 }}>
              先用線上工具做 {pageData.areaName} 窗簾價格試算，再用價格指南比對品項與安裝費用，最後安排丈量確認即可。
            </p>
            <div style={{ display: 'flex', gap: '0.6rem', flexWrap: 'wrap' }}>
              <Link href={buildCalculatorUrl()} className="btn-primary" style={{ fontSize: '0.9rem' }}>
                {pageData.areaName}線上估價
              </Link>
              <Link href="/blog/curtain-price-guide-2026/" className="btn-outline" style={{ fontSize: '0.9rem' }}>
                查看窗簾價格指南
              </Link>
              {ownerBoostLinks.map((link) => (
                <Link key={link.href} href={link.href} className="btn-outline" style={{ fontSize: '0.9rem' }}>
                  {link.label}
                </Link>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="py-section bg-stone-50">
        <div className="section-container">
          <div className="section-heading">
            <h2 style={{ fontSize: '2rem' }}>精選人氣窗簾款式</h2>
            <p>不論是新屋裝潢或舊屋翻新，我們提供百種以上材質供您挑選</p>
          </div>
          <div className="product-grid">
            {displayProducts.map(product => (
              <div key={product.id} style={{ background: 'white', borderRadius: '1rem', overflow: 'hidden', boxShadow: '0 4px 12px rgba(0,0,0,0.05)' }}>
                <img src={withBasePath(product.image)} alt={product.name} style={{ width: '100%', height: '220px', objectFit: 'cover' }} loading="lazy" />
                <div style={{ padding: '1.5rem' }}>
                  <h3 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '0.5rem' }}>{product.name}</h3>
                  <p style={{ fontSize: '0.9rem', color: 'var(--stone-600)', marginBottom: '1rem', lineHeight: 1.6 }}>{product.description}</p>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.55rem' }}>
                    <Link href={productPath(product)} className="btn-outline" style={{ flex: 1, justifyContent: 'center', minWidth: '120px' }}>了解詳情</Link>
                    <Link href={buildCalculatorUrl(product.id, pageData.id)} className="btn-primary" style={{ flex: 1, justifyContent: 'center', minWidth: '120px' }}>此區估價</Link>
                  </div>
                </div>
              </div>
            ))}
          </div>
          <div style={{ textAlign: 'center', marginTop: '3rem' }}>
             <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center', flexWrap: 'wrap' }}>
               <Link href="/products" className="btn-secondary" style={{ fontSize: '1.05rem', padding: '0.8rem 2.5rem' }}>查看全部窗簾款式</Link>
               <Link href="/location/" className="btn-outline" style={{ fontSize: '1.05rem', padding: '0.8rem 2.5rem' }}>返回 30 區總覽</Link>
             </div>
          </div>
        </div>
      </section>

      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <h2>{pageData.areaName}常見問題</h2>
          </div>
          <div style={{ display: 'grid', gap: '1rem' }}>
            {pageData.faqs.map((faq, index) => (
              <details key={index} style={{ background: 'var(--stone-50)', border: '1px solid var(--stone-200)', borderRadius: '0.75rem', overflow: 'hidden' }}>
                <summary style={{ padding: '1rem 1.25rem', fontWeight: 700, cursor: 'pointer', listStyle: 'none' }}>{faq.q}</summary>
                <div style={{ padding: '0 1.25rem 1rem', color: 'var(--stone-600)', lineHeight: 1.7 }}>{faq.a}</div>
              </details>
            ))}
          </div>
        </div>
      </section>

      {relatedAreas.length > 0 && (
        <section className="py-section bg-stone-50 border-t border-stone-200">
          <div className="section-container" style={{ maxWidth: '900px' }}>
            <div className="section-heading">
              <h2>鄰近服務區域</h2>
              <p>也可查看附近地區的窗簾規劃與到府丈量服務</p>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '1rem' }}>
              {relatedAreas.map(related => (
                <Link
                  key={related.id}
                  href={`/location/${related.id}/`}
                  style={{
                    background: 'white',
                    border: '1px solid var(--stone-200)',
                    borderRadius: '0.85rem',
                    padding: '1rem 1.1rem',
                    textDecoration: 'none',
                    color: 'inherit',
                    display: 'block',
                  }}
                >
                  <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: 'var(--stone-900)' }}>
                    {related.areaName}窗簾服務
                  </h3>
                  <p style={{ margin: '0.4rem 0 0 0', fontSize: '0.86rem', color: 'var(--stone-600)', lineHeight: 1.6 }}>
                    {related.title}
                  </p>
                </Link>
              ))}
            </div>
          </div>
        </section>
      )}

      <section style={{ background: 'var(--stone-900)', color: 'white', padding: '5rem 0', textAlign: 'center' }}>
        <div className="section-container">
          <h2 style={{ fontSize: '2rem', fontWeight: 700, marginBottom: '1rem' }}>立即預約 {pageData.areaName} 免費到府丈量</h2>
          <p style={{ color: 'var(--stone-300)', marginBottom: '2.5rem', fontSize: '1.1rem', maxWidth: '600px', margin: '0 auto 2.5rem auto' }}>
            專人攜帶樣本到府，依據您的現場採光、裝潢風格給予最專業的配置建議，量尺與報價完全免費！
          </p>
          <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link href={buildCalculatorUrl()} className="btn-primary" style={{ background: 'var(--amber-600)', padding: '1rem 2.5rem', fontSize: '1.1rem' }}>線上快速估價 <ChevronRight size={20} /></Link>
            <a href="https://line.me/ti/p/fDWxUXkiZb" className="btn-secondary" style={{ background: '#06C755', borderColor: '#06C755', color: 'white', padding: '1rem 2.5rem', fontSize: '1.1rem' }}>加 LINE 立即預約</a>
          </div>
        </div>
      </section>
    </>
  );
}
