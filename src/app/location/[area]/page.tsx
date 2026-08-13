import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import { getLocationPageById, locationPages } from '@/data/locationPages';
import { products } from '@/data/products';
import { absoluteUrl, buildCalculatorUrl, buildOgTwitterMeta, COMPANY_NAME, productPath } from '@/lib/seo';
import { withBasePath } from '@/lib/base-path';
import { ChevronRight, MapPin, CheckCircle2 } from 'lucide-react';

function buildLocationCopy(areaName: string) {
  return {
    title: `${areaName}窗簾價格試算｜丈量、估價與安裝條件`,
    description: `宏森開發有限公司的${areaName}窗簾服務資訊入口。可先用同一尺寸比較產品預算，再由丈量確認窗型、材料、配件、施工條件與正式報價；本頁不代表當地另設分店。`,
  };
}

export async function generateStaticParams() {
  return locationPages.map(page => ({ area: page.id }));
}

export async function generateMetadata({ params }: { params: Promise<{ area: string }> }): Promise<Metadata> {
  const { area } = await params;
  const pageData = getLocationPageById(area);
  if (!pageData) return { title: '找不到頁面' };

  const locationCopy = buildLocationCopy(pageData.areaName);
  const title = `${locationCopy.title} | 宏森開發窗簾`;
  const description = locationCopy.description;
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
      imageAlt: `${pageData.areaName}窗簾丈量與估價服務`,
    }),
  };
}

export default async function LocationPage({ params }: { params: Promise<{ area: string }> }) {
  const { area } = await params;
  const pageData = getLocationPageById(area);
  if (!pageData) notFound();
  const locationCopy = buildLocationCopy(pageData.areaName);
  const relatedAreas = pageData.relatedAreaIds
    .map(areaId => getLocationPageById(areaId))
    .filter((item): item is NonNullable<typeof item> => Boolean(item));

  const displayProducts = pageData.featuredProductIds
    .map(productId => products.find(product => product.id === productId))
    .filter((product): product is (typeof products)[number] => Boolean(product));
  const featuredProductNames = displayProducts.map(product => product.name).join('、');
  const pageFaqs = [
    {
      q: `${pageData.areaName}窗簾服務可以先線上估價嗎？`,
      a: `可以。先在估價工具輸入尺寸並選擇${pageData.areaName}，用同一尺寸比較品項；正式金額仍需依窗型、配件與施工條件在丈量後確認。`,
    },
    {
      q: `${pageData.areaName}窗簾正式報價會確認哪些項目？`,
      a: '現場會確認實際寬高、安裝位置、窗簾盒或軌道條件、材質與控制配件，再提供正式報價；線上結果只用於前期預算比較。',
    },
    {
      q: `${pageData.areaName}頁面代表當地有獨立分店嗎？`,
      a: `不是。本頁是宏森開發有限公司提供${pageData.areaName}服務的資訊入口，所有地區頁都引用同一家公司、聯絡方式與服務流程，不宣稱當地另設分店。`,
    },
    {
      q: `${pageData.areaName}可以先比較哪些窗簾品項？`,
      a: `本頁目前連結${featuredProductNames || '主要窗簾品項'}；建議固定同一尺寸比較 2 到 3 種方案，再依採光、隱私、清潔與安裝條件收斂。`,
    },
  ];
  const auditedServiceFacts = [
    `本頁是宏森開發有限公司的${pageData.areaName}服務資訊入口，不是獨立分店或門市。`,
    `可先用同一尺寸比較${featuredProductNames || '主要窗簾品項'}，再安排丈量確認窗型與安裝條件。`,
    '線上估價提供預算區間；正式價格、材料規格、施工時程與售後條件以現場確認及書面報價為準。',
  ];

  const ownerBoostLinksByArea: Record<string, Array<{ href: string; label: string }>> = {
    banqiao: [
      { href: buildCalculatorUrl(undefined, 'banqiao'), label: '板橋窗簾價格試算：直接帶入板橋地區' },
      { href: buildCalculatorUrl('P006', 'banqiao'), label: '板橋百葉窗價格試算：鋁百葉防潮方案' },
      { href: buildCalculatorUrl('P009', 'banqiao'), label: '板橋風琴簾價格試算與線上估價' },
      { href: '/curtain/living-room/', label: '客廳窗簾推薦：板橋落地窗與雙層窗簾比價' },
      { href: '/products/wooden-blinds/', label: '實木百葉窗價格試算：板橋客廳木質感與葉片控光' },
      { href: '/curtain/blackout/', label: '遮光窗簾推薦：板橋主臥補眠與西曬降溫方向' },
      { href: '/blog/curtain-price-guide-2026/', label: '先看窗簾價格與百葉窗價格試算指南' },
      { href: '/products/seamless-sheer-curtains/', label: '無縫紗簾推薦：板橋客廳透光不透人方案' },
      { href: '/products/custom-curtains/', label: '板橋訂製窗簾價格與全室搭配重點' },
    ],
    taipei: [
      { href: buildCalculatorUrl(undefined, 'taipei'), label: '台北窗簾價格試算：直接帶入台北地區' },
      { href: '/calculator/', label: '窗簾價格試算：先用同尺寸比較全室預算' },
      { href: buildCalculatorUrl('P010', 'taipei'), label: '台北調光簾價格試算與線上估價' },
      { href: buildCalculatorUrl('P007', 'taipei'), label: '台北實木百葉窗價格試算' },
      { href: '/curtain/living-room/', label: '客廳窗簾推薦：台北落地窗、無縫紗簾與木百葉比價' },
      { href: '/products/wooden-blinds/', label: '實木百葉窗價格試算：台北客廳木質感與安裝費重點' },
      { href: '/products/custom-curtains/', label: '台北窗簾訂製：遮光布簾與客廳主窗方案' },
      { href: '/curtain/blackout/', label: '遮光窗簾推薦：台北臥室與西曬房比價方向' },
      { href: '/blog/curtain-price-guide-2026/', label: '台北窗簾價格指南與安裝費重點' },
      { href: '/products/seamless-sheer-curtains/', label: '無縫紗簾推薦：台北客廳透光方案' },
      { href: '/location/zhongzheng/', label: '中正區窗簾價格試算入口' },
    ],
    sanchong: [
      { href: buildCalculatorUrl(undefined, 'sanchong'), label: '三重窗簾價格試算：直接帶入三重地區' },
      { href: buildCalculatorUrl('P006', 'sanchong'), label: '三重百葉窗價格試算：鋁百葉與防潮方案' },
      { href: buildCalculatorUrl('P007', 'sanchong'), label: '三重實木百葉窗價格試算' },
      { href: '/curtain/living-room/', label: '客廳窗簾推薦：三重落地窗搭配重點' },
      { href: '/products/custom-curtains/', label: '三重窗簾推薦：窗簾訂製價格與遮光布簾重點' },
      { href: '/products/aluminum-blinds/', label: '百葉窗價格試算：三重鋁百葉與百葉窗簾價格' },
      { href: '/products/wooden-blinds/', label: '實木百葉窗產品與價格重點' },
    ],
    zhongzheng: [
      { href: buildCalculatorUrl(undefined, 'zhongzheng'), label: '中正區窗簾價格試算：直接帶入中正區' },
      { href: buildCalculatorUrl('P010', 'zhongzheng'), label: '中正區調光簾價格試算：學區住宅與書房控光' },
      { href: buildCalculatorUrl('P006', 'zhongzheng'), label: '中正區鋁百葉窗價格試算：小窗、防潮與辦公空間入口' },
      { href: buildCalculatorUrl('P002', 'zhongzheng'), label: '中正區無縫紗簾價格試算：客廳透光不透人方案' },
      { href: '/products/custom-curtains/', label: '窗簾訂製：中正區客廳與臥室布簾方案' },
      { href: '/products/wooden-blinds/', label: '實木百葉窗價格試算：中正區書房、景觀窗與木質感方案' },
      { href: '/curtain/blackout/', label: '遮光窗簾推薦：中正區臥室補眠與西曬隔熱重點' },
      { href: '/curtain/living-room/', label: '客廳窗簾推薦：中正區落地窗、紗簾與雙層搭配' },
      { href: '/products/seamless-sheer-curtains/', label: '無縫紗簾推薦：中正區客廳透光方案' },
      { href: '/products/zebra-blinds/', label: '調光簾價格試算：比較斑馬簾與客廳控光重點' },
      { href: '/cases/', label: '窗簾施工案例：查看中正區與台北學區住宅實景' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格與百葉窗價格試算指南' },
    ],
    shilin: [
      { href: buildCalculatorUrl(undefined, 'shilin'), label: '士林窗簾價格試算：直接帶入士林與天母地區' },
      { href: buildCalculatorUrl('P001', 'shilin'), label: '士林窗簾訂製：先抓遮光布簾與客廳主窗預算' },
      { href: buildCalculatorUrl('P005', 'shilin'), label: '士林遮光捲簾價格試算：臥室與租屋方案' },
      { href: buildCalculatorUrl('P009', 'shilin'), label: '士林風琴簾價格試算：西曬隔熱與透天高窗控溫' },
      { href: buildCalculatorUrl('P002', 'shilin'), label: '士林無縫紗簾價格試算：天母客廳透光不透人方案' },
      { href: '/curtain/blackout/', label: '遮光窗簾推薦：士林臥室補眠與西曬隔熱重點' },
      { href: '/curtain/living-room/', label: '客廳窗簾推薦：士林落地窗、雙層窗簾與搭配重點' },
      { href: '/products/custom-curtains/', label: '窗簾訂製：士林客廳布簾與遮光等級重點' },
      { href: '/products/seamless-sheer-curtains/', label: '無縫紗簾推薦：士林客廳透光方案與雙層搭配' },
      { href: '/cases/', label: '窗簾施工案例：查看士林、天母與台北住宅實景' },
      { href: '/location/taipei/', label: '台北窗簾推薦：比對士林與市區丈量流程' },
    ],
    neihu: [
      { href: buildCalculatorUrl(undefined, 'neihu'), label: '內湖窗簾價格試算：直接帶入內湖地區' },
      { href: buildCalculatorUrl('P006', 'neihu'), label: '內湖百葉窗價格試算：鋁百葉與商辦防眩光方案' },
      { href: buildCalculatorUrl('P010', 'neihu'), label: '內湖調光簾價格試算：會議室與住宅控光' },
      { href: buildCalculatorUrl('P013', 'neihu'), label: '內湖直立簾估價：大面玻璃與辦公室隔間' },
      { href: '/products/aluminum-blinds/', label: '百葉窗價格試算：內湖鋁百葉與百葉窗簾價格' },
      { href: '/products/custom-curtains/', label: '窗簾訂製價格：內湖住宅與商辦布簾丈量' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：內湖窗簾推薦與正式報價差異' },
    ],
    shulin: [
      { href: buildCalculatorUrl(undefined, 'shulin'), label: '樹林窗簾價格試算：直接帶入樹林地區' },
      { href: buildCalculatorUrl('P001', 'shulin'), label: '樹林窗簾訂製價格：透天與社區主窗預算' },
      { href: buildCalculatorUrl('P004', 'shulin'), label: '樹林羅馬簾估價：小窗與多窗格配置' },
      { href: buildCalculatorUrl('P008', 'shulin'), label: '樹林竹簾價格試算：透天自然採光方案' },
      { href: '/products/custom-curtains/', label: '窗簾訂製價格：樹林窗簾與遮光布簾重點' },
      { href: '/products/aluminum-blinds/', label: '百葉窗價格試算：樹林小窗與防潮百葉方案' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：樹林窗簾推薦與安裝費重點' },
    ],
    zhonghe: [
      { href: buildCalculatorUrl(undefined, 'zhonghe'), label: '中和窗簾價格試算：直接帶入中和地區' },
      { href: buildCalculatorUrl('P003', 'zhonghe'), label: '中和客廳窗簾價格試算：蛇形簾與落地窗預算' },
      { href: buildCalculatorUrl('P010', 'zhonghe'), label: '中和調光簾價格試算：辦公室與店面控光' },
      { href: buildCalculatorUrl('P013', 'zhonghe'), label: '中和直立簾估價：商辦隔間與大面玻璃' },
      { href: '/curtain/living-room/', label: '客廳窗簾推薦：中和社區住宅與落地窗搭配' },
      { href: '/curtain/blackout/', label: '遮光窗簾推薦：中和臥室與店面夜間隱私' },
      { href: '/products/zebra-blinds/', label: '調光簾價格試算：中和窗簾推薦的辦公控光選項' },
      { href: '/products/vertical-blinds/', label: '直立簾估價：中和店面與商辦大窗面方案' },
      { href: '/products/custom-curtains/', label: '窗簾訂製價格：中和住家布簾與臥室遮光' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：中和窗簾價格試算與安裝費重點' },
    ],
    xinzhuang: [
      { href: buildCalculatorUrl(undefined, 'xinzhuang'), label: '新莊窗簾價格試算：直接帶入新莊與副都心地區' },
      { href: buildCalculatorUrl('P010', 'xinzhuang'), label: '新莊調光簾價格試算：客廳與景觀宅日夜控光' },
      { href: buildCalculatorUrl('P006', 'xinzhuang'), label: '新莊百葉窗價格試算：鋁百葉防潮與好清潔方案' },
      { href: buildCalculatorUrl('P009', 'xinzhuang'), label: '新莊風琴簾價格試算：西曬隔熱與臥室控溫' },
      { href: buildCalculatorUrl('P005', 'xinzhuang'), label: '新莊捲簾價格試算：租屋、書房與辦公空間入口' },
      { href: '/products/aluminum-blinds/', label: '百葉窗價格試算：比較鋁百葉、木百葉與安裝費' },
      { href: '/products/zebra-blinds/', label: '調光簾價格試算：斑馬簾條紋寬度與遮光等級' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：比對新莊估價與正式報價差異' },
    ],
    yingge: [
      { href: buildCalculatorUrl(undefined, 'yingge'), label: '鶯歌窗簾價格試算：直接帶入鶯歌透天地區' },
      { href: buildCalculatorUrl('P001', 'yingge'), label: '鶯歌窗簾訂製：先抓客廳布簾與遮光主窗預算' },
      { href: buildCalculatorUrl('P005', 'yingge'), label: '鶯歌捲簾價格試算：展示空間與工作區快速估價' },
      { href: buildCalculatorUrl('P009', 'yingge'), label: '鶯歌風琴簾價格試算：西曬隔熱與高窗控溫' },
      { href: buildCalculatorUrl('P011', 'yingge'), label: '鶯歌柔紗簾價格試算：主臥柔光與展示空間採光' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：先看鶯歌窗簾行情與安裝費' },
      { href: '/products/custom-curtains/', label: '窗簾訂製：比較透天主窗、雙層窗簾與遮光布簾' },
    ],
  };
  const ownerBoostLinks = ownerBoostLinksByArea[pageData.id] ?? [];

  const serviceSchema = {
    '@context': 'https://schema.org',
    '@type': 'Service',
    '@id': `${absoluteUrl(`/location/${pageData.id}/`)}#service`,
    name: `${pageData.areaName}窗簾丈量、估價與安裝服務`,
    image: absoluteUrl(pageData.heroImage),
    url: absoluteUrl(`/location/${pageData.id}/`),
    provider: {
      '@type': 'LocalBusiness',
      '@id': `${absoluteUrl('/')}#localBusiness`,
      name: COMPANY_NAME,
      url: absoluteUrl('/'),
    },
    areaServed: {
      '@type': 'AdministrativeArea',
      name: pageData.areaName
    },
    description: locationCopy.description,
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
    mainEntity: pageFaqs.map(faq => ({
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
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(serviceSchema) }} />
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
          <h1>{locationCopy.title}</h1>
          <p data-ai-answer="true" style={{ maxWidth: '800px', margin: '0 auto', color: 'rgba(255,255,255,0.9)' }}>{locationCopy.description}</p>
        </div>
      </div>

      <section className="py-section bg-white">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '3rem' }}>
            <div>
              <h2 style={{ fontSize: '1.8rem', fontWeight: 700, marginBottom: '1.5rem', color: 'var(--stone-900)' }}>{pageData.areaName}窗簾服務與報價界線</h2>
              <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
                {auditedServiceFacts.map((fact, i) => (
                  <li key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: '0.75rem', fontSize: '1.05rem', color: 'var(--stone-700)', lineHeight: 1.6 }}>
                    <CheckCircle2 size={24} style={{ color: 'var(--amber-600)', flexShrink: 0, marginTop: '0.1rem' }} />
                    {fact}
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
            <h3 style={{ fontSize: '1.2rem', fontWeight: 700, color: '#92400E', marginBottom: '1rem' }}>{pageData.areaName}本頁可完成的事</h3>
            <ul style={{ listStyle: 'none', display: 'grid', gap: '0.75rem' }}>
              {auditedServiceFacts.map((highlight, i) => (
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
              <Link href={buildCalculatorUrl(undefined, pageData.id)} className="btn-primary" style={{ fontSize: '0.9rem' }}>
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
            {pageFaqs.map((faq, index) => (
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
            <Link href={buildCalculatorUrl(undefined, pageData.id)} className="btn-primary" style={{ background: 'var(--amber-600)', padding: '1rem 2.5rem', fontSize: '1.1rem' }}>線上快速估價 <ChevronRight size={20} /></Link>
            <a href="https://line.me/ti/p/fDWxUXkiZb" className="btn-secondary" style={{ background: '#06C755', borderColor: '#06C755', color: 'white', padding: '1rem 2.5rem', fontSize: '1.1rem' }}>加 LINE 立即預約</a>
          </div>
        </div>
      </section>
    </>
  );
}
