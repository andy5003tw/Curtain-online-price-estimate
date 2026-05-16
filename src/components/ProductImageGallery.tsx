"use client";

import { useState } from 'react';
import { X, ChevronLeft, ChevronRight } from 'lucide-react';

interface GalleryImage {
  src: string;
  alt: string;
}

interface ProductImageGalleryProps {
  gallery: GalleryImage[];
}

export default function ProductImageGallery({ gallery }: ProductImageGalleryProps) {
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);

  if (!gallery || gallery.length === 0) return null;

  const handleNext = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (selectedIndex !== null) {
      setSelectedIndex((selectedIndex + 1) % gallery.length);
    }
  };

  const handlePrev = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (selectedIndex !== null) {
      setSelectedIndex((selectedIndex - 1 + gallery.length) % gallery.length);
    }
  };

  return (
    <>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '1rem' }} className="gallery-grid">
        {gallery.map((img, i) => (
          <div 
            key={i} 
            className="gallery-item" 
            style={{ borderRadius: '1rem', overflow: 'hidden', aspectRatio: '4/3', background: 'var(--stone-200)', position: 'relative', cursor: 'pointer' }}
            onClick={() => setSelectedIndex(i)}
          >
            <img
              src={img.src}
              alt={img.alt}
              title={img.alt}
              loading={i === 0 ? 'eager' : 'lazy'}
              style={{ width: '100%', height: '100%', objectFit: 'cover', transition: 'transform 0.3s ease' }}
            />
            <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.55), transparent)', padding: '1.5rem 1rem 0.75rem', pointerEvents: 'none' }}>
              <p style={{ color: 'white', fontSize: '0.8rem', margin: 0, fontWeight: 500, textShadow: '0 1px 3px rgba(0,0,0,0.5)' }}>{img.alt}</p>
            </div>
          </div>
        ))}
      </div>

      <style dangerouslySetInnerHTML={{__html: `
        @media (min-width: 768px) { .gallery-grid { grid-template-columns: repeat(4, 1fr) !important; } }
        .gallery-item img { transition: transform 0.35s ease; }
        .gallery-item:hover img { transform: scale(1.05); }
      `}} />

      {/* Lightbox Overlay */}
      {selectedIndex !== null && (
        <div 
          style={{
            position: 'fixed',
            top: 0, left: 0, right: 0, bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.9)',
            zIndex: 9999,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            opacity: 1,
            animation: 'fadeIn 0.2s ease-out'
          }}
          onClick={() => setSelectedIndex(null)}
        >
          <button 
            style={{ position: 'absolute', top: '1.5rem', right: '1.5rem', background: 'rgba(255,255,255,0.1)', border: 'none', color: 'white', padding: '0.5rem', borderRadius: '50%', cursor: 'pointer', transition: 'background 0.2s' }}
            onClick={(e) => { e.stopPropagation(); setSelectedIndex(null); }}
            className="lightbox-close"
          >
            <X size={28} />
          </button>
          
          {gallery.length > 1 && (
            <button 
              style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', background: 'rgba(255,255,255,0.1)', border: 'none', color: 'white', padding: '1rem', borderRadius: '50%', cursor: 'pointer', transition: 'background 0.2s' }}
              onClick={handlePrev}
              className="lightbox-nav"
            >
              <ChevronLeft size={36} />
            </button>
          )}

          <div style={{ maxWidth: '90vw', maxHeight: '85vh', position: 'relative' }} onClick={(e) => e.stopPropagation()}>
            <img 
              src={gallery[selectedIndex].src} 
              alt={gallery[selectedIndex].alt} 
              style={{ maxWidth: '100%', maxHeight: '85vh', objectFit: 'contain', borderRadius: '0.5rem', boxShadow: '0 4px 20px rgba(0,0,0,0.5)' }} 
            />
            <div style={{ position: 'absolute', bottom: '-2.5rem', left: 0, right: 0, textAlign: 'center', color: 'white', fontSize: '1rem', fontWeight: 500 }}>
              {gallery[selectedIndex].alt} ({selectedIndex + 1} / {gallery.length})
            </div>
          </div>

          {gallery.length > 1 && (
            <button 
              style={{ position: 'absolute', right: '1rem', top: '50%', transform: 'translateY(-50%)', background: 'rgba(255,255,255,0.1)', border: 'none', color: 'white', padding: '1rem', borderRadius: '50%', cursor: 'pointer', transition: 'background 0.2s' }}
              onClick={handleNext}
              className="lightbox-nav"
            >
              <ChevronRight size={36} />
            </button>
          )}

          <style dangerouslySetInnerHTML={{__html: `
            @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
            .lightbox-close:hover, .lightbox-nav:hover { background: rgba(255,255,255,0.2) !important; }
            @media (max-width: 640px) {
              .lightbox-nav { padding: 0.5rem !important; }
            }
          `}} />
        </div>
      )}
    </>
  );
}
