import type { Metadata } from 'next';
import Link from 'next/link';
import {
  getLocationCoverageSummary,
  getLocationPagesByIds,
  locationPages,
} from '@/data/locationPages';
import { absoluteUrl, buildCalculatorUrl, buildOgTwitterMeta } from '@/lib/seo';
import { withBasePath } from '@/lib/base-path';
import { ChevronRight, MapPin, Calculator, Building2, GraduationCap, TrainFront, Mountain, type LucideIcon } from 'lucide-react';
import EditorialLandingHero from '@/components/EditorialLandingHero';

const locationCoverage = getLocationCoverageSummary();
const HUB_TITLE = `服務區域總覽｜雙北 ${locationCoverage.administrativeAreaCount} 個行政區與 ${locationCoverage.cityOverviewCount} 個市級總覽`;
const HUB_DESCRIPTION = `一次查看宏森窗簾在台北與新北 ${locationCoverage.administrativeAreaCount} 個行政區及 ${locationCoverage.cityOverviewCount} 個市級總覽，共 ${locationCoverage.indexableLocationPageCount} 個可索引地區服務入口。`;

export const metadata: Metadata = {
  title: HUB_TITLE,
  description: HUB_DESCRIPTION,
  keywords: ['台北窗簾服務區域', '新北窗簾服務區域', '窗簾到府丈量', '窗簾地區頁索引'],
  ...buildOgTwitterMeta({
    title: HUB_TITLE,
    description: HUB_DESCRIPTION,
    path: '/location/',
    image: '/banner_img/banner_01.webp',
    imageAlt: '宏森窗簾地區服務總覽',
  }),
};

const locationThumbMap: Record<string, string> = {
  sanchong: '/Construction Cases_img/LINE_ALBUM_20240813三重介壽路-蛇形簾_260414_1.webp',
  banqiao: '/Construction Cases_img/LINE_ALBUM_20240429板橋中正路379巷-捲簾_260414_1.webp',
  daan: '/banner_img/banner_01.webp',
  xinyi: '/Construction Cases_img/LINE_ALBUM_民生東路三段-直立簾_260414_1.webp',
  zhongshan: '/Construction Cases_img/LINE_ALBUM_中山北路二段_260414_1.webp',
  xinzhuang: '/Construction Cases_img/LINE_ALBUM_新莊中正路-窗簾_260414_1.webp',
  neihu: '/Construction Cases_img/LINE_ALBUM_20240628內湖金豐街-布簾及調光簾_260414_1.webp',
  zhonghe: '/Construction Cases_img/LINE_ALBUM_中和建八路-鋁百葉_260414_1.webp',
  yonghe: '/Construction Cases_img/LINE_ALBUM_永福街-調光簾、捲簾、浴百葉_260414_1.webp',
  luzhou: '/Construction Cases_img/LINE_ALBUM_蘆洲水湳街_260414_1.webp',
  xindian: '/Construction Cases_img/LINE_ALBUM_新店中央四街_260414_1.webp',
  linkou: '/Construction Cases_img/LINE_ALBUM_林口遠雄未來城_260414_1.webp',
  shulin: '/Construction Cases_img/LINE_ALBUM_20240802樹林佳園路三段-拉門_260414_1.webp',
  songshan: '/Construction Cases_img/LINE_ALBUM_2025227松隆路捲簾導軌_260414_1.webp',
  zhongzheng: '/Construction Cases_img/LINE_ALBUM_20240530北市南昌路一段-醫院隔簾_260414_1.webp',
  taipei: '/about_img/about_01.webp',
  'new-taipei': '/Construction Cases_img/LINE_ALBUM_疏洪西路（蛇型簾+一般紗）_260414_2.webp',
  shilin: '/images/P001_curtain.webp',
  beitou: '/images/P007_Log blinds.webp',
  nangang: '/images/P005_roller blind.webp',
  wenshan: '/images/P010_dimming curtain.webp',
  wanhua: '/images/P004_Roman blind.webp',
  datong: '/images/P006_Aluminum blinds.webp',
  tucheng: '/images/P009_accordion curtain.webp',
  xizhi: '/images/P005_roller blind02.webp',
  taishan: '/images/P010_dimming curtain02.webp',
  wugu: '/images/P006_Aluminum blinds02.webp',
  yingge: '/images/P008_Bamboo curtain.webp',
  sanxia: '/images/P001_curtain02.webp',
  danshui: '/images/P011_Soft gauze curtains.webp',
  bali: '/images/P003_Snake curtain.webp',
};

interface ClusterSection {
  key: string;
  title: string;
  desc: string;
  ids: readonly string[];
  icon: LucideIcon;
  iconColor: string;
}

interface CityGroupDef {
  cityId: string;
  anchorId: string;
  badgeText: string;
  subText: string;
  themeClass: 'taipei' | 'new-taipei';
  tagText: string;
  heroDesc: string;
  sections: ClusterSection[];
}

const cityGroups: CityGroupDef[] = [
  {
    cityId: 'taipei',
    anchorId: 'taipei-city',
    badgeText: `🏛️ 台北市服務網絡 ｜ 涵蓋 ${locationCoverage.taipeiAdministrativeAreaCount} 個行政區`,
    subText: '豪宅聚落・景觀高窗・文教學區，台北全區免費專人攜帶布樣到府丈量',
    themeClass: 'taipei',
    tagText: '✨ 台北都會核心 旗艦總覽',
    heroDesc: '整合信義、大安、士林等全區豪宅、學區與商業空間。30 年工廠直營工班到府精準丈量，提供蛇形簾、調光簾與木百葉等全系列產品客製規劃。',
    sections: [
      {
        key: 'taipei-metro-core',
        title: '台北都會核心圈｜旗艦生活圈（4 區）',
        desc: '台北主要商業、行政與豪宅精華區，提供雙層蛇形簾、大面採光高窗與精品調光簾方案。',
        ids: ['daan', 'xinyi', 'songshan', 'zhongshan'],
        icon: Building2,
        iconColor: '#b45309',
      },
      {
        key: 'taipei-scenic-edu',
        title: '台北景觀與文教生活圈｜8 區到府丈量',
        desc: '涵蓋天母豪宅、學區公寓、山景別墅與文創街區，兼顧通風防潮、採光柔化與夜間隱私。',
        ids: ['zhongzheng', 'shilin', 'beitou', 'neihu', 'nangang', 'wenshan', 'wanhua', 'datong'],
        icon: GraduationCap,
        iconColor: '#4f46e5',
      },
    ],
  },
  {
    cityId: 'new-taipei',
    anchorId: 'new-taipei-city',
    badgeText: `🏙️ 新北市服務網絡 ｜ 涵蓋 ${locationCoverage.newTaipeiAdministrativeAreaCount} 個行政區`,
    subText: '三重直營工班・捷運大城・景觀重劃區，快速到府丈量與廠辦合一透明價',
    themeClass: 'new-taipei',
    tagText: '🏭 三重在地工廠 在地直營',
    heroDesc: '宏森廠辦深耕新北，從板橋、三重核心捷運圈到林口、淡水海線景觀宅，皆享工班直營快速到府服務與遮光布簾、調光簾即時線上試算。',
    sections: [
      {
        key: 'newtaipei-core-mrt',
        title: '新北核心大城與捷運生活圈｜8 區快速估價',
        desc: '高密度住宅生活圈，廠辦合一快速到府，客廳落地窗簾、遮光捲簾與百葉窗熱門比價。',
        ids: ['sanchong', 'banqiao', 'xinzhuang', 'zhonghe', 'yonghe', 'luzhou', 'tucheng', 'xindian'],
        icon: TrainFront,
        iconColor: '#0f766e',
      },
      {
        key: 'newtaipei-extended-scenic',
        title: '新北延伸與景觀生活圈｜9 區到府丈量',
        desc: '涵蓋林口高樓住宅、海線河岸景觀宅、山城透天與廠辦園區，強化隔熱、抗西曬與耐用度。',
        ids: ['linkou', 'xizhi', 'taishan', 'wugu', 'shulin', 'yingge', 'sanxia', 'danshui', 'bali'],
        icon: Mountain,
        iconColor: '#0284c7',
      },
    ],
  },
];

export default function LocationHubPage() {
  const renderedCityGroups = cityGroups.map(group => {
    const heroPage = locationPages.find(p => p.id === group.cityId);
    const sections = group.sections.map(sec => ({
      ...sec,
      pages: getLocationPagesByIds(sec.ids),
    }));
    return {
      ...group,
      heroPage,
      sections,
    };
  });

  const locationItemListId = `${absoluteUrl('/location/')}#service-area-list`;
  const locationHubSchema = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'CollectionPage',
        '@id': `${absoluteUrl('/location/')}#collection`,
        url: absoluteUrl('/location/'),
        name: HUB_TITLE,
        description: HUB_DESCRIPTION,
        inLanguage: 'zh-TW',
        mainEntity: { '@id': locationItemListId },
      },
      {
        '@type': 'ItemList',
        '@id': locationItemListId,
        name: `雙北 ${locationCoverage.administrativeAreaCount} 個行政區與 ${locationCoverage.cityOverviewCount} 個市級總覽`,
        numberOfItems: locationCoverage.indexableLocationPageCount,
        itemListElement: locationPages.map((page, index) => ({
          '@type': 'ListItem',
          position: index + 1,
          name: page.title,
          url: absoluteUrl(`/location/${page.id}/`),
        })),
      },
      {
        '@type': 'BreadcrumbList',
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: '首頁', item: absoluteUrl('/') },
          { '@type': 'ListItem', position: 2, name: '服務區域總覽', item: absoluteUrl('/location/') },
        ],
      },
    ],
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(locationHubSchema) }} />

      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>›</span>
          <span>服務區域總覽</span>
        </div>
      </nav>

      <EditorialLandingHero
        theme="location"
        eyebrow="📍 大台北 GEO 樞紐"
        title={`台北與新北 ${locationCoverage.administrativeAreaCount} 區行政區服務入口`}
        description={`宏森 30 年工廠直營工班，整合台北與新北 ${locationCoverage.administrativeAreaCount} 個行政區及 ${locationCoverage.cityOverviewCount} 個市級總覽，提供現場精準丈量、同尺寸多材質透明比價與正式報價。`}
        desktopImage="/location_img/location-hero-desktop.webp"
        mobileImage="/location_img/location-hero-mobile.webp"
        imageAlt="雙北窗簾服務區域形象示意：自然採光客廳的窗簾搭配"
        primaryAction={{ href: '/products/', label: '先看全部產品' }}
        secondaryAction={{ href: buildCalculatorUrl(), label: '前往線上估價' }}
      />

      <section className="location-city-jump-strip" aria-label="服務地點快速入口">
        <div className="city-jump-nav">
          <a href="#taipei-city" className="city-jump-btn taipei">
            🏛️ 台北市服務區 往下捲動 ↓
          </a>
          <a href="#new-taipei-city" className="city-jump-btn new-taipei">
            🏙️ 新北市服務區 往下捲動 ↓
          </a>
        </div>
      </section>

      <section className="py-section bg-stone-50 border-t border-stone-200">
        <div className="section-container">
          {renderedCityGroups.map((cityGroup) => {
            const hero = cityGroup.heroPage;
            return (
              <div
                key={cityGroup.cityId}
                id={cityGroup.anchorId}
                className={`city-overview ${cityGroup.themeClass}`}
                style={{ scrollMarginTop: '90px' }}
              >
                {/* 城市服務整合卡：左側實景、右側城市資訊與行動入口 */}
                {hero && (
                  <div className="metro-dual-card-container">
                    {/* 左卡：景觀情境圖片卡 */}
                    <div className="metro-image-card">
                      <img
                        src={withBasePath(locationThumbMap[hero.id] || hero.heroImage)}
                        alt={`${hero.areaName}窗簾旗艦服務`}
                        title={`${hero.areaName}窗簾推薦`}
                        loading="lazy"
                      />
                      <span className="metro-image-card-badge">
                        <MapPin size={13} />
                        {hero.id === 'taipei' ? '台北市全區窗簾旗艦' : '新北市全區窗簾旗艦'}
                      </span>
                    </div>

                    {/* 右卡：城市標題、服務摘要與操作按鈕 */}
                    <div className="metro-content-card">
                      <span className="metro-content-tag">{cityGroup.tagText}</span>
                      <h2 className="metro-content-title">{cityGroup.badgeText}</h2>
                      <p className="metro-content-lead">{cityGroup.subText}</p>
                      <p className="metro-content-desc">{cityGroup.heroDesc}</p>
                      <div className="metro-content-actions">
                        <Link
                          href={`/location/${hero.id}/`}
                          className="btn-primary"
                          style={{
                            background: 'var(--amber-700)',
                            padding: '0.55rem 1.25rem',
                            fontSize: '0.88rem',
                          }}
                        >
                          查看{hero.areaName}全區專頁 <ChevronRight size={14} />
                        </Link>
                        <Link
                          href={buildCalculatorUrl(undefined, hero.id)}
                          className="btn-outline"
                          style={{
                            padding: '0.55rem 1.25rem',
                            fontSize: '0.88rem',
                          }}
                        >
                          <Calculator size={14} style={{ display: 'inline', marginRight: '0.25rem' }} />
                          {hero.areaName}線上估價
                        </Link>
                      </div>
                    </div>
                  </div>
                )}

                {/* 3. 該城市底下的生活圈與行政區小卡網格 */}
                {cityGroup.sections.map(section => {
                  const SectionIcon = section.icon;

                  return (
                    <div key={section.key} className="location-cluster" style={{ marginBottom: '2rem' }}>
                      <div className="location-cluster-header">
                        <h2>
                          <SectionIcon size={30} aria-hidden="true" style={{ color: section.iconColor }} />
                          <span>{section.title}</span>
                        </h2>
                        <p>{section.desc}</p>
                      </div>

                      <div className="location-cluster-grid">
                        {section.pages.map(page => {
                          const thumb = locationThumbMap[page.id] || page.heroImage || '/banner_img/banner_01.webp';
                          return (
                            <article key={page.id} className="location-hub-card">
                            <div className="location-hub-thumb">
                              <img
                                src={withBasePath(thumb)}
                                alt={`${page.areaName}窗簾施工與到府丈量`}
                                title={`${page.areaName}窗簾服務`}
                                loading="lazy"
                              />
                            </div>
                            <div className="location-hub-body">
                              <h3 className="location-hub-title">
                                <MapPin
                                  size={15}
                                  style={{
                                    display: 'inline',
                                    color: 'var(--amber-600)',
                                    verticalAlign: 'middle',
                                    marginRight: '0.25rem',
                                  }}
                                />
                                {page.areaName}窗簾服務
                              </h3>
                              <p className="location-hub-desc">{page.shortDescription}</p>
                              <div className="location-hub-actions">
                                <Link href={`/location/${page.id}/`} className="btn-outline">
                                  查看地區頁
                                </Link>
                                <Link
                                  href={buildCalculatorUrl(undefined, page.id)}
                                  className="btn-primary"
                                  style={{ background: 'var(--amber-700)' }}
                                >
                                  <Calculator size={13} style={{ display: 'inline', marginRight: '0.2rem' }} />
                                  帶入估價
                                </Link>
                              </div>
                            </div>
                            </article>
                          );
                        })}
                      </div>
                    </div>
                  );
                })}
              </div>
            );
          })}
        </div>
      </section>
    </>
  );
}
