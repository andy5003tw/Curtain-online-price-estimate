'use client';

import React, { useState, useEffect } from 'react';

export interface CityTabItem {
  id: string;
  name: string;
  icon: string;
  count: number;
  subText: string;
  anchorId: string;
  content: React.ReactNode;
}

interface LocationCityTabsProps {
  tabs: CityTabItem[];
  defaultCityId?: string;
}

export function LocationCityTabs({ tabs, defaultCityId = 'taipei' }: LocationCityTabsProps) {
  const [activeCity, setActiveCity] = useState<string>(defaultCityId);

  useEffect(() => {
    // 檢查初始 URL hash
    const handleHash = () => {
      const hash = window.location.hash.toLowerCase();
      if (hash.includes('new-taipei')) {
        setActiveCity('new-taipei');
      } else if (hash.includes('taipei')) {
        setActiveCity('taipei');
      }
    };

    handleHash();
    window.addEventListener('hashchange', handleHash);
    return () => window.removeEventListener('hashchange', handleHash);
  }, []);

  const handleSelectTab = (cityId: string, anchorId: string) => {
    setActiveCity(cityId);
    if (typeof window !== 'undefined') {
      window.history.replaceState(null, '', `#${anchorId}`);
      // 平滑捲動至頁籤區域
      const targetElement = document.getElementById('city-tabs-container');
      if (targetElement) {
        const yOffset = -90;
        const y = targetElement.getBoundingClientRect().top + window.pageYOffset + yOffset;
        window.scrollTo({ top: y, behavior: 'smooth' });
      }
    }
  };

  return (
    <div id="city-tabs-container" className="city-tabs-wrapper">
      {/* 雙子星旗艦頁籤切換列 */}
      <div className="city-tabs-nav" role="tablist" aria-label="服務城市切換">
        {tabs.map((tab) => {
          const isActive = activeCity === tab.id;
          return (
            <button
              key={tab.id}
              type="button"
              role="tab"
              aria-selected={isActive}
              aria-controls={`panel-${tab.id}`}
              id={`tab-${tab.id}`}
              className={`city-tab-btn ${isActive ? 'active' : 'inactive'} ${tab.id}`}
              onClick={() => handleSelectTab(tab.id, tab.anchorId)}
            >
              <div className="tab-icon-box">
                <span className="tab-icon-emoji">{tab.icon}</span>
              </div>
              <div className="tab-text-group">
                <div className="tab-title-row">
                  <span className="tab-title">{tab.name}</span>
                  <span className="tab-count-badge">{tab.count} 個行政區</span>
                </div>
                <div className="tab-sub">{tab.subText}</div>
              </div>
              <div className="tab-active-indicator" />
            </button>
          );
        })}
      </div>

      {/* 城市內容面板：所有城市 DOM 均 100% 存在於靜態 HTML 中，SEO 完全無損 */}
      <div className="city-tabs-content">
        {tabs.map((tab) => {
          const isActive = activeCity === tab.id;
          return (
            <div
              key={tab.id}
              role="tabpanel"
              id={`panel-${tab.id}`}
              aria-labelledby={`tab-${tab.id}`}
              className={`city-tab-pane ${isActive ? 'active' : 'hidden'}`}
            >
              {tab.content}
            </div>
          );
        })}
      </div>
    </div>
  );
}
