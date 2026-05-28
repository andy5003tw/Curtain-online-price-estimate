export const knowledgeCategories = [
  { id: 'buying-guides', name: '空間挑選指南' },
  { id: 'product-deep-dives', name: '款式與材質解析' },
  { id: 'budgeting', name: '預算與價格分析' },
  { id: 'maintenance', name: '保養與清潔技巧' },
  { id: 'installation', name: '丈量與安裝指南' },
];

export const knowledgeTags = [
  '一般窗簾', '無縫紗簾', '蛇形窗簾', '醫院窗簾', '羅馬簾', '捲簾', 
  '鋁百葉窗簾', '木百葉窗簾', '竹簾', '風琴簾', '調光簾', '柔紗簾', '直立簾',
  '客廳窗簾', '臥室窗簾', '防潮', '遮光', '隔熱'
];

export interface FAQ {
  question: string;
  answer: string;
}

export interface KnowledgePost {
  id: string;
  title: string;
  description: string;
  category: string;
  tags: string[];
  date: string;
  readMin: number;
  coverImage: string;
  contentHtml: string;
  faqs?: FAQ[];
}

export const knowledgePosts: KnowledgePost[] = [
  {
    id: 'buying-guide-for-different-spaces',
    title: '窗簾怎麼挑？客廳、臥室、衛浴的終極窗簾挑選指南',
    description: '買窗簾不知道從何下手？本文為您詳細解析不同空間（客廳、臥室、衛浴、辦公室）最適合的窗簾款式，從大器的蛇形窗簾到防潮的鋁百葉窗簾，幫您找到最完美的居家搭配。',
    category: 'buying-guides',
    tags: ['一般窗簾', '蛇形窗簾', '無縫紗簾', '鋁百葉窗簾', '直立簾', '客廳窗簾', '臥室窗簾'],
    date: '2024-04-14',
    readMin: 8,
    coverImage: '/blog/buying-guide-cover.webp',
    faqs: [
      {
        question: '客廳最推薦哪種窗簾？',
        answer: '客廳通常推薦大氣的蛇形窗簾或具備光影調節功能的直立簾，能提升空間質感。'
      },
      {
        question: '浴室窗簾要注意什麼？',
        answer: '浴室環境潮濕，必須選擇鋁百葉或具備防水防潮功能的材質，以防發霉。'
      }
    ],
    contentHtml: `
      <h2>客廳的氣派首選：蛇形窗簾與直立簾</h2>
      <p>客廳是居家空間的門面，通常配有大型落地窗。我們強烈推薦使用<strong><a href="/products/s-fold-curtains/">蛇形窗簾</a></strong>。其獨特的 S 型曲線設計，能展現出布料完美的整齊垂墜感，瞬間提升空間質感。若預算有限，傳統的<strong><a href="/products/custom-curtains/">一般窗簾</a></strong>同樣能透過不同的抓褶工法達到不錯的效果。</p>
      <p>如果您喜好現代極簡風格，或者客廳需要精準的光線控制，<strong><a href="/products/vertical-blinds/">直立簾</a></strong>是絕佳選擇。它不僅線條俐落，還具備 180 度葉片轉向功能，讓光影變化更加豐富。</p>
      
      <h2>臥室的睡眠守護者：高遮光一般窗簾配無縫紗簾</h2>
      <p>臥室最注重的就是「遮光」與「隱私」。我們建議採用雙層軌道設計：內層使用高遮光材質的<strong>一般窗簾</strong>，阻擋清晨刺眼的陽光；外層搭配輕盈透光的<strong><a href="/products/seamless-sheer-curtains/">無縫紗簾</a></strong>。無縫紗簾沒有接縫的設計能消除視覺阻礙，白天拉上紗簾既能保有隱私，又能讓自然光柔和灑入。</p>
      <p>小面積的臥室窗戶，則非常推薦使用層次分明的<strong><a href="/products/roman-shades/">羅馬簾</a></strong>，收起時優雅不佔空間。</p>

      <h2>衛浴與廚房：防潮專家鋁百葉窗簾</h2>
      <p>廚房與衛浴環境潮濕，絕對要避免使用布料窗簾。<strong><a href="/products/aluminum-blinds/">鋁百葉窗簾</a></strong>具備優異的防潮特性，鋁合金材質堅固耐用，清理方便，能有效防止發霉。若有辦公空間的需求，簡約且操作直覺的<strong><a href="/products/roller-blinds/">捲簾</a></strong>也是經濟實惠的首選。</p>
    `
  },
  {
    id: 'material-and-style-deep-dive',
    title: '窗簾款式與材質全解析：調光簾、風琴簾與百葉窗到底差在哪？',
    description: '市面上的窗簾款式五花八門，調光簾跟柔紗簾到底有什麼不同？竹簾和木百葉有什麼特性差異？這篇文章帶您深入了解各種熱門窗簾的材質秘密與防燃標準。',
    category: 'product-deep-dives',
    tags: ['調光簾', '柔紗簾', '竹簾', '風琴簾', '木百葉窗簾', '醫院窗簾', '防潮', '遮光'],
    date: '2024-04-10',
    readMin: 10,
    coverImage: '/blog/material-guide-cover.webp',
    faqs: [
      {
        question: '調光簾跟柔紗簾有什麼不同？',
        answer: '調光簾是一布一紗的雙層交錯設計，操作直覺；柔紗簾則是將葉片懸浮在兩層輕紗間，光線更為柔美。'
      },
      {
        question: '為什麼風琴簾可以隔熱？',
        answer: '風琴簾具備獨特的蜂巢結構，能在中空層留住靜止空氣，有效阻絕熱空氣與噪音。'
      }
    ],
    contentHtml: `
      <h2>控制光影的終極魔術師：調光簾與柔紗簾</h2>
      <p>現代裝潢中最熱門的兩款窗簾莫過於<strong><a href="/products/zebra-blinds/">調光簾</a></strong>（俗稱斑馬簾）與<strong><a href="/products/soft-sheer-blinds/">柔紗簾</a></strong>。</p>
      <p>調光簾透過一布一紗的雙層交錯滾動設計，能自由切換「透光」與「遮蔽」模式，實用性極高。而柔紗簾則是進階的奢華選擇，它將葉片懸浮在兩層輕紗之間，能營造出如雲端般極致柔美的光線，是追求頂級質感的首選。</p>

      <h2>自然禪風與節能首選：木百葉、竹簾與風琴簾</h2>
      <p>熱愛自然材質的屋主，一定會考慮<strong><a href="/products/wooden-blinds/">木百葉窗簾</a></strong>。天然的木頭紋理能大幅提升空間的溫潤感；若追求古樸的東方韻味，<strong><a href="/products/bamboo-blinds/">竹簾</a></strong>透氣極佳的特性也能帶來截然不同的氛圍。</p>
      <p>值得一提的是被譽為「節能神器」的<strong><a href="/products/honeycomb-blinds/">風琴簾</a></strong>（蜂巢簾）。其獨特的六角形蜂巢結構，不僅美觀，更能在中空層留住靜止空氣，有效阻絕室外高溫或冷空氣，具備極佳的恆溫與隔斷噪音效果。</p>

      <h2>特殊環境專用：醫院窗簾的嚴格標準</h2>
      <p>除了居家窗簾，醫療、長照或部分商業空間有更嚴格的安全法規。宏森提供的<strong><a href="/products/hospital-curtains/">醫院窗簾</a></strong>具備醫療等級的防燃與抗菌處理，且頂部多採用網狀通風設計，確保冷氣與光源能無礙流通，符合最高規格的安全需求。</p>
    `
  },
  {
    id: 'budget-allocation-for-curtains',
    title: '窗簾價格大解析：從平價到頂級，如何聰明分配窗簾預算？',
    description: '裝潢到了最後階段，窗簾預算該怎麼抓？本文公開宏森工廠直營的透明報價邏輯，教您如何根據空間重要性，精準分配捲簾、百葉窗到布簾的預算。',
    category: 'budgeting',
    tags: ['捲簾', '鋁百葉窗簾', '一般窗簾', '客廳窗簾'],
    date: '2024-04-05',
    readMin: 5,
    coverImage: '/blog/price-guide-cover.webp',
    faqs: [
      {
        question: '預算有限時該選擇什麼窗簾？',
        answer: '若預算有限，推薦使用捲簾或鋁百葉窗簾，它們計價平實且耐用度高，是高 CP 值的首選。'
      }
    ],
    contentHtml: `
      <h2>高性價比的平價王者：捲簾與鋁百葉</h2>
      <p>如果預算有限，或者窗戶數量極多（例如辦公室、書房），<strong><a href="/products/roller-blinds/">捲簾</a></strong>絕對是 CP 值最高的選擇。它計價方式依據才數（30x30cm），材料與五金相對單純，安裝快速。</p>
      <p>廚衛空間則強烈建議保留預算給<strong><a href="/products/aluminum-blinds/">鋁百葉窗簾</a></strong>，雖然價格平實，但其耐用與防潮的實用性遠大於價格。</p>

      <h2>主空間的視覺重心：一般窗簾與蛇形窗簾</h2>
      <p>客廳是全家人的活動核心，也是賓客的第一印象。建議將 50% 甚至更多的預算投入在客廳的窗簾上。選擇質地厚實的<strong>一般窗簾</strong>，並搭配精緻的<strong>蛇形窗簾</strong>抓褶工法與烤漆軌道，能讓整體裝潢價值翻倍。宏森身為工廠直營，省下了高昂的盤商抽成，讓您能用市售平價窗簾的價格，升級到更頂級的布料質感。</p>
    `
  },
  {
    id: 'curtain-cleaning-and-maintenance',
    title: '5分鐘學會日常窗簾保養：各類材質清洗與除塵技巧',
    description: '窗簾多久要洗一次？風琴簾跟百葉窗該怎麼清？掌握正確的窗簾清潔保養技巧，不僅能防塵蟎，還能大幅延長窗簾使用壽命。',
    category: 'maintenance',
    tags: ['風琴簾', '木百葉窗簾', '無縫紗簾', '一般窗簾'],
    date: '2024-03-25',
    readMin: 6,
    coverImage: '/blog/cleaning-guide-cover.webp',
    faqs: [
      {
        question: '布料窗簾可以丟洗衣機洗嗎？',
        answer: '若要機洗，必須先將掛勾全部卸下，放入洗衣袋並使用柔洗模式，以防布料勾破或變形。'
      }
    ],
    contentHtml: `
      <h2>布料窗簾的清潔法則</h2>
      <p>包含<strong>一般窗簾</strong>與<strong><a href="/products/seamless-sheer-curtains/">無縫紗簾</a></strong>，我們建議日常使用吸塵器（配合布料專用吸頭）或靜電除塵撢，每週將表面的落塵吸除即可。一般家庭大約半年至一年拆下水洗一次即可，拆洗前請務必將掛勾全部卸下。紗簾材質較為細緻，若要機洗，必須放入洗衣袋並使用柔洗模式，避免勾破。</p>

      <h2>百葉窗與硬式窗簾保養</h2>
      <p><strong><a href="/products/wooden-blinds/">木百葉窗簾</a></strong>最怕水，清潔時請千萬不要用水直接沖洗！最好的方式是戴上棉質白手套，直接用手指捏住葉片輕輕滑過，即可將灰塵拂去；或使用特別設計的百葉窗除塵刷。若有髒污，應使用微濕的抹布輕擦後立刻擦乾。</p>
      <p>至於脆弱且結構特殊的<strong><a href="/products/honeycomb-blinds/">風琴簾</a></strong>，切忌用水清洗或用力擠壓。日常保養只需使用吹風機的「冷風模式」將中空蜂巢內的灰塵吹出，或使用吸塵器最微弱吸力清理表面。</p>
    `
  },
  {
    id: 'curtain-measurement-and-installation',
    title: '窗簾尺寸怎麼量？軌道、羅馬桿與空間預留安裝教學',
    description: '自己量尺寸估價其實很簡單！本教學帶您了解量尺秘訣、以及針對羅馬簾、直立簾等特殊窗簾安裝時該注意的天花板與窗盒預留空間。',
    category: 'installation',
    tags: ['羅馬簾', '直立簾', '一般窗簾', '客廳窗簾'],
    date: '2024-03-10',
    readMin: 7,
    coverImage: '/blog/measure-guide-cover.webp',
    faqs: [
      {
        question: '窗簾尺寸應該怎麼量才不會漏光？',
        answer: '建議寬度比窗框左右各向外延伸 10 至 15 公分；高度若為半腰窗，則向下延伸 15 至 20 公分，確保完整遮蔽。'
      }
    ],
    contentHtml: `
      <h2>寬度與高度的測量黃金法則</h2>
      <p>要讓窗簾美觀且不漏光，尺寸絕對不能剛剛好齊平窗框。一般來說，測量寬度時，建議左右各向外延伸 10 至 15 公分；高度則建議向下延伸 15 至 20 公分（若是半腰窗）。若選擇落地型<strong>一般窗簾</strong>，則高度需測量至距離地板約 1~2 公分處，以防拖地積塵。</p>

      <h2>特殊款式的空間預留（窗簾盒）</h2>
      <p>不同的窗簾款式對「窗簾盒」的深度要求完全不同。如果您的裝潢預計要安裝具有大圓弧擺摺的<strong>蛇形窗簾</strong>，不論單層或雙層，窗簾盒的深度至少需要預留 15~25 公分，否則窗簾會擠壓變形。</p>
      <p>相對的，如果您使用的是上下開闔的<strong><a href="/products/roman-shades/">羅馬簾</a></strong>，或是葉片垂直的<strong><a href="/products/vertical-blinds/">直立簾</a></strong>，安裝空間的厚度需求就大幅減少。但在測量直立簾時，務必考慮到它左右收合時，葉片會佔用一小部分玻璃面積，因此軌道寬度建議比窗框設計得更寬一些。</p>
    `
  },
  {
    id: 'blackout-curtain-guide',
    title: '【2026 遮光窗簾全攻略】遮光等級與挑選指南：如何打造 100% 全遮光睡眠環境？',
    description: '深受光線困擾？本文詳細解析遮光窗簾等級（1級至3級）、塗層與三明治布料差異，並分享如何透過安裝細節達到 100% 全遮光的完美睡眠空間。',
    category: 'buying-guides',
    tags: ['遮光', '一般窗簾', '臥室窗簾', '隔熱'],
    date: '2026-04-20',
    readMin: 8,
    coverImage: '/blog/blackout-curtain-guide.webp',
    faqs: [
      {
        question: '遮光窗簾真的能達到 100% 全遮光嗎？',
        answer: '是的，透過選擇「1級遮光」布料並搭配「窗簾盒」設計，可以有效阻絕上方與側面的漏光，達到近乎 100% 的全遮光效果。'
      },
      {
        question: '三明治遮光布與塗層遮光布哪個比較好？',
        answer: '三明治遮光布手感較軟且可水洗，耐用度高；塗層布遮光性更強但洗滌後幾次易龜裂。一般居家首推耐用度高的高品質三明治布。'
      }
    ],
    contentHtml: `
      <h2>遮光等級怎麼看？1 級與 3 級的實測差異</h2>
      <p>市面上的遮光窗簾通常分為三級。<strong>1 級遮光</strong>（遮光率達 99.99% 以上）能確保室內幾乎全黑，適合對光線極度敏感的淺眠者。而 <strong>3 級遮光</strong> 則能保留微弱光感，適合書房或客廳使用。挑選時建議直接在門市用手機手電筒貼近布料實測最準確。</p>
      
      <h2>布料材質決定壽命：三明治布 vs. 塗層布</h2>
      <p>目前主流為「三明治遮光布」，在兩層布料中間織入黑色消光紗，手感柔軟且可機洗；另一種則是「背面塗層布」，遮光效果極佳但清洗幾次後塗層易龜裂脫落。追求耐用度的屋主，我們首推<strong><a href="/products/custom-curtains/">高品質三明治布</a></strong>。</p>

      <h2>100% 全遮光的關鍵：安裝細節</h2>
      <p>就算布料不透光，若安裝不當（如上方漏光、側面縫隙），遮光效果也會大打折扣。建議搭配<strong>窗簾盒</strong>或使用<strong>側邊磁吸設計</strong>，並增加布料摺深與寬度，才能真正阻絕每一絲陽光。</p>
    `
  },
  {
    id: 's-curtain-vs-vertical-blind',
    title: '落地窗首選：蛇形簾 vs. 直立簾深度比較！客廳裝潢該選哪一種？',
    description: '客廳落地窗是大面積視覺焦點。該選展現大氣垂墜感的蛇形簾，還是強調線條感與採光彈性的直立簾？優缺點、清潔便利度與預算一次分析給您看。',
    category: 'product-deep-dives',
    tags: ['蛇形窗簾', '直立簾', '客廳窗簾', '一般窗簾'],
    date: '2026-04-18',
    readMin: 7,
    coverImage: '/blog/s-curtain-vs-vertical-blind.webp',
    faqs: [
      {
        question: '客廳落地窗一定要裝蛇形簾嗎？',
        answer: '不一定。蛇形簾大氣典雅但需要較深的窗簾盒空間；若空間有限或追求採光彈性，直立簾也是非常現代且實用的選擇。'
      },
      {
        question: '直立簾容易壞嗎？',
        answer: '現代直立簾的軌道與零件已大幅改良，只要正常撥動葉片，耐用度與一般窗簾無異，且更易於單獨更換受損葉片。'
      }
    ],
    contentHtml: `
      <h2>蛇形簾：飯店風的質感保證</h2>
      <p><strong><a href="/products/s-fold-curtains/">蛇形窗簾</a></strong>以其優雅、整齊的 S 型曲線著稱，是目前現代與北歐風裝潢的最愛。它能讓布料呈現極具質感的垂墜感，但缺點是需要的窗簾盒深度較大（至少 15-20 公分），且布料用量較多，預算相對較高。</p>

      <h2>直立簾：小坪數與光影大師</h2>
      <p><strong><a href="/products/vertical-blinds/">直立簾</a></strong>近年來強勢回歸，特別是葉片可 180 度調整的特性，讓您在保有隱私的同時，能細膩調整進光量。對於需要視覺延伸、拉高空間感的窄長落地窗來說，直立簾的俐落感是蛇形簾難以企及的。</p>

      <h2>如何做最終決定？</h2>
      <p>如果您追求溫潤、舒適的居家感，蛇形簾是首選；如果您喜愛俐落、簡約且預算有限，直立簾的 CP 值與功能性會讓您非常滿意。</p>
    `
  },
  {
    id: 'curtain-price-guide-2026',
    title: '2026 窗簾價格指南：1 分鐘看懂窗簾價格試算、三重窗簾比價與安裝費',
    description: '想做窗簾價格試算嗎？本文整理 2026 捲簾、鋁百葉、風琴簾、實木百葉窗價格試算與安裝費重點，並附三重窗簾比價流程。',
    category: 'budgeting',
    tags: ['訂製窗簾價格', '窗簾價格試算', '窗簾安裝費用', '窗簾訂做價格', '訂做窗簾價格', '窗簾報價', '捲簾', '風琴簾'],
    date: '2026-05-21',
    readMin: 6,
    coverImage: '/blog/curtain-price-guide-2026.webp',
    faqs: [
      {
        question: '同尺寸為何報價不同（窗型 / 配件 / 施工）？',
        answer: '同尺寸仍會因窗型、五金配件、安裝難度與布料等級不同而有價差。建議先做窗簾價格試算抓區間，再由丈量確認細節。'
      },
      {
        question: '窗簾價格試算前需要先準備哪些資訊？',
        answer: '至少準備窗戶寬高（公分）、預計款式與安裝區域，先完成線上估價後再安排到府丈量，報價會更快速且準確。'
      },
      {
        question: '窗簾安裝費用會另外加嗎？',
        answer: '多數品項會把基本安裝費用納入估價，但若遇到高樓特殊施工、偏遠區或客製配件，仍可能有額外費用，需丈量後確認。'
      },
      {
        question: '實木百葉窗價格試算適合用在哪些空間？',
        answer: '常見於客廳、書房與西曬窗。建議先在同尺寸下對比實木百葉與捲簾、調光簾，再決定是否升級材質與配件。'
      }
    ],
    contentHtml: `
      <p>若你是從<strong>窗簾價格試算</strong>搜尋進來，建議先開啟<strong><a href="/calculator/">窗簾計算機</a></strong>輸入尺寸，再回來對照本文行情。若你正在比價<strong>三重窗簾</strong>，可先看<strong><a href="/location/sanchong/">三重窗簾價格試算入口</a></strong>；若在台北市，也可先看<strong><a href="/location/taipei/">台北窗簾價格試算入口</a></strong>，再決定丈量順序。</p>

      <h2>訂製窗簾價格怎麼算？先看「才數」與起計規則</h2>
      <p>台灣窗簾常以「才」計價（1 才 = 30x30cm）。基本公式為：寬(cm) x 高(cm) / 900 = 才數。由於小窗仍有固定工序，多數品項會有基本起計才數，因此窗簾訂做價格不只看面積，還要看款式與施工條件。</p>

      <h2>2026 常見窗簾訂做價格行情（連工帶料）</h2>
      <ul>
        <li><strong><a href="/products/roller-blinds/">捲簾</a>：</strong> 約 $60~$100 / 才，屬於高 CP 值入門款。</li>
        <li><strong><a href="/products/aluminum-blinds/">鋁百葉窗簾</a>：</strong> 約 $90~$180 / 才，防潮好清潔，常用於廚房與衛浴。</li>
        <li><strong><a href="/products/honeycomb-blinds/">風琴簾（蜂巢簾）</a>：</strong> 約 $200~$500 / 才，主打隔熱節能與臥室控溫。</li>
        <li><strong><a href="/products/wooden-blinds/">實木百葉窗</a>：</strong> 可先做實木百葉窗價格試算，再依木種與葉片規格確認正式報價。</li>
        <li><strong><a href="/products/custom-curtains/">一般布簾</a>：</strong> 常以幅寬與車工計價，客廳一窗約 $5,000~$15,000 不等。</li>
      </ul>

      <h2>窗簾價格總覽（快速對照）</h2>
      <p>如果你只想先抓預算，建議先記住這個順序：<strong>捲簾/鋁百葉（入門） → 一般布簾（中段） → 風琴簾/高規功能簾（進階）</strong>。再依照你的採光需求與空間用途微調，會比一開始就挑花色有效率。</p>

      <h2>窗簾價格試算怎麼做最快？</h2>
      <ol>
        <li>先量「寬 x 高」公分，輸入到<strong><a href="/calculator/">窗簾計算機</a></strong>。</li>
        <li>同尺寸切換 2~3 種品項（例如捲簾、鋁百葉、風琴簾）比較價差。</li>
        <li>最後再決定是否要升級材質或追加配件，避免一開始就過度客製。</li>
      </ol>

      <h2>窗簾安裝費用怎麼看？三個常見影響因子</h2>
      <ol>
        <li><strong>窗型與施工難度：</strong> 轉角窗、高窗、特殊牆面固定條件，通常會提高施工時間與安裝成本。</li>
        <li><strong>配件與五金：</strong> 軌道等級、支架數量、附加五金與拆舊需求，會影響最後安裝費用。</li>
        <li><strong>地區與時段：</strong> 偏遠區、特殊時段施工或社區管理限制，可能產生額外施工成本。</li>
      </ol>

      <h2>窗簾報價流程：先估價、再丈量、最後確認</h2>
      <p>建議先用<strong><a href="/calculator/">窗簾計算機 / 窗簾估價工具</a></strong>輸入尺寸，先抓到訂做窗簾價格區間與安裝費用估算，再由師傅到府丈量確認窗型、配件與施工條件。若您正在搜尋<strong>三重窗簾</strong>，可先看<strong><a href="/location/sanchong/">三重窗簾推薦與價格試算</a></strong>；若要先評估<strong>實木百葉窗價格試算</strong>，可直接看<strong><a href="/products/wooden-blinds/">實木百葉窗產品頁與試算重點</a></strong>；若在台北文教生活圈，也可看<strong><a href="/location/zhongzheng/">中正區窗簾價格試算</a></strong>服務頁，快速銜接在地丈量流程。</p>
    `
  },
  {
    id: 'prevent-curtain-mold',
    title: '窗簾發霉怎麼辦？浴室與潮濕環境的窗簾防霉預防與處理妙招',
    description: '台灣潮濕氣候讓窗簾容易長黑斑？本文教您如何針對不同材質處理霉斑，並分享浴室、廚房選購窗簾時的最佳「防潮」選擇。',
    category: 'maintenance',
    tags: ['防潮', '鋁百葉窗簾', '捲簾'],
    date: '2026-04-12',
    readMin: 5,
    coverImage: '/blog/prevent-curtain-mold.webp',
    faqs: [
      {
        question: '窗簾發霉可以只噴除霉劑嗎？',
        answer: '不建議直接噴灑強效除霉劑，因為其中的化學成分可能導致布料褪色或損壞纖維。建議先局部測試，或使用稀釋的氧系洗劑。'
      },
      {
        question: '浴室適合裝什麼窗簾？',
        answer: '浴室強烈建議安裝鋁百葉窗簾或具備防水塗層的捲簾，這類材質不吸水，能從根本預防霉菌滋生。'
      }
    ],
    contentHtml: `
      <h2>為什麼窗簾會發霉？</h2>
      <p>潮濕環境、不通風以及布料纖維殘留的皮屑灰塵是霉菌的溫床。特別是窗邊的水氣若未即時排除，布簾很容易在底部產生難看的黑斑。</p>

      <h2>霉斑處理 3 步驟</h2>
      <ol>
        <li><strong>稀釋洗劑：</strong> 對於可洗布料，使用稀釋的氧系漂白水浸泡（注意：氯系漂白水易導致布料褪色）。</li>
        <li><strong>刷洗細節：</strong> 使用軟毛刷輕輕刷除，避免傷及纖維。</li>
        <li><strong>徹底乾燥：</strong> 洗後務必自然風乾或低溫烘乾，切忌在未乾的情況下收摺。</li>
      </ol>

      <h2>防潮首選推薦</h2>
      <p>在浴室或高濕度區域，我們強烈建議使用<strong><a href="/products/aluminum-blinds/">鋁百葉窗簾</a></strong>或具備<strong>防水塗層的捲簾</strong>。這類材質完全不吸水，日常只需擦拭即可保持乾燥，是預防發霉的最根本方案。</p>
    `
  },
  {
    id: 'smart-curtain-installation',
    title: '電動窗簾安裝全攻略：傳統窗簾也能變智能？軌道預留與智能家居整合教學',
    description: '想回家就看到窗簾自動開啟？本文詳細解析電動窗簾安裝時的電源預留、馬達選擇，以及如何整合至 Apple HomeKit 或 Google Home 系統。',
    category: 'installation',
    tags: ['一般窗簾', '捲簾', '客廳窗簾', '臥室窗簾'],
    date: '2026-04-08',
    readMin: 9,
    coverImage: '/blog/smart-curtain-installation.webp',
    faqs: [
      {
        question: '舊窗簾可以改裝成電動的嗎？',
        answer: '大部分布簾與捲簾都可以透過更換電動軌道或安裝馬達來升級，但具體需視現場空間與窗盒深度而定。'
      },
      {
        question: '電動窗簾需要留插座嗎？',
        answer: '裝潢初期預留 110V 插座最穩定；若已完工，也可選擇鋰電池馬達，約半年充一次電即可，免拉線。'
      }
    ],
    contentHtml: `
      <h2>電動窗簾的兩大類型：馬達與電池版</h2>
      <p>如果您正處於裝潢階段，強烈建議在窗簾盒附近<strong>預留 110V 電源插座</strong>，插電式馬達推力穩定且終身免充電。若已裝潢完成，則可考慮「鋰電池版」馬達，約半年充一次電即可，安裝不受限。</p>

      <h2>智能整合：手機與語音控制</h2>
      <p>現代馬達多支援 Zigbee 或 Wi-Fi 協定。透過專用網關，您可以設定「自動定時」——例如早上 7:00 陽光灑入喚醒您，或結合環境感測器，當西曬過強時自動闔上降溫。</p>

      <h2>電動窗簾的預算與規劃</h2>
      <p>電動系統的費用主要來自馬達（約 $4,000~$12,000 / 支）加上特製導軌。宏森提供多款靜音馬達選擇，並具備專業工程團隊到府評估水電預留狀況，讓您的智能家居夢想輕鬆實現。</p>
    `
  }
];
