import Link from 'next/link';
import { Suspense } from 'react';
import { CalculatorCatalogProvider, CalculatorForm, CalculatorProductMenu, CalculatorProductsList } from './CalculatorClient';
import { products } from '@/data/products';
import { calculatorFaq } from '@/data/calculatorFaq';
import { buildCalculatorUrl } from '@/lib/seo';
import EditorialLandingHero from '@/components/EditorialLandingHero';
import {
  Calculator,
  CircleDollarSign,
  CircleHelp,
  ClipboardList,
  Home,
  LayoutGrid,
  MapPin,
  Ruler,
  ShieldCheck,
  SlidersHorizontal,
  Sparkles,
  SunMedium,
  Wrench,
} from 'lucide-react';

const calculatorProducts = products.map((product) => ({
  id: product.id,
  name: product.name,
  slug: product.slug,
  canonicalSlug: product.canonicalSlug,
  requires_track: product.requires_track,
}));

const calculatorQuickGroups = [
  {
    title: '熱門產品與價格',
    links: [
      { href: '/products/roller-blinds/', label: '捲簾估價：先看遮光、安裝與適用空間', icon: SlidersHorizontal },
      { href: buildCalculatorUrl('P007'), label: '實木百葉試算：直接帶入木百葉品項', icon: Ruler },
      { href: '/blog/curtain-price-guide-2026/', label: '2026 窗簾價格指南：先看安裝費與預算', icon: CircleDollarSign },
      { href: '/products/wooden-blinds/', label: '實木百葉價格：木種、葉片與安裝條件', icon: Home },
      { href: '/location/banqiao/', label: '板橋窗簾價格試算：地區推薦與丈量入口', icon: MapPin },
    ],
  },
  {
    title: '地區與隔熱方案',
    links: [
      { href: '/products/aluminum-blinds/', label: '鋁百葉估價：防潮、葉片與安裝條件', icon: ShieldCheck },
      { href: buildCalculatorUrl('P009'), label: '風琴簾試算：西曬隔熱與臥室控溫', icon: SunMedium },
      { href: '/location/taipei/', label: '台北窗簾價格試算：估價後安排丈量', icon: MapPin },
      { href: '/curtain/living-room/', label: '客廳窗簾價格試算：落地窗款式建議', icon: Home },
      { href: '/location/zhongzheng/', label: '中正區窗簾推薦：價格試算與丈量入口', icon: MapPin },
    ],
  },
  {
    title: '透光與調光比較',
    links: [
      { href: '/calculator/?product=P002', label: '紗簾價格試算：透光不透人與安裝費', icon: Sparkles },
      { href: buildCalculatorUrl('P010'), label: '調光簾試算：客廳與臥室控光預算', icon: SunMedium },
      { href: '/products/seamless-sheer-curtains/', label: '無縫紗簾推薦：透光不透人方案', icon: Sparkles },
      { href: '/location/sanchong/', label: '三重窗簾推薦：價格試算與在地入口', icon: MapPin },
      { href: buildCalculatorUrl('P007', 'sanchong'), label: '三重實木百葉試算：快速帶入品項', icon: Ruler },
    ],
  },
];

const calculatorBasics = [
  { text: '先輸入接近實際的寬高尺寸，可先抓窗簾價格區間，再由現場丈量微調。', icon: Ruler },
  { text: '窗簾安裝費用會受窗型、配件與施工難度影響，估價頁可先看材料與基本安裝費的大方向預算。', icon: Wrench },
  { text: '想判斷窗簾價格多少合理，請用同一組尺寸比較 2 到 3 種品項，避免只看單才價格。', icon: CircleDollarSign },
  { text: '台北窗簾估價前，請先準備每扇窗的寬高、想比較的品項、安裝區域與主要需求（如遮光、採光或隱私）；若有窗簾盒、特殊窗型、既有軌道或現場照片也可一併提供。自量尺寸只供預算比較，正式報價仍以現場丈量為準。', icon: ClipboardList },
  { text: '若要比較不同產品，建議固定同一尺寸切換捲簾、鋁百葉、實木百葉、調光簾與風琴簾，判斷更直覺。', icon: LayoutGrid },
  { text: '若你想先做「百葉窗價格試算」，可先比較鋁百葉與實木百葉，再依防潮、木質感與安裝條件挑選。', icon: ShieldCheck },
  { text: '若你想先比較「紗簾價格」，可用同尺寸切換無縫紗簾與遮光布簾，確認透光不透人、雙層搭配與安裝費差異。', icon: Sparkles },
  { text: '若你想先衝「實木百葉窗價格試算」，可先切換木百葉品項再套用三重或台北區域，會更接近實際報價條件。', icon: Home },
  { text: '若你正在搜尋「三重窗簾」或「板橋窗簾」，可直接從本頁快速切到對應地區頁比對在地方案與交期。', icon: MapPin },
];

const calculatorFaqIcons = [Calculator, CircleDollarSign, SlidersHorizontal, ClipboardList, LayoutGrid, Wrench];

export default function CalculatorPage() {
  return (
    <CalculatorCatalogProvider bootstrapProducts={calculatorProducts}>
      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>/</span>
          <span>線上估價</span>
        </div>
      </nav>

      <EditorialLandingHero
        theme="calculator"
        eyebrow="線上估價・先掌握材料與基本安裝費"
        title="1 分鐘，掌握預算範圍"
        description="輸入接近實際的尺寸，先比較不同窗簾的預算方向。"
        desktopImage="/nav-hero/calculator-desktop.webp"
        mobileImage="/nav-hero/calculator-mobile.webp"
        imageAlt="窗邊布樣與量尺整理於估價準備桌面的情境"
        primaryAction={{ href: '#calculator-form', label: '開始 1 分鐘試算' }}
        secondaryAction={{ href: '#calculator-basics', label: '先看估價重點' }}
      />

      <section className="editorial-guide" aria-labelledby="calculator-guide-heading">
        <div className="section-container editorial-guide__inner">
          <div className="editorial-guide__copy">
            <h2 id="calculator-guide-heading">窗簾價格試算與窗簾線上估價</h2>
            <p>先用同一組尺寸比較材料與基本安裝費，再安排雙北到府丈量確認窗型、配件與正式報價。</p>
          </div>
          <nav className="editorial-guide__links" aria-label="線上估價快速入口">
            <a href="#calculator-form">立即開始試算</a>
            <Link href="/blog/curtain-price-guide-2026/">2026 價格指南</Link>
            <Link href="/location/taipei/">台北到府丈量</Link>
            <Link href="/products/">先比較窗簾款式</Link>
          </nav>
        </div>
      </section>

      <Suspense fallback={null}>
        <CalculatorProductMenu products={calculatorProducts} />
      </Suspense>

      <section className="py-section bg-stone-50">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <h2>先試算，再丈量：窗簾報價流程一次完成</h2>
            <p>先用線上工具掌握窗簾價格與安裝費用區間，再由專人到府確認窗型、配件與施工條件。</p>
          </div>
          <div className="calculator-quick-link-cards" aria-label="估價品項與地區快速連結">
            {calculatorQuickGroups.map(group => (
              <section className="calculator-quick-link-card" key={group.title}>
                <h3>{group.title}</h3>
                <nav className="calculator-quick-link-card__links" aria-label={group.title}>
                  {group.links.map(link => {
                    const Icon = link.icon;
                    return (
                      <Link key={link.href} href={link.href}>
                        <Icon className="calculator-quick-link-icon" aria-hidden="true" size={17} strokeWidth={1.9} />
                        <span>{link.label}</span>
                      </Link>
                    );
                  })}
                </nav>
              </section>
            ))}
          </div>
          <div id="calculator-form" className="section-anchor">
            <Suspense fallback={<div style={{ textAlign: 'center', padding: '3rem', color: 'var(--stone-400)' }}>載入估價工具...</div>}>
              <CalculatorForm products={calculatorProducts} />
            </Suspense>
          </div>
        </div>
      </section>

      <section id="calculator-basics" className="py-section bg-white border-t border-stone-200 section-anchor">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <h2>窗簾價格試算前，先看三個重點</h2>
          </div>
          <div className="calculator-basics-list">
            {calculatorBasics.map((item, index) => {
              const Icon = item.icon;
              return (
                <div className="calculator-basics-item" key={index}>
                  <span className="calculator-basics-icon" aria-hidden="true"><Icon size={22} strokeWidth={1.8} /></span>
                  <p>{item.text}</p>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <h2>常見問題</h2>
          </div>
          <div className="calculator-faq-list">
            {calculatorFaq.map((item, index) => {
              const FaqIcon = calculatorFaqIcons[index] ?? CircleHelp;
              return (
                <article className="calculator-faq-item" key={index}>
                  <div className="calculator-faq-icon" aria-hidden="true">
                    <FaqIcon size={40} strokeWidth={1.7} />
                  </div>
                  <div className="calculator-faq-content">
                    <h3>{item.q}</h3>
                    <p>{item.a}</p>
                  </div>
                </article>
              );
            })}
          </div>
        </div>
      </section>

      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container">
          <div className="section-heading">
            <h2>所有可估價品項</h2>
          </div>
          <CalculatorProductsList products={calculatorProducts} />
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
    </CalculatorCatalogProvider>
  );
}
