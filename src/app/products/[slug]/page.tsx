import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import { findProductBySlugOrId, products } from '@/data/products';
import { getServiceAreasForProduct } from '@/data/locationPages';
import { absoluteUrl, buildCalculatorUrl, COMPANY_NAME, productPath } from '@/lib/seo';
import { withBasePath } from '@/lib/base-path';
import { ChevronRight, CheckCircle2, Calculator, Star, BookOpen } from 'lucide-react';
import ProductScrollMenu from '@/components/ProductScrollMenu';
import ProductImageGallery from '@/components/ProductImageGallery';

// SSG: generate paths for all products
export async function generateStaticParams() {
  return [
    ...products.map(p => ({ slug: p.slug })),
    ...products.map(p => ({ slug: p.id })),
  ];
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const product = findProductBySlugOrId(slug);
  if (!product) return { title: '找不到產品' };

  const seo = (product as any).seo;
  return {
    title: seo?.meta_title || `${product.name} 訂製 | 宏森開發`,
    description: seo?.meta_description || product.description,
    keywords: [...(seo?.keywords || []), product.primaryKeyword, ...product.secondaryKeywords],
    alternates: { canonical: absoluteUrl(productPath(product)) },
    openGraph: {
      title: seo?.meta_title || product.name,
      description: seo?.meta_description || product.description,
      url: absoluteUrl(productPath(product)),
      images: [{ url: absoluteUrl(product.image), alt: product.image_alt || product.name }],
    },
  };
}

// Product-specific rich content
const productDetails: Record<string, { features: string[]; useCases: string[]; fullDesc: string }> = {
  P001: {
    features: ['優異遮光效果', '良好隔音性能', '多種布料與花色選擇', '耐洗耐用'],
    useCases: ['臥室', '客廳', '辦公室'],
    fullDesc: '窗簾訂製價格先從同一尺寸開始比較布料、遮光等級、軌道與基本安裝費；想知道做窗簾價格，可先線上估價，再由到府丈量確認正式報價。一般布簾兼顧遮光、隔音與垂墜感，適合客廳主窗、臥室與書房的訂製需求。',
  },
  P002: {
    features: ['無縫設計、視覺更純淨', '透光不透人的遮蔽效果', '輕薄飄逸，極具美感', '適合搭配遮光布簾使用'],
    useCases: ['客廳', '餐廳', '書房'],
    fullDesc: '透光不透人紗簾價格先固定同一尺寸，比較無縫紗簾、雙層搭配、軌道、窗高與基本安裝費；可先線上估價，再安排到府看樣與丈量。無縫紗簾兼顧白天採光、隱私與空間通透感，適合客廳、書房與落地窗。',
  },
  P003: {
    features: ['獨特 S 型曲線設計', '布料垂墜感極佳', '適合落地窗使用', '展現現代奢華風格'],
    useCases: ['客廳落地窗', '主臥室', '高端商業空間'],
    fullDesc: '蛇形窗簾是以專用軌道與等距吊掛配件形成規律 S 型波浪的布簾做法，適合想讓客廳落地窗保有整齊垂墜與一致摺距的空間。若主要需求是葉片調光或左右收合方式，應另比較直立簾；實際波浪密度、布量、窗簾盒與軌道條件仍需在丈量後確認。',
  },
  P004: {
    features: ['層次分明的摺疊設計', '收起時佔空間小', '多種布料選擇', '適合小窗與多窗格'],
    useCases: ['小窗', '廚房', '衛浴', '書房'],
    fullDesc: '羅馬簾以水平折疊的方式展開或收合，展開時布料平整且有層次感，收起時整齊利落不佔空間。羅馬簾特別適合不適合安裝傳統窗簾的空間，如窗戶較小、窗格較多的情況。選材豐富，從輕薄透光到厚重遮光布料皆有。',
  },
  P005: {
    features: ['操作簡單直覺', '不佔空間', '防潑水特性', '適合浴室廚房'],
    useCases: ['辦公室', '廚房', '浴室', '書房'],
    fullDesc: '捲簾價格試算怎麼看最快？建議先固定同一尺寸，比較透光捲簾、半遮光捲簾與全遮光捲簾，再看捲簾安裝價格、遮光需求與使用空間。捲簾是租屋、辦公室、廚房與書房最容易快速評估的入門款式，整片布料圍繞頂部卷軸收合，不佔窗框空間，操作直覺且好清潔。',
  },
  P006: {
    features: ['鋁合金材質堅固耐用', '精確調光', '防潮耐洗', '現代簡約外觀'],
    useCases: ['衛浴', '廚房', '辦公室'],
    fullDesc: '百葉窗價格試算若以防潮與好清潔為優先，先鎖定鋁百葉的葉片寬度、窗型與基本安裝費，再用同一尺寸線上估價確認鋁百葉窗價格。鋁百葉可精準調光且防潮耐洗，適合浴室、廚房、商辦與需要高頻清潔的小窗；重視木質感時，再比較實木百葉專頁。',
  },
  P007: {
    features: ['天然木材質感溫潤', '提升空間高級感', '自然紋理獨一無二', '多種木種與色系'],
    useCases: ['客廳', '書房', '餐廳'],
    fullDesc: '實木百葉窗價格試算應先固定同一組窗戶尺寸，再比較木種、葉片寬度、表面塗裝、窗型與基本安裝費；可用線上估價確認木百葉窗簾價格，再由到府丈量確認正式報價。實木百葉適合客廳、書房與重視木質感的乾燥空間；浴室、廚房等高濕環境則應改看鋁百葉價格試算。',
  },
  P008: {
    features: ['古樸東方韻味', '透氣性極佳', '輕盈自然材質', '環保天然'],
    useCases: ['日式空間', '禪風書房', '餐廳'],
    fullDesc: '竹簾訂製建議先固定同一組尺寸，再比較編織密度、透光程度、竹簾價格、安裝位置與保養方式。竹簾以天然竹材編織而成，光線穿過竹條後會變得柔和，並保留良好通風效果，特別適合和室窗簾、日式窗簾、茶室與注重自然感的書房或餐廳。',
  },
  P009: {
    features: ['蜂巢結構隔熱效果顯著', '節能省電', '隔音效果佳', '輕薄美觀'],
    useCases: ['客廳', '臥室', '節能住宅'],
    fullDesc: '風琴簾價格試算先比較蜂巢簾隔熱、透光等級、蜂巢層數與基本安裝費，再用同尺寸線上估價抓預算。風琴簾的中空蜂巢結構適合西曬窗、臥室控溫與高窗；確認需求後再安排到府丈量。',
  },
  P010: {
    features: ['斑馬紋雙層交錯設計', '靈活切換透光/隱私模式', '現代時尚外觀', '操作便利'],
    useCases: ['客廳', '臥室', '辦公室'],
    fullDesc: '調光簾價格試算怎麼比最快？建議先固定同一尺寸，比較條紋寬度、遮光等級與安裝費，再看客廳或臥室的日夜控光需求。調光簾（斑馬簾）採雙層交錯條紋，可在透光與隱私模式間快速切換，特別適合需要日夜不同採光設定的客廳、臥室與新莊副都心景觀宅。',
  },
  P011: {
    features: ['葉片懸浮於兩層紗布間', '柔化自然光線', '兼顧隱私與採光', '精品住宅質感'],
    useCases: ['主臥', '客廳', '精品住宅', '飯店'],
    fullDesc: '柔紗簾價格試算建議先固定同一尺寸，再比較葉片角度、透光柔化、夜間隱私與安裝費。它的葉片懸浮於兩層輕薄紗布之間，光線穿透後比調光簾更柔和，適合主臥、客廳與精品住宅想保留自然採光，又希望視覺更精緻的空間。',
  },
  P012: {
    features: ['防焰規格可依材料文件確認', '抗菌規格需依選用布料確認', '頂部通風網可依場域需求配置', '洗滌方式依材料標示確認'],
    useCases: ['醫院', '診所', '護理之家', '公家機關'],
    fullDesc: '醫院隔簾價格通常先看隔簾尺寸、軌道長度、頂部通風網、施工時段與實際材料規格。醫療院所若要求防焰、抗菌或耐洗條件，必須針對選用布料核對標示與供應商文件。建議先用同尺寸抓價格區間，再安排現場丈量確認軌道、吊掛高度與正式報價。',
  },
  P013: {
    features: ['垂直葉片左右收合', '180 度葉片轉向調光', '適合大型落地窗', '線條俐落現代感'],
    useCases: ['大型落地窗', '辦公室', '商業空間'],
    fullDesc: '直立簾以垂直懸掛葉片組成，可左右收合並旋轉葉片調整採光與隱私。直立線條適合寬幅落地窗或辦公空間；遮光程度仍取決於葉片材質、重疊量與安裝縫隙。',
  },
};

// Per-product extended SEO data
const productSeoExtras: Record<string, {
  priceTable: { label: string; range: string }[];
  lsiParagraph: string;
  relatedBlogIds: string[];
}> = {
  P001: {
    priceTable: [
      { label: '窗簾訂製價格試算：標準半腰窗 (150×150 cm)', range: '約 NT$ 1,800 – 2,800 起' },
      { label: '訂製窗簾價格：標準落地窗 (200×240 cm)', range: '約 NT$ 3,500 – 5,500 起' },
      { label: '做窗簾價格與基本安裝 (300×240 cm)', range: '約 NT$ 5,000 – 8,000 起' },
    ],
    lsiParagraph: '窗簾訂製價格若想抓得準，通常要先釐清空間用途、遮光程度、布料手感、雙層需求與安裝條件。一般布簾（cloth curtains）是台灣居家最普及的窗簾選擇，適用於客廳落地窗、主臥室、書房及辦公室。若你正在比較做窗簾價格、訂製窗簾價格、窗簾訂做價格、遮光窗簾與客廳布簾，重點不只在布料本身，也包含軌道長度、雙層配置、基本安裝費、安裝高度與是否需要窗簾盒修飾。相較於捲簾或百葉窗，布簾更能展現空間的溫馨氛圍與個人風格。若您在三重、板橋、內湖或樹林尋找窗簾訂製與遮光窗簾服務，建議先做線上估價，再安排到府丈量與樣本挑選。',
    relatedBlogIds: ['blog-001', 'blog-002'],
  },
  P002: {
    priceTable: [
      { label: '紗簾價格試算：標準半腰窗 (150×150 cm)', range: '約 NT$ 1,200 – 2,000 起' },
      { label: '透光不透人紗簾價格：落地窗 (200×240 cm)', range: '約 NT$ 2,200 – 3,800 起' },
      { label: '雙層窗簾搭配、軌道與基本安裝費', range: '依軌道、窗高與遮光層確認' },
    ],
    lsiParagraph: '無縫紗簾是近年來很受歡迎的透光不透人紗簾款式，尤其適合想保留自然光、又不希望白天室內被一眼看穿的家庭。若你正在比較紗簾價格、透光不透人紗簾、紗簾推薦、雙層窗簾搭配或客廳紗簾價格，重點不只在布料本身，也包含軌道長度、垂墜高度、基本安裝費、是否搭配遮光布簾與現場安裝條件。建議先確認想要的採光感，再做紗簾價格試算，整體報價會更接近實際需求。',
    relatedBlogIds: ['blog-001'],
  },
  P003: {
    priceTable: [
      { label: '蛇形軌道半腰窗 (150×150 cm)', range: '約 NT$ 2,800 – 4,500 起' },
      { label: '蛇形軌道落地窗 (200×240 cm)', range: '約 NT$ 5,000 – 8,000 起' },
      { label: '大型落地窗 (300×240 cm)', range: '約 NT$ 7,500 – 12,000 起' },
    ],
    lsiParagraph: '蛇形窗簾（S-fold curtains）是客廳落地窗常見的 S 型布簾做法，透過專用軌道與等距吊掛配件形成規律曲線。若你在比較蛇形簾、S 型窗簾、客廳窗簾或落地窗窗簾，先確認希望的是布料垂墜與固定摺距，還是葉片調光；後者可改看直立簾。規劃時要一起確認窗幅、布量、波浪密度、窗簾盒深度與軌道固定面；線上內容只能協助理解差異，最後仍以現場丈量與材料確認為準。',
    relatedBlogIds: ['blog-001'],
  },
  P004: {
    priceTable: [
      { label: '小型窗羅馬簾 (60×100 cm)', range: '約 NT$ 1,500 – 2,500 起' },
      { label: '標準窗羅馬簾 (120×150 cm)', range: '約 NT$ 2,500 – 4,000 起' },
    ],
    lsiParagraph: '羅馬簾（Roman Shade）以水平折疊方式收合，適合小窗、多窗格或希望減少左右收納空間的情境。材質、透光程度、防潮需求與操作方式都要依安裝位置確認；廚房或衛浴使用時，應先核對所選布料的清潔與耐濕條件。',
    relatedBlogIds: ['blog-001'],
  },
  P005: {
    priceTable: [
      { label: '捲簾價格試算 (80×150 cm)', range: '約 NT$ 800 – 1,500 起' },
      { label: '遮光捲簾價格試算 (150×180 cm)', range: '約 NT$ 1,500 – 2,800 起' },
      { label: '捲簾安裝價格與辦公室大型窗 (200×200 cm)', range: '約 NT$ 2,800 – 5,000 起' },
    ],
    lsiParagraph: '捲簾價格試算若想抓得快，通常先比透光捲簾、半遮光捲簾與全遮光捲簾，再看布料等級、透光係數與安裝條件。捲簾（Roll Screen）整體結構簡潔、清潔便利，是辦公室、租屋與住宅都常見的高 CP 值選擇。若你正在比較捲簾價格試算、捲簾安裝價格、台北捲簾價格、三重捲簾價格或新莊捲簾估價，建議先用窗簾計算機完成初步試算，再搭配現場丈量確認五金與施工細節，正式窗簾報價會更精準。',
    relatedBlogIds: ['blog-001'],
  },
  P006: {
    priceTable: [
      { label: '百葉窗價格試算 (80×120 cm)', range: '約 NT$ 1,200 – 2,000 起' },
      { label: '鋁百葉窗價格試算 (150×180 cm)', range: '約 NT$ 2,200 – 3,500 起' },
      { label: '百葉窗簾價格與基本安裝', range: '依葉片寬度、窗型與施工條件確認' },
    ],
    lsiParagraph: '百葉窗價格試算若想抓得準，通常要先固定同一組尺寸比較鋁百葉、實木百葉與風琴簾，再判斷防潮、清潔便利與隔熱需求。百葉窗簾價格、百葉窗價格、鋁百葉窗價格與三重、板橋、內湖、樹林常見安裝情境，通常會因葉片寬度、烤漆等級、窗型與安裝位置而有差異。鋁百葉窗簾（Venetian Blind）以鋁合金葉片為核心，具備防潮、防水、好清潔特性，特別適合浴室、廚房、商辦小窗與需要高頻清潔的工作空間。若想先抓預算，建議先用窗簾估價工具輸入尺寸，再由現場丈量確認細節，正式窗簾報價會更精準。',
    relatedBlogIds: ['blog-001'],
  },
  P007: {
    priceTable: [
      { label: '木百葉窗簾價格 (80×120 cm)', range: '約 NT$ 2,500 – 4,500 起' },
      { label: '木百葉窗簾價格 (150×180 cm)', range: '約 NT$ 4,500 – 8,000 起' },
      { label: '實木百葉窗價格試算 (200×180 cm)', range: '約 NT$ 6,500 – 11,000 起' },
      { label: '三重 / 台北到府丈量與基本安裝', range: '依窗型與施工條件確認' },
    ],
    lsiParagraph: '實木百葉窗價格試算是否合理，通常取決於木種、葉片寬度、表面塗裝、窗型、配件與安裝高度。台北實木百葉窗價格、板橋實木百葉窗價格與中正區常見丈量情境不一定完全相同，重點在窗型、基本安裝費與施工條件是否一致。建議先用窗簾計算機以同尺寸試算木百葉，再查看台北、板橋與中正區地區頁的丈量流程，最後由現場確認五金規格與施工條件，讓木百葉窗簾價格與正式報價更貼近。',
    relatedBlogIds: ['blog-001'],
  },
  P008: {
    priceTable: [
      { label: '竹簾訂製 (90×150 cm)', range: '約 NT$ 1,500 – 2,500 起' },
      { label: '和室窗簾竹簾 (150×180 cm)', range: '約 NT$ 2,800 – 4,500 起' },
      { label: '日式窗簾現場丈量與安裝', range: '依編織密度、窗型與安裝位置確認' },
    ],
    lsiParagraph: '竹簾（Bamboo Blind）適合想保留通風、自然材質與柔和採光的空間。若你正在比較竹簾、竹簾訂製、和室窗簾、日式窗簾或竹簾價格，建議先確認編織密度、透光程度、室內濕度與安裝位置，再決定是否搭配布簾做雙層配置。宏森使用優質原竹材料，提供多種編織密度選擇，兼顧遮蔽效果、自然感與日常清潔。',
    relatedBlogIds: ['blog-001'],
  },
  P009: {
    priceTable: [
      { label: '風琴簾價格試算 (120×150 cm)', range: '約 NT$ 3,500 – 6,000 起' },
      { label: '蜂巢簾價格試算 (200×240 cm)', range: '約 NT$ 6,000 – 10,000 起' },
    ],
    lsiParagraph: '風琴簾價格試算時，除了尺寸，透光等級、蜂巢層數與控制配件也會影響最終金額。風琴簾（蜂巢簾，Honeycomb Shade）利用中空結構減少熱傳導，對西曬窗、士林透天高窗、新莊景觀宅與臥室控溫特別有感。若你正在比較台北風琴簾價格、三重風琴簾價格、蜂巢簾價格試算或新莊蜂巢簾估價，建議先用窗簾計算機做初步估價，再安排到府丈量確認安裝條件，窗簾報價流程會更透明。',
    relatedBlogIds: ['blog-001'],
  },
  P010: {
    priceTable: [
      { label: '調光簾 (120×150 cm)', range: '約 NT$ 2,500 – 4,500 起' },
      { label: '調光簾 (200×240 cm)', range: '約 NT$ 4,500 – 7,500 起' },
    ],
    lsiParagraph: '調光簾價格試算時，除了尺寸外，條紋密度、遮光等級與控制配件是主要差異。調光簾（Zebra Blind）能在透光與隱私之間快速切換，外觀俐落，特別適合現代住宅、商辦與新莊副都心景觀宅。若你正在比較台北調光簾價格、三重調光簾價格與新莊調光簾估價，先用窗簾計算機估價、再到府丈量，可更快確認最適規格。',
    relatedBlogIds: ['blog-001'],
  },
  P011: {
    priceTable: [
      { label: '柔紗簾價格試算 (150×210 cm)', range: '約 NT$ 4,500 – 7,500 起' },
      { label: '柔紗簾訂製落地窗 (200×240 cm)', range: '約 NT$ 6,000 – 10,000 起' },
    ],
    lsiParagraph: '柔紗簾（Sheer Shade）適合想同時保留自然光、隱私與精品住宅質感的窗型。若正在比較柔紗簾價格、柔紗簾訂製、透光窗簾或調光簾價格，建議先用同一組寬高做柔紗簾價格試算，再依葉片角度、布紗層次、窗型高度與台北大安、信義或新北住宅的安裝條件判斷正式報價。柔紗簾的清潔與耐用度也要納入預算，才不會只看單才價格而忽略後續保養。',
    relatedBlogIds: ['blog-001'],
  },
  P012: {
    priceTable: [
      { label: '醫院隔簾價格試算 (120×200 cm)', range: '約 NT$ 2,000 – 3,500 起' },
      { label: '醫療隔簾價格與軌道 (200×200 cm)', range: '約 NT$ 3,500 – 6,000 起' },
      { label: '診所隔簾、特殊材料規格與現場安裝', range: '依材料文件、軌道長度、施工時段與場域條件確認' },
    ],
    lsiParagraph: '醫院隔簾價格若要抓得準，通常要先確認隔簾寬高、軌道長度、頂部通風網、吊掛高度、施工時段與材料文件。醫療隔簾、診所隔簾與護理之家隔簾需要兼顧分區隱私、清潔、維護及院所採購條件；防焰、抗菌或耐洗規格都應以實際選用材料的文件為準。',
    relatedBlogIds: ['blog-001'],
  },
  P013: {
    priceTable: [
      { label: '直立簾 (200×210 cm)', range: '約 NT$ 3,000 – 5,500 起' },
      { label: '直立簾 (300×240 cm)', range: '約 NT$ 5,500 – 9,500 起' },
    ],
    lsiParagraph: '直立簾（Vertical Blind）由垂直葉片組成，可左右收合並旋轉葉片調整採光與隱私，適合寬幅落地窗或需要分區控光的空間。規劃時應確認葉片材質、重疊量、軌道長度、收納方向與維修方式；遮光程度仍會受材料與安裝縫隙影響。',
    relatedBlogIds: ['blog-001'],
  },
};

const defaultSeoExtras = {
  priceTable: [
    { label: '標準半腰窗', range: '約 NT$ 1,800 – 3,500 起' },
    { label: '標準落地窗', range: '約 NT$ 3,500 – 6,500 起' },
  ],
  lsiParagraph: '宏森開發有限公司提供台北市與新北市主要服務區的窗簾估價、丈量與施工諮詢。建議先用線上工具比較預算，再依實際窗型、材料、配件與施工條件確認正式報價。',
  relatedBlogIds: ['blog-001'],
};

type PriceTableRow = { label: string; range: string };

function buildReferencePriceOffer(priceTable: PriceTableRow[], url: string) {
  const ranges = priceTable.flatMap(({ range }) =>
    [...range.matchAll(/NT\$\s*([\d,]+)\s*[–-]\s*([\d,]+)/g)].map(([, low, high]) => ({
      low: Number(low.replaceAll(',', '')),
      high: Number(high.replaceAll(',', '')),
    }))
  );

  if (!ranges.length) return undefined;

  return {
    '@type': 'AggregateOffer',
    url,
    priceCurrency: 'TWD',
    lowPrice: Math.min(...ranges.map(({ low }) => low)),
    highPrice: Math.max(...ranges.map(({ high }) => high)),
    offerCount: ranges.length,
  };
}

// Per-product FAQ + extended schema data
const productV3Data: Record<string, {
  faqs: { q: string; a: string }[];
  material: string;
  colorOptions: string;
  comparisons: { feature: string; thisProduct: string; vs1: string; vs1Name: string }[];
  galleryDesc: string;
}> = {
  P001: {
    faqs: [
      { q: '做窗簾價格怎麼先抓預算？', a: '先輸入窗戶寬高，再確認遮光需求與布料風格；用同一尺寸比較客廳布簾、臥室遮光布簾、雙層窗簾、軌道與基本安裝費，最後由到府丈量確認正式報價。' },
      { q: '做窗簾價格和正式報價通常差在哪裡？', a: '線上試算會先抓布料、軌道、車工與基本安裝費，正式報價則會再看窗型、安裝高度、窗簾盒、是否拆舊與五金條件。先用同尺寸試算，再丈量確認最準。' },
      { q: '布簾可以做到完全遮光嗎？', a: '可以。選擇三層夾心的「三明治遮光布」或在布料背面加貼遮光塗層，即可達到接近 100% 的遮光效果，非常適合需要完全避光的臥室或視聽室。' },
      { q: '布簾和蛇形簾有什麼差異？', a: '一般布簾使用傳統打褶或2.5倍寬鬆比例製作，波浪較隨意自然。蛇形簾則使用專屬鉤夾讓每個波浪間距完全一致，展現高端精品感，但價格也較高。' },
      { q: '遮光窗簾價格怎麼抓比較準？', a: '建議先用同一尺寸比較一般布簾、遮光布簾與遮光捲簾，再依遮光等級、雙層需求、軌道與安裝條件判斷最適合的正式報價區間。' },
      { q: '訂製窗簾價格除了布料，還要看什麼？', a: '還要看窗型尺寸、雙層需求、軌道長度、安裝高度、窗簾盒與施工難度。這些條件會直接影響窗簾訂製價格與正式報價差異。' },
    ],
    material: '聚酯纖維、棉麻混紡、天鵝絨、三明治遮光布',
    colorOptions: '超過50種顏色選擇，提供訂製花色',
    comparisons: [
      { feature: '遮光效果', thisProduct: '★★★★★（可選全遮光）', vs1: '★★★（半透光）', vs1Name: '紗簾' },
      { feature: '布料垂墜感', thisProduct: '★★★★', vs1: '★★★★★', vs1Name: '蛇形簾' },
      { feature: '清潔難易度', thisProduct: '★★★★（可機洗）', vs1: '★★★★★（濕布輕拭）', vs1Name: '捲簾' },
      { feature: '適合小窗', thisProduct: '★★★', vs1: '★★★★★', vs1Name: '羅馬簾' },
    ],
    galleryDesc: '一般布簾客廳落地窗施工實景',
  },
  P002: {
    faqs: [
      { q: '紗簾價格和無縫紗簾推薦先看哪三件事？', a: '建議先固定同一尺寸，比較透光不透人效果、是否需要雙層窗簾搭配，以及軌道與安裝費。這樣做無縫紗簾價格試算時，會更容易判斷正式報價差異。' },
      { q: '透光不透人紗簾價格要看哪些條件？', a: '透光不透人紗簾價格主要看窗戶寬高、布料密度、軌道長度、是否做雙層窗簾與安裝條件。建議先用同尺寸比較紗簾與遮光布簾，再安排丈量確認正式報價。' },
      { q: '紗簾價格試算會包含基本安裝費嗎？', a: '會先把材料、軌道與基本安裝費放進估價區間，但正式報價仍會依窗高、軌道長度、雙層搭配與現場施工條件確認。' },
      { q: '無縫紗簾可以單獨使用嗎？', a: '可以。單獨使用時，白天採光充足、視覺通透，適合客廳或書房；若夜晚也需要完整隱私，建議搭配遮光布簾形成雙層窗簾系統。' },
      { q: '無縫紗簾和一般縫合紗簾有什麼差別？', a: '一般紗簾在拼接處會有縫合線，強光照射下較容易看出接縫。無縫紗簾採用整幅布料，視覺更乾淨，對大面窗與落地窗特別有感。' },
      { q: '無縫紗簾價格怎麼抓比較準？', a: '建議先確認窗戶寬高、是否要做雙層窗簾、軌道長度與安裝區域，再用線上估價工具做無縫紗簾價格試算，最後由丈量確認正式報價。' },
      { q: '透光不透人紗簾適合直接當客廳主窗嗎？', a: '若白天採光與隱私是主要需求，透光不透人紗簾很適合當客廳主窗外層；若夜晚需要完整遮蔽，建議同步比較雙層窗簾或遮光布簾。' },
      { q: '搜尋無縫紗簾推薦，該先確認哪些重點？', a: '建議先確認白天採光需求、是否需要透光不透人效果、夜間是否搭配遮光布簾，以及整體窗高與軌道條件，這樣更容易判斷適合的款式與預算。' },
      { q: '無縫紗簾適合搭配哪些空間？', a: '客廳、書房、臥室外層與落地窗都是常見搭配場景。若想保留通透感又不希望空間太空，可以再搭配布簾、蛇形簾或木百葉做分層配置。' },
      { q: '台北、士林或中正區想做無縫紗簾，下一步怎麼安排？', a: '可先保留無縫紗簾價格試算結果，再切到台北、士林或中正區服務頁安排到府丈量與看樣，現場確認窗型、軌道與遮光搭配後，報價會更貼近實際需求。' },
    ],
    material: '聚酯纖維超細纖維（無縫工藝）',
    colorOptions: '白色、米白、象牙、淡灰、淡粉等20種色系',
    comparisons: [
      { feature: '採光效果', thisProduct: '★★★★★（透光）', vs1: '★（全遮光）', vs1Name: '全遮光布簾' },
      { feature: '視覺純淨度', thisProduct: '★★★★★（無縫）', vs1: '★★★', vs1Name: '一般紗簾' },
      { feature: '遮蔽隱私', thisProduct: '★★★（白天佳）', vs1: '★★★★★', vs1Name: '捲簾' },
      { feature: '價格親和度', thisProduct: '★★★★', vs1: '★★★', vs1Name: '柔紗簾' },
    ],
    galleryDesc: '無縫紗簾客廳採光實景圖',
  },
  P003: {
    faqs: [
      { q: '蛇形簾的軌道安裝有什麼特別之處？', a: '蛇形簾需要使用專用的蛇形軌道，軌道上有等距排列的C型鉤槽，確保每個波浪間距固定。宏森會在丈量時確認天花板結構是否適合安裝蛇形軌道，並給予最佳建議。' },
      { q: '客廳落地窗想做蛇形窗簾，要先確認什麼？', a: '先確認希望的是固定 S 型摺距與布料垂墜，還是葉片調光；前者可規劃蛇形窗簾，後者可一併比較直立簾。接著量測窗幅、窗高、窗簾盒深度與軌道固定面，正式規格仍以丈量為準。' },
      { q: '蛇形簾的清潔難度高嗎？', a: '蛇形簾清洗時需稍微注意保持褶子形狀。建議用衣架撐住後輕輕手洗或使用洗衣袋冷水機洗，洗後立即掛回軌道讓重力自然拉直，不要大力擰乾，避免破壞波浪形狀。' },
    ],
    material: '高垂墜感聚酯纖維、棉麻混紡，搭配鋁合金蛇形軌道',
    colorOptions: '深灰、軍綠、米白、奶油、深藍等30種精選色系',
    comparisons: [
      { feature: '視覺質感', thisProduct: '★★★★★', vs1: '★★★', vs1Name: '一般布簾' },
      { feature: '波浪一致性', thisProduct: '★★★★★（等間距）', vs1: '★★★（隨機）', vs1Name: '一般布簾' },
      { feature: '安裝複雜度', thisProduct: '★★★（需專用軌道）', vs1: '★★★★★', vs1Name: '捲簾' },
      { feature: '成本效益', thisProduct: '★★★', vs1: '★★★★★', vs1Name: '一般布簾' },
    ],
    galleryDesc: '蛇形簾大型落地窗施工案例',
  },
  P004: {
    faqs: [
      { q: '羅馬簾和捲簾有什麼差別？', a: '羅馬簾收合時布料會形成層次分明的水平折疊，展開時布料平整且有層次感，質感較高。捲簾則是將布料捲起收納，收起後幾乎完全隱藏，風格更簡潔。羅馬簾適合居家溫馨風格，捲簾適合辦公室簡約風格。' },
      { q: '羅馬簾適合潮濕的浴室使用嗎？', a: '可以，但需選擇防水布料材質的羅馬簾。宏森可依您的使用環境推薦防潮布料，確保在浴室高濕度環境下的耐用性和抗霉效果。' },
      { q: '羅馬簾有哪些操作方式？', a: '羅馬簾主要有繩控式（傳統拉繩）和鍊珠控制式兩種。近年也推出無繩彈簧設計，適合有幼兒或寵物的家庭，避免繩子帶來的安全隱患。' },
    ],
    material: '純棉、麻布、防水聚酯纖維，搭配鋁合金橫桿',
    colorOptions: '素色或格紋約25種，可客製化花色',
    comparisons: [
      { feature: '適合小窗格', thisProduct: '★★★★★', vs1: '★★★（空間需求較大）', vs1Name: '一般布簾' },
      { feature: '視覺層次感', thisProduct: '★★★★★', vs1: '★★★', vs1Name: '捲簾' },
      { feature: '佔空間程度', thisProduct: '★★★★★（不佔左右）', vs1: '★★★', vs1Name: '布簾' },
      { feature: '清洗便利性', thisProduct: '★★★', vs1: '★★★★★', vs1Name: '鋁百葉' },
    ],
    galleryDesc: '羅馬簾多窗格廚房施工案例',
  },
  P005: {
    faqs: [
      { q: '捲簾價格試算要先看哪三件事？', a: '建議先看遮光等級、透光布料與安裝空間。三個條件先確定後，再用同一尺寸比較台北、三重或新莊常見捲簾方案，判斷最快。' },
      { q: '捲簾可以做到完全遮光嗎？', a: '可以。選擇全遮光布料，並採窗框貼合式安裝，可大幅降低漏光；若是臥室用途可再加側邊遮光配件。' },
      { q: '辦公室捲簾或廚房捲簾好清潔嗎？', a: '捲簾布料多可直接用濕布擦拭，防潑水材質更容易保養，屬於日常維護成本較低的窗簾類型。' },
      { q: '新莊或副都心景觀宅，捲簾適合當主窗方案嗎？', a: '可以，但建議先依採光與隱私需求決定是否搭配紗簾或改看調光簾。若白天需要更細的控光切換，調光簾通常會比單層捲簾更靈活。' },
      { q: '捲簾安裝價格和捲簾價格試算差在哪裡？', a: '線上試算會先抓材質與基本安裝費，正式差異多半來自高窗施工、窗框條件、五金配件與是否需要拆舊。先試算再丈量，判斷會更準。' },
    ],
    material: '防潑水聚酯纖維、遮光塗層布料，搭配鋁合金滾軸',
    colorOptions: '白色、灰色、米色、黑色等15種素色，另有透光/全遮光選擇',
    comparisons: [
      { feature: '清潔便利性', thisProduct: '★★★★★（濕布擦拭）', vs1: '★★★（需拆洗）', vs1Name: '布簾' },
      { feature: '最小化收納', thisProduct: '★★★★★', vs1: '★★★', vs1Name: '羅馬簾' },
      { feature: '保溫隔熱', thisProduct: '★★★', vs1: '★★★★★', vs1Name: '蜂巢簾' },
      { feature: '價格親和度', thisProduct: '★★★★★', vs1: '★★', vs1Name: '柔紗簾' },
    ],
    galleryDesc: '辦公室捲簾整層施工實景',
  },
  P006: {
    faqs: [
      { q: '百葉窗價格試算要先比鋁百葉、木百葉還是風琴簾？', a: '若優先考慮防潮與好清潔，先比鋁百葉；若重視木質感，先比木百葉；若主要需求是隔熱與臥室控溫，則先比風琴簾。建議用同尺寸同步試算。' },
      { q: '鋁百葉和木百葉哪個更適合潮濕空間？', a: '潮濕空間優先選鋁百葉。鋁合金葉片防潮好清潔，適合浴室與廚房；木百葉偏重質感與木紋風格，較適合客廳與書房等乾燥空間。' },
      { q: '鋁百葉可以先線上估價再安排丈量嗎？', a: '可以。建議先用窗簾計算機抓預算，再安排到府丈量確認窗型、葉片寬度與安裝細節，整體窗簾報價會更準確且流程更有效率。' },
      { q: '新莊百葉窗價格試算後，正式報價通常差在哪裡？', a: '多半差在葉片寬度、安裝高度、特殊窗型與現場五金條件。先做線上估價抓基礎區間，再由丈量確認正式報價，會最接近實際施工。' },
      { q: '百葉窗簾價格除了尺寸，還要看什麼？', a: '還要看葉片寬度、烤漆等級、安裝位置、窗框條件與是否需要拆舊。這些都會讓百葉窗簾價格、百葉窗價格與正式報價產生差異。' },
    ],
    material: '鋁合金（厚度0.18mm），烤漆表面處理',
    colorOptions: '白色、米白、灰色、黑色、香檳金等20種，葉片寬16/25/50mm可選',
    comparisons: [
      { feature: '防水防潮', thisProduct: '★★★★★', vs1: '★★', vs1Name: '木百葉' },
      { feature: '自然質感', thisProduct: '★★★', vs1: '★★★★★', vs1Name: '木百葉' },
      { feature: '清潔便利度', thisProduct: '★★★★★', vs1: '★★★', vs1Name: '布簾' },
      { feature: '價格親和度', thisProduct: '★★★★★', vs1: '★★★', vs1Name: '木百葉' },
    ],
    galleryDesc: '鋁百葉浴室、廚房防潮安裝案例',
  },
  P007: {
    faqs: [
      { q: '實木百葉窗價格試算怎麼判斷合理？', a: '先固定同一組窗戶寬高，再比較木種、葉片寬度、表面塗裝、安裝高度與五金配件；線上估價可先抓木百葉窗簾價格，正式報價仍由丈量確認。這個試算適合客廳與書房等乾燥空間。' },
      { q: '實木百葉窗價格試算要先看哪 3 個變數？', a: '先看木種、葉片寬度與窗型施工條件。三個變數一致時，台北實木百葉窗價格與三重實木百葉窗價格才有可比性。建議先用線上估價工具輸入尺寸，再安排丈量確認。' },
      { q: '台北實木百葉窗價格、三重實木百葉窗價格差在哪裡？', a: '主要差在木種等級、塗裝與現場施工條件（例如高窗、轉角窗、特殊五金）。先做實木百葉窗價格試算，再比同規格報價，判斷會更準確。' },
      { q: '實木百葉窗價格試算會包含安裝費嗎？', a: '線上估價會先納入基本安裝費，正式報價仍會依安裝高度、窗框條件、五金配件與是否需要特殊施工微調。' },
      { q: '木百葉窗簾價格為什麼不能只看單才價格？', a: '木百葉窗簾價格還會受到木種、葉片寬度、塗裝、五金、窗型與基本安裝費影響。建議用同尺寸試算，再由丈量確認正式報價。' },
      { q: '木百葉窗簾價格要怎麼和鋁百葉比較？', a: '建議輸入同一組寬高，先比較木百葉、鋁百葉與捲簾的估價，再把木種質感、葉片控光、保養與安裝條件一起納入，較能判斷升級是否值得。' },
      { q: '客廳落地窗做實木百葉，價格會比一般小窗高很多嗎？', a: '通常會，因為窗幅較大、葉片數量與安裝條件較複雜，但木質感與控光效果也更完整。建議先以客廳主窗尺寸試算，再和同尺寸的調光簾或布簾一起比較。' },
      { q: '木百葉可以用在浴室嗎？', a: '天然實木不建議長期使用在高濕環境，浴室可優先考慮防潮材質；木百葉更適合客廳、書房等乾燥空間。' },
      { q: '木百葉的葉片可調整與保養嗎？', a: '可以調整葉片角度做精準控光。日常建議乾布除塵，遇到髒污以微濕布輕拭後立即擦乾。' },
    ],
    material: '天然實木（西洋松、白橡木、胡桃木、柚木等多種木種）',
    colorOptions: '天然原木色、白色、淺灰色、胡桃棕等10種木紋色系',
    comparisons: [
      { feature: '自然木質感', thisProduct: '★★★★★（真實木紋）', vs1: '★★★（仿木紋）', vs1Name: '仿木百葉' },
      { feature: '防水效果', thisProduct: '★★（不耐潮）', vs1: '★★★★★', vs1Name: '鋁百葉' },
      { feature: '空間高級感', thisProduct: '★★★★★', vs1: '★★★', vs1Name: '鋁百葉' },
      { feature: '保養複雜度', thisProduct: '★★（需定期保養）', vs1: '★★★★★', vs1Name: '鋁百葉' },
    ],
    galleryDesc: '木百葉書房、客廳自然光影施工實景',
  },
  P008: {
    faqs: [
      { q: '竹簾訂製價格要先看哪三件事？', a: '建議先看編織密度、透光程度與安裝空間。這三件事先確定後，再比較竹簾是否要搭配布簾或紗簾，預算會更準。' },
      { q: '竹簾遮光效果好嗎？', a: '竹簾屬於過濾光線型窗簾，不是完全遮光。日光透過竹條縫隙後會變柔和；若需要完整遮光，建議在竹簾後方加掛遮光布簾。' },
      { q: '竹簾適合多雨潮濕的氣候嗎？', a: '室內通風良好的空間可以使用，但若長期高濕度或容易直接淋水，仍建議改看鋁百葉或防水材質窗簾。' },
      { q: '和室窗簾或日式窗簾一定要用竹簾嗎？', a: '不一定。竹簾是最常見的自然系選擇，但若需要更高隱私、較低保養門檻或更完整遮蔽，也可同步比較捲簾、羅馬簾或布簾。' },
      { q: '竹簾價格怎麼看比較準？', a: '建議先用同一尺寸比較編織密度、透光程度與安裝位置，再決定是否搭配布簾。這樣比單看材質名稱更容易抓到實際預算。' },
    ],
    material: '天然竹材（手工編織，經防蟲防霉處理）',
    colorOptions: '天然竹色、深棕色、淡黃色等自然色系',
    comparisons: [
      { feature: '自然禪意感', thisProduct: '★★★★★', vs1: '★★', vs1Name: '捲簾' },
      { feature: '通風透氣性', thisProduct: '★★★★★', vs1: '★★★', vs1Name: '布簾' },
      { feature: '遮光效果', thisProduct: '★★（過濾光線）', vs1: '★★★★★', vs1Name: '全遮光布簾' },
      { feature: '環保天然', thisProduct: '★★★★★（天然材料）', vs1: '★★★', vs1Name: '捲簾' },
    ],
    galleryDesc: '竹簾日式茶室、書房和風情境施工案例',
  },
  P009: {
    faqs: [
      { q: '風琴簾價格試算要先看哪三件事？', a: '建議先看透光等級、蜂巢層數與控制配件。三個條件一致時，再比較台北、三重或新莊常見施工情境，判斷會更準。' },
      { q: '風琴簾（蜂巢簾）真的有隔熱與節能效果嗎？', a: '有。蜂巢中空結構可形成空氣層，減少熱傳導，對西曬窗與臥室溫控很有幫助。實際節能效果會依窗向、使用習慣與空調設定而不同。' },
      { q: '可以先估價再決定是否安排丈量嗎？', a: '可以，先用窗簾計算機做初步估價，再安排到府丈量確認細節，能讓窗簾報價與施工規劃更透明。' },
      { q: '新莊或板橋西曬房，風琴簾比調光簾更適合嗎？', a: '若你最在意降溫與隔熱，風琴簾通常更有優勢；若更在意白天視覺層次與日夜切換，則可同步比較調光簾，再用同尺寸試算。' },
      { q: '蜂巢簾價格試算除了尺寸，還要看什麼？', a: '還要看蜂巢層數、透光等級、控制配件、安裝高度與是否為透天高窗。這些條件會直接影響風琴簾正式報價。' },
    ],
    material: '蜂巢狀中空聚酯纖維（Honeycomb 結構）',
    colorOptions: '白色、米白、淡灰、淡藍等15種素色，單層/雙層蜂巢選擇',
    comparisons: [
      { feature: '隔熱保溫', thisProduct: '★★★★★', vs1: '★★★', vs1Name: '布簾' },
      { feature: '節能省電', thisProduct: '★★★★★', vs1: '★★', vs1Name: '鋁百葉' },
      { feature: '顏色選擇', thisProduct: '★★★', vs1: '★★★★★', vs1Name: '布簾' },
      { feature: '成本效益', thisProduct: '★★★（較高單價）', vs1: '★★★★★', vs1Name: '捲簾' },
    ],
    galleryDesc: '蜂巢簾西曬房隔熱施工案例',
  },
  P010: {
    faqs: [
      { q: '調光簾價格試算要先比較哪三件事？', a: '建議先比較條紋寬度、遮光等級與安裝空間。這三件事先確認後，再比台北、三重或新莊常見調光簾方案，速度最快。' },
      { q: '調光簾可以完全遮光嗎？', a: '調光簾在條紋完全交錯時可達高度遮光，但並非100%全黑。若臥室需極致遮光，可搭配全遮光布料或改用全遮光捲簾。' },
      { q: '調光簾耐用嗎、後續維護麻煩嗎？', a: '正常使用下相當耐用，平時以乾布或除塵撢清潔即可，避免大力拉扯與水洗可延長使用壽命。' },
      { q: '新莊副都心景觀宅想做日夜控光，調光簾適合當主窗嗎？', a: '很適合。調光簾可在保留白天採光的同時快速切換隱私模式，若夜間還需要更高遮光，可再搭配遮光布簾或全遮光捲簾一起比較。' },
    ],
    material: '聚酯纖維雙層交錯編織（透明條紋與不透明條紋交替）',
    colorOptions: '白色、灰色、米色、深灰、淡藍等20種，條紋寬度3/5/7cm可選',
    comparisons: [
      { feature: '現代設計感', thisProduct: '★★★★★', vs1: '★★★', vs1Name: '捲簾' },
      { feature: '調光靈活性', thisProduct: '★★★★★', vs1: '★★★（僅開/關）', vs1Name: '布簾' },
      { feature: '防塵效果', thisProduct: '★★★★（不易積灰）', vs1: '★★', vs1Name: '百葉窗' },
      { feature: '完全遮光', thisProduct: '★★★', vs1: '★★★★★', vs1Name: '全遮光布簾' },
    ],
    galleryDesc: '調光簾臥室與辦公室採光情境案例',
  },
  P011: {
    faqs: [
      { q: '柔紗簾價格試算要先看哪三件事？', a: '先看寬高尺寸、葉片角度與安裝條件。柔紗簾屬於較精緻的透光窗簾，建議用同尺寸比較柔紗簾、調光簾與無縫紗簾，再決定預算。' },
      { q: '柔紗簾和調光簾有什麼差別？', a: '柔紗簾的葉片在兩層紗布之間，光線更柔和、視覺更精緻；調光簾則是條紋布片交錯，控光更俐落、價格通常較親和。' },
      { q: '柔紗簾適合客廳還是臥室？', a: '兩者都適合。客廳可用柔紗簾保留採光與質感，主臥則適合營造柔和放鬆的光影；若需要深度遮光，可搭配遮光布簾。' },
      { q: '柔紗簾訂製可以先線上估價嗎？', a: '可以。先在估價頁選柔紗簾並輸入寬高尺寸，得到初步預算後，再安排到府丈量確認窗型、安裝位置與正式報價。' },
      { q: '柔紗簾的保養方式？', a: '建議使用冷風吹塵或軟毛刷輕除表面灰塵，避免水洗或高吸力吸塵器直接拉扯紗布。若有嚴重汙漬，建議交由專業清潔處理。' },
    ],
    material: '超細纖維紗布（兩層）夾入布料葉片，纖薄高透光材質',
    colorOptions: '白色、米白、香檳色、淡灰等10種，柔和色調為主',
    comparisons: [
      { feature: '高端質感', thisProduct: '★★★★★（飯店級）', vs1: '★★★', vs1Name: '捲簾' },
      { feature: '光線柔化效果', thisProduct: '★★★★★', vs1: '★★★', vs1Name: '布簾' },
      { feature: '清潔難易度', thisProduct: '★★（需小心保養）', vs1: '★★★★★', vs1Name: '捲簾' },
      { feature: '價格親和度', thisProduct: '★★（高端款）', vs1: '★★★★★', vs1Name: '布簾' },
    ],
    galleryDesc: '柔紗簾飯店風主臥室搭配示意',
  },
  P012: {
    faqs: [
      { q: '醫院隔簾價格要先看哪三件事？', a: '建議先看隔簾尺寸、軌道長度與防焰抗菌布料規格。若還有夜間施工、分區施工或拆舊需求，正式報價會再依現場條件調整。' },
      { q: '醫療隔簾的防焰或抗菌規格怎麼確認？', a: '應依院所採購條件與現場需求，逐項核對實際選用布料的標示、適用標準、測試或供應商文件；網站上的產品分類不能替代該批材料證明。' },
      { q: '醫院隔簾多久需要更換？', a: '沒有適用所有場域的固定年限。應依材料說明、洗滌紀錄、破損、污染與院所維護規範評估，並由管理單位確認更換時點。' },
      { q: '抗菌或耐洗效果可以直接從網站判定嗎？', a: '不可以。抗菌、耐洗與洗滌次數會因實際布料與處理方式不同，報價與採購時應要求對應材料文件及保養說明。' },
    ],
    material: '聚酯纖維隔簾；防焰、抗菌、耐洗與頂部通風網規格依實際選用材料及文件確認',
    colorOptions: '醫院藍、醫療綠、白色、米白等8種標準醫療色系',
    comparisons: [
      { feature: '防焰規格', thisProduct: '依選用材料文件核對', vs1: '需另行核對', vs1Name: '一般布簾' },
      { feature: '抗菌／耐洗規格', thisProduct: '依選用材料文件核對', vs1: '需另行核對', vs1Name: '一般窗簾' },
      { feature: '耐工業洗滌', thisProduct: '★★★★★', vs1: '★★', vs1Name: '一般布簾' },
      { feature: '居家美觀度', thisProduct: '★★★', vs1: '★★★★★', vs1Name: '柔紗簾' },
    ],
    galleryDesc: '醫院病房、診所隔簾專業施工案例',
  },
  P013: {
    faqs: [
      { q: '直立簾適合哪種窗型？', a: '直立簾最適合「寬度大於高度」的超寬型落地窗，或者需要左右分割控制的大型玻璃牆面。對於高度不足200cm的窗戶，視覺比例較不協調，建議選擇其他款式。' },
      { q: '直立簾的葉片壞了怎麼辦？', a: '直立簾最大的優點之一是維修便利性極高。每片葉片都可以單獨拆卸更換，不需要整組拆除，維修成本很低。宏森可以提供原廠同款葉片，確保顏色一致性。' },
      { q: '直立簾的操作方式有哪些？', a: '直立簾傳統使用拉棒或繩鏈操控，可整體左移或右移收合，也可旋轉葉片調控光線。現代款式也可以安裝電動馬達，透過遙控器或手機APP進行智能控制，適合大型商業空間。' },
    ],
    material: '高強度聚酯纖維葉片（標準寬度89mm），搭配鋁合金導軌系統',
    colorOptions: '白色、米白、灰色、木紋等15種，葉片可選半透光或遮光材質',
    comparisons: [
      { feature: '超寬窗適用性', thisProduct: '★★★★★', vs1: '★★', vs1Name: '布簾' },
      { feature: '視覺拉高效果', thisProduct: '★★★★★（垂直線條）', vs1: '★★★', vs1Name: '百葉窗' },
      { feature: '維修便利性', thisProduct: '★★★★★（單片換）', vs1: '★★', vs1Name: '布簾' },
      { feature: '居家美觀度', thisProduct: '★★★', vs1: '★★★★★', vs1Name: '蛇形簾' },
    ],
    galleryDesc: '直立簾辦公室、大型落地窗施工實景',
  },
};

// Product gallery images (4 per product)
const productGallery: Record<string, { src: string; alt: string }[]> = {
  P001: [
    { src: '/images/P001_curtain.webp',   alt: '一般窗簾客廳落地窗施工實景' },
    { src: '/images/P001_curtain02.webp', alt: '一般布簾臥室遮光效果展示' },
    { src: '/images/P001_curtain03.webp', alt: '一般窗簾多色布料樣本展示' },
    { src: '/images/P001_curtain04.webp', alt: '一般布簾辦公室空間安裝案例' },
  ],
  P002: [
    { src: '/images/P002_screening.webp',   alt: '無縫紗簾客廳透光採光效果' },
    { src: '/images/P002_screening02.webp', alt: '無縫紗簾書房日光通透展示' },
    { src: '/images/P002_screening03.webp', alt: '無縫紗簾搭配遮光布簾雙層系統' },
    { src: '/images/P002_screening04.webp', alt: '無縫紗簾純白視覺極簡空間' },
  ],
  P003: [
    { src: '/images/P003_Snake curtain.webp',   alt: '蛇形窗簾落地窗S型曲線展示' },
    { src: '/images/P003_Snake curtain02.webp', alt: '蛇形簾主臥室奢華垂墜施工案例' },
    { src: '/images/P003_Snake curtain03.webp', alt: '蛇形窗簾北歐風格深灰色搭配' },
    { src: '/images/P003_Snake curtain04.webp', alt: '蛇形簾商業空間精品質感展示' },
  ],
  P004: [
    { src: '/images/P004_Roman blind.webp',   alt: '羅馬簾書房水平折疊層次展示' },
    { src: '/images/P004_Roman blind02.webp', alt: '羅馬簾廚房小窗格安裝案例' },
    { src: '/images/P004_Roman blind03.webp', alt: '羅馬簾多種布料顏色樣本展示' },
    { src: '/images/P004_Roman blind04.webp', alt: '羅馬簾衛浴防水材質施工實景' },
  ],
  P005: [
    { src: '/images/P005_roller blind.webp',   alt: '捲簾辦公室整排施工實景' },
    { src: '/images/P005_roller blind02.webp', alt: '捲簾廚房防潑水材質安裝案例' },
    { src: '/images/P005_roller blind03.webp', alt: '捲簾遮光效果半拉展示' },
    { src: '/images/P005_roller blind04.webp', alt: '捲簾透光材質採光實景圖' },
  ],
  P006: [
    { src: '/images/P006_Aluminum blinds.webp',   alt: '鋁百葉浴室防潮安裝實景' },
    { src: '/images/P006_Aluminum blinds02.webp', alt: '鋁百葉廚房防水葉片展示' },
    { src: '/images/P006_Aluminum blinds03.webp', alt: '鋁百葉辦公室精確調光展示' },
    { src: '/images/P006_Aluminum blinds04.webp', alt: '鋁百葉多色系葉片顏色樣本' },
  ],
  P007: [
    { src: '/images/P007_Log blinds.webp',   alt: '木百葉書房天然木紋光影效果' },
    { src: '/images/P007_Log blinds02.webp', alt: '木百葉客廳胡桃木色搭配展示' },
    { src: '/images/P007_Log blinds03.webp', alt: '木百葉餐廳北歐風格安裝案例' },
    { src: '/images/P007_Log blinds04.webp', alt: '木百葉多種木種色系樣本展示' },
  ],
  P008: [
    { src: '/images/P008_Bamboo curtain.webp',   alt: '竹簾日式茶室禪意空間展示' },
    { src: '/images/P008_Bamboo curtain02.webp', alt: '竹簾書房柔和透光效果實景' },
    { src: '/images/P008_Bamboo curtain03.webp', alt: '竹簾峇里島度假風格空間搭配' },
    { src: '/images/P008_Bamboo curtain04.webp', alt: '竹簾天然竹材編織工藝特寫' },
  ],
  P009: [
    { src: '/images/P009_accordion curtain.webp',   alt: '風琴簾西曬房隔熱效果展示' },
    { src: '/images/P009_accordion curtain02.webp', alt: '蜂巢簾臥室節能遮光安裝案例' },
    { src: '/images/P009_accordion curtain03.webp', alt: '風琴簾蜂巢中空結構特寫展示' },
    { src: '/images/P009_accordion curtain04.webp', alt: '蜂巢簾客廳透光柔和採光實景' },
  ],
  P010: [
    { src: '/images/P010_dimming curtain.webp',   alt: '調光簾斑馬紋現代客廳展示' },
    { src: '/images/P010_dimming curtain02.webp', alt: '調光簾臥室遮光採光切換效果' },
    { src: '/images/P010_dimming curtain03.webp', alt: '調光簾辦公室辦公空間安裝案例' },
    { src: '/images/P010_dimming curtain04.webp', alt: '斑馬簾條紋寬度比較展示' },
  ],
  P011: [
    { src: '/images/P011_Soft gauze curtains.webp',   alt: '柔紗簾飯店風主臥室夢幻光影' },
    { src: '/images/P011_Soft gauze curtains02.webp', alt: '柔紗簾客廳奢華垂墜效果展示' },
    { src: '/images/P011_Soft gauze curtains03.webp', alt: '柔紗簾薄霧光線透光特效實景' },
    { src: '/images/P011_Soft gauze curtains04.webp', alt: '柔紗簾高端住宅精品安裝案例' },
  ],
  P012: [
    { src: '/images/P012_hospital curtains.webp',   alt: '醫院隔簾病房分隔施工實景' },
    { src: '/images/P012_hospital curtains02.webp', alt: '醫院窗簾診所空間專業安裝案例' },
    { src: '/images/P012_hospital curtains03.webp', alt: '醫院隔簾布料與通風網細節展示' },
    { src: '/images/P012_hospital curtains04.webp', alt: '醫院隔簾頂部通風軌道設計展示' },
  ],
  P013: [
    { src: '/images/P013_straight blinds.webp',   alt: '直立簾辦公室大型落地窗展示' },
    { src: '/images/P013_straight blinds02.webp', alt: '直立簾垂直葉片調光效果實景' },
    { src: '/images/P013_straight blinds03.webp', alt: '直立簾超寬型落地窗安裝案例' },
    { src: '/images/P013_straight blinds04.webp', alt: '直立簾商業空間現代感展示' },
  ],
};

const howToSchema = (productName: string) => ({
  '@context': 'https://schema.org',
  '@type': 'HowTo',
  name: `宏森${productName}訂製安裝完整流程`,
  description: `詳細說明宏森開發${productName}從預約到完工安裝的四個專業步驟`,
  step: [
    { '@type': 'HowToStep', position: 1, name: '預約免費到府丈量', text: '透過電話、LINE 或線上表單預約，專業人員攜帶樣本與色卡親赴您家丈量，完全免費。' },
    { '@type': 'HowToStep', position: 2, name: '現場選料與報價', text: '師傅於現場依您的空間、採光與風格需求，推薦最合適的布料材質，並立即提供透明報價。' },
    { '@type': 'HowToStep', position: 3, name: '依確認規格製作', text: '確認訂單、材料與尺寸後進入製作，完成後再依約安排安裝。' },
    { '@type': 'HowToStep', position: 4, name: '專業到府安裝', text: '完工後約定時間由專業師傅上門安裝，並提供完整使用說明與售後服務諮詢。' },
  ],
});

export default async function ProductDetailPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const product = findProductBySlugOrId(slug);
  if (!product) notFound();

  const canonicalProductUrl = absoluteUrl(productPath(product));
  const details = productDetails[product.id] || {
    features: ['高品質材料', '專業施工', '多種顏色選擇'],
    useCases: ['住家', '辦公室', '商業空間'],
    fullDesc: product.description,
  };

  const seo = (product as any).seo;
  const productSchema = {
    '@context': 'https://schema.org',
    '@type': 'Product',
    '@id': `${canonicalProductUrl}#product`,
    name: product.name,
    image: absoluteUrl(product.image),
    description: details.fullDesc,
    sku: product.id,
    brand: { '@type': 'Brand', name: COMPANY_NAME },
  };

  const extras = productSeoExtras[product.id] || defaultSeoExtras;
  const v3 = productV3Data[product.id] || { faqs: [], material: '聚酯纖維', colorOptions: '多種顏色可選', comparisons: [], galleryDesc: '' };
  // Render and serialize the same focused FAQ set so HTML and JSON-LD stay in parity.
  const pageFaqs = v3.faqs.slice(0, 5);
  const gallery = (productGallery[product.id] || []).map((item) => ({
    ...item,
    src: withBasePath(item.src),
  }));
  const relatedProducts = products.filter(p => p.id !== product.id).slice(0, 4);
  const serviceAreas = getServiceAreasForProduct(product.id, 6);
  const primaryAreaId = serviceAreas[0]?.id;
  const productHeroTitleMap: Record<string, string> = {
    P001: '做窗簾價格試算｜訂製布簾、遮光與安裝費',
    P002: '紗簾價格試算｜透光不透人紗簾、安裝費與到府看樣',
    P003: '蛇形窗簾｜客廳落地窗 S 型布簾、軌道與線上估價',
    P005: '捲簾價格試算｜遮光捲簾、捲簾安裝價格與線上估價',
    P006: '百葉窗價格試算｜鋁百葉防潮、安裝費與線上估價',
    P007: '實木百葉窗價格試算｜木百葉、客廳書房與安裝費',
    P008: '竹簾訂製｜竹簾、和室窗簾、日式窗簾與價格試算',
    P009: '風琴簾價格試算｜蜂巢簾隔熱、安裝費與線上估價',
    P010: '調光簾價格試算｜斑馬簾價格、客廳控光與安裝費',
    P011: '柔紗簾價格試算｜柔紗簾訂製、透光窗簾與精品住宅搭配',
    P012: '醫院隔簾價格｜醫療隔簾、特殊規格文件與診所施工',
  };
  const productInternalLinksMap: Record<string, Array<{ href: string; label: string }>> = {
    P001: [
      { href: '/calculator/?product=P001', label: '做窗簾價格試算：輸入尺寸比較布簾、遮光與基本安裝費' },
      { href: '/curtain/blackout/', label: '遮光窗簾推薦：比較補眠、西曬與隔熱方案' },
      { href: '/products/roller-blinds/', label: '捲簾價格試算：比較遮光捲簾與布簾差異' },
      { href: '/products/honeycomb-blinds/', label: '風琴簾價格試算：比較隔熱與臥室控溫方案' },
      { href: '/location/sanchong/', label: '三重窗簾價格試算：訂製窗簾與遮光布簾丈量入口' },
      { href: '/location/banqiao/', label: '板橋窗簾推薦：做窗簾價格與全室布簾比價' },
      { href: '/location/neihu/', label: '內湖窗簾推薦：商辦與住宅訂製窗簾丈量入口' },
      { href: '/location/shulin/', label: '樹林窗簾推薦：透天與社區窗簾訂製價格入口' },
      { href: '/products/', label: '窗簾產品總覽：先比較窗簾訂製、捲簾與風琴簾' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：窗簾訂製、安裝費與報價重點' },
    ],
    P002: [
      { href: '/calculator/?product=P002', label: '紗簾價格試算：先抓透光不透人紗簾與安裝費預算' },
      { href: '/calculator/?product=P002&area=taipei', label: '台北紗簾價格試算：透光不透人紗簾先抓預算' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：紗簾價格、安裝費與試算差異' },
      { href: '/curtain/living-room/', label: '客廳窗簾推薦：比較無縫紗簾、調光簾與落地窗搭配' },
      { href: '/curtain/blackout/', label: '遮光窗簾推薦：比較雙層窗簾、補眠與夜間隱私需求' },
      { href: '/location/shilin/', label: '士林窗簾推薦：天母客廳紗簾與遮光比價入口' },
      { href: '/location/taipei/', label: '台北窗簾推薦與台北窗簾價格試算入口' },
      { href: '/location/banqiao/', label: '板橋窗簾推薦與板橋窗簾價格試算入口' },
      { href: '/location/zhongzheng/', label: '中正區窗簾價格試算：客廳紗簾與調光簾比價入口' },
    ],
    P003: [
      { href: '/calculator/?product=P003', label: '蛇形窗簾線上估價：先帶入客廳落地窗尺寸與蛇形軌道需求' },
      { href: '/blog/s-curtain-vs-vertical-blind/', label: '蛇形窗簾與直立簾比較：客廳落地窗先確認垂墜或葉片調光需求' },
      { href: '/products/custom-curtains/', label: '一般布簾訂製：比較固定 S 型摺距與傳統布簾抓褶做法' },
      { href: '/location/sanchong/', label: '三重窗簾丈量：客廳落地窗、窗簾盒與蛇形軌道條件確認' },
      { href: '/location/taipei/', label: '台北窗簾估價：客廳落地窗蛇形簾先抓預算與丈量條件' },
    ],
    P005: [
      { href: '/calculator/?product=P005', label: '捲簾價格試算：直接帶入捲簾品項' },
      { href: '/curtain/blackout/', label: '遮光窗簾推薦：比較遮光捲簾、布簾與蜂巢簾' },
      { href: '/products/zebra-blinds/', label: '調光簾價格試算：比較日夜控光與條紋寬度' },
      { href: '/products/honeycomb-blinds/', label: '風琴簾價格試算：比較西曬隔熱與臥室控溫' },
      { href: '/location/xinzhuang/', label: '新莊窗簾推薦：捲簾、調光簾與百葉窗比價入口' },
      { href: '/location/taipei/', label: '台北窗簾推薦與台北捲簾價格試算入口' },
      { href: '/location/sanchong/', label: '三重窗簾推薦與三重捲簾價格試算入口' },
      { href: '/location/shilin/', label: '士林窗簾推薦：天母遮光捲簾與客廳紗簾比價入口' },
      { href: '/products/', label: '窗簾產品總覽：先比較捲簾、窗簾訂製與風琴簾' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：捲簾安裝費、遮光等級與報價差異' },
    ],
    P006: [
      { href: '/calculator/?product=P006', label: '百葉窗價格試算：直接帶入鋁百葉品項' },
      { href: '/products/wooden-blinds/', label: '實木百葉窗價格試算：比較木質感、葉片寬度與安裝費' },
      { href: '/products/honeycomb-blinds/', label: '風琴簾價格試算：比較隔熱與百葉窗差異' },
      { href: '/products/bamboo-blinds/', label: '竹簾訂製：比較自然通風、和室窗簾與日式空間風格' },
      { href: '/location/sanchong/', label: '三重窗簾價格試算入口：比較鋁百葉與木百葉' },
      { href: '/location/banqiao/', label: '板橋窗簾推薦：百葉窗價格試算與丈量流程' },
      { href: '/location/neihu/', label: '內湖窗簾推薦：科技園區百葉窗價格試算入口' },
      { href: '/location/shulin/', label: '樹林窗簾推薦：透天小窗與百葉窗簾價格入口' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：百葉窗安裝費、葉片寬度與報價重點' },
    ],
    P008: [
      { href: '/calculator/?product=P008', label: '竹簾價格試算：直接帶入竹簾品項' },
      { href: '/products/custom-curtains/', label: '窗簾訂製：比較竹簾、布簾與雙層窗簾搭配' },
      { href: '/products/roller-blinds/', label: '捲簾價格試算：比較好清潔與遮光需求' },
      { href: '/location/yingge/', label: '鶯歌窗簾推薦：透天採光、展示空間與到府價格試算' },
      { href: '/products/aluminum-blinds/', label: '百葉窗價格試算：比較竹簾、鋁百葉與防潮窗面差異' },
      { href: '/about/', label: '工廠直營窗簾與品牌服務：先看丈量流程與估價方式' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：先看竹簾、捲簾與百葉窗行情差異' },
    ],
    P009: [
      { href: '/calculator/?product=P009', label: '風琴簾價格試算：直接帶入蜂巢簾品項' },
      { href: '/products/aluminum-blinds/', label: '百葉窗價格試算：比較鋁百葉與風琴簾防潮隔熱差異' },
      { href: '/products/roller-blinds/', label: '捲簾價格試算：比較價格親和與隔熱差異' },
      { href: '/products/zebra-blinds/', label: '調光簾價格試算：比較日夜控光與西曬房需求' },
      { href: '/location/xinzhuang/', label: '新莊窗簾推薦：風琴簾、西曬隔熱與景觀宅比價入口' },
      { href: '/location/banqiao/', label: '板橋窗簾推薦：風琴簾價格試算與臥室控溫入口' },
      { href: '/location/shilin/', label: '士林窗簾推薦：天母透天高窗、西曬隔熱與蜂巢簾入口' },
      { href: '/curtain/blackout/', label: '遮光窗簾推薦：比較補眠、隔熱與蜂巢簾方向' },
      { href: '/products/', label: '窗簾產品總覽：先比較風琴簾、捲簾與百葉窗' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：風琴簾價格、蜂巢層數與安裝費' },
    ],
    P010: [
      { href: '/calculator/?product=P010', label: '調光簾價格試算：直接帶入斑馬簾品項' },
      { href: '/products/roller-blinds/', label: '捲簾價格試算：比較遮光等級與價格親和度' },
      { href: '/products/soft-sheer-blinds/', label: '柔紗簾價格試算：比較柔化光線與精品住宅質感' },
      { href: '/products/honeycomb-blinds/', label: '風琴簾價格試算：比較隔熱節能與臥室控溫' },
      { href: '/location/xinzhuang/', label: '新莊窗簾推薦：調光簾、捲簾與百葉窗快速比價' },
      { href: '/location/taipei/', label: '台北窗簾推薦與台北調光簾價格試算入口' },
      { href: '/location/sanchong/', label: '三重窗簾推薦與三重調光簾價格試算入口' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：調光簾條紋寬度、安裝費與報價重點' },
    ],
    P011: [
      { href: '/calculator/?product=P011', label: '柔紗簾價格試算：直接帶入柔紗簾品項' },
      { href: '/products/zebra-blinds/', label: '調光簾價格試算：比較斑馬簾與柔紗簾控光差異' },
      { href: '/products/seamless-sheer-curtains/', label: '無縫紗簾推薦：比較透光不透人與雙層窗簾' },
      { href: '/curtain/living-room/', label: '客廳窗簾推薦：柔紗簾、調光簾與無縫紗簾比較' },
      { href: '/location/taipei/', label: '台北窗簾價格試算：精品住宅與主臥柔光方案' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：柔紗簾、調光簾與安裝費差異' },
    ],
    P012: [
      { href: '/calculator/?product=P012', label: '醫院隔簾價格試算：直接帶入醫療隔簾品項' },
      { href: '/products/vertical-blinds/', label: '直立簾估價：比較醫療空間大面隔間與商辦控光' },
      { href: '/products/roller-blinds/', label: '捲簾價格試算：診所辦公區與防眩光窗面入口' },
      { href: '/location/zhongzheng/', label: '中正區窗簾推薦：醫療院所、診所與學區商辦丈量入口' },
      { href: '/location/shilin/', label: '士林窗簾推薦：醫院隔簾、診所窗簾與天母丈量入口' },
      { href: '/location/zhonghe/', label: '中和窗簾價格試算：診所、店面與商辦施工入口' },
      { href: '/products/', label: '窗簾產品總覽：比較醫療隔簾、直立簾與特殊材料規格' },
      { href: '/blog/curtain-price-guide-2026/', label: '窗簾價格指南：醫院隔簾價格、軌道與安裝費重點' },
    ],
    P007: [
      { href: '/calculator/?product=P007', label: '實木百葉窗價格試算：直接帶入木百葉品項與基本安裝費' },
      { href: '/products/aluminum-blinds/', label: '高濕空間改看鋁百葉：浴室、廚房的防潮價格試算' },
      { href: '/calculator/?product=P007&area=taipei', label: '台北實木百葉窗價格試算：先抓安裝預算' },
      { href: '/location/sanchong/', label: '三重窗簾價格試算入口：對照實木百葉窗價格' },
      { href: '/location/taipei/', label: '台北窗簾價格試算入口：對照客廳木百葉窗價格' },
      { href: '/', label: '宏森窗簾推薦：回首頁比較價格試算與產品入口' },
      { href: '/location/zhongzheng/', label: '中正區窗簾價格試算入口：書房、景觀窗與木百葉比價' },
      { href: '/curtain/living-room/', label: '客廳窗簾推薦：實木百葉與落地窗搭配重點' },
      { href: '/calculator/?product=P007&area=sanchong', label: '三重實木百葉窗價格試算：直接帶入木百葉品項' },
      { href: '/blog/curtain-price-guide-2026/', label: '2026 窗簾價格指南：木百葉窗簾價格與基本安裝費' },
      { href: '/location/banqiao/', label: '板橋窗簾推薦：比較木百葉窗簾價格與丈量流程' },
    ],
  };
  const productHeroTitle = productHeroTitleMap[product.id] || `宏森${product.name}訂製服務`;
  const internalLinks = productInternalLinksMap[product.id] || [
    { href: '/blog', label: '如何挑選適合自己家的窗簾款式？完整指南' },
    { href: '/blog', label: '窗簾材質大比較：布簾、捲簾、百葉窗哪個適合你？' },
    { href: '/calculator/', label: `立即使用線上估價工具計算${product.name}預算` },
  ];

  const imageObjectSchema = gallery.map((img, i) => ({
    '@context': 'https://schema.org',
    '@type': 'ImageObject',
    contentUrl: absoluteUrl(img.src),
    name: img.alt,
    description: `${product.name}施工案例圖片 ${i + 1}`,
    author: { '@type': 'Organization', name: COMPANY_NAME },
  }));

  // Legacy testimonials in productSeoExtras have no bound receipt or source URL.
  // Keep them out of rendered HTML and structured data until verifiable evidence exists.
  const productSchemaWithEvidence = {
    ...productSchema,
    material: v3.material,
    color: v3.colorOptions,
    // These aggregate offers are derived from the visible reference-price table.
    // They describe configurable made-to-measure products, not a fabricated fixed price.
    offers: buildReferencePriceOffer(extras.priceTable, canonicalProductUrl),
  };

  const faqSchema = pageFaqs.length > 0 ? {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: pageFaqs.map(f => ({
      '@type': 'Question',
      name: f.q,
      acceptedAnswer: { '@type': 'Answer', text: f.a },
    })),
  } : null;

  const howToData = howToSchema(product.name);
  const breadcrumbSchema = {
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: '首頁', item: absoluteUrl('/') },
      { '@type': 'ListItem', position: 2, name: '產品系列', item: absoluteUrl('/products/') },
      { '@type': 'ListItem', position: 3, name: product.name, item: canonicalProductUrl },
    ],
  };

  const unifiedSchema = {
    '@context': 'https://schema.org',
    '@graph': [
      productSchemaWithEvidence,
      howToData,
      breadcrumbSchema,
      ...(faqSchema ? [faqSchema] : []),
      ...imageObjectSchema
    ]
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(unifiedSchema) }} />

      <nav className="breadcrumb" aria-label="breadcrumb">
        <div className="breadcrumb-inner">
          <Link href="/">首頁</Link>
          <span>›</span>
          <Link href="/products">產品系列</Link>
          <span>›</span>
          <span>{product.name}</span>
        </div>
      </nav>

      <ProductScrollMenu products={products} currentProductId={product.id} />
      
      <style dangerouslySetInnerHTML={{__html: `
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
      `}} />

      {/* Product Detail Hero */}
      <section className="py-section bg-white">
        <div className="section-container">
          <div className="product-hero-grid" style={{ alignItems: 'start' }}>
            <div style={{ borderRadius: '1.25rem', overflow: 'hidden', background: 'var(--stone-100)', aspectRatio: '4/3' }}>
              <img
                src={withBasePath(product.image)}
                alt={product.image_alt || product.name}
                title={product.image_title || product.name}
                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
              />
            </div>
            <div>
              <div className="tag">{product.name}</div>
              <h1 style={{ fontSize: '2rem', fontWeight: 700, marginBottom: '1rem', lineHeight: 1.3 }}>
                {productHeroTitle}
              </h1>
              <p data-ai-answer="true" style={{ color: 'var(--stone-600)', lineHeight: 1.9, marginBottom: '1.5rem', fontSize: '1rem' }}>
                {details.fullDesc}
              </p>

              <h2 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: '0.75rem' }}>產品特色</h2>
              <ul style={{ listStyle: 'none', marginBottom: '1.5rem', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                {details.features.map((f, i) => (
                  <li key={i} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.925rem', color: 'var(--stone-700)' }}>
                    <CheckCircle2 size={16} style={{ color: 'var(--amber-600)', flexShrink: 0 }} />
                    {f}
                  </li>
                ))}
              </ul>

              <h2 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: '0.5rem' }}>適用空間</h2>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '2rem' }}>
                {details.useCases.map((u, i) => (
                  <span key={i} className="tag" style={{ marginBottom: 0 }}>{u}</span>
                ))}
              </div>

              <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
                <Link href={buildCalculatorUrl(product.id)} className="btn-primary">
                  <Calculator size={16} />
                  {product.id === 'P007' ? '立即做實木百葉窗價格試算' : '立即估價'}
                </Link>
                <a href="tel:0289727322" className="btn-outline">
                  致電諮詢
                </a>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Image Gallery */}
      {gallery.length > 0 && (
        <section className="py-section bg-stone-50">
          <div className="section-container">
            <div className="section-heading">
              <h2>{product.name}施工實景圖集</h2>
              <p style={{ fontSize: '0.9rem' }}>{v3.galleryDesc}</p>
            </div>
            <ProductImageGallery gallery={gallery} />
          </div>
        </section>
      )}

      {/* ---- SEO RICH CONTENT SECTIONS ---- */}

      {/* 1. HowTo Service Flow */}
      <section className="py-section bg-stone-50">
        <div className="section-container" style={{ maxWidth: '860px' }}>
          <div className="section-heading">
            <h2>{product.name}－宏森專業服務四大步驟</h2>
          </div>
          <div style={{ display: 'grid', gap: '1.25rem' }}>
            {howToData.step.map((step) => (
              <div key={step.position} style={{ display: 'flex', gap: '1.25rem', background: 'white', padding: '1.5rem', borderRadius: '1rem', boxShadow: '0 2px 10px rgba(0,0,0,0.04)', border: '1px solid var(--stone-100)' }}>
                <div style={{ background: '#D97706', color: 'white', borderRadius: '50%', width: '2.5rem', height: '2.5rem', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: '1rem', flexShrink: 0 }}>{step.position}</div>
                <div>
                  <h3 style={{ fontWeight: 700, marginBottom: '0.3rem', fontSize: '1.05rem' }}>{step.name}</h3>
                  <p style={{ color: 'var(--stone-600)', fontSize: '0.95rem', lineHeight: 1.7, margin: 0 }}>{step.text}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 2. Price Transparency Table */}
      <section className="py-section bg-white">
        <div className="section-container" style={{ maxWidth: '860px' }}>
          <div className="section-heading">
            <h2>{product.name}參考價格一覽</h2>
            <p style={{ fontSize: '0.9rem', color: 'var(--stone-500)' }}>以下為市場行情參考區間，實際依布料材質、窗幅等因素報價，詳情請使用線上估價或致電洽詢。</p>
          </div>
          <div style={{ borderRadius: '1rem', overflow: 'hidden', border: '1px solid var(--stone-100)' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#D97706', color: 'white' }}>
                  <th style={{ padding: '0.9rem 1.5rem', textAlign: 'left', fontSize: '0.95rem', fontWeight: 700 }}>規格說明</th>
                  <th style={{ padding: '0.9rem 1.5rem', textAlign: 'right', fontSize: '0.95rem', fontWeight: 700 }}>參考價格</th>
                </tr>
              </thead>
              <tbody>
                {extras.priceTable.map((row, i) => (
                  <tr key={i} style={{ borderTop: '1px solid var(--stone-100)', background: i % 2 === 0 ? 'white' : 'var(--stone-50)' }}>
                    <td style={{ padding: '0.8rem 1.5rem', fontSize: '0.9rem', color: 'var(--stone-700)' }}>{row.label}</td>
                    <td style={{ padding: '0.8rem 1.5rem', fontSize: '0.9rem', color: '#B45309', fontWeight: 700, textAlign: 'right' }}>{row.range}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p style={{ marginTop: '1rem', fontSize: '0.8rem', color: 'var(--stone-400)', textAlign: 'center' }}>✦ 線上價格為預算參考；正式報價依材料、窗型、配件與施工條件確認</p>
          <div style={{ marginTop: '1.5rem', textAlign: 'center' }}>
            <Link href={buildCalculatorUrl(product.id)} className="btn-primary">
              <Calculator size={16} /> {product.id === 'P007' ? '直接做實木百葉窗價格試算' : '直接線上估算我的費用'}
            </Link>
          </div>
        </div>
      </section>

      {/* V3: Specification Panel */}
      <section className="py-section bg-white" style={{ borderTop: '1px solid var(--stone-100)' }}>
        <div className="section-container" style={{ maxWidth: '860px' }}>
          <div className="section-heading">
            <h2>{product.name}材質與規格說明</h2>
          </div>
          <div style={{ display: 'grid', gap: '1rem', gridTemplateColumns: '1fr', marginBottom: '0' }} className="spec-grid">
            <div style={{ background: 'var(--stone-50)', borderRadius: '1rem', padding: '1.5rem', border: '1px solid var(--stone-100)' }}>
              <h3 style={{ fontSize: '0.85rem', color: 'var(--stone-500)', marginBottom: '0.4rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>主要材質</h3>
              <p style={{ fontWeight: 600, color: 'var(--stone-800)', fontSize: '0.95rem', margin: 0 }}>{v3.material}</p>
            </div>
            <div style={{ background: 'var(--stone-50)', borderRadius: '1rem', padding: '1.5rem', border: '1px solid var(--stone-100)' }}>
              <h3 style={{ fontSize: '0.85rem', color: 'var(--stone-500)', marginBottom: '0.4rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>顏色選擇</h3>
              <p style={{ fontWeight: 600, color: 'var(--stone-800)', fontSize: '0.95rem', margin: 0 }}>{v3.colorOptions}</p>
            </div>
            <div style={{ background: 'var(--amber-50)', borderRadius: '1rem', padding: '1.5rem', border: '1px solid var(--amber-100)' }}>
              <h3 style={{ fontSize: '0.85rem', color: '#92400E', marginBottom: '0.4rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>生產方式</h3>
              <p style={{ fontWeight: 600, color: 'var(--stone-800)', fontSize: '0.95rem', margin: 0 }}>依丈量尺寸、選用材料與確認規格進行製作</p>
            </div>
          </div>
          <style dangerouslySetInnerHTML={{__html: `@media (min-width: 640px) { .spec-grid { grid-template-columns: 1fr 1fr 1fr !important; } }`}} />
        </div>
      </section>

      {/* V3: Product Comparison Table */}
      {v3.comparisons.length > 0 && (
        <section className="py-section bg-stone-50">
          <div className="section-container" style={{ maxWidth: '860px' }}>
            <div className="section-heading">
              <h2>{product.name}與其他款式比較</h2>
              <p style={{ fontSize: '0.9rem' }}>協助您快速找到最適合您需求的窗簾款式</p>
            </div>
            <div style={{ borderRadius: '1rem', overflow: 'hidden', border: '1px solid var(--stone-200)' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ background: 'var(--stone-800)', color: 'white' }}>
                    <th style={{ padding: '0.9rem 1.25rem', textAlign: 'left', fontSize: '0.875rem', fontWeight: 700 }}>比較項目</th>
                    <th style={{ padding: '0.9rem 1.25rem', textAlign: 'center', fontSize: '0.875rem', fontWeight: 700, background: '#D97706' }}>{product.name}（本款）</th>
                    <th style={{ padding: '0.9rem 1.25rem', textAlign: 'center', fontSize: '0.875rem', fontWeight: 700 }}>其他款式</th>
                  </tr>
                </thead>
                <tbody>
                  {v3.comparisons.map((row, i) => (
                    <tr key={i} style={{ borderTop: '1px solid var(--stone-100)', background: i % 2 === 0 ? 'white' : 'var(--stone-50)' }}>
                      <td style={{ padding: '0.85rem 1.25rem', fontSize: '0.875rem', fontWeight: 600, color: 'var(--stone-700)' }}>{row.feature}</td>
                      <td style={{ padding: '0.85rem 1.25rem', fontSize: '0.85rem', textAlign: 'center', color: '#92400E', background: 'rgba(251,191,36,0.06)', fontWeight: 600 }}>{row.thisProduct}</td>
                      <td style={{ padding: '0.85rem 1.25rem', fontSize: '0.85rem', textAlign: 'center', color: 'var(--stone-500)' }}>{row.vs1}<br /><span style={{ fontSize: '0.75rem', color: 'var(--stone-400)' }}>（{row.vs1Name}）</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </section>
      )}

      {/* V3: FAQ Section */}
      {pageFaqs.length > 0 && (
        <section className="py-section bg-white">
          <div className="section-container" style={{ maxWidth: '860px' }}>
            <div className="section-heading">
              <h2>{product.name}常見問題 FAQ</h2>
            </div>
            <div style={{ display: 'grid', gap: '1rem' }}>
              {pageFaqs.map((faq, i) => (
                <details key={i} style={{ background: 'var(--stone-50)', border: '1px solid var(--stone-200)', borderRadius: '0.75rem', overflow: 'hidden' }}>
                  <summary style={{ padding: '1.1rem 1.5rem', fontWeight: 700, fontSize: '0.95rem', color: 'var(--stone-800)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '0.5rem', listStyle: 'none' }}>
                    <span style={{ background: '#D97706', color: 'white', borderRadius: '50%', width: '1.5rem', height: '1.5rem', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.75rem', fontWeight: 800, flexShrink: 0 }}>Q</span>
                    {faq.q}
                  </summary>
                  <div style={{ padding: '0 1.5rem 1.25rem 1.5rem', borderTop: '1px solid var(--stone-200)', paddingTop: '1rem' }}>
                    <p style={{ fontSize: '0.9rem', color: 'var(--stone-600)', lineHeight: 1.8, margin: 0 }}>{faq.a}</p>
                  </div>
                </details>
              ))}
            </div>
          </div>
        </section>
      )}

      {/* 4. LSI Keyword Paragraph */}
      <section style={{ background: 'white', padding: '3rem 0', borderTop: '1px solid var(--stone-100)' }}>
        <div className="section-container" style={{ maxWidth: '860px' }}>
          <h2 style={{ fontSize: '1.3rem', fontWeight: 700, marginBottom: '1rem', color: 'var(--stone-800)' }}>
            更多關於宏森{product.name}的訂製服務
          </h2>
          <p style={{ color: 'var(--stone-600)', lineHeight: 1.9, fontSize: '0.95rem' }}>{extras.lsiParagraph}</p>
        </div>
      </section>

      {/* 5. Internal Blog Links */}
      <section className="py-section bg-amber-50" style={{ borderTop: '1px solid var(--amber-100)' }}>
        <div className="section-container" style={{ maxWidth: '860px' }}>
          <h2 style={{ fontSize: '1.3rem', fontWeight: 700, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <BookOpen size={20} style={{ color: '#D97706' }} /> 延伸閱讀：窗簾知識庫
          </h2>
          <div style={{ display: 'grid', gap: '1rem' }}>
            {internalLinks.map((entry, index) => (
              <Link
                key={`${entry.href}-${index}`}
                href={entry.href}
                style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', background: 'white', borderRadius: '0.75rem', padding: '1rem 1.25rem', textDecoration: 'none', color: 'var(--stone-700)', border: '1px solid var(--amber-200)', transition: 'all 0.2s' }}
              >
                <ChevronRight size={16} style={{ color: '#D97706', flexShrink: 0 }} />
                <span style={{ fontWeight: 600, fontSize: '0.95rem' }}>{entry.label}</span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {serviceAreas.length > 0 && (
        <section className="py-section bg-white" style={{ borderTop: '1px solid var(--stone-100)' }}>
          <div className="section-container" style={{ maxWidth: '860px' }}>
            <h2 style={{ fontSize: '1.3rem', fontWeight: 700, marginBottom: '1.25rem' }}>
              可服務區域快速入口
            </h2>
            <p style={{ color: 'var(--stone-600)', fontSize: '0.92rem', lineHeight: 1.75, marginBottom: '1rem' }}>
              以下地區頁提供此產品的在地案例、丈量流程與估價導流，方便依居住區域快速比對。
            </p>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '0.9rem' }}>
              {serviceAreas.map(area => (
                <article
                  key={area.id}
                  style={{
                    border: '1px solid var(--stone-200)',
                    borderRadius: '0.85rem',
                    background: 'var(--stone-50)',
                    padding: '0.9rem 1rem',
                    display: 'flex',
                    flexDirection: 'column',
                    height: '100%',
                  }}
                >
                  <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: 'var(--stone-900)' }}>
                    {area.areaName}窗簾服務頁
                  </h3>
                  <p style={{ margin: '0.4rem 0 0 0', fontSize: '0.85rem', color: 'var(--stone-600)', lineHeight: 1.6 }}>
                    {area.shortDescription}
                  </p>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: '0.6rem', marginTop: 'auto', paddingTop: '0.8rem' }}>
                    <Link href={`/location/${area.id}/`} className="btn-outline" style={{ display: 'flex', width: '100%', minWidth: 0, boxSizing: 'border-box', minHeight: '3.35rem', justifyContent: 'center', alignItems: 'center', padding: '0.65rem 0.5rem', textAlign: 'center', lineHeight: 1.35, whiteSpace: 'normal' }}>
                      查看地區頁
                    </Link>
                    <Link href={buildCalculatorUrl(product.id, area.id)} className="btn-primary" style={{ display: 'flex', width: '100%', minWidth: 0, boxSizing: 'border-box', minHeight: '3.35rem', justifyContent: 'center', alignItems: 'center', padding: '0.65rem 0.5rem', textAlign: 'center', lineHeight: 1.35, whiteSpace: 'normal' }}>
                      直接帶入估價
                    </Link>
                  </div>
                </article>
              ))}
            </div>
            <div style={{ marginTop: '1rem', display: 'flex', flexWrap: 'wrap', gap: '0.75rem' }}>
              <Link href={buildCalculatorUrl(product.id, primaryAreaId)} className="btn-primary">
                <Calculator size={16} /> 直接估價此產品
              </Link>
              <Link href={buildCalculatorUrl(undefined, primaryAreaId)} className="btn-outline">
                前往整體估價頁
              </Link>
              <Link href="/location/" className="btn-secondary">
                查看 30 區總覽
              </Link>
            </div>
          </div>
        </section>
      )}

      {/* Related Products */}
      <section className="py-section bg-stone-50">
        <div className="section-container">
          <div className="section-heading">
            <h2>您可能也感興趣</h2>
          </div>
          <div className="product-grid">
            {relatedProducts.map(p => (
              <article key={p.id} className="product-card">
                <div className="product-card-img">
                  <img src={withBasePath(p.image)} alt={p.image_alt || p.name} loading="lazy" />
                </div>
                <div className="product-card-body">
                  <h3>{p.name}</h3>
                  <p>{p.description}</p>
                  <Link href={productPath(p)} className="btn-outline">
                    了解更多 <ChevronRight size={14} />
                  </Link>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
