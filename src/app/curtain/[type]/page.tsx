import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import { pillarPages } from '@/data/pillarPages';
import { products } from '@/data/products';
import { absoluteUrl, buildOgTwitterMeta, COMPANY_NAME, productPath } from '@/lib/seo';
import { ChevronRight, CheckCircle2 } from 'lucide-react';

export async function generateStaticParams() {
  return pillarPages.map(page => ({ type: page.id }));
}

export async function generateMetadata({ params }: { params: Promise<{ type: string }> }): Promise<Metadata> {
  const { type } = await params;
  const pageData = pillarPages.find(p => p.id === type);
  if (!pageData) return { title: '找不到頁面' };

  const title = `${pageData.title} | 宏森開發`;
  const description = pageData.description;
  const pagePath = `/curtain/${pageData.id}/`;

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
      type: 'article',
    }),
  };
}

export default async function PillarPage({ params }: { params: Promise<{ type: string }> }) {
  const { type } = await params;
  const pageData = pillarPages.find(p => p.id === type);
  if (!pageData) notFound();

  const relatedProducts = products.filter(p => pageData.relatedProductIds.includes(p.id));

  const articleSchema = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: pageData.title,
    description: pageData.description,
    image: absoluteUrl(pageData.heroImage),
    mainEntityOfPage: { '@type': 'WebPage', '@id': absoluteUrl(`/curtain/${pageData.id}/`) },
    author: { '@type': 'Organization', name: COMPANY_NAME },
    publisher: { '@type': 'Organization', name: COMPANY_NAME, logo: { '@type': 'ImageObject', url: absoluteUrl('/logo.webp') } },
  };

  const faqSchema = pageData.faqs && pageData.faqs.length > 0 ? {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: pageData.faqs.map(f => ({
      '@type': 'Question',
      name: f.q,
      acceptedAnswer: { '@type': 'Answer', text: f.a },
    })),
  } : null;

  const breadcrumbSchema = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: '首頁', item: absoluteUrl('/') },
      { '@type': 'ListItem', position: 2, name: pageData.shortTitle, item: absoluteUrl(`/curtain/${pageData.id}/`) }
    ]
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(articleSchema) }} />
      {faqSchema && <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />}
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbSchema) }} />

      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>›</span>
          <span>{pageData.shortTitle}</span>
        </div>
      </nav>

      <div className="page-hero" style={{ backgroundImage: `linear-gradient(rgba(0,0,0,0.6), rgba(0,0,0,0.6)), url(${pageData.heroImage})`, backgroundSize: 'cover', backgroundPosition: 'center' }}>
        <div className="section-container">
          <div className="tag" style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}>主題選購指南</div>
          <h1>{pageData.title}</h1>
          <p style={{ maxWidth: '800px', margin: '0 auto', color: 'rgba(255,255,255,0.9)' }}>{pageData.description}</p>
        </div>
      </div>

      <section className="py-section bg-white">
        <div className="section-container" style={{ maxWidth: '800px' }}>
          {pageData.sections.map((sec, i) => (
            <div key={i} style={{ marginBottom: '3rem' }}>
              <h2 style={{ fontSize: '1.8rem', fontWeight: 700, marginBottom: '1.5rem', color: 'var(--stone-900)' }}>{sec.heading}</h2>
              <div style={{ color: 'var(--stone-600)', lineHeight: 1.8, fontSize: '1.05rem', whiteSpace: 'pre-line' }}>
                {sec.content}
              </div>
            </div>
          ))}
        </div>
      </section>

      {relatedProducts.length > 0 && (
        <section className="py-section bg-stone-50">
          <div className="section-container">
            <div className="section-heading">
              <h2 style={{ fontSize: '2rem' }}>精選{pageData.shortTitle}推薦款式</h2>
              <p>我們為您準備了最適合的窗簾選擇，工廠直營品質保證。</p>
            </div>
            <div className="product-grid">
              {relatedProducts.map(product => (
                <div key={product.id} style={{ background: 'white', borderRadius: '1rem', overflow: 'hidden', boxShadow: '0 4px 12px rgba(0,0,0,0.05)' }}>
                  <img src={product.image} alt={product.name} style={{ width: '100%', height: '250px', objectFit: 'cover' }} loading="lazy" />
                  <div style={{ padding: '1.5rem' }}>
                    <h3 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '0.5rem' }}>{product.name}</h3>
                    <p style={{ fontSize: '0.9rem', color: 'var(--stone-600)', marginBottom: '1.5rem', lineHeight: 1.6 }}>{product.description}</p>
                    <Link href={productPath(product)} className="btn-outline" style={{ width: '100%', justifyContent: 'center' }}>了解詳情</Link>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>
      )}

      {pageData.faqs && pageData.faqs.length > 0 && (
        <section className="py-section bg-white border-t border-stone-200">
          <div className="section-container" style={{ maxWidth: '800px' }}>
            <div className="section-heading">
              <h2>常見問題</h2>
            </div>
            {pageData.faqs.map((faq, i) => (
              <div key={i} style={{ marginBottom: '1.25rem', padding: '1.5rem', background: 'var(--stone-50)', borderRadius: '1rem', border: '1px solid var(--stone-100)' }}>
                <h3 style={{ fontWeight: 700, marginBottom: '0.75rem', fontSize: '1.1rem', color: 'var(--amber-800)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span style={{ background: 'var(--amber-100)', color: 'var(--amber-700)', padding: '0.15rem 0.5rem', borderRadius: '0.5rem', fontSize: '0.85rem' }}>Q</span>
                  {faq.q}
                </h3>
                <p style={{ color: 'var(--stone-700)', fontSize: '0.95rem', lineHeight: 1.8, margin: 0, paddingLeft: '2.25rem' }}>{faq.a}</p>
              </div>
            ))}
          </div>
        </section>
      )}
      
      <section style={{ background: 'var(--stone-900)', color: 'white', padding: '4rem 0', textAlign: 'center' }}>
        <div className="section-container">
          <h2 style={{ fontSize: '1.8rem', fontWeight: 700, marginBottom: '0.75rem' }}>準備好升級您的居家空間了嗎？</h2>
          <p style={{ color: 'var(--stone-300)', marginBottom: '2.5rem', fontSize: '1.05rem' }}>立即預約免費到府丈量，大台北地區專人服務。</p>
          <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center' }}>
            <Link href="/calculator" className="btn-primary" style={{ background: 'var(--amber-600)' }}>線上快速估價 <ChevronRight size={18} /></Link>
            <a href="https://line.me/ti/p/fDWxUXkiZb" className="btn-secondary" style={{ background: '#06C755', borderColor: '#06C755', color: 'white' }}>加 LINE 預約丈量</a>
          </div>
        </div>
      </section>
    </>
  );
}
