import type { Metadata } from 'next';
import Link from 'next/link';
import { CheckCircle2, Phone, MapPin, ShieldCheck, Factory, Clock, Calculator, ChevronRight } from 'lucide-react';
import { absoluteUrl, buildOgTwitterMeta } from '@/lib/seo';
import { withBasePath } from '@/lib/base-path';

const ABOUT_TITLE = '關於我們 | 30年專業窗簾訂製・工廠直營・宏森開發';
const ABOUT_DESCRIPTION = '宏森開發有限公司自1996年深耕窗簾市場，提供三重、新北市、台北地區專業窗簾訂製與施工。工廠直營保證價格實惠、品質嚴控，服務台大、立法院等指標客戶。';

export const metadata: Metadata = {
  title: ABOUT_TITLE,
  description: ABOUT_DESCRIPTION,
  keywords: ['關於宏森窗簾', '窗簾訂製流程', '窗簾安裝', '窗簾報價', '窗簾價格試算', '台北窗簾', '新北窗簾'],
  ...buildOgTwitterMeta({
    title: ABOUT_TITLE,
    description: ABOUT_DESCRIPTION,
    path: '/about/',
    image: '/Curtain installation_img/Curtain installation_01.webp',
    imageAlt: '宏森窗簾團隊施工與服務流程',
  }),
};

const processSteps = [
  { title: '預約量尺', desc: '電話或線上預約，專業人員帶著樣本到府。', icon: <Phone size={24} /> },
  { title: '到府丈量', desc: '精確測量尺寸，並現場提供材質建議。', icon: <MapPin size={24} /> },
  { title: '即時報價', desc: '根據選定材質現場提供透明報價。', icon: <Calculator size={24} /> },
  { title: '工廠訂製', desc: '確認訂單後，工廠開始裁剪縫製、品質控管。', icon: <Factory size={24} /> },
  { title: '專業施工', desc: '專業師傅約定時間到府安裝，確保穩固與平整。', icon: <ShieldCheck size={24} /> },
  { title: '售後服務', desc: '完善的保固與諮詢，不怕窗簾變孤兒。', icon: <Clock size={24} /> },
];

const advantages = [
  { title: '價格優勢', desc: '省去實體門市抽成與盤商利潤，將成本直接回饋給客戶，讓您以最實惠價格獲得高品質產品。' },
  { title: '品質管控', desc: '每一窗窗簾皆在自有工廠監製，從車工細節、對花精準度到摺皺倍數，皆能嚴格把關。' },
  { title: '交貨速度', desc: '自有工廠不需轉單外包，大幅縮短製作時程，從丈量到安裝都能提供最迅速的彈性服務。' },
];

const iconicCases = [
  '高級學府：台灣大學、台灣師範大學、台灣藝術大學',
  '政府機關：國防部、立法院',
  '醫療體系：桃園醫院 (桃醫)',
  '教育機構：集美國小',
  '知名社區：美河市',
];

const faqs = [
  { q: '量尺要收費嗎？', a: '宏森開發提供台北市、新北市不限區域的「免費到府量尺與報價」服務，確認施作才收費，沒有隱藏成本。' },
  { q: '只有一窗也可以服務嗎？', a: '沒問題！無論是整間房屋或是單一窗戶，我們都提供同樣專業的丈量與安裝服務。' },
  { q: '外縣市有服務嗎？', a: '我們主要服務大台北地區（雙北）。台北市及新北市以外的區域，視距離酌收基本出差車資，歡迎致電洽詢。' },
];

const breadcrumbSchema = {
  '@context': 'https://schema.org',
  '@type': 'BreadcrumbList',
  itemListElement: [
    { '@type': 'ListItem', position: 1, name: '首頁', item: absoluteUrl('/') },
    { '@type': 'ListItem', position: 2, name: '關於我們', item: absoluteUrl('/about/') }
  ]
};


const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: faqs.map(faq => ({
    '@type': 'Question',
    name: faq.q,
    acceptedAnswer: {
      '@type': 'Answer',
      text: faq.a
    }
  }))
};

export default function AboutPage() {
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />
      
      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>›</span>
          <span>關於我們</span>
        </div>
      </nav>

      <div className="page-hero">
        <div className="section-container">
          <div className="tag" style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}>三十年專業傳承</div>
          <h1>為什麼選擇宏森窗簾？</h1>
          <p>工廠直營、價格透明，我們用三十年的經驗，為您打造最溫馨的居家光影。</p>
        </div>
      </div>

      {/* Intro & Advantages */}
      <section className="py-section bg-white">
        <div className="section-container">
          <div className="about-grid" style={{ marginBottom: '4rem' }}>
            <div className="about-text">
              <div className="tag">我們的堅持</div>
              <h2>工廠直營，品質與價格的雙重保證</h2>
              <p>宏森開發有限公司自1996年開業以來，始終堅持「專業、品質、誠信」三大核心指標。我們深知消費者對於窗簾的需求不僅是美觀，更是耐用與安全。</p>
              <p style={{ marginTop: '0.85rem', color: 'var(--stone-600)', lineHeight: 1.7 }}>
                若您想先了解窗簾價格與安裝費用，可先使用
                <Link href="/calculator/" style={{ margin: '0 0.25rem', color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
                  線上估價工具
                </Link>
                ，或查看
                <Link href="/blog/curtain-price-guide-2026/" style={{ marginLeft: '0.25rem', color: 'var(--amber-700)', fontWeight: 700, textDecoration: 'underline' }}>
                  2026 訂製窗簾價格指南
                </Link>
                。
              </p>
              
              <div className="adv-list" style={{ marginTop: '2rem' }}>
                {advantages.map((adv, i) => (
                  <div key={i} style={{ marginBottom: '1.5rem' }}>
                    <h3 style={{ fontSize: '1.1rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.4rem' }}>
                      <CheckCircle2 size={18} className="text-amber-600" /> {adv.title}
                    </h3>
                    <p style={{ fontSize: '0.925rem', color: 'var(--stone-600)', lineHeight: 1.6 }}>{adv.desc}</p>
                  </div>
                ))}
              </div>
            </div>
            <div className="about-imgs">
              <img src={withBasePath('/Curtain installation_img/Curtain installation_01.webp')} alt="宏森窗簾工廠直營品質監控" loading="lazy" />
              <img src={withBasePath('/Curtain installation_img/Curtain installation_03.webp')} alt="專業窗簾師傅現場施工" loading="lazy" />
            </div>
          </div>
        </div>
      </section>

      {/* Service Process */}
      <section className="py-section bg-stone-50">
        <div className="section-container">
          <div className="about-grid items-start" style={{ gap: '3rem' }}>
            <div className="about-text" style={{ flex: '1 1 50%' }}>
              <div className="tag" style={{ background: 'white', border: '1px solid var(--stone-200)' }}>服務流程</div>
              <h2 style={{ fontSize: '2.4rem', fontWeight: 700, marginBottom: '1rem', color: 'var(--stone-900)' }}>透明化的六大服務步驟</h2>
              <p style={{ color: 'var(--stone-500)', fontSize: '1.05rem', marginBottom: '2.5rem', maxWidth: '500px' }}>
                從預約到售後，我們讓您掌握每一個細節，絕不讓窗簾變成裝修遺珠。
              </p>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '1.25rem' }}>
                {processSteps.map((step, i) => (
                  <div key={i} style={{ display: 'flex', gap: '1.25rem', background: 'white', padding: '1.5rem', borderRadius: '1rem', boxShadow: '0 2px 12px rgba(0,0,0,0.03)', border: '1px solid var(--stone-100)', transition: 'all 0.3s ease' }} className="process-card">
                    <div style={{ background: 'var(--amber-50)', color: 'var(--amber-600)', padding: '0.8rem', borderRadius: '0.8rem', height: 'fit-content', flexShrink: 0 }}>
                      {step.icon}
                    </div>
                    <div>
                      <h3 style={{ fontSize: '1.1rem', fontWeight: 700, margin: '0 0 0.4rem 0', color: 'var(--stone-900)' }}>
                        <span style={{ color: 'var(--stone-300)', marginRight: '0.5rem', fontWeight: 900 }}>0{i+1}.</span>
                        {step.title}
                      </h3>
                      <p style={{ fontSize: '0.95rem', color: 'var(--stone-500)', margin: 0, lineHeight: 1.6 }}>{step.desc}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Image side - Sticky on desktop */}
            <div style={{ flex: '1 1 40%', position: 'sticky', top: '100px', display: 'flex', flexDirection: 'column', gap: '1.5rem', paddingTop: '2rem' }}>
              <div style={{ position: 'relative', borderRadius: '1.5rem', overflow: 'hidden', boxShadow: '0 10px 40px rgba(0,0,0,0.08)' }}>
                <img src={withBasePath('/Curtain installation_img/Curtain installation_03.webp')} alt="宏森專業安裝" loading="lazy" style={{ width: '100%', height: '500px', objectFit: 'cover', display: 'block' }} />
                <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.8), transparent)', padding: '3rem 2rem 2rem' }}>
                  <h4 style={{ color: 'white', fontSize: '1.2rem', fontWeight: 700, margin: '0 0 0.5rem 0' }}>專業安裝團隊</h4>
                  <p style={{ color: 'rgba(255,255,255,0.8)', fontSize: '0.9rem', margin: 0 }}>我們嚴格要求施工品質，絕不留下滿地粉塵，只留下美麗光影。</p>
                </div>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem' }}>
                <img src={withBasePath('/Construction Cases_img/LINE_ALBUM_板橋 龍昌診所_260414_5.webp')} alt="龍昌診所案例" loading="lazy" style={{ width: '100%', height: '180px', objectFit: 'cover', borderRadius: '1rem', boxShadow: '0 4px 12px rgba(0,0,0,0.05)' }} />
                <img src={withBasePath('/Construction Cases_img/LINE_ALBUM_20240813三重介壽路-蛇形簾_260414_5.webp')} alt="精緻居家窗簾" loading="lazy" style={{ width: '100%', height: '180px', objectFit: 'cover', borderRadius: '1rem', boxShadow: '0 4px 12px rgba(0,0,0,0.05)' }} />
              </div>
            </div>
          </div>
        </div>

        <style dangerouslySetInnerHTML={{__html: `
          .process-card:hover { transform: translateX(10px); border-color: var(--amber-200) !important; box-shadow: 0 8px 24px rgba(245, 158, 11, 0.08) !important; }
          .line-badge:hover { transform: scale(1.08) !important; }
        `}} />
      </section>

      {/* Trust & Authority */}
      <section className="py-section bg-white">
        <div className="section-container">
          <div className="about-grid items-center">
            <div className="about-imgs">
               <img src={withBasePath('/Curtain installation_img/Curtain installation_02.webp')} alt="大型公共工程窗簾實錄" loading="lazy" />
               <img src={withBasePath('/Curtain installation_img/Curtain installation_04.webp')} alt="台大等指標客戶指定選用" loading="lazy" />
            </div>
            <div className="about-text">
              <div className="tag">在地深耕・權威認證</div>
              <h2>台大、立法院多次選用</h2>
              <p>宏森開發不僅服務萬戶住家，更有幸獲得諸多頂尖機構的信任。我們深耕三重國小捷運站周邊及大台北各地區，提供符合消防局認可的「防焰標籤」窗簾，是商辦與醫療院所的第一選擇。</p>
              
              <div style={{ marginTop: '1.5rem', padding: '1.5rem', background: 'var(--stone-50)', borderRadius: '1rem', border: '1px solid var(--stone-200)' }}>
                <h4 style={{ fontWeight: 700, marginBottom: '1rem', fontSize: '1rem' }}>指標性服務客戶</h4>
                <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
                  {iconicCases.map((c, i) => (
                    <li key={i} style={{ marginBottom: '0.5rem', fontSize: '0.9rem', display: 'flex', alignItems: 'center', gap: '0.5rem', color: 'var(--stone-700)' }}>
                      <span style={{ width: '4px', height: '4px', borderRadius: '50%', background: 'var(--amber-600)' }}></span>
                      {c}
                    </li>
                  ))}
                </ul>
              </div>
              <p style={{ marginTop: '1.5rem', fontSize: '0.9rem', color: 'var(--amber-700)', fontWeight: 600 }}>
                * 提供消防局認可防焰標籤，確保安全無虞。
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Map & Location */}
      <section className="py-section bg-white" style={{ borderTop: '1px solid var(--stone-100)' }}>
        <div className="section-container" style={{ maxWidth: '1000px' }}>
          <div className="about-grid items-center" style={{ gap: '4rem' }}>
            <div className="about-text">
              <div className="tag">實體服務據點</div>
              <h2>在地聯絡資訊與位置</h2>
              <p>我們深耕三重與大台北地區，工廠直營，提供最高品質的在地服務。歡迎隨時透過電話或預約我們到府為您進行專業的量尺與估價。</p>
              
              <div style={{ marginTop: '2rem', display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
                <div style={{ display: 'flex', gap: '1rem', alignItems: 'flex-start' }}>
                  <div style={{ background: 'var(--amber-50)', color: 'var(--amber-600)', padding: '0.8rem', borderRadius: '50%' }}>
                    <MapPin size={24} />
                  </div>
                  <div>
                    <h4 style={{ fontWeight: 700, margin: '0 0 0.25rem 0', color: 'var(--stone-900)' }}>工廠/聯絡地址</h4>
                    <p style={{ color: 'var(--stone-600)', margin: 0, lineHeight: 1.5 }}>241 新北市三重區<br/>仁愛街125巷89號1樓</p>
                  </div>
                </div>
                
                <div style={{ display: 'flex', gap: '1rem', alignItems: 'flex-start' }}>
                  <div style={{ background: 'var(--amber-50)', color: 'var(--amber-600)', padding: '0.8rem', borderRadius: '50%' }}>
                    <Phone size={24} />
                  </div>
                  <div>
                    <h4 style={{ fontWeight: 700, margin: '0 0 0.25rem 0', color: 'var(--stone-900)' }}>服務專線</h4>
                    <div style={{ color: 'var(--stone-600)', margin: 0, lineHeight: 1.6, display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <a href="tel:0289727322" style={{ textDecoration: 'none', color: 'inherit' }}>02-8972-7322</a>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <a href="tel:0980113006" style={{ textDecoration: 'none', color: 'inherit' }}>0980-113006</a>
                        <a href="https://line.me/ti/p/fDWxUXkiZb" className="line-badge" target="_blank" rel="noopener noreferrer" style={{ background: '#06C755', color: 'white', textDecoration: 'none', fontSize: '0.7rem', padding: '0.1rem 0.4rem', borderRadius: '4px', fontWeight: 700, letterSpacing: '0.02rem', transition: 'transform 0.2s', display: 'inline-block' }}>加 LINE</a>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <a href="tel:0973808799" style={{ textDecoration: 'none', color: 'inherit' }}>0973-808799</a>
                        <a href="https://line.me/ti/p/nS1XQ4-flk" className="line-badge" target="_blank" rel="noopener noreferrer" style={{ background: '#06C755', color: 'white', textDecoration: 'none', fontSize: '0.7rem', padding: '0.1rem 0.4rem', borderRadius: '4px', fontWeight: 700, letterSpacing: '0.02rem', transition: 'transform 0.2s', display: 'inline-block' }}>加 LINE</a>
                      </div>
                    </div>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '1rem', alignItems: 'flex-start' }}>
                  <div style={{ background: 'var(--amber-50)', color: 'var(--amber-600)', padding: '0.8rem', borderRadius: '50%' }}>
                    <Clock size={24} />
                  </div>
                  <div>
                    <h4 style={{ fontWeight: 700, margin: '0 0 0.25rem 0', color: 'var(--stone-900)' }}>營業時間</h4>
                    <p style={{ color: 'var(--stone-600)', margin: 0, lineHeight: 1.5 }}>週一至週六 09:00 - 18:00<br/><span style={{ fontSize: '0.85rem' }}>(建議來訪或到府丈量前先電話預約)</span></p>
                  </div>
                </div>
              </div>
            </div>
            <div style={{ width: '100%', height: '400px', borderRadius: '1.5rem', overflow: 'hidden', boxShadow: '0 4px 20px rgba(0,0,0,0.06)' }}>
              <iframe 
                src="https://maps.google.com/maps?q=新北市三重區仁愛街125巷89號&t=&z=16&ie=UTF8&iwloc=&output=embed" 
                width="100%" 
                height="100%" 
                style={{ border: 0 }} 
                allowFullScreen={true} 
                loading="lazy" 
                referrerPolicy="no-referrer-when-downgrade"
              ></iframe>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section className="py-section bg-stone-50">
        <div className="section-container" style={{ maxWidth: '800px' }}>
          <div className="section-heading">
            <div className="tag">專家問答</div>
            <h2>關於我們的常見問題</h2>
          </div>
          <div className="faq-grid">
            {faqs.map((faq, i) => (
              <div key={i} style={{ background: 'white', padding: '1.5rem', borderRadius: '1rem', border: '1px solid var(--stone-200)', marginBottom: '1rem' }}>
                <h3 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: '0.5rem', color: 'var(--stone-900)' }}>Q: {faq.q}</h3>
                <p style={{ fontSize: '0.925rem', color: 'var(--stone-600)', lineHeight: 1.7 }}>A: {faq.a}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section style={{ background: 'var(--stone-900)', color: 'white', padding: '5rem 0', textAlign: 'center' }}>
        <div className="section-container">
          <h2>三十年的溫度，一試成主顧</h2>
          <p style={{ color: 'var(--stone-400)', marginBottom: '2.5rem', marginTop: '1rem' }}>宏森開發，您美化居家生活最值得信賴的好伙伴。</p>
          <div style={{ display: 'flex', gap: '1.25rem', justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link href="/calculator" className="btn-primary" style={{ background: 'var(--amber-600)', padding: '1rem 2rem' }}>
              立即線上估價 <ChevronRight size={18} />
            </Link>
            <a href="tel:0289727322" className="btn-secondary" style={{ padding: '1rem 2rem' }}>
              直接聯繫我們 02-8972-7322
            </a>
          </div>
        </div>
      </section>
    </>
  );
}
