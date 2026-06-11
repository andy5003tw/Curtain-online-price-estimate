'use client';

import { useState, useMemo, useEffect, useRef } from 'react';
import Link from 'next/link';
import { constructionCases } from '@/data/constructionCases';
import { absoluteUrl } from '@/lib/seo';
import { withBasePath } from '@/lib/base-path';
import { MapPin, Tag, Calendar, Image as ImageIcon, Search, Filter, X, ChevronRight, ChevronLeft, XCircle } from 'lucide-react';

const ALL_DISTRICTS = '所有地區';
const ALL_TYPES = '所有款式';

const QUICK_LINKS = [
  { label: '三重國小捷運站', keyword: '三重' },
  { label: '三重集美街', keyword: '集美街' },
  { label: '三重仁愛街', keyword: '仁愛街' },
  { label: '板橋新海路', keyword: '新海路' },
  { label: '板橋龍昌診所', keyword: '龍昌' },
  { label: '新莊化成路', keyword: '化成路' },
  { label: '新莊中正路', keyword: '中正路' },
  { label: '內湖民權路', keyword: '民權' },
  { label: '台北市中山區', keyword: '中山' },
  { label: '台北市南京西路', keyword: '南京西路' }
];

const CASE_OWNER_LINKS = [
  { href: '/calculator/', label: '窗簾價格試算：先帶尺寸做線上估價' },
  { href: '/products/custom-curtains/', label: '窗簾訂製推薦：先看客廳主窗與雙層布簾' },
  { href: '/curtain/living-room/', label: '客廳窗簾推薦：先比落地窗、紗簾與雙層搭配' },
  { href: '/curtain/blackout/', label: '遮光窗簾推薦：先比補眠、西曬與隔熱方案' },
  { href: '/products/roller-blinds/', label: '捲簾價格試算：書房、租屋與小窗預算入口' },
  { href: '/products/honeycomb-blinds/', label: '風琴簾價格試算：西曬與隔熱窗面怎麼抓' },
  { href: '/products/seamless-sheer-curtains/', label: '無縫紗簾推薦：客廳透光不透人方案' },
  { href: '/blog/budget-allocation-for-curtains/', label: '窗簾預算分配：先看客廳主窗與功能窗怎麼抓' },
  { href: '/location/shilin/', label: '士林窗簾價格試算入口' },
];

const CASE_FAQS = [
  {
    q: '看窗簾施工案例時，先比哪三件事最有效率？',
    a: '建議先比窗型、款式和採光需求，再看是否需要遮光、透光不透人或雙層搭配。這樣回到線上估價工具時，比價會更接近正式報價。',
  },
  {
    q: '施工案例能幫我判斷客廳窗簾要選無縫紗簾還是調光簾嗎？',
    a: '可以。若重視柔和採光與空間通透感，可先看無縫紗簾與雙層窗簾案例；若希望快速切換透光與隱私，可優先看調光簾案例，再帶同尺寸去做價格試算。',
  },
  {
    q: '看完案例後，下一步是先估價還是先約丈量？',
    a: '若還在比預算，建議先做窗簾價格試算；若已經鎖定 1 到 2 種款式，就可以直接切到對應地區頁安排丈量與看樣，流程會更快。',
  },
  {
    q: '三重、板橋、新莊、台北的施工案例可以對照同一種產品嗎？',
    a: '可以，案例頁很適合先看同款產品在不同窗型與空間中的呈現，再用同一組尺寸切到地區頁或產品頁做比價，避免只看單一照片就下決定。',
  },
  {
    q: '看完施工案例後，可以順便判斷窗簾預算怎麼分配嗎？',
    a: '可以。先把客廳主窗、主臥遮光與西曬窗面列為優先，再把小窗交給捲簾或鋁百葉控制成本，接著用線上估價工具輸入同尺寸比較，就能快速抓出大概預算。',
  },
];

function CaseCard({ c, onOpenLightbox }: { c: any, onOpenLightbox: (images: string[], index: number) => void }) {
  const [previewIndex, setPreviewIndex] = useState(0);
  const scrollRef = useRef<HTMLDivElement>(null);
  const caseImages = useMemo(() => c.images.map((img: string) => withBasePath(img)), [c.images]);

  const scrollLeft = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (scrollRef.current) scrollRef.current.scrollBy({ left: -150, behavior: 'smooth' });
  };
  
  const scrollRight = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (scrollRef.current) scrollRef.current.scrollBy({ left: 150, behavior: 'smooth' });
  };

  return (
    <article className="case-card" style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'white', borderRadius: '1rem', overflow: 'hidden', border: '1px solid var(--stone-100)', transition: 'all 0.3s ease' }}>
      <div 
        className="case-card-img" 
        onClick={() => onOpenLightbox(caseImages, previewIndex)}
        style={{ position: 'relative', width: '100%', paddingTop: '75%', cursor: 'zoom-in', background: 'var(--stone-100)' }}
      >
        <img 
          src={caseImages[previewIndex] || caseImages[0]} 
          alt={c.title} 
          loading="lazy" 
          style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', objectFit: 'cover', transition: 'transform 0.5s ease' }}
          onMouseOver={(e) => e.currentTarget.style.transform = 'scale(1.05)'}
          onMouseOut={(e) => e.currentTarget.style.transform = 'scale(1)'}
        />
        <div style={{ position: 'absolute', top: '0.75rem', left: '0.75rem', display: 'flex', gap: '0.4rem' }}>
          <span style={{ fontSize: '0.7rem', padding: '0.2rem 0.6rem', background: 'rgba(255,255,255,0.95)', color: 'var(--stone-800)', borderRadius: '0.5rem', fontWeight: 700 }}>{c.type}</span>
        </div>
        {c.images.length > 1 && (
          <div style={{ position: 'absolute', bottom: '0.75rem', right: '0.75rem', background: 'rgba(0,0,0,0.7)', color: 'white', padding: '0.25rem 0.75rem', borderRadius: '1rem', fontSize: '0.75rem', display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
            <ImageIcon size={12} /> {c.images.length}
          </div>
        )}
      </div>
      
      <div className="case-card-body" style={{ padding: '1.25rem', flexGrow: 1, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', color: 'var(--stone-400)', fontSize: '0.8rem', marginBottom: '0.5rem', fontWeight: 500 }}>
          <MapPin size={12} /> {c.location}
        </div>
        <h3 style={{ fontSize: '1.1rem', marginBottom: '1rem', fontWeight: 700, lineHeight: 1.4, color: 'var(--stone-900)' }}>{c.title}</h3>
        
        <div style={{ marginTop: 'auto' }}>
          {/* Scrollable Thumbnails with arrows */}
          {c.images.length > 1 && (
            <div style={{ position: 'relative', marginBottom: '1.25rem', display: 'flex', alignItems: 'center' }}>
              <button 
                onClick={scrollLeft}
                style={{ position: 'absolute', left: '-10px', zIndex: 2, background: 'rgba(255,255,255,0.9)', border: '1px solid var(--stone-200)', borderRadius: '50%', width: '1.8rem', height: '1.8rem', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', boxShadow: '0 2px 5px rgba(0,0,0,0.1)' }}
              >
                <ChevronLeft size={14} style={{ color: 'var(--stone-600)' }} />
              </button>
              
              <div 
                ref={scrollRef}
                style={{ 
                  display: 'flex', gap: '0.5rem', padding: '0.5rem', background: 'var(--stone-50)', 
                  borderRadius: '0.75rem', overflowX: 'auto', scrollBehavior: 'smooth',
                  flexGrow: 1,
                  scrollbarWidth: 'none', // Firefox
                  msOverflowStyle: 'none'  // IE
                }}
              >
                {caseImages.map((img: string, idx: number) => (
                  <div 
                    key={idx} 
                    onMouseEnter={() => setPreviewIndex(idx)}
                    onClick={() => onOpenLightbox(caseImages, idx)}
                    style={{ 
                      flex: '0 0 auto', width: '30%', minWidth: '60px', aspectRatio: '1', position: 'relative', 
                      borderRadius: '0.3rem', overflow: 'hidden', cursor: 'pointer', 
                      border: previewIndex === idx ? '2px solid var(--amber-500)' : '2px solid transparent',
                      transition: 'all 0.2s'
                    }}
                  >
                    <img src={img} alt={`${c.title} 細節 ${idx+1}`} style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
                  </div>
                ))}
              </div>

              <button 
                onClick={scrollRight}
                style={{ position: 'absolute', right: '-10px', zIndex: 2, background: 'rgba(255,255,255,0.9)', border: '1px solid var(--stone-200)', borderRadius: '50%', width: '1.8rem', height: '1.8rem', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', boxShadow: '0 2px 5px rgba(0,0,0,0.1)' }}
              >
                <ChevronRight size={14} style={{ color: 'var(--stone-600)' }} />
              </button>
            </div>
          )}
          
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingTop: '1rem', borderTop: '1px solid var(--stone-50)' }}>
            <span style={{ fontSize: '0.75rem', color: 'var(--stone-400)', display: 'flex', alignItems: 'center', gap: '0.2rem' }}><Calendar size={12} /> {c.date}</span>
            <button 
              onClick={() => onOpenLightbox(caseImages, previewIndex)}
              style={{ background: 'none', border: 'none', color: 'var(--amber-600)', fontSize: '0.85rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '0.1rem', cursor: 'pointer', padding: '0.25rem', borderRadius: '0.25rem' }}
              onMouseOver={(e) => e.currentTarget.style.background = 'var(--amber-50)'}
              onMouseOut={(e) => e.currentTarget.style.background = 'none'}
            >
              觀看實景 <ChevronRight size={14} />
            </button>
          </div>
        </div>
      </div>
    </article>
  )
}


export default function CasesPage() {
  const [selectedDistrict, setSelectedDistrict] = useState(ALL_DISTRICTS);
  const [selectedType, setSelectedType] = useState(ALL_TYPES);
  const [searchQuery, setSearchQuery] = useState('');
  
  // Lightbox state
  const [lightbox, setLightbox] = useState<{ images: string[], index: number } | null>(null);

  // Extract unique districts and types for filters
  const districts = useMemo(() => {
    const set = new Set<string>();
    constructionCases.forEach(c => {
      const match = c.location.match(/^(三重|板橋|新莊|蘆洲|中和|永和|內湖|中山|林口|樹林|桃園|竹北|大園|新店|北市|大觀路|集美街|三和路|三陽路|化成路|南京西路|承德路|民生東路|漢口街|羅斯福路|錦通街|長安街|藝文一街|疏洪西路|南雅西路|重慶北路|重新路)/);
      if (match) {
        let name = match[1];
        if (name.includes('羅斯福路') || name.includes('南京西路') || name.includes('承德路') || name.includes('中山') || name.includes('北市') || name.includes('漢口街') || name.includes('錦通街') || name.includes('復興北路') || name.includes('民生東路')) name = '台北市';
        if (name.includes('三重') || name.includes('集美街') || name.includes('三和路') || name.includes('三陽路') || name.includes('重新路') || name.includes('重安街') || name.includes('疏洪西路') || name.includes('仁愛街')) name = '三重區';
        if (name.includes('板橋') || name.includes('大觀路') || name.includes('南雅西路')) name = '板橋區';
        if (name.includes('新莊') || name.includes('化成路')) name = '新莊區';
        if (name.includes('蘆洲')) name = '蘆洲區';
        if (name.includes('新店')) name = '新店區';
        if (name.includes('林口')) name = '林口區';
        if (name.includes('中和')) name = '中和區';
        if (name.includes('桃園') || name.includes('蘆竹') || name.includes('大園') || name.includes('藝文一街')) name = '桃園/蘆竹';
        set.add(name);
      }
    });
    return [ALL_DISTRICTS, ...Array.from(set).sort()];
  }, []);

  const types = useMemo(() => {
    const set = new Set<string>();
    constructionCases.forEach(c => {
      if (c.type && c.type !== '精選窗簾') set.add(c.type);
    });
    return [ALL_TYPES, ...Array.from(set).sort()];
  }, []);

  const [visibleCount, setVisibleCount] = useState(12);

  const filteredCases = useMemo(() => {
    return constructionCases.filter(c => {
      const matchDistrict = selectedDistrict === ALL_DISTRICTS || c.location.includes(selectedDistrict) || 
        (selectedDistrict === '台北市' && (c.location.includes('羅斯福路') || c.location.includes('南京西路') || c.location.includes('北市') || c.location.includes('中山') || c.location.includes('漢口街') || c.location.includes('復興北路') || c.location.includes('錦通街') || c.location.includes('民生東路'))) ||
        (selectedDistrict === '三重區' && (c.location.includes('三重') || c.location.includes('集美街') || c.location.includes('三和路') || c.location.includes('三陽路') || c.location.includes('重新路') || c.location.includes('疏洪西路'))) ||
        (selectedDistrict === '板橋區' && (c.location.includes('板橋') || c.location.includes('大觀路') || c.location.includes('南雅西路')));
      
      const matchType = selectedType === ALL_TYPES || c.type === selectedType;
      
      // Advanced Search Matcher
      let matchSearch = true;
      if (searchQuery.trim() !== '') {
        const normalizedQuery = searchQuery.toLowerCase().replace(/臺/g, '台');
        const searchWords = normalizedQuery.split(/\s+/);
        
        // Add implicit aliases to target string so simple queries match
        const aliases: string[] = [];
        const loc = c.location.replace(/臺/g, '台');
        if (/三重|板橋|新莊|蘆洲|中和|林口|新店|樹林/.test(loc)) aliases.push('新北市', '新北');
        if (/北市|台北|內湖|中山|松江|民生|羅斯福|長安/.test(loc)) aliases.push('台北市', '台北', '北市');
        
        const targetString = `${c.title} ${c.location} ${c.type} ${aliases.join(' ')}`.toLowerCase().replace(/臺/g, '台');
        
        matchSearch = searchWords.every(word => targetString.includes(word));
      }

      return matchDistrict && matchType && matchSearch;
    });
  }, [selectedDistrict, selectedType, searchQuery]);

  const displayedCases = useMemo(() => filteredCases.slice(0, visibleCount), [filteredCases, visibleCount]);

  // Reset count when filters change
  useEffect(() => {
    setVisibleCount(12);
  }, [selectedDistrict, selectedType, searchQuery]);

  // Body scroll lock for lightbox
  useEffect(() => {
    if (lightbox) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [lightbox]);

  // keydown for lightbox
  useEffect(() => {
    if (!lightbox) return;
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setLightbox(null);
      if (e.key === 'ArrowRight') setLightbox(prev => prev ? { ...prev, index: (prev.index + 1) % prev.images.length } : null);
      if (e.key === 'ArrowLeft') setLightbox(prev => prev ? { ...prev, index: (prev.index - 1 + prev.images.length) % prev.images.length } : null);
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [lightbox]);

  const caseListSchema = {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    name: '宏森開發窗簾施工案例庫',
    url: absoluteUrl('/cases/'),
    itemListElement: filteredCases.slice(0, 20).map((c, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: c.title,
      description: `${c.location}的${c.type}施作案例`,
    })),
  };

  const faqSchema = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: CASE_FAQS.map((faq) => ({
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
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(caseListSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }}
      />
      
      <style dangerouslySetInnerHTML={{__html: `
        .cases-grid ::-webkit-scrollbar { display: none; }
      `}} />

      {/* 燈箱展開圖片 */}
      {lightbox && (
        <div 
          onClick={() => setLightbox(null)}
          style={{
            position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
            background: 'rgba(0,0,0,0.95)', 
            zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', 
            padding: '1rem'
          }}
        >
          {/* Main Image */}
          <div 
            onClick={(e) => e.stopPropagation()}
            style={{ position: 'relative', width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
          >
            <img 
              src={lightbox.images[lightbox.index]} 
              alt="實景放大" 
              style={{ 
                maxWidth: '100%', maxHeight: '95vh', objectFit: 'contain', 
                boxShadow: '0 25px 50px -12px rgba(0,0,0,0.5)',
                willChange: 'transform'
              }} 
            />
            
            {/* Prev/Next Buttons */}
            {lightbox.images.length > 1 && (
              <>
                <button 
                  onClick={(e) => { e.stopPropagation(); setLightbox({ ...lightbox, index: (lightbox.index - 1 + lightbox.images.length) % lightbox.images.length }); }}
                  style={{ position: 'absolute', left: '2%', top: '50%', transform: 'translateY(-50%)', background: 'rgba(255,255,255,0.1)', border: 'none', color: 'white', cursor: 'pointer', borderRadius: '50%', width: '3rem', height: '3rem', display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'background 0.2s' }}
                  onMouseOver={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.3)'}
                  onMouseOut={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'}
                >
                  <ChevronLeft size={32} />
                </button>
                <button 
                  onClick={(e) => { e.stopPropagation(); setLightbox({ ...lightbox, index: (lightbox.index + 1) % lightbox.images.length }); }}
                  style={{ position: 'absolute', right: '2%', top: '50%', transform: 'translateY(-50%)', background: 'rgba(255,255,255,0.1)', border: 'none', color: 'white', cursor: 'pointer', borderRadius: '50%', width: '3rem', height: '3rem', display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'background 0.2s' }}
                  onMouseOver={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.3)'}
                  onMouseOut={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'}
                >
                  <ChevronRight size={32} />
                </button>
                
                {/* Image counter */}
                <div style={{ position: 'absolute', bottom: '2%', left: '50%', transform: 'translateX(-50%)', background: 'rgba(0,0,0,0.6)', color: 'white', padding: '0.4rem 1rem', borderRadius: '2rem', fontSize: '0.9rem', letterSpacing: '0.1em' }}>
                  {lightbox.index + 1} / {lightbox.images.length}
                </div>
              </>
            )}
            
            {/* Close */}
            <button 
              onClick={() => setLightbox(null)}
              style={{ position: 'absolute', top: '1.5rem', right: '1.5rem', background: 'rgba(255,255,255,0.1)', border: 'none', color: 'white', cursor: 'pointer', borderRadius: '50%', padding: '0.5rem', display: 'flex', transition: 'background 0.2s' }}
              onMouseOver={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.4)'}
              onMouseOut={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'}
            >
              <XCircle size={32} />
            </button>
          </div>
        </div>
      )}

      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>›</span>
          <span>施工案例</span>
        </div>
      </nav>

      <div className="page-hero">
        <div className="section-container">
          <div className="tag" style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}>窗簾施工案例 / 客廳窗簾實景 / 價格試算前先看</div>
          <h1>窗簾施工案例｜客廳窗簾實景、遮光搭配與估價入口</h1>
          <p>先看三重、板橋、新莊、台北與士林的客廳窗簾、遮光窗簾、捲簾與無縫紗簾實景，再帶同一組尺寸接到窗簾價格試算、產品頁與地區丈量安排。</p>
        </div>
      </div>

      <section className="py-section bg-stone-50">
        <div className="section-container">
          <div style={{ marginBottom: '2rem', background: 'white', border: '1px solid var(--stone-200)', borderRadius: '1rem', padding: '1.5rem' }}>
            <h2 style={{ fontSize: '1.15rem', fontWeight: 700, color: 'var(--stone-900)', marginBottom: '0.75rem' }}>
              AI 短答案：看完案例後，怎麼最快走到正式報價？
            </h2>
            <p style={{ margin: '0 0 1rem 0', color: 'var(--stone-600)', lineHeight: 1.8, fontSize: '0.95rem' }}>
              先用施工案例確認想比的窗型、採光需求與款式，再把同一組尺寸帶進價格試算工具。若你已經鎖定客廳窗簾、遮光窗簾、捲簾或風琴簾，可直接切到對應產品頁與預算分配文章，讓估價與丈量流程接得更順。
            </p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.6rem' }}>
              {CASE_OWNER_LINKS.map((link, index) => (
                <Link
                  key={link.href}
                  href={link.href}
                  className={index === 0 ? 'btn-primary' : 'btn-outline'}
                  style={{ fontSize: '0.9rem' }}
                >
                  {link.label}
                </Link>
              ))}
            </div>
          </div>
          
          {/* Filters */}
          <div className="filters-row" id="cases-filter-section" style={{ marginBottom: '3rem', background: 'white', padding: '1.5rem', borderRadius: '1.5rem', border: '1px solid var(--stone-200)', boxShadow: '0 4px 12px rgba(0,0,0,0.03)' }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '1rem' }}>
              <div className="filter-group">
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.4rem', color: 'var(--stone-500)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>服務區域</label>
                <div style={{ position: 'relative' }}>
                  <MapPin size={14} style={{ position: 'absolute', left: '0.85rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--amber-600)' }} />
                  <select 
                    value={selectedDistrict} 
                    onChange={(e) => setSelectedDistrict(e.target.value)}
                    style={{ width: '100%', padding: '0.65rem 1rem 0.65rem 2.25rem', borderRadius: '0.75rem', border: '1px solid var(--stone-200)', outline: 'none', background: 'var(--stone-50)', fontSize: '0.9rem', cursor: 'pointer' }}
                  >
                    {districts.map(d => <option key={d} value={d}>{d}</option>)}
                  </select>
                </div>
              </div>
              <div className="filter-group">
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.4rem', color: 'var(--stone-500)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>窗簾類型</label>
                <div style={{ position: 'relative' }}>
                  <Tag size={14} style={{ position: 'absolute', left: '0.85rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--amber-600)' }} />
                  <select 
                    value={selectedType} 
                    onChange={(e) => setSelectedType(e.target.value)}
                    style={{ width: '100%', padding: '0.65rem 1rem 0.65rem 2.25rem', borderRadius: '0.75rem', border: '1px solid var(--stone-200)', outline: 'none', background: 'var(--stone-50)', fontSize: '0.9rem', cursor: 'pointer' }}
                  >
                    {types.map(t => <option key={t} value={t}>{t}</option>)}
                  </select>
                </div>
              </div>
              <div className="filter-group" style={{ gridColumn: 'span 1' }}>
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.4rem', color: 'var(--stone-500)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>搜尋關鍵字</label>
                <div style={{ position: 'relative' }}>
                  <Search size={14} style={{ position: 'absolute', left: '0.85rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--stone-400)' }} />
                  <input 
                    type="text" 
                    placeholder="如：台北市、中山區..." 
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    style={{ width: '100%', padding: '0.65rem 1rem 0.65rem 2.25rem', borderRadius: '0.75rem', border: '1px solid var(--stone-200)', outline: 'none', fontSize: '0.9rem' }}
                  />
                  {searchQuery && (
                    <button onClick={() => setSearchQuery('')} style={{ position: 'absolute', right: '0.75rem', top: '50%', transform: 'translateY(-50%)', border: 'none', background: 'none', color: 'var(--stone-400)', cursor: 'pointer' }}>
                      <X size={14} />
                    </button>
                  )}
                </div>
              </div>
            </div>
            <div style={{ marginTop: '1rem', paddingTop: '1rem', borderTop: '1px solid var(--stone-100)', fontSize: '0.825rem', color: 'var(--stone-500)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span>在此條件下共有 <strong style={{ color: 'var(--stone-800)', fontSize: '1rem' }}>{filteredCases.length}</strong> 個案例</span>
              {(selectedDistrict !== ALL_DISTRICTS || selectedType !== ALL_TYPES || searchQuery !== '') && (
                <button onClick={() => { setSelectedDistrict(ALL_DISTRICTS); setSelectedType(ALL_TYPES); setSearchQuery(''); }} style={{ background: 'var(--stone-100)', border: 'none', color: 'var(--stone-700)', padding: '0.4rem 0.8rem', borderRadius: '0.5rem', fontWeight: 600, cursor: 'pointer', fontSize: '0.825rem', display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
                  <X size={12} /> 清除篩選
                </button>
              )}
            </div>
          </div>

          {/* Cases Grid */}
          <div className="cases-grid">
            {displayedCases.map((c, index) => (
              <CaseCard key={`${c.id}-${index}`} c={c} onOpenLightbox={(imgs, idx) => setLightbox({ images: imgs, index: idx })} />
            ))}
          </div>

          {/* Load More Button */}
          {visibleCount < filteredCases.length && (
            <div style={{ textAlign: 'center', marginTop: '4rem' }}>
              <button 
                onClick={() => setVisibleCount(prev => prev + 12)}
                className="btn-outline"
                style={{ padding: '1rem 3rem', fontSize: '1rem', background: 'white' }}
              >
                載入更多案例 ({filteredCases.length - visibleCount})
              </button>
            </div>
          )}

          {filteredCases.length === 0 && (
            <div style={{ textAlign: 'center', padding: '6rem 0', background: 'white', borderRadius: '1.5rem', border: '1px dashed var(--stone-300)' }}>
              <div style={{ width: '80px', height: '80px', background: 'var(--stone-50)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 1.5rem' }}>
                <Search size={32} style={{ color: 'var(--stone-300)' }} />
              </div>
              <h3 style={{ color: 'var(--stone-800)' }}>找不到對應的案例</h3>
              <p style={{ color: 'var(--stone-500)', maxWidth: '300px', margin: '0.5rem auto 1.5rem' }}>請嘗試調整篩選條件，或是輸入更簡單的關鍵字搜尋（例如：台北市、板橋）。</p>
              <button 
                onClick={() => { setSelectedDistrict(ALL_DISTRICTS); setSelectedType(ALL_TYPES); setSearchQuery(''); }}
                style={{ background: 'var(--stone-900)', color: 'white', padding: '0.75rem 2rem', borderRadius: '0.75rem', border: 'none', fontWeight: 600, cursor: 'pointer' }}
              >
                重設篩選條件
              </button>
            </div>
          )}
        </div>
      </section>

      {/* Local Authority Section */}
      <section className="py-section bg-white">
        <div className="section-container">
          <div className="section-heading">
            <div className="tag">服務據點快速搜尋</div>
            <h2>三重・台北地區在地服務</h2>
            <p>點擊下列標籤，立即查看您所在地區的實景案例。</p>
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '1rem', justifyContent: 'center', maxWidth: '900px', margin: '0 auto' }}>
            {QUICK_LINKS.map((link, i) => (
              <button 
                key={i} 
                onClick={() => {
                  setSearchQuery(link.keyword);
                  setSelectedDistrict(ALL_DISTRICTS); // Optional: clear district strict filter
                  const filterEl = document.getElementById('cases-filter-section');
                  if (filterEl) {
                    const y = filterEl.getBoundingClientRect().top + window.scrollY - 100;
                    window.scrollTo({ top: y, behavior: 'smooth' });
                  } else {
                    window.scrollTo({ top: 300, behavior: 'smooth' });
                  }
                }}
                style={{ padding: '0.75rem 1.25rem', background: 'var(--stone-50)', borderRadius: '2rem', border: '1px solid var(--stone-200)', fontSize: '0.9rem', color: 'var(--stone-700)', fontWeight: 500, cursor: 'pointer', display: 'flex', alignItems: 'center', transition: 'all 0.2s ease', boxShadow: '0 2px 5px rgba(0,0,0,0.02)' }}
                onMouseOver={(e) => { e.currentTarget.style.background = 'var(--stone-100)'; e.currentTarget.style.borderColor = 'var(--stone-300)'; e.currentTarget.style.transform = 'translateY(-2px)' }}
                onMouseOut={(e) => { e.currentTarget.style.background = 'var(--stone-50)'; e.currentTarget.style.borderColor = 'var(--stone-200)'; e.currentTarget.style.transform = 'translateY(0)' }}
              >
                <MapPin size={12} style={{ display: 'inline', marginRight: '0.4rem', color: 'var(--amber-600)' }} /> {link.label}
              </button>
            ))}
          </div>
        </div>
      </section>

      <section className="py-section bg-white border-t border-stone-200">
        <div className="section-container" style={{ maxWidth: '900px' }}>
          <div className="section-heading">
            <h2>施工案例常見問題</h2>
            <p>先看案例、再抓預算、再估價與丈量，流程會更容易收斂。</p>
          </div>
          <div style={{ display: 'grid', gap: '1rem' }}>
            {CASE_FAQS.map((faq, index) => (
              <details key={index} style={{ background: 'var(--stone-50)', border: '1px solid var(--stone-200)', borderRadius: '0.75rem', overflow: 'hidden' }}>
                <summary style={{ padding: '1rem 1.25rem', fontWeight: 700, cursor: 'pointer', listStyle: 'none' }}>{faq.q}</summary>
                <div style={{ padding: '0 1.25rem 1rem', color: 'var(--stone-600)', lineHeight: 1.75 }}>{faq.a}</div>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section style={{ background: 'var(--stone-900)', color: 'white', padding: '5rem 0', textAlign: 'center' }}>
        <div className="section-container">
          <h2 style={{ fontSize: '2rem', fontWeight: 700, marginBottom: '1rem' }}>看完案例後，直接帶尺寸做線上估價</h2>
          <p style={{ color: 'var(--stone-400)', marginBottom: '3rem', fontSize: '1.1rem' }}>先抓到窗簾價格區間，再回頭比客廳主窗、遮光窗與功能窗的預算配置，正式報價會更快收斂。</p>
          <div style={{ display: 'flex', gap: '1.5rem', justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link href="/calculator" className="btn-primary" style={{ background: 'var(--amber-600)', padding: '1rem 2.5rem' }}>立即線上估價</Link>
            <Link href="/blog/budget-allocation-for-curtains/" className="btn-secondary" style={{ padding: '1rem 2.5rem', background: 'rgba(255,255,255,0.1)' }}>先看窗簾預算怎麼分配</Link>
          </div>
        </div>
      </section>
    </>
  );
}
