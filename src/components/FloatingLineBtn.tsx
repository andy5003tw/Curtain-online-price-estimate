'use client';
import { useState } from 'react';

export default function FloatingLineBtn() {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="floating-line-wrapper">
      <div 
        className={`floating-line-menu qr-version ${isOpen ? 'open' : ''}`} 
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{ position: 'absolute', top: '0.5rem', right: '0.5rem', cursor: 'pointer', color: 'var(--stone-400)' }} onClick={() => setIsOpen(false)} aria-label="隱藏選單">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 6 6 18M6 6l12 12"/></svg>
        </div>
        <div className="qr-box">
          <div className="qr-title">專員一 0980</div>
          <img src="https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=https://line.me/ti/p/fDWxUXkiZb" alt="LINE QR 0980" />
          <a href="https://line.me/ti/p/fDWxUXkiZb" target="_blank" rel="noopener noreferrer">用電腦版開啟</a>
        </div>
        <div className="qr-divider"></div>
        <div className="qr-box">
          <div className="qr-title">專員二 0973</div>
          <img src="https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=https://line.me/ti/p/nS1XQ4-flk" alt="LINE QR 0973" />
          <a href="https://line.me/ti/p/nS1XQ4-flk" target="_blank" rel="noopener noreferrer">用電腦版開啟</a>
        </div>
      </div>
      
      <div className="floating-line-btn" aria-label="切換 LINE 好友選單" onClick={() => setIsOpen(!isOpen)}>
        <svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round">
          {isOpen ? (
            <path d="M18 6 6 18M6 6l12 12" />
          ) : (
            <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z" />
          )}
        </svg>
        <span className="line-btn-text">{isOpen ? '關閉選單' : 'LINE 諮詢'}</span>
      </div>
    </div>
  );
}
