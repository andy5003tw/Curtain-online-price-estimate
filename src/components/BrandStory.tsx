'use client';

import { useState } from 'react';
import { ChevronDown, ChevronUp } from 'lucide-react';

interface BrandStoryProps {
  content1: React.ReactNode;
  content2: React.ReactNode;
}

export default function BrandStory({ content1, content2 }: BrandStoryProps) {
  const [isExpanded, setIsExpanded] = useState(false);

  return (
    <div className="brand-story-wrapper">
      <div className={`brand-story-content ${isExpanded ? 'expanded' : 'collapsed'}`}>
        <div style={{ display: 'grid', gap: '1.5rem', gridTemplateColumns: '1fr', alignItems: 'center' }} className="brand-story-grid">
          {content1}
          {content2}
        </div>
      </div>
      
      <div className="brand-story-toggle-mobile">
        <button 
          onClick={() => setIsExpanded(!isExpanded)}
          className="btn-read-more"
        >
          {isExpanded ? (
            <>收合內容 <ChevronUp size={18} /></>
          ) : (
            <>詳閱全文 <ChevronDown size={18} /></>
          )}
        </button>
      </div>

      <style jsx>{`
        .brand-story-wrapper {
          position: relative;
        }

        .brand-story-toggle-mobile {
          display: none;
          justify-content: center;
          margin-top: 1.5rem;
        }

        .btn-read-more {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          padding: 0.6rem 2rem;
          background: white;
          border: 1.5px solid var(--amber-600);
          color: var(--amber-600);
          border-radius: 999px;
          font-weight: 700;
          font-size: 0.95rem;
          cursor: pointer;
          transition: all 0.2s;
        }

        .btn-read-more:hover {
          background: var(--amber-50);
          transform: translateY(-2px);
        }

        @media (max-width: 768px) {
          .brand-story-toggle-mobile {
            display: flex;
          }

          .brand-story-content.collapsed {
            max-height: 200px;
            overflow: hidden;
            mask-image: linear-gradient(to bottom, black 60%, transparent 100%);
            -webkit-mask-image: linear-gradient(to bottom, black 60%, transparent 100%);
          }

          .brand-story-content.expanded {
            max-height: 2000px;
            transition: max-height 0.5s ease-in;
          }
          
          .brand-story-content {
            transition: max-height 0.3s ease-out;
          }
        }
      `}</style>
    </div>
  );
}
