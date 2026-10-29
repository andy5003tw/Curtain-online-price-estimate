'use client';

import Link from 'next/link';
import { useState } from 'react';
import { usePathname } from 'next/navigation';
import { Menu, X, ChevronRight, Home, MapPin } from 'lucide-react';
import { CATALOG_URL } from '@/lib/seo';

export default function Header() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  const isCurrentPage = (href: string) => (
    pathname === href || pathname === `${href}/` || pathname?.startsWith(`${href}/`)
  );
  const isLocationPage = isCurrentPage('/location');

  return (
    <header className="site-header">
      <div className="header-inner">
        <div className="logo-group">
          <Link href="/" className="home-icon-link" aria-label="回到首頁" onClick={() => setOpen(false)}>
            <Home size={20} />
          </Link>
          <Link href="/" className="logo-main" onClick={() => setOpen(false)}>宏森窗簾</Link>
          <span className="logo-sub">專業訂製</span>
        </div>

        {/* Desktop Nav */}
        <nav className="desktop-nav">
          <Link href="/about" className={`nav-link${isCurrentPage('/about') ? ' is-current' : ''}`} aria-current={isCurrentPage('/about') ? 'page' : undefined}>關於我們</Link>
          <Link href="/products" className={`nav-link${isCurrentPage('/products') ? ' is-current' : ''}`} aria-current={isCurrentPage('/products') ? 'page' : undefined}>產品系列</Link>
          <Link href="/cases" className={`nav-link${isCurrentPage('/cases') ? ' is-current' : ''}`} aria-current={isCurrentPage('/cases') ? 'page' : undefined}>施工案例</Link>
          <Link href="/blog" className={`nav-link${isCurrentPage('/blog') ? ' is-current' : ''}`} aria-current={isCurrentPage('/blog') ? 'page' : undefined}>窗簾知識</Link>
          <Link href="/calculator" className={`nav-link${isCurrentPage('/calculator') ? ' is-current' : ''}`} aria-current={isCurrentPage('/calculator') ? 'page' : undefined}>線上估價</Link>
          <Link
            href="/location/"
            className={`nav-link nav-location-link${isLocationPage ? ' is-current' : ''}`}
            aria-current={isLocationPage ? 'page' : undefined}
          >
            <MapPin size={15} aria-hidden="true" />
            服務地點
          </Link>
          <a
            href={CATALOG_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="nav-cta"
          >
            官方型錄
          </a>
        </nav>

        {/* Mobile toggle */}
        <button
          className="mobile-menu-btn"
          onClick={() => setOpen(!open)}
          aria-label="切換選單"
        >
          {open ? <X size={24} /> : <Menu size={24} />}
        </button>
      </div>

      {/* Mobile Nav */}
      <nav className={`mobile-nav${open ? ' open' : ''}`}>
        <Link href="/about" className={`nav-link${isCurrentPage('/about') ? ' is-current' : ''}`} aria-current={isCurrentPage('/about') ? 'page' : undefined} onClick={() => setOpen(false)}>關於我們</Link>
        <Link href="/products" className={`nav-link${isCurrentPage('/products') ? ' is-current' : ''}`} aria-current={isCurrentPage('/products') ? 'page' : undefined} onClick={() => setOpen(false)}>產品系列</Link>
        <Link href="/cases" className={`nav-link${isCurrentPage('/cases') ? ' is-current' : ''}`} aria-current={isCurrentPage('/cases') ? 'page' : undefined} onClick={() => setOpen(false)}>施工案例</Link>
        <Link href="/blog" className={`nav-link${isCurrentPage('/blog') ? ' is-current' : ''}`} aria-current={isCurrentPage('/blog') ? 'page' : undefined} onClick={() => setOpen(false)}>窗簾知識</Link>
        <Link href="/calculator" className={`nav-link${isCurrentPage('/calculator') ? ' is-current' : ''}`} aria-current={isCurrentPage('/calculator') ? 'page' : undefined} onClick={() => setOpen(false)}>線上估價</Link>
        <Link
          href="/location/"
          className={`nav-link nav-location-link${isLocationPage ? ' is-current' : ''}`}
          aria-current={isLocationPage ? 'page' : undefined}
          onClick={() => setOpen(false)}
        >
          <MapPin size={16} aria-hidden="true" />
          服務地點
        </Link>
        
        <div style={{ margin: '0.5rem 0.5rem', paddingTop: '0.5rem', borderTop: '1px solid var(--stone-200)', display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
          <span style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--stone-400)', padding: '0 0.25rem', marginTop: '0.5rem', marginBottom: '0.25rem' }}>線上客服 / 免費估價</span>
          <a href="https://line.me/ti/p/fDWxUXkiZb" target="_blank" rel="noopener noreferrer" style={{ display: 'flex', alignItems: 'center', padding: '0.65rem 0.75rem', color: 'var(--stone-900)', borderRadius: '0.5rem', textDecoration: 'none', fontWeight: 600, backgroundColor: 'rgba(6, 199, 85, 0.1)' }} onClick={() => setOpen(false)}>
            <div style={{ width: '8px', height: '8px', background: '#06C755', borderRadius: '50%', display: 'inline-block', marginRight: '0.6rem' }}></div>
            客服一 0980 (加 LINE)
          </a>
          <a href="https://line.me/ti/p/nS1XQ4-flk" target="_blank" rel="noopener noreferrer" style={{ display: 'flex', alignItems: 'center', padding: '0.65rem 0.75rem', color: 'var(--stone-900)', borderRadius: '0.5rem', textDecoration: 'none', fontWeight: 600, backgroundColor: 'rgba(6, 199, 85, 0.1)' }} onClick={() => setOpen(false)}>
            <div style={{ width: '8px', height: '8px', background: '#06C755', borderRadius: '50%', display: 'inline-block', marginRight: '0.6rem' }}></div>
            客服二 0973 (加 LINE)
          </a>
        </div>

        <a
          href={CATALOG_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="mobile-cta"
          onClick={() => setOpen(false)}
        >
          官方型錄（正式官網）
          <ChevronRight size={16} style={{ display: 'inline', marginLeft: '0.25rem' }} />
        </a>
      </nav>
    </header>
  );
}
