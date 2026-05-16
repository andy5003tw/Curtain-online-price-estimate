'use client';

import { useState, Suspense, useEffect } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';

function BlogListContent({ knowledgePosts, knowledgeCategories, knowledgeTags }: any) {
  const searchParams = useSearchParams();
  const initialCategory = searchParams?.get('category') || 'all';
  const initialTag = searchParams?.get('tag') || null;

  const [activeCategory, setActiveCategory] = useState<string>(initialCategory);
  const [activeTag, setActiveTag] = useState<string | null>(initialTag);

  // Sync state if URL changes
  useEffect(() => {
    const cat = searchParams?.get('category');
    const tag = searchParams?.get('tag');
    if (cat) { setActiveCategory(cat); setActiveTag(null); }
    if (tag) { setActiveTag(tag); setActiveCategory('all'); }
  }, [searchParams]);

  const handleCategoryClick = (catId: string) => {
    setActiveCategory(catId);
    setActiveTag(null);
  };

  const handleTagClick = (tag: string) => {
    if (activeTag === tag) {
      setActiveTag(null); // toggle off
    } else {
      setActiveTag(tag);
      setActiveCategory('all');
    }
  };

  const filteredPosts = knowledgePosts.filter((post: any) => {
    if (activeTag) {
      return post.tags.includes(activeTag);
    }
    if (activeCategory !== 'all') {
      return post.category === activeCategory;
    }
    return true; // show all
  });

  return (
    <>
      {/* Main Content Area */}
      <section className="py-section bg-stone-50">
        <div className="section-container" style={{ display: 'flex', flexWrap: 'wrap', gap: '3rem', alignItems: 'flex-start' }}>
          
          {/* Main Grid */}
          <div style={{ flex: '1 1 60%', minWidth: '300px' }}>
            
            {/* Category Tabs */}
            <div style={{ marginBottom: '2rem', display: 'flex', gap: '0.8rem', overflowX: 'auto', paddingBottom: '0.5rem', scrollbarWidth: 'none' }}>
              <button 
                onClick={() => handleCategoryClick('all')}
                style={{ 
                  background: activeCategory === 'all' && !activeTag ? 'var(--stone-900)' : 'white', 
                  color: activeCategory === 'all' && !activeTag ? 'white' : 'var(--stone-600)', 
                  border: activeCategory === 'all' && !activeTag ? '1px solid var(--stone-900)' : '1px solid var(--stone-200)', 
                  padding: '0.4rem 1rem', borderRadius: '2rem', cursor: 'pointer', whiteSpace: 'nowrap', transition: 'all 0.2s', fontWeight: 600
                }}
              >
                全部文章
              </button>
              {knowledgeCategories.map((cat: any) => (
                <button 
                  key={cat.id} 
                  onClick={() => handleCategoryClick(cat.id)}
                  style={{ 
                    background: activeCategory === cat.id && !activeTag ? 'var(--stone-900)' : 'white', 
                    color: activeCategory === cat.id && !activeTag ? 'white' : 'var(--stone-600)', 
                    border: activeCategory === cat.id && !activeTag ? '1px solid var(--stone-900)' : '1px solid var(--stone-200)', 
                    padding: '0.4rem 1rem', borderRadius: '2rem', cursor: 'pointer', whiteSpace: 'nowrap', transition: 'all 0.2s', fontWeight: 600
                  }}
                >
                  {cat.name}
                </button>
              ))}
            </div>

            {/* Current Filter Indicator */}
            {activeTag && (
              <div style={{ marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.8rem' }}>
                <span style={{ fontSize: '0.9rem', color: 'var(--stone-500)' }}>目前搜尋標籤：</span>
                <span style={{ background: 'var(--amber-100)', color: 'var(--amber-800)', padding: '0.3rem 1rem', borderRadius: '2rem', fontSize: '0.9rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                  #{activeTag}
                  <button onClick={() => setActiveTag(null)} style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', fontSize: '1rem', lineHeight: 1, padding: 0 }}>×</button>
                </span>
              </div>
            )}

            {/* Articles List */}
            {filteredPosts.length === 0 ? (
              <div style={{ padding: '4rem 2rem', textAlign: 'center', background: 'white', borderRadius: '1rem', border: '1px solid var(--stone-100)' }}>
                <p style={{ color: 'var(--stone-500)', fontSize: '1.1rem' }}>沒有找到符合條件的文章。</p>
                <button onClick={() => {setActiveCategory('all'); setActiveTag(null);}} style={{ marginTop: '1rem', background: 'var(--amber-600)', color: 'white', border: 'none', padding: '0.6rem 1.5rem', borderRadius: '2rem', cursor: 'pointer', fontWeight: 600 }}>重設篩選</button>
              </div>
            ) : (
              <div className="blog-grid" style={{ gridTemplateColumns: '1fr', gap: '1.5rem' }}>
                {filteredPosts.map((article: any) => {
                  const categoryName = knowledgeCategories.find((c: any) => c.id === article.category)?.name || '未分類';
                  return (
                    <article key={article.id} className="case-card" style={{ display: 'flex', flexDirection: 'column', background: 'white', borderRadius: '1rem', overflow: 'hidden', border: '1px solid var(--stone-100)', transition: 'all 0.3s ease' }}>
                      <div style={{ display: 'flex', flexWrap: 'wrap' }}>
                        {/* Thumbnail Image */}
                        <div style={{ flex: '1 1 200px', minHeight: '200px', position: 'relative', background: 'var(--stone-100)' }}>
                          <img 
                            src={article.coverImage} 
                            alt={article.title} 
                            style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', objectFit: 'cover' }} 
                            onError={(e) => { e.currentTarget.style.display = 'none'; }}
                          />
                        </div>
                        {/* Article Content */}
                        <div style={{ flex: '2 1 300px', padding: '1.5rem', display: 'flex', flexDirection: 'column' }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.75rem' }}>
                            <span style={{ fontSize: '0.8rem', fontWeight: 700, color: 'var(--amber-700)', background: 'var(--amber-50)', padding: '0.2rem 0.6rem', borderRadius: '0.4rem' }}>{categoryName}</span>
                            <span className="blog-card-meta">{article.date} · 約 {article.readMin} 分鐘</span>
                          </div>
                          <h3 style={{ fontSize: '1.3rem', fontWeight: 700, margin: '0 0 0.8rem 0', color: 'var(--stone-900)', lineHeight: 1.4 }}>
                            <Link href={`/blog/${article.id}`} style={{ textDecoration: 'none', color: 'inherit' }}>{article.title}</Link>
                          </h3>
                          <p style={{ color: 'var(--stone-500)', lineHeight: 1.6, marginBottom: '1.5rem', fontSize: '0.95rem' }}>{article.description}</p>
                          
                          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem', marginBottom: '1.5rem' }}>
                            {article.tags.map((t: string) => (
                              <button key={t} onClick={() => handleTagClick(t)} style={{ fontSize: '0.75rem', background: 'var(--stone-50)', color: 'var(--stone-500)', padding: '0.2rem 0.5rem', borderRadius: '0.3rem', border: '1px solid var(--stone-200)', cursor: 'pointer', transition: 'all 0.2s' }} className="hover-tag-light">
                                #{t}
                              </button>
                            ))}
                          </div>

                          <div style={{ marginTop: 'auto', borderTop: '1px solid var(--stone-50)', paddingTop: '1rem' }}>
                            <Link
                              href={`/blog/${article.id}`}
                              style={{ display: 'inline-flex', alignItems: 'center', fontSize: '0.9rem', fontWeight: 600, color: 'var(--amber-600)', textDecoration: 'none' }}
                            >
                              閱讀全文 <span style={{ marginLeft: '0.3rem' }}>→</span>
                            </Link>
                          </div>
                        </div>
                      </div>
                    </article>
                  );
                })}
              </div>
            )}
          </div>

          {/* Sidebar */}
          <aside style={{ flex: '1 1 300px', position: 'sticky', top: '2rem' }}>
            <div style={{ background: 'white', padding: '1.5rem', borderRadius: '1rem', border: '1px solid var(--stone-100)', marginBottom: '1.5rem' }}>
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '1rem', color: 'var(--stone-900)' }}>快速查詢標籤</h3>
              <p style={{ fontSize: '0.85rem', color: 'var(--stone-500)', marginBottom: '1rem' }}>點擊產品標籤尋找相關文章</p>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                {knowledgeTags.map((tag: string, i: number) => (
                  <button 
                    key={i} 
                    onClick={() => handleTagClick(tag)}
                    className="hover-tag" 
                    style={{ 
                      fontSize: '0.85rem', padding: '0.4rem 0.8rem', 
                      background: activeTag === tag ? 'var(--stone-800)' : 'var(--stone-50)', 
                      color: activeTag === tag ? 'white' : 'var(--stone-600)', 
                      borderRadius: '2rem', cursor: 'pointer', transition: 'all 0.2s', border: '1px solid var(--stone-200)' 
                    }}
                  >
                    {tag}
                  </button>
                ))}
              </div>
            </div>

            <div style={{ background: 'var(--stone-900)', color: 'white', padding: '2rem 1.5rem', borderRadius: '1rem', textAlign: 'center' }}>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: '0 0 1rem 0' }}>找不到解答嗎？</h3>
              <p style={{ fontSize: '0.9rem', color: 'var(--stone-400)', marginBottom: '1.5rem', lineHeight: 1.5 }}>我們提供免費到府丈量與專業諮詢，為您量身打造最適合的窗簾方案。</p>
              <Link href="/calculator" style={{ display: 'block', background: 'var(--amber-600)', color: 'white', padding: '0.8rem', borderRadius: '0.5rem', fontWeight: 600, textDecoration: 'none', marginBottom: '0.8rem', transition: 'background 0.2s' }} onMouseOver={e => e.currentTarget.style.background = 'var(--amber-500)'} onMouseOut={e => e.currentTarget.style.background = 'var(--amber-600)'}>線上快速估價</Link>
              {/* Responsive tel link using CSS to reveal number on desktop */}
              <a href="tel:0289727322" className="responsive-tel-btn" style={{ display: 'block', border: '1px solid rgba(255,255,255,0.3)', color: 'white', padding: '0.8rem', borderRadius: '0.5rem', fontWeight: 600, textDecoration: 'none', transition: 'background 0.2s' }} onMouseOver={e => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'} onMouseOut={e => e.currentTarget.style.background = 'transparent'}>
                <span className="tel-text-short">撥打預約電話</span>
                <span className="tel-text-long" style={{ display: 'none' }}>撥打預約電話 (02-8972-7322)</span>
              </a>
            </div>
          </aside>
          
        </div>
      </section>

      <style dangerouslySetInnerHTML={{__html: `
        .hover-tag:hover { background: var(--stone-200) !important; color: var(--stone-800) !important; }
        .hover-tag-light:hover { background: var(--stone-200) !important; }
        /* Responsive Tel Btn details */
        @media (min-width: 768px) {
          .tel-text-short { display: none !important; }
          .tel-text-long { display: inline !important; }
          .case-card { flex-direction: row !important; }
        }
      `}} />
    </>
  );
}

export default function BlogListClient({ knowledgePosts, knowledgeCategories, knowledgeTags }: any) {
  return (
    <Suspense fallback={<div style={{ padding: '4rem', textAlign: 'center' }}>載入知識庫中...</div>}>
      <BlogListContent knowledgePosts={knowledgePosts} knowledgeCategories={knowledgeCategories} knowledgeTags={knowledgeTags} />
    </Suspense>
  );
}
