// hifi-screens.jsx — Poby hi-fi designs
// iOS · 미니멀. Instagram-inspired dark camera + Setlog-inspired accent treatment.
// Mint reserved for pose-match success per components.md.

const PW = 390,PH = 844;
const SH = 47; // iOS status bar
const HI = 34; // home indicator zone

// palette
const ink = '#0f0f10';
const ink2 = '#3a3a3c';
const ink3 = '#8e8e93';
const hair = '#e6e3d8';
const paper = '#f7f5ef';
const cam = '#0a0a0a';

// theme — paper/recapture/etc. Allows a 'modern' (cool slate) variant
// next to the warm beige default.
const THEMES = {
  warm: {
    paper: '#f7f5ef',
    paper2: '#f0eee5',
    grabber: '#d6d3c8',
    doneOff: '#c5c0b3',
    doneOn: '#0a8a72',
  },
  modern: {
    paper: '#f2f2f7',
    paper2: '#ffffff',
    grabber: '#d1d1d6',
    doneOff: '#c7c7cc',
    doneOn: '#0a7d68',
  },
};
const ThemeCtx = React.createContext(THEMES.warm);
const useTheme = () => React.useContext(ThemeCtx);
const mint = '#4dd6b6';
const mintDeep = '#0d2b25';
const danger = '#ff5f57';
const pinkA = '#ff6db3';
const pinkB = '#9d5cff';

// ─────────────────────────────────────────────
// iOS chrome
// ─────────────────────────────────────────────
const StatusBar = ({ light }) =>
<div style={{
  position: 'absolute', top: 0, left: 0, right: 0, height: SH,
  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
  padding: '0 28px', fontFamily: '-apple-system, Pretendard, system-ui',
  fontSize: 15, fontWeight: 600, color: light ? '#fff' : ink, zIndex: 40
}}>
    <span>9:41</span>
    {/* dynamic island */}
    <div style={{
    width: 120, height: 30, borderRadius: 999, background: '#000',
    position: 'absolute', left: '50%', top: 11, transform: 'translateX(-50%)'
  }} />
    <span style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
      <SignalIcon light={light} />
      <WifiIcon light={light} />
      <BatteryIcon light={light} />
    </span>
  </div>;


const SignalIcon = ({ light }) =>
<svg width="17" height="11" viewBox="0 0 17 11" fill={light ? '#fff' : ink}>
    {[0, 1, 2, 3].map((i) =>
  <rect key={i} x={i * 4.2} y={11 - (i + 1) * 2.6} width="3" height={(i + 1) * 2.6} rx=".5" />
  )}
  </svg>;

const WifiIcon = ({ light }) =>
<svg width="16" height="11" viewBox="0 0 16 11" fill="none" stroke={light ? '#fff' : ink} strokeWidth="1.4" strokeLinecap="round">
    <path d="M1 4.2 Q 8 -.8 15 4.2" />
    <path d="M3.4 6.8 Q 8 3 12.6 6.8" />
    <path d="M5.7 9 Q 8 7.5 10.3 9" />
    <circle cx="8" cy="10" r=".8" fill={light ? '#fff' : ink} stroke="none" />
  </svg>;

const BatteryIcon = ({ light }) =>
<span style={{ display: 'flex', alignItems: 'center', gap: 2 }}>
    <span style={{ fontSize: 12, fontWeight: 500, color: light ? '#fff' : ink, marginRight: 2 }}>87</span>
    <div style={{ position: 'relative', width: 24, height: 12, border: `1.2px solid ${light ? 'rgba(255,255,255,.45)' : 'rgba(0,0,0,.4)'}`, borderRadius: 3.5, padding: 1.5 }}>
      <div style={{ width: '82%', height: '100%', background: light ? '#fff' : ink, borderRadius: 1.5 }} />
      <div style={{ position: 'absolute', right: -2.5, top: 3.5, width: 1.5, height: 4, borderRadius: 1, background: light ? 'rgba(255,255,255,.5)' : 'rgba(0,0,0,.4)' }} />
    </div>
  </span>;


const HomeIndicator = ({ light }) =>
<div style={{
  position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)',
  width: 134, height: 5, borderRadius: 3, background: light ? '#fff' : ink,
  opacity: .9, zIndex: 40
}} />;


const Phone = ({ children, bg, theme = 'warm' }) => {
  const t = THEMES[theme] || THEMES.warm;
  return (
    <ThemeCtx.Provider value={t}>
      <div style={{
        width: PW, height: PH, background: bg ?? '#000', position: 'relative',
        overflow: 'hidden', borderRadius: 50,
        boxShadow: '0 30px 80px -20px rgba(0,0,0,.35), 0 0 0 1px rgba(0,0,0,.06) inset',
        fontFamily: '-apple-system, Pretendard, "SF Pro Text", system-ui',
        color: ink
      }}>
        {children}
      </div>
    </ThemeCtx.Provider>
  );
};


// ─────────────────────────────────────────────
// camera preview placeholder (clean — no labels)
// uses a moody gradient so the dark UI reads correctly
// ─────────────────────────────────────────────
const Preview = ({ children, framed }) =>
<div style={{
  position: 'absolute', inset: 0, background: cam, overflow: 'hidden'
}}>
    {/* subtle photographic gradient suggesting a real scene */}
    <div style={{
    position: 'absolute', inset: 0,
    background: `
        radial-gradient(140% 90% at 30% 20%, #2a2a2c 0%, transparent 55%),
        radial-gradient(120% 120% at 80% 100%, #1a1a1c 0%, transparent 60%),
        linear-gradient(180deg, #161616 0%, #0a0a0a 100%)
      `
  }} />
    {/* faint film grain */}
    <div style={{
    position: 'absolute', inset: 0, opacity: .18,
    backgroundImage: `radial-gradient(rgba(255,255,255,.08) 1px, transparent 1px)`,
    backgroundSize: '3px 3px', mixBlendMode: 'screen'
  }} />
    {/* faux subject silhouette so guide alignment reads */}
    <SubjectSilhouette />
    {framed &&
  <div style={{
    position: 'absolute', inset: 12, borderRadius: 38, pointerEvents: 'none',
    boxShadow: `0 0 0 1.5px rgba(255,255,255,.06), 0 0 0 3px rgba(77,214,182,.0)`,
    background: 'linear-gradient(135deg, rgba(255,109,179,.0), rgba(157,92,255,.0))'
  }} />
  }
    {children}
  </div>;


const SubjectSilhouette = ({ matched, dim = .6 }) =>
<svg viewBox="0 0 390 844" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
    <defs>
      <radialGradient id="figGrad" cx="50%" cy="35%" r="50%">
        <stop offset="0%" stopColor={`rgba(255,255,255,${0.16 * dim + .04})`} />
        <stop offset="100%" stopColor="rgba(255,255,255,0)" />
      </radialGradient>
    </defs>
    <ellipse cx="195" cy="320" rx="64" ry="80" fill="url(#figGrad)" />
    <path d="M 90 600 Q 195 480 300 600 L 300 844 L 90 844 Z" fill="url(#figGrad)" />
  </svg>;


// ─────────────────────────────────────────────
// SF-style stroke icons
// ─────────────────────────────────────────────
const Sw = ({ d, size = 24, c = '#fff', w = 1.8, fill = 'none', extra }) =>
<svg width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={c}
strokeWidth={w} strokeLinecap="round" strokeLinejoin="round">{d}{extra}</svg>;

const IFlash = ({ on }) =>
<Sw c={on ? '#ffd84d' : '#fff'} d={<path d="M13 2 L4 14 h6 l-1 8 L19 9 h-6 z" fill={on ? '#ffd84d' : 'none'} />} />;

const IFlip = () =>
<Sw d={<><path d="M4 8 H 16 L 13 5" /><path d="M20 16 H 8 L 11 19" /></>} />;

const IGallery = () =>
<Sw d={<><rect x="3" y="5" width="18" height="14" rx="3" /><circle cx="9" cy="11" r="1.8" fill="#fff" /><path d="M21 17 L 14 11 L 5 19" /></>} />;

const IClose = ({ c = '#fff' }) => <Sw c={c} d={<path d="M6 6 L18 18 M18 6 L6 18" />} />;
const IBack = ({ c = '#fff' }) => <Sw c={c} d={<path d="M15 5 L7 12 L15 19" />} />;
const IPlus = ({ c = '#fff', size = 24 }) => <Sw size={size} c={c} w={2} d={<path d="M12 5 V19 M5 12 H19" />} />;
const ICheck = ({ c = '#fff', size = 18 }) => <Sw size={size} c={c} w={2.2} d={<path d="M4 12 L10 18 L20 6" />} />;
const ITrash = ({ c = '#fff' }) => <Sw c={c} d={<><path d="M4 7 H20" /><path d="M9 7 V5 a 2 2 0 0 1 2 -2 h2 a 2 2 0 0 1 2 2 V7" /><path d="M6 7 L7 20 a 2 2 0 0 0 2 2 h6 a 2 2 0 0 0 2 -2 L18 7" /></>} />;
const IChevron = ({ c = ink2, dir = 'down', size = 14 }) =>
<Sw size={size} c={c} w={2} d={
dir === 'right' ? <path d="M9 6 L15 12 L9 18" /> :
dir === 'left' ? <path d="M15 6 L9 12 L15 18" /> :
<path d="M6 9 L12 15 L18 9" />
} />;

const IRatio = ({ label = '9:16' }) =>
<div style={{
  height: 28, padding: '0 10px', borderRadius: 14,
  background: 'rgba(255,255,255,.12)', backdropFilter: 'blur(20px)',
  color: '#fff', fontSize: 12, fontWeight: 600, letterSpacing: .2,
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  fontFamily: '"SF Mono", ui-monospace, monospace', border: '1px solid rgba(255,255,255,.18)'
}}>{label}</div>;


// glass button (top chrome chips)
const GlassChip = ({ children, onDark = true, size = 36, style }) =>
<button style={{
  width: size, height: size, borderRadius: '50%', border: 'none',
  background: onDark ? 'rgba(255,255,255,.16)' : 'rgba(0,0,0,.06)',
  backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  color: '#fff', cursor: 'pointer', padding: 0, ...style
}}>{children}</button>;


// ─────────────────────────────────────────────
// guide outline (head/shoulders) as overlay
// ─────────────────────────────────────────────
const GuideOverlay = ({ matched, dashed, scale = 1, opacity = 1, hi = true, accent = null }) => {
  const c = matched ? mint : '#fff';
  const filter = hi ? `drop-shadow(0 0 10px ${matched ? 'rgba(77,214,182,.55)' : 'rgba(255,255,255,.35)'})` : 'none';
  const w = 780,h = 1280;
  return (
    <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="xMidYMid meet"
    style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity, filter, pointerEvents: 'none' }}>
      <g fill="none" stroke={accent || c} strokeWidth={5} strokeLinecap="round" strokeLinejoin="round"
      strokeDasharray={dashed ? '10 8' : 'none'}>
        <ellipse cx="390" cy="380" rx="118" ry="148" />
        <path d="M348 510 L 348 570 M 432 510 L 432 570" />
        <path d="M180 700 Q 390 620 600 700" />
        <path d="M188 710 L 226 1280" />
        <path d="M592 710 L 554 1280" />
        <path d="M208 740 Q 138 960 178 1200" />
        <path d="M572 740 Q 642 960 602 1200" />
        {/* corner ticks (rule-of-thirds hint) */}
        <g strokeWidth={2} opacity={.55}>
          <line x1="0" y1={h / 3} x2="44" y2={h / 3} />
          <line x1={w - 44} y1={h / 3} x2={w} y2={h / 3} />
          <line x1="0" y1={2 * h / 3} x2="44" y2={2 * h / 3} />
          <line x1={w - 44} y1={2 * h / 3} x2={w} y2={2 * h / 3} />
        </g>
      </g>
    </svg>);

};

// "Setlog-inspired" gradient inner frame — shown when a guide is applied,
// communicates "guide mode" without resorting to garish color
const GuideFrame = ({ matched, intensity = 1 }) => {
  const a = matched ? `rgba(77,214,182,${.95 * intensity})` : `rgba(255,255,255,${.5 * intensity})`;
  const b = matched ? `rgba(77,214,182,${.35 * intensity})` : `rgba(255,109,179,${.55 * intensity})`;
  return (
    <div style={{
      position: 'absolute', inset: 0, borderRadius: 50, pointerEvents: 'none',
      boxShadow: `inset 0 0 0 2px ${a}, inset 0 0 0 4px ${b}`,
      transition: 'box-shadow .3s'
    }} />);

};

// ─────────────────────────────────────────────
// s1 — guideline strip + controls
// ─────────────────────────────────────────────
const GuideThumb = ({ active, n }) =>
<div style={{
  width: 54, height: 72, borderRadius: 14, flex: '0 0 auto',
  background: '#2a2a2c', position: 'relative', overflow: 'hidden',
  boxShadow: active ? `0 0 0 2px ${mint}, 0 0 0 4px rgba(77,214,182,.25)` : '0 0 0 1px rgba(255,255,255,.18)'
}}>
    {/* mini guide silhouette */}
    <svg viewBox="0 0 54 72" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
      <ellipse cx="27" cy="20" rx="9" ry="11" fill="rgba(255,255,255,.85)" />
      <path d="M10 50 Q 27 36 44 50 L 44 72 L 10 72 Z" fill="rgba(255,255,255,.75)" />
    </svg>
    {active &&
  <div style={{
    position: 'absolute', top: 4, right: 4, width: 16, height: 16, borderRadius: 8,
    background: mint, display: 'flex', alignItems: 'center', justifyContent: 'center'
  }}><ICheck c={mintDeep} size={11} /></div>
  }
  </div>;


const PlusThumb = ({ pulse }) =>
<div style={{
  width: 54, height: 72, borderRadius: 14, flex: '0 0 auto',
  background: 'rgba(255,255,255,.08)',
  border: '1.5px dashed rgba(255,255,255,.6)',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  animation: pulse ? 'pobyPulse 2.2s ease-in-out infinite' : 'none'
}}>
    <IPlus c="#fff" size={22} />
  </div>;


const CONTROLS_H = 84;
const SHUTTER_BOTTOM = CONTROLS_H + 14;
const STRIP_BOTTOM = SHUTTER_BOTTOM + 78 + 18;

const Shutter = ({ matched }) =>
<div style={{
  position: 'absolute', bottom: SHUTTER_BOTTOM, left: '50%', transform: 'translateX(-50%)', zIndex: 20
}}>
    <div style={{
    width: 76, height: 76, borderRadius: '50%',
    border: `4px solid ${matched ? mint : '#fff'}`,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    boxShadow: matched ? '0 0 24px rgba(77,214,182,.55)' : '0 4px 18px rgba(0,0,0,.35)',
    background: 'rgba(0,0,0,.15)', backdropFilter: 'blur(8px)'
  }}>
      <div style={{
      width: 60, height: 60, borderRadius: '50%',
      background: matched ? mint : '#fff',
      transition: 'background .25s'
    }} />
    </div>
  </div>;


// top chrome: close (only s3), flash, settings + ratio (center-tucked)
const TopChrome = ({ matched, onCancel, ratio = '9:16' }) =>
<div style={{
  position: 'absolute', top: SH + 10, left: 0, right: 0, height: 44,
  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
  padding: '0 18px', zIndex: 25
}}>
    {onCancel ? <GlassChip><IClose /></GlassChip> : <div style={{ width: 36 }} />}
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      {matched &&
    <div style={{
      background: mint, color: mintDeep, fontWeight: 700, fontSize: 12,
      padding: '7px 12px 7px 9px', borderRadius: 999, display: 'flex', alignItems: 'center', gap: 5,
      boxShadow: '0 6px 16px rgba(77,214,182,.35)'
    }}>
          <ICheck c={mintDeep} size={14} /> 포즈 매칭
        </div>
    }
      <IRatio label={ratio} />
    </div>
    <GlassChip><IFlash /></GlassChip>
  </div>;


const BottomControls = () =>
<div style={{
  position: 'absolute', bottom: 0, left: 0, right: 0, height: CONTROLS_H,
  background: '#000', display: 'flex', alignItems: 'center',
  justifyContent: 'space-between', padding: '0 28px', paddingBottom: HI,
  zIndex: 22
}}>
    <button style={chipBtn}><IGallery /></button>
    <button style={chipBtn}><IFlip /></button>
  </div>;

const chipBtn = {
  width: 48, height: 48, borderRadius: 14, border: 'none',
  background: 'rgba(255,255,255,.10)',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  cursor: 'pointer', padding: 0, backdropFilter: 'blur(10px)'
};

// the guide-list strip
const GuideStrip = ({ items, activeIdx, empty }) =>
<div style={{ ...{
    position: 'absolute', bottom: STRIP_BOTTOM, left: 0, right: 0,
    display: 'flex', gap: 8, padding: '0 18px',
    overflowX: 'auto', zIndex: 18,
    justifyContent: empty ? 'flex-end' : 'flex-start'
  }, justifyContent: "center" }}>
    {!empty && items.map((_, i) => <GuideThumb key={i} n={i + 1} active={i === activeIdx} />)}
    <PlusThumb pulse={empty} />
  </div>;


// ─────────────────────────────────────────────
// s1 variants
// ─────────────────────────────────────────────
const S1Empty = () =>
<Phone>
    <Preview />
    <StatusBar light />
    <TopChrome />
    <div style={{
    position: 'absolute', left: 0, right: 0, bottom: STRIP_BOTTOM + 86,
    textAlign: 'center', color: 'rgba(255,255,255,.92)', fontSize: 15, fontWeight: 500, zIndex: 18
  }}>
      <div style={{ fontSize: 17, fontWeight: 600, letterSpacing: -.2 }}>
        첫 가이드라인을 추가해보세요
      </div>
      <div style={{ marginTop: 4, fontSize: 13, color: 'rgba(255,255,255,.62)' }}>
        좋아하는 사진의 구도를 카메라에 띄울 수 있어요
      </div>
    </div>
    <GuideStrip empty />
    <Shutter />
    <BottomControls />
    <HomeIndicator light />
  </Phone>;


const S1WithGuides = ({ activeIdx = null, matched = false, items = [1, 2, 3, 4, 5, 6] }) =>
<Phone>
    <Preview framed />
    {activeIdx != null && <GuideOverlay matched={matched} />}
    {activeIdx != null && <GuideFrame matched={matched} />}
    <StatusBar light />
    <TopChrome matched={matched} />
    <GuideStrip items={items} activeIdx={activeIdx} />
    <Shutter matched={matched} />
    <BottomControls />
    <HomeIndicator light />
  </Phone>;


// ─────────────────────────────────────────────
// + bottom sheet
// ─────────────────────────────────────────────
const SheetRow = ({ icon, title, sub, accent }) => {
  const t = useTheme();
  return (
<button style={{
  width: '100%', display: 'flex', alignItems: 'center', gap: 14,
  padding: '14px 14px', border: 'none', background: '#fff',
  borderRadius: 18, marginBottom: 8, cursor: 'pointer', textAlign: 'left',
  boxShadow: '0 1px 0 rgba(0,0,0,.04)'
}}>
    <div style={{
    width: 44, height: 44, borderRadius: 14,
    background: accent ? mint : t.paper2,
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    color: accent ? mintDeep : ink
  }}>{icon}</div>
    <div style={{ flex: 1 }}>
      <div style={{ fontSize: 16, fontWeight: 600, color: ink, letterSpacing: -.2 }}>{title}</div>
      <div style={{ fontSize: 13, color: ink3, marginTop: 2 }}>{sub}</div>
    </div>
    <IChevron dir="right" c={ink3} size={18} />
  </button>
  );
};


const S1PlusModal = ({ theme = 'warm' }) => {
  const t = THEMES[theme];
  return (
<Phone theme={theme}>
    <Preview />
    <StatusBar light />
    <TopChrome />
    <GuideStrip items={[1, 2, 3]} />
    <Shutter />
    <BottomControls />
    {/* dim */}
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.55)', zIndex: 30, backdropFilter: 'blur(4px)' }} />
    {/* sheet */}
    <div style={{
    position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 31,
    background: t.paper, borderRadius: '28px 28px 0 0', padding: '10px 16px 28px',
    boxShadow: '0 -8px 30px rgba(0,0,0,.18)'
  }}>
      <div style={{ width: 36, height: 5, borderRadius: 3, background: t.grabber, margin: '8px auto 14px' }} />
      <div style={{ fontSize: 19, fontWeight: 700, color: ink, padding: '2px 6px 14px', letterSpacing: -.3 }}>
        가이드라인 추가
      </div>
      <SheetRow
      icon={<Sw c={ink} d={<><circle cx="12" cy="13" r="4" /><rect x="3" y="6" width="18" height="14" rx="3" /><path d="M8 6 L9.5 4 H14.5 L16 6" /></>} />}
      title="가이드 사진 찍기"
      sub="지금 카메라로 직접 촬영해요" />
    
      <SheetRow
      icon={<Sw c={ink} d={<><rect x="3" y="5" width="18" height="14" rx="3" /><circle cx="9" cy="11" r="1.8" fill={ink} /><path d="M21 17 L 14 11 L 5 19" /></>} />}
      title="갤러리에서 등록"
      sub="기존 사진을 가이드로 사용해요" />
    
      <button style={{
      marginTop: 6, width: '100%', background: 'transparent', border: 'none',
      padding: '14px 0', fontSize: 16, color: ink3, cursor: 'pointer'
    }}>취소</button>
    </div>
    <HomeIndicator />
  </Phone>
  );
};


// ─────────────────────────────────────────────
// long-press delete
// ─────────────────────────────────────────────
const S1DeleteModal = ({ theme = 'warm' }) =>
<Phone theme={theme}>
    <Preview framed />
    <GuideOverlay />
    <GuideFrame />
    <StatusBar light />
    <TopChrome />
    <GuideStrip items={[1, 2, 3, 4]} activeIdx={1} />
    <Shutter />
    <BottomControls />
    <HomeIndicator light />
    {/* dim */}
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.55)', zIndex: 30, backdropFilter: 'blur(2px)' }} />
    {/* alert */}
    <div style={{
    position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%,-50%)',
    width: 280, background: 'rgba(245,245,245,.96)', backdropFilter: 'blur(40px)',
    borderRadius: 14, zIndex: 31, overflow: 'hidden',
    boxShadow: '0 10px 40px rgba(0,0,0,.25)'
  }}>
      <div style={{ padding: '20px 16px 14px', textAlign: 'center' }}>
        <div style={{ fontSize: 17, fontWeight: 600, color: '#000', letterSpacing: -.3 }}>
          가이드라인을 삭제할까요?
        </div>
        <div style={{ fontSize: 13, color: '#3c3c43', marginTop: 6, lineHeight: 1.35 }}>
          삭제한 가이드라인은 복구할 수 없어요.
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', borderTop: '.5px solid rgba(0,0,0,.18)' }}>
        <button style={alertBtn}>취소</button>
        <button style={{ ...alertBtn, color: danger, fontWeight: 600, borderLeft: '.5px solid rgba(0,0,0,.18)' }}>삭제</button>
      </div>
    </div>
  </Phone>;

const alertBtn = {
  padding: '13px 0', fontSize: 17, color: '#007aff', background: 'transparent',
  border: 'none', cursor: 'pointer', fontFamily: 'inherit'
};

// ─────────────────────────────────────────────
// s2 — extraction
// ─────────────────────────────────────────────
const S2Header = ({ doneActive, title = '새 가이드라인' }) => {
  const t = useTheme();
  return (
<div style={{
  position: 'absolute', top: SH, left: 0, right: 0, height: 52, zIndex: 5,
  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
  padding: '0 18px', background: t.paper
}}>
    <button style={hdrBtn}>취소</button>
    <span style={{ fontSize: 17, fontWeight: 600, color: ink, letterSpacing: -.2 }}>{title}</span>
    <button style={{ ...hdrBtn, color: doneActive ? t.doneOn : t.doneOff, fontWeight: 600 }}>완료</button>
  </div>
  );
};

const hdrBtn = {
  background: 'transparent', border: 'none', fontSize: 17, color: ink,
  cursor: 'pointer', fontFamily: 'inherit', padding: 0
};

const PhotoArea = ({ children, ratio = '3:4' }) =>
<div style={{
  position: 'absolute', top: SH + 52 + 18, left: 18, right: 18, bottom: 100,
  borderRadius: 26, overflow: 'hidden',
  background: '#1a1a1c',
  boxShadow: '0 14px 30px rgba(0,0,0,.12), inset 0 0 0 .5px rgba(0,0,0,.08)'
}}>
    {/* faux photo gradient */}
    <div style={{
    position: 'absolute', inset: 0,
    background: `
        radial-gradient(80% 60% at 50% 38%, #d6c9a8 0%, transparent 60%),
        radial-gradient(120% 100% at 90% 110%, #6c5c3d 0%, transparent 60%),
        linear-gradient(180deg, #b3a283 0%, #5a4a35 100%)
      `
  }} />
    {/* subject blob */}
    <svg viewBox="0 0 300 400" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
      <ellipse cx="150" cy="155" rx="50" ry="62" fill="rgba(60,40,20,.4)" />
      <path d="M 60 290 Q 150 220 240 290 L 240 400 L 60 400 Z" fill="rgba(60,40,20,.45)" />
    </svg>
    {children}
  </div>;


const S2Loading = ({ theme = 'warm' }) =>
<Phone bg={THEMES[theme].paper} theme={theme}>
    <StatusBar />
    <S2Header doneActive={false} />
    <PhotoArea>
      <div style={{
      position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center', gap: 22,
      background: 'rgba(0,0,0,.42)', backdropFilter: 'blur(8px)'
    }}>
        <div style={{
        width: 48, height: 48, borderRadius: '50%',
        border: '3px solid rgba(255,255,255,.25)', borderTopColor: '#fff',
        animation: 'pobySpin 1s linear infinite'
      }} />
        <div style={{ color: '#fff', fontSize: 16, fontWeight: 600, letterSpacing: -.2 }}>
          인물을 감지하고 있어요
        </div>
        <div style={{
        width: 220, height: 6, borderRadius: 3, background: 'rgba(255,255,255,.18)', overflow: 'hidden'
      }}>
          <div style={{
          width: '62%', height: '100%', background: mint, borderRadius: 3,
          boxShadow: `0 0 12px ${mint}`
        }} />
        </div>
        <div style={{ color: 'rgba(255,255,255,.65)', fontSize: 12, fontFamily: '"SF Mono",ui-monospace,monospace' }}>
          62 % · 라인 추출 중
        </div>
      </div>
    </PhotoArea>
    <HomeIndicator />
  </Phone>;


const S2Success = ({ theme = 'warm' }) =>
<Phone bg={THEMES[theme].paper} theme={theme}>
    <StatusBar />
    <S2Header doneActive />
    <PhotoArea>
      <GuideOverlay opacity={.95} />
      <div style={{
      position: 'absolute', left: 16, right: 16, bottom: 16,
      background: 'rgba(0,0,0,.5)', backdropFilter: 'blur(10px)',
      color: '#fff', textAlign: 'center', padding: '10px 14px', borderRadius: 14,
      fontSize: 13, fontWeight: 500, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8
    }}>
        <ICheck size={16} c={mint} /> 가이드라인이 추출되었어요
      </div>
    </PhotoArea>
    <HomeIndicator />
  </Phone>;


const S2Error = ({ theme = 'warm' }) =>
<Phone bg={THEMES[theme].paper} theme={theme}>
    <StatusBar />
    <S2Header doneActive={false} />
    <PhotoArea>
      <div style={{
      position: 'absolute', inset: 0, background: 'rgba(0,0,0,.55)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24
    }}>
        <div style={{
        background: '#fff', borderRadius: 22, padding: '22px 18px 16px',
        textAlign: 'center', width: '100%'
      }}>
          <div style={{
          width: 44, height: 44, borderRadius: '50%',
          background: 'rgba(255,95,87,.12)', color: danger,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          margin: '0 auto 10px'
        }}>
            <Sw c={danger} w={2.2} d={<><circle cx="12" cy="12" r="9" /><path d="M12 7 V13" /><circle cx="12" cy="16.5" r=".4" fill={danger} /></>} />
          </div>
          <div style={{ fontSize: 17, fontWeight: 700, color: ink, letterSpacing: -.2 }}>
            인물을 찾지 못했어요
          </div>
          <div style={{ fontSize: 13, color: ink3, marginTop: 6, lineHeight: 1.4 }}>
            얼굴과 상체가 모두 보이는 사진으로<br />다시 시도해주세요.
          </div>
          <button style={{
          marginTop: 16, width: '100%', padding: '12px 0', borderRadius: 14,
          background: ink, color: '#fff', border: 'none', fontSize: 15, fontWeight: 600,
          cursor: 'pointer', fontFamily: 'inherit'
        }}>다른 사진 선택</button>
        </div>
      </div>
    </PhotoArea>
    <HomeIndicator />
  </Phone>;


// ─────────────────────────────────────────────
// s3 — capture for guide
// ─────────────────────────────────────────────
const S3Capture = ({ theme = 'warm' }) =>
<Phone theme={theme}>
    <Preview />
    <StatusBar light />
    {/* top: back + hint pill + (placeholder) */}
    <div style={{
    position: 'absolute', top: SH + 10, left: 0, right: 0, height: 44, zIndex: 25,
    display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 18px'
  }}>
      <GlassChip><IBack /></GlassChip>
      <div style={{
      padding: '8px 14px', borderRadius: 999,
      background: 'rgba(0,0,0,.4)', backdropFilter: 'blur(10px)',
      color: '#fff', fontSize: 13, fontWeight: 500
    }}>가이드로 쓸 사진을 찍어주세요</div>
      <GlassChip><IFlash /></GlassChip>
    </div>
    {/* big composition tip */}
    <div style={{
    position: 'absolute', left: 0, right: 0, bottom: STRIP_BOTTOM + 0,
    textAlign: 'center', color: 'rgba(255,255,255,.78)', fontSize: 13, zIndex: 18
  }}>
      얼굴 · 상체가 모두 보이도록
    </div>
    <Shutter />
    <BottomControls />
    <HomeIndicator light />
  </Phone>;


const S3Recapture = ({ theme = 'warm' }) => {
  const t = THEMES[theme];
  return (
<Phone theme={theme}>
    <Preview />
    <StatusBar light />
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.55)', zIndex: 28, backdropFilter: 'blur(6px)' }} />
    {/* card */}
    <div style={{
    position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%,-50%)',
    width: 300, background: '#fff', borderRadius: 22, zIndex: 29,
    padding: '22px 20px 18px', textAlign: 'center',
    boxShadow: '0 16px 50px rgba(0,0,0,.35)'
  }}>
      <div style={{ fontSize: 17, fontWeight: 700, color: ink, letterSpacing: -.2 }}>
        이 사진으로 가이드를 만들까요?
      </div>
      <div style={{ fontSize: 13, color: ink3, marginTop: 6 }}>
        완료를 누르면 가이드라인을 추출해요.
      </div>
      <div style={{ display: 'flex', gap: 10, marginTop: 18 }}>
        <button style={{
        flex: 1, padding: '13px 0', borderRadius: 14,
        background: t.paper2, color: ink, border: 'none', fontSize: 15, fontWeight: 600,
        cursor: 'pointer', fontFamily: 'inherit'
      }}>재촬영</button>
        <button style={{
        flex: 1, padding: '13px 0', borderRadius: 14,
        background: mint, color: mintDeep, border: 'none', fontSize: 15, fontWeight: 700,
        cursor: 'pointer', fontFamily: 'inherit',
        boxShadow: '0 6px 14px rgba(77,214,182,.4)'
      }}>완료</button>
      </div>
    </div>
    <HomeIndicator light />
  </Phone>
  );
};


// ─────────────────────────────────────────────
// s4 — gallery
// ─────────────────────────────────────────────
const S4Gallery = ({ selectedIdx = null, theme = 'warm' }) => {
  const cells = Array.from({ length: 18 });
  // varied faux-photo gradients for visual texture
  const palettes = [
  ['#e6d5b8', '#b39572'], ['#cdd6e0', '#7d8a9a'], ['#e8c2c2', '#a37272'],
  ['#c5d8c0', '#6e8c6a'], ['#dcd1e6', '#8470a0'], ['#f0e0c0', '#b08858'],
  ['#c5c5c5', '#6b6b6b'], ['#e0d8a0', '#8a7e50'], ['#d4a8b8', '#7e5363']];

  return (
    <Phone bg={THEMES[theme].paper} theme={theme}>
      <StatusBar />
      <S2Header doneActive={selectedIdx != null} title="사진 선택" />
      {/* album dropdown */}
      <div style={{
        position: 'absolute', top: SH + 52 + 12, left: 18,
        display: 'flex', alignItems: 'center', gap: 4,
        fontSize: 15, fontWeight: 600, color: ink
      }}>
        최근 항목 <IChevron dir="down" c={ink} size={14} />
      </div>
      <div style={{
        position: 'absolute', top: SH + 52 + 44, left: 12, right: 12, bottom: 24,
        display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 3, overflow: 'hidden'
      }}>
        {cells.map((_, i) => {
          const p = palettes[i % palettes.length];
          const sel = i === selectedIdx;
          return (
            <div key={i} style={{
              aspectRatio: '1/1', borderRadius: 3, overflow: 'hidden', position: 'relative',
              background: `linear-gradient(135deg, ${p[0]} 0%, ${p[1]} 100%)`,
              boxShadow: sel ? `inset 0 0 0 3px ${mint}` : 'none'
            }}>
              {/* faint figure */}
              <svg viewBox="0 0 100 100" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
                <ellipse cx="50" cy="38" rx="14" ry="17" fill="rgba(0,0,0,.18)" />
                <path d="M22 80 Q 50 60 78 80 L 78 100 L 22 100 Z" fill="rgba(0,0,0,.2)" />
              </svg>
              {sel &&
              <div style={{
                position: 'absolute', top: 6, right: 6, width: 22, height: 22, borderRadius: 11,
                background: mint, display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: '0 2px 6px rgba(0,0,0,.2)'
              }}><ICheck c={mintDeep} size={13} /></div>
              }
              {!sel &&
              <div style={{
                position: 'absolute', top: 6, right: 6, width: 22, height: 22, borderRadius: 11,
                border: '1.5px solid rgba(255,255,255,.85)'
              }} />
              }
            </div>);

        })}
      </div>
      <HomeIndicator />
    </Phone>);

};

// ─────────────────────────────────────────────
// export
// ─────────────────────────────────────────────
// theme-aware s1 wrappers (S1Empty / S1WithGuides don't show paper, but pass
// theme through so any future paper-using descendants pick it up)
const S1EmptyT = ({ theme = 'warm' }) => <ThemeCtx.Provider value={THEMES[theme]}><S1Empty/></ThemeCtx.Provider>;
const S1WithGuidesT = (p) => <ThemeCtx.Provider value={THEMES[p.theme||'warm']}><S1WithGuides {...p}/></ThemeCtx.Provider>;

Object.assign(window, {
  PW, PH, THEMES,
  S1Empty, S1WithGuides, S1PlusModal, S1DeleteModal,
  S1EmptyT, S1WithGuidesT,
  S2Loading, S2Success, S2Error,
  S3Capture, S3Recapture,
  S4Gallery
});