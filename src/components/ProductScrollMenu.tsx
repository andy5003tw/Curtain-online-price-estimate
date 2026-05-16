"use client";

import { useEffect, useRef } from 'react';
import Link from 'next/link';
import { products } from '@/data/products';
import { productPath } from '@/lib/seo';

type Product = typeof products[0];

interface ProductScrollMenuProps {
  products: Product[];
  currentProductId?: string;
  basePath?: string;
  buildHref?: (product: Product) => string;
}

export default function ProductScrollMenu({ products, currentProductId, basePath = '/products', buildHref }: ProductScrollMenuProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // Attempt to center the active item on hydration / mount
    if (containerRef.current) {
      const activeElement = containerRef.current.querySelector('.active') as HTMLElement;
      if (activeElement) {
        // Options for scrollIntoView:
        // inline: 'center' will center the element horizontally.
        activeElement.scrollIntoView({ behavior: 'auto', inline: 'center', block: 'nearest' });
      }
    }
  }, [currentProductId]);

  return (
    <div style={{ position: 'sticky', top: '65px', zIndex: 40, background: '#fafaf9', padding: '0.75rem 0', borderBottom: '1px solid rgba(0,0,0,0.05)', boxShadow: '0 4px 12px rgba(0,0,0,0.03)' }}>
      <div className="breadcrumb-inner" style={{ paddingTop: 0, paddingBottom: 0 }}>
        <div ref={containerRef} className="scroll-menu-container hide-scroll">
          {products.map(p => {
            const isActive = p.id === currentProductId;
            const href = buildHref
              ? buildHref(p)
              : basePath.includes('{productId}')
                ? basePath.replace('{productId}', p.id)
                : basePath.includes('?')
                  ? `${basePath}${p.id}`
                  : productPath(p);
            return (
              <Link
                key={'nav-' + p.id}
                href={href}
                className={`scroll-menu-item ${isActive ? 'active' : ''}`}
                prefetch={false} 
                scroll={false}
                style={{
                  borderColor: isActive ? '#f59e0b' : '#e7e5e4',
                  backgroundColor: isActive ? '#fffbeb' : 'white',
                  color: isActive ? '#b45309' : '#44403c',
                  borderWidth: '1.5px',
                  fontWeight: isActive ? 700 : 600,
                  boxShadow: isActive ? '0 0 0 1px #f59e0b' : '0 2px 4px rgba(0,0,0,0.02)'
                }}
              >
                {p.name}
              </Link>
            );
          })}
        </div>
      </div>
      <style dangerouslySetInnerHTML={{
        __html: `
          .hide-scroll::-webkit-scrollbar { display: none; }
          .scroll-menu-container {
            display: flex;
            overflow-x: auto;
            gap: 0.75rem;
            scrollbar-width: none;
            -webkit-overflow-scrolling: touch;
            padding: 0.25rem 0;
          }
          @media (min-width: 1024px) {
            .scroll-menu-container {
              flex-wrap: nowrap;
              overflow-x: auto;
              justify-content: center;
              gap: 0.5rem;
            }
          }
          .scroll-menu-item {
            white-space: nowrap;
            padding: 0.35rem 0.75rem;
            border-radius: 2rem;
            border: 1.5px solid #e7e5e4;
            background: white;
            color: #44403c;
            font-size: 0.825rem;
            font-weight: 600;
            text-decoration: none;
            flex-shrink: 0;
            transition: none;
            box-shadow: 0 2px 4px rgba(0,0,0,0.02);
            outline: none;
            -webkit-tap-highlight-color: transparent;
            margin: 0 2px;
          }
          .scroll-menu-item:hover {
            border-color: #fcd34d;
            background: #fffbeb;
          }
          .product-hero-grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: 2.5rem;
          }
          @media (min-width: 800px) {
            .product-hero-grid {
              grid-template-columns: 1fr 1fr;
              gap: 4rem;
            }
          }
        `
      }} />
    </div>
  );
}
