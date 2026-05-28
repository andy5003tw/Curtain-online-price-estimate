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
    fullDesc: '一般窗簾是居家最經典的選擇，採用雙層布料設計，提供優異的遮光效果，同時具備良好的隔音性能。多種布料材質與花色任您挑選，從簡約到奢華皆有，搭配專業軌道系統，開合順暢且耐用，使用壽命長達十年以上。',
  },
  P002: {
    features: ['無縫設計、視覺更純淨', '透光不透人的遮蔽效果', '輕薄飄逸，極具美感', '適合搭配遮光布簾使用'],
    useCases: ['客廳', '餐廳', '書房'],
    fullDesc: '無縫紗簾採用特殊的無縫工藝，消除傳統紗簾因拼接造成的縫合線，讓整片紗簾呈現極致純淨的美感。輕薄透光的紗料在日光下如薄霧般飄逸，既保有隱私又不遮擋光線，是現代簡約裝潢的最佳搭配。',
  },
  P003: {
    features: ['獨特 S 型曲線設計', '布料垂墜感極佳', '適合落地窗使用', '展現現代奢華風格'],
    useCases: ['客廳落地窗', '主臥室', '高端商業空間'],
    fullDesc: '蛇形窗簾採用特殊夾的蛇形軌道系統，讓布料呈現整齊且完美的 S 型曲線垂墜感。相較於傳統窗簾的隨機皺褶，蛇形簾每個波浪間距一致，展現如精品店般的高端視覺效果。特別適合大型落地窗，讓空間瞬間升級到另一個層次。',
  },
  P004: {
    features: ['層次分明的摺疊設計', '收起時佔空間小', '多種布料選擇', '適合小窗與多窗格'],
    useCases: ['小窗', '廚房', '衛浴', '書房'],
    fullDesc: '羅馬簾以水平折疊的方式展開或收合，展開時布料平整且有層次感，收起時整齊利落不佔空間。羅馬簾特別適合不適合安裝傳統窗簾的空間，如窗戶較小、窗格較多的情況。選材豐富，從輕薄透光到厚重遮光布料皆有。',
  },
  P005: {
    features: ['操作簡單直覺', '不佔空間', '防潑水特性', '適合浴室廚房'],
    useCases: ['辦公室', '廚房', '浴室', '書房'],
    fullDesc: '想比較台北捲簾價格與三重捲簾價格，捲簾會是最容易快速評估的入門款式。整片布料圍繞頂部卷軸收合，不佔窗框空間，操作直覺且好清潔。搭配不同透光等級布料，可同時兼顧隱私、採光與預算控制。',
  },
  P006: {
    features: ['鋁合金材質堅固耐用', '精確調光', '防潮耐洗', '現代簡約外觀'],
    useCases: ['衛浴', '廚房', '辦公室'],
    fullDesc: '想比較台北鋁百葉窗價格與三重鋁百葉窗價格，鋁百葉是兼顧預算與耐用度的高實用選擇。鋁合金葉片可精準調光且防潮耐洗，特別適合浴室、廚房與需要高頻清潔的空間。',
  },
  P007: {
    features: ['天然木材質感溫潤', '提升空間高級感', '自然紋理獨一無二', '多種木種與色系'],
    useCases: ['客廳', '書房', '餐廳'],
    fullDesc: '想衝「實木百葉窗價格試算」排名時，建議先比較台北實木百葉窗價格與三重實木百葉窗價格，再依木種、葉片寬度與窗型縮小選項。先用窗簾線上估價抓預算區間，再安排丈量確認安裝條件，實木百葉窗價格試算會更接近正式報價。',
  },
  P008: {
    features: ['古樸東方韻味', '透氣性極佳', '輕盈自然材質', '環保天然'],
    useCases: ['日式空間', '禪風書房', '餐廳'],
    fullDesc: '竹簾以天然竹材編織而成，每根竹條都保留了竹子獨有的光澤與紋理。透過竹條的間隙，光線可以柔和地透入室內，同時保持良好的通風效果。特別適合日式、禪風、峇里島風格的空間裝潢，為室內帶來自然清新的氣息。',
  },
  P009: {
    features: ['蜂巢結構隔熱效果顯著', '節能省電', '隔音效果佳', '輕薄美觀'],
    useCases: ['客廳', '臥室', '節能住宅'],
    fullDesc: '台北風琴簾價格與三重風琴簾價格評估時，常會同步比較隔熱節能效益。風琴簾（蜂巢簾）採中空蜂巢結構，可有效阻隔熱傳導並提升室內舒適度，對西曬窗與臥室控溫特別有感。',
  },
  P010: {
    features: ['斑馬紋雙層交錯設計', '靈活切換透光/隱私模式', '現代時尚外觀', '操作便利'],
    useCases: ['客廳', '臥室', '辦公室'],
    fullDesc: '台北調光簾價格與三重調光簾價格常是屋主最常比較的項目之一。調光簾（斑馬簾）採雙層交錯條紋，可在透光與隱私模式間快速切換，特別適合需要日夜不同採光設定的客廳與臥室。',
  },
  P011: {
    features: ['葉片懸浮於兩層紗布間', '優雅柔和的光線效果', '高端質感', '獨特唯美設計'],
    useCases: ['主臥', '客廳', '飯店'],
    fullDesc: '柔紗簾是近年來最受歡迎的高端窗簾款式，葉片懸浮於兩層輕薄紗布之間，讓光線穿透後變得柔和而夢幻。相較於普通窗簾，柔紗簾的視覺效果更加精緻高端，通常出現於五星級飯店或高端住宅設計中。自然的光影效果讓室內充滿唯美氛圍。',
  },
  P012: {
    features: ['符合CNS 防燃標準', '抗菌特殊處理', '頂部網狀通風設計', '耐工業洗滌'],
    useCases: ['醫院', '診所', '護理之家', '公家機關'],
    fullDesc: '醫院窗簾（隔簾）專為醫療環境設計，布料經過防燃處理，符合消防法規的CNS防燃標準。同時具備抗菌功能，能有效抑制細菌滋生，維護醫療環境衛生。頂部採用特殊的網狀通風設計，確保空氣流通，適合安裝於病房、診療室等需要分隔空間的醫療環境。',
  },
  P013: {
    features: ['垂直葉片左右收合', '180 度葉片轉向調光', '適合大型落地窗', '線條俐落現代感'],
    useCases: ['大型落地窗', '辦公室', '商業空間'],
    fullDesc: '直立簾以垂直懸掛的葉片組成，可左右收合讓光線完全進入室內，也可旋轉葉片角度調整遮光程度，最大可旋轉至180度實現完全遮光。直立的線條設計在視覺上拉高空間感，特別適合寬幅的大型落地窗或辦公室隔間使用，展現現代洗鍊的辦公風格。',
  },
};

// Per-product extended SEO data
const productSeoExtras: Record<string, {
  reviews: { author: string; location: string; rating: number; text: string }[];
  priceTable: { label: string; range: string }[];
  lsiParagraph: string;
  relatedBlogIds: string[];
}> = {
  P001: {
    reviews: [
      { author: '陳小姐', location: '台北市大安區', rating: 5, text: '師傅量尺非常仔細，布料材質摸起來很厚實，安裝後遮光效果超好，睡覺不再被早上的陽光吵醒！' },
      { author: '林先生', location: '新北市三重區', rating: 5, text: '從選布到安裝一條龍，價格比想像的合理，工廠直營果然不一樣，強烈推薦！' },
      { author: '王太太', location: '新北市板橋區', rating: 5, text: '已經是第二次找宏森了，這次換客廳的大落地窗布簾，垂墜感超美，非常滿意。' },
    ],
    priceTable: [
      { label: '標準半腰窗 (150×150 cm)', range: '約 NT$ 1,800 – 2,800 起' },
      { label: '標準落地窗 (200×240 cm)', range: '約 NT$ 3,500 – 5,500 起' },
      { label: '客廳大景窗 (300×240 cm)', range: '約 NT$ 5,000 – 8,000 起' },
    ],
    lsiParagraph: '一般布簾（cloth curtains）是台灣居家最普及的窗簾選擇，適用於客廳落地窗、主臥室、書房及辦公室。常見的布料材質包含三明治遮光布、麻布、天鵝絨及雪尼爾，各有不同的遮光係數與觸感。相較於捲簾或百葉窗，布簾更能展現空間的溫馨氛圍與個人風格，是大台北地區訂製窗簾的最熱門款式之一。若您在尋找台北市或新北市的布簾訂製服務，宏森窗簾工廠直營，提供免費到府丈量與現場樣本挑選，讓您一次搞定窗簾選購的所有疑問。',
    relatedBlogIds: ['blog-001', 'blog-002'],
  },
  P002: {
    reviews: [
      { author: '蔡小姐', location: '台北市中正區', rating: 5, text: '無縫紗簾裝上去整個空間變得很有質感，白天透光但鄰居看不進來，完全符合需求。' },
      { author: '黃先生', location: '新北市新莊區', rating: 5, text: '師傅安裝很有經驗，紗簾選色也給了很好的建議，搭配遮光布簾效果超好！' },
    ],
    priceTable: [
      { label: '標準半腰窗紗簾 (150×150 cm)', range: '約 NT$ 1,200 – 2,000 起' },
      { label: '落地窗紗簾 (200×240 cm)', range: '約 NT$ 2,200 – 3,800 起' },
    ],
    lsiParagraph: '無縫紗簾是近年來深受現代簡約風格愛好者青睞的窗簾款式。因採用無縫工藝，整片紗簾沒有縫合線，呈現最純淨的視覺效果。透光不透人的特性讓白天自然光可以柔和透入，同時保有隱私。非常適合搭配同一軌道上的遮光布簾，形成雙層窗簾系統，白天拉紗簾、夜晚拉遮光布，功能性極佳。台北市、新北市各區均可提供免費到府量尺服務。',
    relatedBlogIds: ['blog-001'],
  },
  P003: {
    reviews: [
      { author: '江小姐', location: '台北市信義區', rating: 5, text: '蛇形簾的波浪弧度真的超漂亮，打開時每個褶子間距都一樣，比精品飯店還有質感！' },
      { author: '張先生', location: '新北市永和區', rating: 5, text: '特意為客廳大落地窗換成蛇形簾，整個空間瞬間升級，朋友來都誇讚。師傅施工也很俐落。' },
      { author: '許太太', location: '台北市大安區', rating: 5, text: '顏色選擇很多，最後選了深灰色，垂墜感一流，跟北歐風裝潢完美搭配，推薦！' },
    ],
    priceTable: [
      { label: '蛇形軌道半腰窗 (150×150 cm)', range: '約 NT$ 2,800 – 4,500 起' },
      { label: '蛇形軌道落地窗 (200×240 cm)', range: '約 NT$ 5,000 – 8,000 起' },
      { label: '大型落地窗 (300×240 cm)', range: '約 NT$ 7,500 – 12,000 起' },
    ],
    lsiParagraph: '蛇形窗簾（S-fold curtains）是目前高端住宅與商業酒店最受歡迎的窗簾款式，透過專屬的蛇形軌道夾，讓布料呈現完美且等間距的 S 型曲線，視覺效果遠優於傳統打褶布簾。台北信義區、大安區、新北市永和區等精裝住宅大量採用。宏森工廠可依您的窗幅客製化每個波浪密度，提供最完美的垂墜比例，免費到府丈量，現場確認效果。',
    relatedBlogIds: ['blog-001'],
  },
  P004: {
    reviews: [
      { author: '劉小姐', location: '台北市文山區', rating: 5, text: '廚房窗戶很不規則，師傅量完之後做出來的羅馬簾完全貼合，摺疊效果很漂亮。' },
      { author: '吳先生', location: '新北市蘆洲區', rating: 5, text: '書房用半透光的羅馬簾，既有隱私又有採光，整體很清爽，選料過程師傅建議很專業。' },
    ],
    priceTable: [
      { label: '小型窗羅馬簾 (60×100 cm)', range: '約 NT$ 1,500 – 2,500 起' },
      { label: '標準窗羅馬簾 (120×150 cm)', range: '約 NT$ 2,500 – 4,000 起' },
    ],
    lsiParagraph: '羅馬簾（Roman Shade）以水平折疊的精巧設計，是小空間與多窗格環境的最佳解方。相較於傳統布簾佔用大量左右空間，羅馬簾收合後幾乎不佔窗框面積，適合廚房、浴室、衛浴等小窗戶或多扇窗的空間。宏森開發提供各種材質選擇，從半透光到全遮光，從純棉到防水布料，依您的需求量身訂製，歡迎預約台北市與新北市各區免費到府丈量。',
    relatedBlogIds: ['blog-001'],
  },
  P005: {
    reviews: [
      { author: '陳先生', location: '台北市中山區', rating: 5, text: '辦公室全部換成捲簾，拉起來整整齊齊的，開會投影也完全不漏光，非常實用！' },
      { author: '林小姐', location: '新北市板橋區', rating: 5, text: '廚房的捲簾防潑水效果真的很好，油煙濺上去用濕布一擦就乾淨，超級好保養！' },
      { author: '朱先生', location: '台北市內湖區', rating: 5, text: '從丈量到安裝不到一週，速度很快，捲簾效果也符合預期，價格合理。' },
    ],
    priceTable: [
      { label: '標準捲簾 (80×150 cm)', range: '約 NT$ 800 – 1,500 起' },
      { label: '標準捲簾 (150×180 cm)', range: '約 NT$ 1,500 – 2,800 起' },
      { label: '辦公室大型捲簾 (200×200 cm)', range: '約 NT$ 2,800 – 5,000 起' },
    ],
    lsiParagraph: '台北捲簾價格與三重捲簾價格差異，通常來自布料等級、透光係數與安裝條件。捲簾（Roll Screen）整體結構簡潔、清潔便利，是辦公室與住宅都常見的高CP值選擇。若想先抓預算，建議先用窗簾計算機完成初步試算，再搭配現場丈量確認五金與施工細節，窗簾報價會更精準。',
    relatedBlogIds: ['blog-001'],
  },
  P006: {
    reviews: [
      { author: '蘇太太', location: '台北市南港區', rating: 5, text: '浴室安裝鋁百葉，旋轉葉片可以精確控制角度，通風採光兩不誤，比裝霧面玻璃還實用。' },
      { author: '鄭先生', location: '新北市中和區', rating: 5, text: '廚房窗戶用鋁百葉，防水防潮效果真的很好，已經用了三年完全沒有任何問題。' },
    ],
    priceTable: [
      { label: '鋁百葉 (80×120 cm)', range: '約 NT$ 1,200 – 2,000 起' },
      { label: '鋁百葉 (150×180 cm)', range: '約 NT$ 2,200 – 3,500 起' },
    ],
    lsiParagraph: '台北鋁百葉窗價格與三重鋁百葉窗價格，通常會因葉片寬度、烤漆等級、窗型與安裝位置而有差異。鋁百葉窗簾（Venetian Blind）以鋁合金葉片為核心，具備防潮、防水、好清潔特性，特別適合浴室與廚房。若想先抓預算，建議先用窗簾估價工具輸入尺寸，再由現場丈量確認細節，窗簾報價會更精準。',
    relatedBlogIds: ['blog-001'],
  },
  P007: {
    reviews: [
      { author: '何小姐', location: '台北市士林區', rating: 5, text: '木百葉的質感真的沒話說，書房裝上去整個變高級了！陽光斜透進來的感覺超美。' },
      { author: '廖先生', location: '新北市淡水區', rating: 5, text: '選了深胡桃木色，搭配原木家具超級協調。師傅說材質是真正的木頭，觸感完全不一樣！' },
      { author: '馮太太', location: '台北市北投區', rating: 5, text: '客廳與書房一起換，師傅很有耐心地解說各種木種差異，最後選到最喜歡的款式。' },
    ],
    priceTable: [
      { label: '木百葉 (80×120 cm)', range: '約 NT$ 2,500 – 4,500 起' },
      { label: '木百葉 (150×180 cm)', range: '約 NT$ 4,500 – 8,000 起' },
    ],
    lsiParagraph: '實木百葉窗價格試算最常受木種、葉片寬度、表面塗裝與施工條件影響。台北實木百葉窗價格與三重實木百葉窗價格不一定誰高誰低，重點在窗型與配件是否一致。建議先用窗簾計算機以同尺寸試算，再到府丈量確認窗型、安裝高度與五金規格，讓實木百葉窗價格試算與正式報價更貼近。',
    relatedBlogIds: ['blog-001'],
  },
  P008: {
    reviews: [
      { author: '羅先生', location: '台北市大同區', rating: 5, text: '日式茶室裝了竹簾，整個空間的禪意感直接提升三個等級，來訪的客人都問在哪裡買的！' },
      { author: '葉小姐', location: '新北市三峽區', rating: 5, text: '竹簾透光效果很自然，光線進來感覺柔和很多，配上綠色植物真的很美。' },
    ],
    priceTable: [
      { label: '竹簾 (90×150 cm)', range: '約 NT$ 1,500 – 2,500 起' },
      { label: '竹簾 (150×180 cm)', range: '約 NT$ 2,800 – 4,500 起' },
    ],
    lsiParagraph: '竹簾（Bamboo Blind）以天然竹材手工編織而成，每根竹條保留竹子獨有的光澤與紋理，透過竹條間隙讓光線柔和地透入室內，同時保持良好通風。特別適合打造日式、禪風、峇里島度假風格的空間。台北市大同區、新北市三峽區等注重自然生活美感的區域廣受歡迎。宏森使用優質原竹材料，提供多種編織密度選擇，兼顧遮蔽效果與通風需求。',
    relatedBlogIds: ['blog-001'],
  },
  P009: {
    reviews: [
      { author: '李先生', location: '台北市信義區', rating: 5, text: '西曬房裝了風琴簾，體感溫度明顯下降很多，冷氣開小一點就夠了，真的有節省電費！' },
      { author: '謝小姐', location: '新北市新店區', rating: 5, text: '蜂巢簾的結構很特別，光線透進來很柔和不刺眼，睡覺品質提升很多，強烈推薦！' },
      { author: '周太太', location: '台北市中正區', rating: 5, text: '師傅特別說明蜂巢簾的隔熱原理，選了上下都能開合的款式，功能性很強大。' },
    ],
    priceTable: [
      { label: '蜂巢簾 (120×150 cm)', range: '約 NT$ 3,500 – 6,000 起' },
      { label: '蜂巢簾 (200×240 cm)', range: '約 NT$ 6,000 – 10,000 起' },
    ],
    lsiParagraph: '台北風琴簾價格與三重風琴簾價格評估時，除了尺寸，透光等級、蜂巢層數與控制配件也會影響最終金額。風琴簾（蜂巢簾，Honeycomb Shade）利用中空結構減少熱傳導，對西曬窗與臥室控溫特別有感。建議先用窗簾計算機做初步估價，再安排到府丈量確認安裝條件，窗簾報價流程會更透明。',
    relatedBlogIds: ['blog-001'],
  },
  P010: {
    reviews: [
      { author: '徐小姐', location: '台北市松山區', rating: 5, text: '斑馬簾真的很有現代感，調整條紋對齊的角度就能控制光線，設計感和實用性都有！' },
      { author: '楊先生', location: '新北市汐止區', rating: 5, text: '辦公室換了調光簾之後，開會不再被強烈陽光干擾，又不影響整體採光，太棒了！' },
      { author: '潘太太', location: '台北市中山區', rating: 5, text: '臥室選了灰色調光簾，白天自然採光、夜晚完全遮光，操作很簡單，選對了！' },
    ],
    priceTable: [
      { label: '調光簾 (120×150 cm)', range: '約 NT$ 2,500 – 4,500 起' },
      { label: '調光簾 (200×240 cm)', range: '約 NT$ 4,500 – 7,500 起' },
    ],
    lsiParagraph: '台北調光簾價格與三重調光簾價格評估時，除了尺寸外，條紋密度、遮光等級與控制配件是主要差異。調光簾（Zebra Blind）能在透光與隱私之間快速切換，外觀俐落，特別適合現代住宅與商辦空間。先用窗簾計算機估價、再到府丈量，可更快確認最適規格。',
    relatedBlogIds: ['blog-001'],
  },
  P011: {
    reviews: [
      { author: '馬小姐', location: '台北市大安區', rating: 5, text: '柔紗簾是我見過最漂亮的窗簾！光線透進來會有薄霧感，整個臥室變得超夢幻！' },
      { author: '吳先生', location: '新北市永和區', rating: 5, text: '以前看飯店的窗簾一直很羨慕，沒想到宏森也可以做出一樣的效果，而且價格很合理。' },
    ],
    priceTable: [
      { label: '柔紗簾 (150×210 cm)', range: '約 NT$ 4,500 – 7,500 起' },
      { label: '柔紗簾 (200×240 cm)', range: '約 NT$ 6,000 – 10,000 起' },
    ],
    lsiParagraph: '柔紗簾（Sheer Shade）是目前高端住宅與精品飯店最熱門的窗簾款式，葉片懸浮於兩層輕薄紗布之間，讓光線穿透後呈現柔和夢幻的光影效果。台北市大安區、信義區的豪宅社區與精品飯店大量採用柔紗簾來提升空間質感。宏森可依您的偏好調整葉片角度與顏色，打造屬於您的獨特光影美學。歡迎預約免費到府量尺，親眼感受柔紗簾的夢幻效果。',
    relatedBlogIds: ['blog-001'],
  },
  P012: {
    reviews: [
      { author: '趙護理長', location: '台北市士林區某醫院', rating: 5, text: '符合CNS防焰標準，通過醫院採購評審。安裝過程很順利，師傅有處理醫療院所施工的經驗。' },
      { author: '陳院長', location: '新北市某診所', rating: 5, text: '醫療空間最重視防焰與清潔，宏森的隔簾完全符合規格，且抗菌處理讓感染風險降低。' },
    ],
    priceTable: [
      { label: '醫院隔簾 (120×200 cm)', range: '約 NT$ 2,000 – 3,500 起' },
      { label: '醫院隔簾 (200×200 cm)', range: '約 NT$ 3,500 – 6,000 起' },
    ],
    lsiParagraph: '醫院窗簾（隔簾）是醫療院所的專業需求，必須符合CNS 1220防燃標準才能通過消防安全規定。宏森所提供的醫院隔簾除了取得防焰標籤認證，更經過抗菌特殊處理，有效抑制細菌繁殖，適用於病房、診療室、護理站等醫療空間。頂部網狀通風設計確保空氣流通，布料可承受工業等級的高溫洗滌。服務範圍涵蓋台北市、新北市各大醫院、診所、護理之家、公家機關等醫療相關場所。',
    relatedBlogIds: ['blog-001'],
  },
  P013: {
    reviews: [
      { author: '游先生', location: '台北市信義區某辦公室', rating: 5, text: '公司的大型落地玻璃牆換了直立簾，視覺上整個空間變得更高挑，開合也超級順暢！' },
      { author: '范小姐', location: '新北市林口區', rating: 5, text: '別墅的超寬落地窗用直立簾，左右可以分開控制，宴客時全開效果很氣派。' },
      { author: '石先生', location: '台北市內湖區', rating: 5, text: '商業辦公室用直立簾很容易維護，壞掉只需換單片葉片即可，貼心的設計。' },
    ],
    priceTable: [
      { label: '直立簾 (200×210 cm)', range: '約 NT$ 3,000 – 5,500 起' },
      { label: '直立簾 (300×240 cm)', range: '約 NT$ 5,500 – 9,500 起' },
    ],
    lsiParagraph: '直立簾（Vertical Blind）以垂直懸掛的葉片組成，可完全左右收合或旋轉至180度實現完全遮光，垂直線條設計在視覺上拉高空間感，特別適合寬幅大型落地窗。台北市信義區辦公大樓、內湖科技園區、新北市林口區商辦廣泛採用直立簾做為空間分隔與遮陽解決方案。宏森直立簾設計易於日常維護，單片葉片損壞時可單獨更換，無需整組拆除，大台北地區提供免費到府量尺報價。',
    relatedBlogIds: ['blog-001'],
  },
};

const defaultSeoExtras = {
  reviews: [
    { author: '客戶評價', location: '台北市', rating: 5, text: '宏森窗簾服務專業，師傅施工細心，品質令人滿意，誠摯推薦給有需要的朋友！' },
  ],
  priceTable: [
    { label: '標準半腰窗', range: '約 NT$ 1,800 – 3,500 起' },
    { label: '標準落地窗', range: '約 NT$ 3,500 – 6,500 起' },
  ],
  lsiParagraph: '宏森開發有限公司自1996年深耕大台北窗簾市場，提供台北市、新北市各行政區（包含三重、蘆洲、板橋、新莊、永和、中和、林口等）的專業到府丈量與施工服務。所有產品均來自自有工廠監製，確保品質一致。歡迎線上估價或致電洽詢免費丈量預約。',
  relatedBlogIds: ['blog-001'],
};

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
      { q: '一般布簾如何清洗保養？', a: '大多數布簾材質可以直接拆下使用洗衣機冷水輕柔洗滌，洗後陰乾拉平即可恢復平整。三明治遮光布建議乾洗或以濕布輕擦。宏森選用的布料皆附有洗滌說明標籤。' },
      { q: '布簾可以做到完全遮光嗎？', a: '可以。選擇三層夾心的「三明治遮光布」或在布料背面加貼遮光塗層，即可達到接近 100% 的遮光效果，非常適合需要完全避光的臥室或視聽室。' },
      { q: '布簾和蛇形簾有什麼差異？', a: '一般布簾使用傳統打褶或2.5倍寬鬆比例製作，波浪較隨意自然。蛇形簾則使用專屬鉤夾讓每個波浪間距完全一致，展現高端精品感，但價格也較高。' },
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
      { q: '紗簾可以單獨使用嗎？', a: '可以。單獨使用紗簾時，白天採光充足、視覺通透，適合客廳或書房。如需夜晚隱私，建議搭配遮光布簾形成雙層系統，功能性更完整。' },
      { q: '無縫紗簾和一般縫合紗簾有什麼差別？', a: '一般紗簾在拼接處有縫合線，在強光照射下會顯現接縫痕跡，視覺較不美觀。無縫紗簾採用整幅布料，沒有接縫，在任何角度光線下都呈現均勻純淨的效果。' },
      { q: '紗簾容易褪色嗎？', a: '宏森選用的紗簾布料均經過UV防褪色處理，在正常室內使用情況下，顏色可穩定維持3-5年以上。避免長期曝曬強烈直射陽光可延長使用壽命。' },
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
      { q: '蛇形窗簾適合哪種裝潢風格？', a: '蛇形窗簾最適合現代簡約、輕奢、北歐及精品飯店風格。完美的S型曲線讓空間一眼就看起來非常精緻高端。不適合鄉村風或傳統中式風格。' },
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
      { q: '台北捲簾價格與三重捲簾價格怎麼估算？', a: '先以窗戶寬高套用估價工具抓到基礎區間，再由丈量確認布料等級、五金與安裝條件，即可得到最終報價。' },
      { q: '捲簾可以做到完全遮光嗎？', a: '可以。選擇全遮光布料，並採窗框貼合式安裝，可大幅降低漏光；若是臥室用途可再加側邊遮光配件。' },
      { q: '辦公室捲簾或廚房捲簾好清潔嗎？', a: '捲簾布料多可直接用濕布擦拭，防潑水材質更容易保養，屬於日常維護成本較低的窗簾類型。' },
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
      { q: '台北鋁百葉窗價格、三重鋁百葉窗價格怎麼估算？', a: '先輸入窗戶尺寸做線上估價，再由丈量確認葉片寬度、安裝位置與五金配件，能快速得到台北與三重更接近實際施工的鋁百葉報價。' },
      { q: '鋁百葉和木百葉哪個更適合潮濕空間？', a: '潮濕空間優先選鋁百葉。鋁合金葉片防潮好清潔，適合浴室與廚房；木百葉偏重質感與木紋風格，較適合客廳與書房等乾燥空間。' },
      { q: '鋁百葉可以先線上估價再安排丈量嗎？', a: '可以。建議先用窗簾計算機抓預算，再安排到府丈量確認窗型與安裝細節，整體窗簾報價會更準確且流程更有效率。' },
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
      { q: '實木百葉窗價格試算要先看哪 3 個變數？', a: '先看木種、葉片寬度與窗型施工條件。三個變數一致時，台北實木百葉窗價格與三重實木百葉窗價格才有可比性。建議先用線上估價工具輸入尺寸，再安排丈量確認。' },
      { q: '台北實木百葉窗價格、三重實木百葉窗價格差在哪裡？', a: '主要差在木種等級、塗裝與現場施工條件（例如高窗、轉角窗、特殊五金）。先做實木百葉窗價格試算，再比同規格報價，判斷會更準確。' },
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
      { q: '竹簾遮光效果好嗎？', a: '竹簾因為竹條之間有縫隙，遮光效果屬於「過濾光線」而非「完全遮光」。日光透過竹條縫隙進來後，光線會變得柔和自然。如需完全遮光，建議在竹簾後方加掛遮光布簾。' },
      { q: '竹簾適合多雨潮濕的氣候嗎？', a: '竹簾對濕度有一定的適應性，但長期高濕度環境可能導致竹材輕微變形或褪色。建議室內通風良好，避免長期雨水直接淋濕。若在浴室或高濕度空間使用，建議選擇鋁百葉或防水材質的窗簾。' },
      { q: '竹簾台灣氣候適合嗎？', a: '台灣人已使用竹簾數十年以上，在一般居室環境下耐用性良好。宏森選用優質竹材，並經過防蟲防霉處理，確保在台灣氣候下的使用壽命。夏日搭配竹簾可讓室內保有通風感，非常清爽。' },
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
      { q: '台北風琴簾價格、三重風琴簾價格怎麼抓預算？', a: '可先用線上估價工具輸入尺寸抓區間，再由丈量確認透光等級、蜂巢層數與控制配件，能更精準比較台北與三重的風琴簾報價。' },
      { q: '風琴簾（蜂巢簾）真的有隔熱與節能效果嗎？', a: '有。蜂巢中空結構可形成空氣層，減少熱傳導，對西曬窗與臥室溫控很有幫助。實際節能效果會依窗向、使用習慣與空調設定而不同。' },
      { q: '可以先估價再決定是否安排丈量嗎？', a: '可以，先用窗簾計算機做初步估價，再安排到府丈量確認細節，能讓窗簾報價與施工規劃更透明。' },
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
      { q: '台北調光簾價格與三重調光簾價格怎麼比較？', a: '可先用估價工具輸入尺寸，再依布料條紋寬度、遮光等級與配件規格做進一步比對，能更快抓到合理預算。' },
      { q: '調光簾可以完全遮光嗎？', a: '調光簾在條紋完全交錯時可達高度遮光，但並非100%全黑。若臥室需極致遮光，可搭配全遮光布料或改用全遮光捲簾。' },
      { q: '調光簾耐用嗎、後續維護麻煩嗎？', a: '正常使用下相當耐用，平時以乾布或除塵撢清潔即可，避免大力拉扯與水洗可延長使用壽命。' },
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
      { q: '柔紗簾的保養方式？', a: '柔紗簾的紗布層非常精緻，建議使用冷風吹塵或用軟毛刷輕輕除塵，避免水洗或以吸塵器用力吸取，以防損傷纖薄的紗布。若出現嚴重汙漬，建議交由專業洗衣店乾洗處理。' },
      { q: '柔紗簾和調光簾有什麼差別？', a: '柔紗簾的葉片懸浮在兩層紗布之間，光線透過後柔和優美，更有夢幻高端的飯店質感，適合高端住宅。調光簾則是簡潔俐落的條紋設計，更偏現代時尚風格，功能性强、清潔便利，適合辦公或休閒空間。' },
      { q: '柔紗簾適合哪些空間？', a: '柔紗簾最適合主臥室（製造唯美放鬆氛圍）、精品飯店客房、高端餐廳或奢華客廳。因為它傳遞給人的感受是高貴夢幻，所以通常在注重視覺美感的空間最能發揮其價值。' },
    ],
    material: '超細纖維紗布（兩層）夾入布料葉片，纖薄高透光材質',
    colorOptions: '白色、米白、香檳色、淡灰等10種，柔和色調為主',
    comparisons: [
      { feature: '高端質感', thisProduct: '★★★★★（飯店級）', vs1: '★★★', vs1Name: '捲簾' },
      { feature: '光線柔化效果', thisProduct: '★★★★★', vs1: '★★★', vs1Name: '布簾' },
      { feature: '清潔難易度', thisProduct: '★★（需小心保養）', vs1: '★★★★★', vs1Name: '捲簾' },
      { feature: '價格親和度', thisProduct: '★★（高端款）', vs1: '★★★★★', vs1Name: '布簾' },
    ],
    galleryDesc: '柔紗簾五星級飯店風主臥室施工案例',
  },
  P012: {
    faqs: [
      { q: '醫院窗簾需要符合哪些法規？', a: '依台灣消防法規，醫療院所的窗簾必須通過CNS 1220防燃標準測試，並取得防焰標籤認證。宏森提供的醫院隔簾均已通過此認證，可提供正式防焰測試報告，協助醫療機構通過消防稽查。' },
      { q: '醫院隔簾多久需要更換？', a: '醫院隔簾依使用頻率與洗滌次數而定，一般建議每2-3年更換一次以確保抗菌效果。宏森可提供大批量的採購服務，協助醫療院所定期更換，並可配合院所的洗滌習慣選擇合適的布料厚度。' },
      { q: '抗菌處理是永久的嗎？', a: '抗菌處理通常可以維持30-50次的工業洗滌週期。超過此次數後，抗菌效果會逐漸降低，建議配合更換新隔簾或向廠商詢問抗菌重新處理的服務。' },
    ],
    material: '防燃聚酯纖維布料（符合CNS 1220防焰標準），頂部網狀通風設計',
    colorOptions: '醫院藍、醫療綠、白色、米白等8種標準醫療色系',
    comparisons: [
      { feature: 'CNS防焰認證', thisProduct: '★★★★★（標準認證）', vs1: '★★', vs1Name: '一般布簾' },
      { feature: '抗菌處理', thisProduct: '★★★★★', vs1: '★', vs1Name: '一般窗簾' },
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
    { src: '/images/P012_hospital curtains03.webp', alt: '醫院隔簾防焰抗菌布料特寫展示' },
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
    { '@type': 'HowToStep', position: 3, name: '工廠訂製製作', text: '確認訂單後，自有工廠開始裁剪縫製，精心監督每道工序，確保品質達到最高標準。' },
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
    offers: {
      '@type': 'Offer',
      '@id': `${canonicalProductUrl}#offer`,
      url: canonicalProductUrl,
      priceCurrency: 'TWD',
      price: (product.pricing as any).unit_price || 0,
      availability: 'https://schema.org/InStock',
      seller: { '@type': 'Organization', name: COMPANY_NAME },
      itemCondition: 'https://schema.org/NewCondition',
    }
  };

  const extras = productSeoExtras[product.id] || defaultSeoExtras;
  const v3 = productV3Data[product.id] || { faqs: [], material: '聚酯纖維', colorOptions: '多種顏色可選', comparisons: [], galleryDesc: '' };
  const gallery = (productGallery[product.id] || []).map((item) => ({
    ...item,
    src: withBasePath(item.src),
  }));
  const relatedProducts = products.filter(p => p.id !== product.id).slice(0, 4);
  const serviceAreas = getServiceAreasForProduct(product.id, 6);
  const primaryAreaId = serviceAreas[0]?.id;
  const productHeroTitleMap: Record<string, string> = {
    P005: '台北捲簾價格、三重捲簾價格與捲簾訂製服務',
    P006: '台北鋁百葉窗價格、三重鋁百葉窗價格與鋁百葉訂製服務',
    P007: '實木百葉窗價格試算｜台北實木百葉窗價格、三重實木百葉窗價格與安裝費',
    P009: '台北風琴簾價格、三重風琴簾價格與蜂巢簾訂製服務',
    P010: '台北調光簾價格、三重調光簾價格與斑馬簾訂製服務',
  };
  const productInternalLinksMap: Record<string, Array<{ href: string; label: string }>> = {
    P005: [
      { href: '/location/taipei/', label: '台北窗簾推薦與台北窗簾訂製服務' },
      { href: '/location/sanchong/', label: '三重窗簾推薦與三重窗簾訂製服務' },
      { href: '/blog/curtain-price-guide-2026/', label: '訂製窗簾價格、窗簾訂做價格與窗簾報價指南' },
      { href: '/calculator/', label: '立即進入窗簾線上估價，試算捲簾價格與安裝費' },
    ],
    P006: [
      { href: '/location/banqiao/', label: '板橋窗簾推薦與板橋窗簾訂製服務' },
      { href: '/location/xinzhuang/', label: '新莊窗簾推薦與新莊窗簾訂製服務' },
      { href: '/blog/curtain-price-guide-2026/', label: '訂製窗簾價格、窗簾訂做價格與窗簾報價指南' },
      { href: '/calculator/', label: '立即進入窗簾線上估價，試算鋁百葉窗價格與安裝費' },
    ],
    P007: [
      { href: '/location/sanchong/', label: '三重窗簾價格試算入口：對照實木百葉窗價格' },
      { href: '/location/taipei/', label: '台北窗簾價格試算入口：對照實木百葉窗價格' },
      { href: '/blog/curtain-price-guide-2026/', label: '2026 窗簾價格指南：實木百葉窗價格試算與安裝費' },
      { href: '/calculator/?product=P007', label: '木百葉專屬估價：立即做實木百葉窗價格試算' },
    ],
    P009: [
      { href: '/location/banqiao/', label: '板橋窗簾推薦與板橋窗簾訂製服務' },
      { href: '/location/xinzhuang/', label: '新莊窗簾推薦與新莊窗簾訂製服務' },
      { href: '/blog/curtain-price-guide-2026/', label: '訂製窗簾價格、窗簾訂做價格與窗簾報價指南' },
      { href: '/calculator/', label: '立即進入窗簾線上估價，試算風琴簾價格與安裝費' },
    ],
    P010: [
      { href: '/location/taipei/', label: '台北窗簾推薦與台北窗簾訂製服務' },
      { href: '/location/sanchong/', label: '三重窗簾推薦與三重窗簾訂製服務' },
      { href: '/blog/curtain-price-guide-2026/', label: '訂製窗簾價格、窗簾訂做價格與窗簾報價指南' },
      { href: '/calculator/', label: '立即進入窗簾線上估價，試算調光簾價格與安裝費' },
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

  const visibleReviewCount = extras.reviews.length;
  const visibleAverageRating = visibleReviewCount
    ? (extras.reviews.reduce((sum, review) => sum + review.rating, 0) / visibleReviewCount).toFixed(1)
    : '5.0';

  const productSchemaWithReviews = {
    ...productSchema,
    material: v3.material,
    color: v3.colorOptions,
    review: extras.reviews.map(r => ({
      '@type': 'Review',
      author: { '@type': 'Person', name: r.author },
      reviewRating: { '@type': 'Rating', ratingValue: String(r.rating), bestRating: '5' },
      reviewBody: r.text,
    })),
  };

  const faqSchema = v3.faqs.length > 0 ? {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: v3.faqs.map(f => ({
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
      productSchemaWithReviews,
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
              <p style={{ color: 'var(--stone-600)', lineHeight: 1.9, marginBottom: '1.5rem', fontSize: '1rem' }}>
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
                  立即估價
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
          <p style={{ marginTop: '1rem', fontSize: '0.8rem', color: 'var(--stone-400)', textAlign: 'center' }}>✦ 大台北地區免費到府丈量 · 報價當場確認無隱藏費用</p>
          <div style={{ marginTop: '1.5rem', textAlign: 'center' }}>
            <Link href={buildCalculatorUrl(product.id)} className="btn-primary">
              <Calculator size={16} /> 直接線上估算我的費用
            </Link>
          </div>
        </div>
      </section>

      {/* 3. Customer Reviews */}
      <section className="py-section bg-stone-50">
        <div className="section-container" style={{ maxWidth: '860px' }}>
          <div className="section-heading">
            <h2>真實顧客評價</h2>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', justifyContent: 'center', marginTop: '0.5rem' }}>
              <div style={{ display: 'flex', color: '#D97706' }}>{'★★★★★'.split('').map((s, i) => <span key={i} style={{ fontSize: '1.2rem' }}>{s}</span>)}</div>
              <span style={{ fontWeight: 700, color: '#92400E' }}>{visibleAverageRating} / 5</span>
              <span style={{ fontSize: '0.85rem', color: 'var(--stone-500)' }}>(本頁列出 {visibleReviewCount} 則評價)</span>
            </div>
          </div>
          <div style={{ display: 'grid', gap: '1.25rem' }}>
            {extras.reviews.map((r, i) => (
              <div key={i} style={{ background: 'white', borderRadius: '1rem', padding: '1.5rem', boxShadow: '0 2px 8px rgba(0,0,0,0.04)', border: '1px solid var(--stone-100)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.75rem', flexWrap: 'wrap', gap: '0.5rem' }}>
                  <div>
                    <span style={{ fontWeight: 700, fontSize: '0.95rem' }}>{r.author}</span>
                    <span style={{ fontSize: '0.8rem', color: 'var(--stone-500)', marginLeft: '0.5rem' }}>{r.location}</span>
                  </div>
                  <div style={{ display: 'flex', color: '#D97706' }}>{'★'.repeat(r.rating).split('').map((s, idx) => <span key={idx}>{s}</span>)}</div>
                </div>
                <p style={{ fontSize: '0.9rem', color: 'var(--stone-600)', lineHeight: 1.7, margin: 0 }}>{r.text}</p>
              </div>
            ))}
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
              <p style={{ fontWeight: 600, color: 'var(--stone-800)', fontSize: '0.95rem', margin: 0 }}>自有工廠監製 · 客製化裁剪 · 30年製版經驗</p>
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
      {v3.faqs.length > 0 && (
        <section className="py-section bg-white">
          <div className="section-container" style={{ maxWidth: '860px' }}>
            <div className="section-heading">
              <h2>{product.name}常見問題 FAQ</h2>
            </div>
            <div style={{ display: 'grid', gap: '1rem' }}>
              {v3.faqs.map((faq, i) => (
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
                  }}
                >
                  <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: 'var(--stone-900)' }}>
                    {area.areaName}窗簾服務頁
                  </h3>
                  <p style={{ margin: '0.4rem 0 0 0', fontSize: '0.85rem', color: 'var(--stone-600)', lineHeight: 1.6 }}>
                    {area.shortDescription}
                  </p>
                  <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.8rem', flexWrap: 'wrap' }}>
                    <Link href={`/location/${area.id}/`} className="btn-outline" style={{ flex: 1, justifyContent: 'center' }}>
                      查看地區頁
                    </Link>
                    <Link href={buildCalculatorUrl(product.id, area.id)} className="btn-primary" style={{ flex: 1, justifyContent: 'center' }}>
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
