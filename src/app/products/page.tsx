import type { Metadata } from 'next';
import Link from 'next/link';
import { ChevronRight } from 'lucide-react';
import ProductScrollMenu from '@/components/ProductScrollMenu';
import { getGeoExpansionPages } from '@/data/locationPages';
import { products } from '@/data/products';
import { withBasePath } from '@/lib/base-path';
import { absoluteUrl, buildCalculatorUrl, buildOgTwitterMeta, productPath } from '@/lib/seo';

const PRODUCTS_TITLE = '窗簾產品總覽｜熱門款式比較、窗簾價格試算與線上估價';
const PRODUCTS_DESCRIPTION =
  '想先比較窗簾款式？這頁整理一般窗簾、無縫紗簾、捲簾、鋁百葉、木百葉、風琴簾與調光簾，方便先看產品重點，再進入窗簾價格試算與線上估價。';

type ProductItem = (typeof products)[number];

const faqItems = [
  {
    q: '第一次挑窗簾，先看產品總覽還是直接估價？',
    a: '若還在比較款式，建議先看產品總覽縮小到 2 到 3 個品項，再用同尺寸做窗簾價格試算，判斷預算會更直覺。',
  },
  {
    q: '產品總覽頁適合先比較哪幾種熱門窗簾？',
    a: '多數住家可先比較一般窗簾、捲簾、木百葉與風琴簾，再依採光、清潔與預算需求決定後續丈量方向。',
  },
  {
    q: '看完產品頁後，可以直接進入線上估價嗎？',
    a: '可以。每個產品卡與頁面底部都可直接導向估價頁，先用接近實際的寬高尺寸抓預算區間，再安排到府丈量。',
  },
  {
    q: '產品總覽頁的估價會包含安裝費嗎？',
    a: '線上估價會先納入基本安裝費，正式報價仍會依窗型、配件與施工條件微調。',
  },
];

const microTags: Record<string, string[]> = {
  P001: ['遮光布簾', '客廳主窗', '經典耐看'],
  P002: ['透光不透人', '雙層搭配', '客廳書房'],
  P003: ['蛇形波浪', '落地窗', '現代簡約'],
  P004: ['小窗配置', '層次收折', '臥室書房'],
  P005: ['好清潔', '防潑水', '辦公空間'],
  P006: ['防潮耐用', '浴室廚房', '葉片調光'],
  P007: ['實木質感', '價格試算', '書房客廳'],
  P008: ['日式自然', '通風透氣', '和室空間'],
  P009: ['隔熱節能', '蜂巢結構', '西曬降溫'],
  P010: ['柔和調光', '隱私兼顧', '日夜切換'],
  P011: ['輕柔層次', '透光柔化', '臥室客廳'],
  P012: ['醫療空間', '防焰抗菌', '專業施工'],
  P013: ['大片窗面', '商空隔間', '直立開闔'],
};

const softProducts = ['P001', 'P002', 'P003', 'P004', 'P011'];
const hardProducts = ['P005', 'P006', 'P007', 'P010'];
const functionProducts = ['P009', 'P012', 'P013', 'P008'];

const quickLinks = [
  { href: '/calculator/', label: '先做窗簾價格試算與線上估價' },
  { href: '/products/wooden-blinds/', label: '實木百葉窗價格試算與產品重點' },
  { href: '/products/seamless-sheer-curtains/', label: '無縫紗簾推薦與透光不透人重點' },
  { href: '/blog/curtain-price-guide-2026/', label: '2026 窗簾價格指南與安裝費說明' },
];

export const metadata: Metadata = {
  title: PRODUCTS_TITLE,
  description: PRODUCTS_DESCRIPTION,
  keywords: [
    '窗簾產品總覽',
    '窗簾產品比較',
    '窗簾價格試算',
    '窗簾線上估價',
    '捲簾',
    '木百葉窗簾',
    '無縫紗簾',
    '風琴簾',
  ],
  ...buildOgTwitterMeta({
    title: PRODUCTS_TITLE,
    description: PRODUCTS_DESCRIPTION,
    path: '/products/',
    image: '/Curtain%20installation_img/Curtain%20installation_02.webp',
    imageAlt: '宏森窗簾產品總覽',
  }),
};

const productListSchema = {
  '@context': 'https://schema.org',
  '@type': 'ItemList',
  name: '宏森窗簾產品系列',
  url: absoluteUrl('/products/'),
  itemListElement: products.map((product, index) => ({
    '@type': 'ListItem',
    position: index + 1,
    url: absoluteUrl(productPath(product)),
    name: product.name,
  })),
};

const breadcrumbSchema = {
  '@context': 'https://schema.org',
  '@type': 'BreadcrumbList',
  itemListElement: [
    { '@type': 'ListItem', position: 1, name: '首頁', item: absoluteUrl('/') },
    { '@type': 'ListItem', position: 2, name: '產品系列', item: absoluteUrl('/products/') },
  ],
};

const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: faqItems.map(item => ({
    '@type': 'Question',
    name: item.q,
    acceptedAnswer: {
      '@type': 'Answer',
      text: item.a,
    },
  })),
};

function getProductsByIds(ids: string[]) {
  return products.filter(product => ids.includes(product.id));
}

export default function ProductsPage() {
  const geoQuickAreas = getGeoExpansionPages();

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(productListSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />

      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>/</span>
          <span>產品系列</span>
        </div>
      </nav>

      <ProductScrollMenu products={products} />

      <section className="py-section bg-white">
        <div className="section-container" style={{ maxWidth: '880px', margin: '0 auto' }}>
          <div className="tag" style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}>
            產品比較 / 價格試算 / 線上估價
          </div>
          <h1>先比較熱門窗簾款式，再進入價格試算</h1>
          <p style={{ lineHeight: 1.85 }}>
            這裡整理宏森常見的布簾、紗簾、捲簾、百葉窗與功能型窗簾，方便先看各品項的使用情境、風格差異與估價方向。若已經有尺寸，
            可直接切到估價頁做窗簾價格試算；若還在比較款式，也能先從熱門產品頁與價格指南縮小選擇範圍。
          </p>
          <div style={{ marginTop: '1.25rem', display: 'grid', gap: '0.55rem' }}>
            {quickLinks.map(link => (
              <Link
                key={link.href}
                href={link.href}
                style={{ color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}
              >
                {link.label}
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section className="py-section bg-stone-50">
        <div className="section-container">
          <CategorySection
            tag="Soft Treatments"
            title="布簾與柔性窗簾"
            description="適合重視垂墜感、布料層次與空間風格的住家情境，可先從客廳、臥室與書房常見配置開始比較。"
            products={getProductsByIds(softProducts)}
          />
          <CategorySection
            tag="Hard Treatments"
            title="百葉與硬式控光產品"
            description="適合需要防潮、好清潔、葉片調光或木質感空間的案件，常見於廚房、浴室、書房與辦公空間。"
            products={getProductsByIds(hardProducts)}
          />
          <CategorySection
            tag="Functional"
            title="隔熱、商空與特殊功能產品"
            description="如果你在意節能、西曬降溫、醫療空間或大面窗隔間，可先從功能型產品比較，再安排估價與丈量。"
            products={getProductsByIds(functionProducts)}
            compact
          />
        </div>
      </section>

      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container" style={{ maxWidth: '820px' }}>
          <div className="section-heading">
            <h2>產品總覽頁常見問題</h2>
            <p>先把比較邏輯釐清，再進估價頁會快很多。</p>
          </div>
          {faqItems.map(item => (
            <div
              key={item.q}
              style={{
                marginBottom: '1rem',
                padding: '1.25rem 1.4rem',
                background: 'var(--stone-50)',
                borderRadius: '0.85rem',
                border: '1px solid var(--stone-100)',
              }}
            >
              <h3 style={{ marginBottom: '0.65rem', fontSize: '1.05rem', color: 'var(--stone-900)' }}>{item.q}</h3>
              <p style={{ margin: 0, color: 'var(--stone-700)', lineHeight: 1.75 }}>{item.a}</p>
            </div>
          ))}
        </div>
      </section>

      {geoQuickAreas.length > 0 && (
        <section className="py-section bg-white border-t border-stone-200">
          <div className="section-container" style={{ maxWidth: '1000px' }}>
            <div className="section-heading">
              <h2>地區頁與估價入口</h2>
              <p>如果你已經有區域需求，可直接從地區頁看丈量流程，再帶入估價頁快速抓預算。</p>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '0.9rem' }}>
              {geoQuickAreas.map(area => (
                <article
                  key={area.id}
                  style={{
                    background: 'var(--stone-50)',
                    border: '1px solid var(--stone-200)',
                    borderRadius: '0.85rem',
                    padding: '1rem',
                  }}
                >
                  <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: 'var(--stone-900)' }}>
                    {area.areaName}窗簾服務
                  </h3>
                  <p style={{ margin: '0.4rem 0 0 0', color: 'var(--stone-600)', fontSize: '0.86rem', lineHeight: 1.6 }}>
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
          </div>
        </section>
      )}

      <section style={{ background: 'var(--stone-900)', color: 'white', padding: '4.5rem 0', textAlign: 'center' }}>
        <div className="section-container" style={{ maxWidth: '760px' }}>
          <h2 style={{ fontSize: '1.9rem', fontWeight: 700, marginBottom: '0.85rem' }}>挑到 2 到 3 個品項後，就能開始試算</h2>
          <p style={{ color: 'var(--stone-300)', marginBottom: '2.5rem', fontSize: '1.05rem', lineHeight: 1.8 }}>
            先比較產品，再用同尺寸做窗簾線上估價，會比直接問單一價格更容易判斷整體預算與安裝方向。
          </p>
          <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link href={buildCalculatorUrl()} className="btn-primary" style={{ background: 'var(--amber-600)', padding: '0.9rem 2.1rem' }}>
              前往窗簾價格試算 <ChevronRight size={18} />
            </Link>
            <Link href="/blog/curtain-price-guide-2026/" className="btn-outline" style={{ padding: '0.9rem 2.1rem' }}>
              先看價格指南
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}

function CategorySection({
  tag,
  title,
  description,
  products,
  compact = false,
}: {
  tag: string;
  title: string;
  description: string;
  products: ProductItem[];
  compact?: boolean;
}) {
  return (
    <div style={{ marginBottom: compact ? '1rem' : '4.5rem' }}>
      <div className="section-heading" style={{ textAlign: 'left', marginBottom: '2.2rem' }}>
        <div className="tag">{tag}</div>
        <h2 style={{ fontSize: '2rem' }}>{title}</h2>
        <p>{description}</p>
      </div>
      <div className="product-grid">
        {products.map(product => (
          <ProductCard key={product.id} product={product} />
        ))}
      </div>
    </div>
  );
}

function ProductCard({ product }: { product: ProductItem }) {
  const tags = microTags[product.id] ?? [];

  return (
    <article id={product.id} className="product-card" style={{ scrollMarginTop: '100px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div className="product-card-img">
        <img src={withBasePath(product.image)} alt={product.image_alt || product.name} title={product.image_title || product.name} loading="lazy" />
      </div>
      <div className="product-card-body" style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        <h3 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--stone-900)' }}>{product.name}</h3>
        <div style={{ display: 'flex', gap: '0.4rem', flexWrap: 'wrap', marginBottom: '0.75rem' }}>
          {tags.map(tag => (
            <span
              key={tag}
              style={{
                background: '#FFFFFF',
                color: '#D97706',
                border: '1px solid #D97706',
                padding: '0.25rem 0.6rem',
                borderRadius: '2rem',
                fontSize: '0.75rem',
                fontWeight: 700,
              }}
            >
              {tag}
            </span>
          ))}
        </div>
        <p style={{ fontSize: '0.9rem', color: 'var(--stone-600)', lineHeight: 1.65, marginBottom: '1.25rem', flex: 1 }}>{product.description}</p>
        <div style={{ display: 'flex', gap: '0.5rem', marginTop: 'auto' }}>
          <Link href={productPath(product)} className="btn-outline" style={{ flex: 1, justifyContent: 'center' }}>
            查看詳情
          </Link>
          <Link href={buildCalculatorUrl(product.id)} className="btn-primary" style={{ flex: 1, justifyContent: 'center', fontSize: '0.88rem', padding: '0.65rem 0.8rem' }}>
            直接估價
          </Link>
        </div>
      </div>
    </article>
  );
}
