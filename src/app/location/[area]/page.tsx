import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import { getLocationPageById, isCityOverviewLocationPage, locationPages } from '@/data/locationPages';
import { products } from '@/data/products';
import { absoluteUrl, buildCalculatorUrl, buildOgTwitterMeta, COMPANY_NAME, productPath } from '@/lib/seo';
import { withBasePath } from '@/lib/base-path';
import { ChevronRight, MapPin, CheckCircle2, Calculator, BookOpen, Sparkles, ShieldCheck, ArrowUpRight } from 'lucide-react';

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
      '@type': isCityOverviewLocationPage(pageData) ? 'City' : 'AdministrativeArea',
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

  // 建立行政區名稱與代碼快速映射（用於市級總覽標籤可點擊跳轉）
  const districtLinkMap = new Map<string, string>();
  for (const p of locationPages) {
    districtLinkMap.set(p.areaName, p.id);
    districtLinkMap.set(p.areaName.replace(/區|市/g, ''), p.id);
  }

  // 雙北實景展示卡配置（新北疏洪西路客廳蛇形簾、台北都會採光豪宅）
  const showcaseImageConfig: Record<string, { image: string; tag: string; title: string; desc: string }> = {
    'new-taipei': {
      image: '/Construction Cases_img/LINE_ALBUM_疏洪西路（蛇型簾+一般紗）_260414_2.webp',
      tag: '新北精選案場實拍',
      title: '客廳落地窗蛇形簾 ＋ 透光不透人一般紗',
      desc: '新北景觀大戶與重劃區採光實景，兼顧白晝柔光漫射與夜間隱私',
    },
    taipei: {
      image: '/about_img/about_01.webp',
      tag: '台北都會精選實景',
      title: '都會豪宅高採光雙層窗簾 ＋ 現代柔光配置',
      desc: '大安、信義、天母住宅指定搭配，高雅波浪垂墜與極致控光',
    },
  };

  const currentShowcase = showcaseImageConfig[pageData.id] ?? {
    image: pageData.heroImage,
    tag: `${pageData.areaName}案場實拍`,
    title: `${pageData.areaName}窗簾客製化丈量與完工實景`,
    desc: '宏森工班到府量身定制，專業窗型評估與安裝保固',
  };

  // 3 步驟透明估價流程步進條
  const serviceSteps = [
    {
      step: 'STEP 01',
      title: '線上 1 分鐘試算',
      desc: `同尺寸比較${featuredProductNames ? featuredProductNames.split('、').slice(0, 2).join('與') : '窗簾款式'}預算`,
    },
    {
      step: 'STEP 02',
      title: '預約免費到府丈量',
      desc: '專人攜帶布板色卡與五金樣本到現場挑選',
    },
    {
      step: 'STEP 03',
      title: '書面報價與安心施工',
      desc: '確認窗簾盒軌道條件，透明報價保固安心',
    },
  ];

  // 雙北精選在地完工微相簿
  const miniGalleryShowcase = [
    {
      image: '/Construction Cases_img/LINE_ALBUM_20240813三重介壽路-蛇形簾_260414_1.webp',
      badge: '客廳落地窗',
      title: '雙層蛇形簾 ＋ 柔光紗',
      desc: '大器波浪垂墜・漫射採光',
    },
    {
      image: '/Construction Cases_img/LINE_ALBUM_20240614三重環河北一段-調光簾_260414_1.webp',
      badge: '書房／辦公',
      title: '精品調光斑馬簾',
      desc: '自由調節光影・俐落好清潔',
    },
    {
      image: '/Construction Cases_img/LINE_ALBUM_20240429板橋中正路379巷-捲簾_260414_1.webp',
      badge: '臥室／西曬',
      title: '全遮光防焰捲簾',
      desc: '深度遮光睡眠・抗曬降溫',
    },
  ];

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
        <div className="section-container" style={{ maxWidth: '1080px' }}>
          {/* 模組一：雙欄圖文品牌信任與服務界線（左圖 4.2 : 右文 5.8 黃金比例） */}
          <div className="location-service-hub">
            <div className="service-feature-image-card">
              <img
                src={withBasePath(currentShowcase.image)}
                alt={`${pageData.areaName}窗簾完工案場實拍`}
                loading="eager"
              />
              <div className="service-image-badge-top">
                <Sparkles size={14} />
                <span>{currentShowcase.tag}</span>
              </div>
              <div className="service-image-caption-bottom">
                <span className="service-image-caption-title">{currentShowcase.title}</span>
                <span className="service-image-caption-desc">{currentShowcase.desc}</span>
              </div>
            </div>

            <div className="service-bounds-content">
              <div className="service-bounds-header">
                <div className="service-bounds-badge">
                  <ShieldCheck size={14} />
                  <span>在地直營・專業承諾</span>
                </div>
                <h2 className="service-bounds-title">{pageData.areaName}窗簾服務與報價界線</h2>
              </div>

              <ul className="service-bounds-list">
                {auditedServiceFacts.map((fact, i) => (
                  <li key={i} className="service-bounds-item">
                    <CheckCircle2 size={20} />
                    <span>{fact}</span>
                  </li>
                ))}
              </ul>

              {/* 3 步驟透明估價流程步進條（替代原本重複的黃色底框） */}
              <div className="service-step-track">
                {serviceSteps.map((step, idx) => (
                  <div key={idx} className="service-step-item">
                    <span className="service-step-number">{step.step}</span>
                    <span className="service-step-title">{step.title}</span>
                    <span className="service-step-desc">{step.desc}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* 模組二：主要服務涵蓋生活圈面板 ＆ 完工微相簿 */}
          <div className="location-districts-panel">
            <div className="districts-panel-header">
              <h3 className="districts-panel-title">
                <MapPin size={20} style={{ color: 'var(--amber-600)' }} />
                <span>主要服務涵蓋區域</span>
              </h3>
              <span className="districts-panel-hint">點選行政區可直接探索專屬案場與價格解析</span>
            </div>

            <div className="districts-pill-matrix">
              {pageData.districts.map((d, i) => {
                const targetAreaId = districtLinkMap.get(d) ?? districtLinkMap.get(d.replace(/區|市/g, ''));
                if (targetAreaId && targetAreaId !== pageData.id) {
                  return (
                    <Link
                      key={i}
                      href={`/location/${targetAreaId}/`}
                      className="district-pill-link"
                      title={`查看${d}窗簾服務推薦與價格試算`}
                    >
                      <MapPin size={14} />
                      <span>{d}</span>
                    </Link>
                  );
                }
                return (
                  <span key={i} className="district-pill-static">
                    {d}
                  </span>
                );
              })}
            </div>

            {/* 在地完工微相簿 */}
            <div className="gallery-mini-showcase">
              <div className="gallery-mini-heading">
                <Sparkles size={16} style={{ color: 'var(--amber-600)' }} />
                <span>雙北熱門空間完工實景推薦</span>
              </div>
              <div className="gallery-mini-grid">
                {miniGalleryShowcase.map((item, idx) => (
                  <div key={idx} className="gallery-mini-card">
                    <div className="gallery-mini-thumb">
                      <img src={withBasePath(item.image)} alt={item.title} loading="lazy" />
                      <span className="gallery-mini-badge">{item.badge}</span>
                    </div>
                    <div className="gallery-mini-info">
                      <div className="gallery-mini-info-title">{item.title}</div>
                      <div className="gallery-mini-info-desc">{item.desc}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* 模組三：價格與估價快速入口分層重構 */}
          <div className="location-quick-entry-card">
            <div className="quick-entry-header">
              <h3 className="quick-entry-title">
                <Calculator size={22} style={{ color: 'var(--amber-600)' }} />
                <span>{pageData.areaName} 窗簾價格與估價快速入口</span>
              </h3>
              <p className="quick-entry-desc">
                先用線上工具做 {pageData.areaName} 窗簾價格試算，再用價格指南比對品項與安裝費用，最後安排專人到府丈量確認即可。
              </p>
            </div>

            {/* 第一層：主要行動 CTA */}
            <div className="quick-entry-primary-actions">
              <Link href={buildCalculatorUrl(undefined, pageData.id)} className="quick-cta-btn-main">
                <Calculator size={18} />
                <span>{pageData.areaName}線上快速估價</span>
                <ChevronRight size={18} />
              </Link>
              <Link href="/blog/curtain-price-guide-2026/" className="quick-cta-btn-sub">
                <BookOpen size={18} />
                <span>查看 2026 窗簾價格指南</span>
              </Link>
            </div>

            {/* 第二層：次要 SEO 關鍵字晶片矩陣 */}
            {ownerBoostLinks.length > 0 && (
              <div>
                <div className="seo-boost-group-title">
                  <span>熱門窗型價格試算與深入推薦</span>
                </div>
                <div className="seo-boost-chips-grid">
                  {ownerBoostLinks.map((link) => (
                    <Link key={link.href} href={link.href} className="seo-quick-chip-link" title={link.label}>
                      <span>{link.label}</span>
                      <ArrowUpRight size={14} />
                    </Link>
                  ))}
                </div>
              </div>
            )}
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
               <Link href="/location/" className="btn-outline" style={{ fontSize: '1.05rem', padding: '0.8rem 2.5rem' }}>返回 29 區總覽</Link>
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
