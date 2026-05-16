import Link from 'next/link';
import { Phone, Mail, MapPin, Clock, ChevronRight } from 'lucide-react';
import { CATALOG_URL } from '@/lib/seo';

export default function Footer() {
  return (
    <footer className="site-footer" id="contact">
      <div className="footer-inner">
        <div className="footer-grid">
          {/* Brand */}
          <div className="footer-brand">
            <h3>宏森開發有限公司</h3>
            <p>
              自1996年起，專營窗簾相關產品訂做與精緻施工。工廠直營提供最實惠價格，服務住家、辦公室、商業空間及公家機關，是您美化居家生活最值得信賴的好伙伴。
            </p>
            <a
              href={CATALOG_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="footer-btn"
            >
              前往官方網站
              <ChevronRight size={16} />
            </a>
          </div>

          {/* Contact */}
          <div className="footer-col">
            <h4>聯絡資訊</h4>
            <ul>
              <li>
                <Phone size={16} className="footer-icon" />
                <div>
                  <div>02-8972-7322</div>
                  <div style={{ fontSize: '0.8rem', color: 'var(--stone-500)', marginTop: '0.25rem' }}>傳真: 02-8972-1866</div>
                  <div style={{ fontSize: '0.8rem', color: 'var(--stone-500)' }}>台哥大: 0980-113006</div>
                  <div style={{ fontSize: '0.8rem', color: 'var(--stone-500)' }}>台哥大2: 0973-808799</div>
                </div>
              </li>
              <li>
                <Mail size={16} className="footer-icon" />
                <a href="mailto:andy5003@hong-sen.com">andy5003@hong-sen.com</a>
              </li>
            </ul>
          </div>

          {/* Location & Hours */}
          <div className="footer-col">
            <h4>營業時間與地址</h4>
            <ul>
              <li>
                <Clock size={16} className="footer-icon" />
                <div>
                  <div>周一 ~ 周六</div>
                  <div>09:00 ~ 12:00</div>
                  <div>13:30 ~ 18:00</div>
                  <div style={{ fontSize: '0.8rem', color: 'var(--stone-500)', marginTop: '0.25rem' }}>※ 請於上班時間來電預約</div>
                </div>
              </li>
              <li>
                <MapPin size={16} className="footer-icon" />
                <div>
                  <div>新北市三重區仁愛街125巷89號1樓</div>
                  <div style={{ fontSize: '0.8rem', color: 'var(--stone-500)', marginTop: '0.25rem' }}>（請由龍門路進入仁愛街）</div>
                </div>
              </li>
            </ul>
          </div>

          {/* SEO Navigation */}
          <div className="footer-col">
            <h4>服務區域與選購指南</h4>
            <ul style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
              <li><Link href="/location/taipei" className="seo-link">📍 台北市窗簾推薦</Link></li>
              <li><Link href="/location/sanchong" className="seo-link">📍 三重區窗簾推薦</Link></li>
              <li><Link href="/location/daan" className="seo-link">📍 大安區窗簾推薦</Link></li>
              <li><Link href="/location/zhongshan" className="seo-link">📍 中山區窗簾推薦</Link></li>
              <li><Link href="/location/shilin" className="seo-link">📍 士林區窗簾推薦</Link></li>
              <li><Link href="/location/neihu" className="seo-link">📍 內湖區窗簾推薦</Link></li>
              <li><Link href="/curtain/blackout" className="seo-link">📖 遮光窗簾挑選指南</Link></li>
              <li><Link href="/curtain/living-room" className="seo-link">📖 客廳窗簾挑選攻略</Link></li>
            </ul>
            <style>{`
              .seo-link { color: var(--stone-300); text-decoration: none; transition: color 0.2s; }
              .seo-link:hover { color: white; }
            `}</style>
          </div>
        </div>

        <div className="footer-bottom">
          <p>© {new Date().getFullYear()} 宏森開發有限公司. All rights reserved. |{' '}
            <Link href="/products">產品系列</Link> |{' '}
            <Link href="/calculator">線上估價</Link> |{' '}
            <Link href="/cases">施工案例</Link> |{' '}
            <Link href="/blog">窗簾知識</Link>
          </p>
        </div>
      </div>
    </footer>
  );
}
