'use client';

import { useState, useMemo, useEffect, useRef } from 'react';
import Link from 'next/link';
import { constructionCases } from '@/data/constructionCases';
import { absoluteUrl } from '@/lib/seo';
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

function CaseCard({ c, onOpenLightbox }: { c: any, onOpenLightbox: (images: string[], index: number) => void }) {
  const [previewIndex, setPreviewIndex] = useState(0);
  const scrollRef = useRef<HTMLDivElement>(null);

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
        onClick={() => onOpenLightbox(c.images, previewIndex)}
        style={{ position: 'relative', width: '100%', paddingTop: '75%', cursor: 'zoom-in', background: 'var(--stone-100)' }}
      >
        <img 
          src={c.images[previewIndex] || c.images[0]} 
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
                {c.images.map((img: string, idx: number) => (
                  <div 
                    key={idx} 
                    onMouseEnter={() => setPreviewIndex(idx)}
                    onClick={() => onOpenLightbox(c.images, idx)}
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
              onClick={() => onOpenLightbox(c.images, previewIndex)}
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

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(caseListSchema) }}
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
          <div className="tag" style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}>實景拍攝</div>
          <h1>施工案例精選</h1>
          <p>累積超過三十年，大台北地區上萬件施作經驗。這裡記錄了我們對每一窗細節的堅持。</p>
        </div>
      </div>

      <section className="py-section bg-stone-50">
        <div className="section-container">
          
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

      {/* CTA */}
      <section style={{ background: 'var(--stone-900)', color: 'white', padding: '5rem 0', textAlign: 'center' }}>
        <div className="section-container">
          <h2 style={{ fontSize: '2rem', fontWeight: 700, marginBottom: '1rem' }}>讓專業師傅到府為您規劃</h2>
          <p style={{ color: 'var(--stone-400)', marginBottom: '3rem', fontSize: '1.1rem' }}>不限區域，台北市及新北市提供免費丈量服務。</p>
          <div style={{ display: 'flex', gap: '1.5rem', justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link href="/calculator" className="btn-primary" style={{ background: 'var(--amber-600)', padding: '1rem 2.5rem' }}>立即線上估價</Link>
            <a href="tel:0289727322" className="btn-secondary" style={{ padding: '1rem 2.5rem', background: 'rgba(255,255,255,0.1)' }}>預約到府量尺 02-8972-7322</a>
          </div>
        </div>
      </section>
    </>
  );
}
