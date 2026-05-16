"use client";
import Link from 'next/link';
import { Calculator } from 'lucide-react';
import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

export default function FloatingCta() {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      // Show when scrolled past the hero section (approx 500px)
      if (window.scrollY > 500) {
        setIsVisible(true);
      } else {
        setIsVisible(false);
      }
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 0, y: 50, scale: 0.9 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 50, scale: 0.9 }}
          transition={{ duration: 0.3, ease: 'easeOut' }}
          style={{
            position: 'fixed',
            bottom: '6.5rem',
            right: '2rem',
            zIndex: 50,
          }}
        >
          <Link
            href="/calculator"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.75rem',
              background: 'var(--amber-600)',
              color: 'white',
              padding: '1rem 1.5rem',
              borderRadius: '999px',
              fontWeight: 700,
              fontSize: '1.05rem',
              textDecoration: 'none',
              boxShadow: '0 10px 25px -5px rgba(217, 119, 6, 0.4), 0 8px 10px -6px rgba(217, 119, 6, 0.2)',
              border: '2px solid rgba(255,255,255,0.2)',
              transition: 'transform 0.2s',
            }}
            onMouseOver={(e) => e.currentTarget.style.transform = 'scale(1.05)'}
            onMouseOut={(e) => e.currentTarget.style.transform = 'scale(1)'}
          >
            <Calculator size={24} />
            <span>一鍵線上估價</span>
          </Link>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
