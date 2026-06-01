/* kit-core.jsx — phone chrome + primitives.
   Depends on Icon (icons.jsx). All exported to window. */

const R = { control: 14, card: 22, sheet: 30, pill: 999, tag: 9 };

/* ---------- Screen shell (fills the artboard) ---------- */
function Screen({ theme = 'dark', children, pad = 0, style }) {
  return (
    <div className={`eh eh-${theme}`} style={{
      position: 'relative', width: '100%', height: '100%',
      background: 'var(--bg)', color: 'var(--text)', overflow: 'hidden',
      display: 'flex', flexDirection: 'column', padding: pad, ...style,
    }}>{children}</div>
  );
}

/* ---------- Status bar (iOS, dynamic island) ---------- */
function StatusBar({ time = '9:41', dark }) {
  const c = 'var(--text)';
  return (
    <div style={{ height: 54, flex: '0 0 auto', position: 'relative', display: 'flex',
      alignItems: 'center', justifyContent: 'space-between', padding: '0 30px 0 34px' }}>
      <div style={{ fontSize: 16, fontWeight: 600, letterSpacing: 0.2, color: c, fontVariantNumeric: 'tabular-nums', marginTop: 4 }}>{time}</div>
      {/* dynamic island */}
      <div style={{ position: 'absolute', left: '50%', top: 12, transform: 'translateX(-50%)',
        width: 122, height: 35, borderRadius: 20, background: '#000' }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginTop: 4, color: c }}>
        {/* cellular */}
        <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0.5" width="3" height="11.5" rx="1" opacity="0.35"/></svg>
        {/* wifi */}
        <svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor"><path d="M8.5 1.6c2.9 0 5.6 1.1 7.6 3 .3.2.3.6 0 .9l-.9.9c-.2.2-.6.2-.8 0a8.4 8.4 0 0 0-11.8 0c-.2.2-.6.2-.8 0l-.9-.9c-.3-.3-.3-.7 0-.9A11 11 0 0 1 8.5 1.6Z"/><path d="M8.5 5.8c1.6 0 3.1.6 4.2 1.7.3.2.3.6 0 .9l-1 1c-.2.2-.5.2-.8 0a4 4 0 0 0-4.9 0c-.2.2-.5.2-.7 0l-1-1c-.3-.3-.3-.7 0-.9a6 6 0 0 1 4.2-1.7Z"/><circle cx="8.5" cy="10.4" r="1.6"/></svg>
        {/* battery */}
        <svg width="27" height="13" viewBox="0 0 27 13"><rect x="0.5" y="0.5" width="22" height="12" rx="3.5" fill="none" stroke="currentColor" strokeOpacity="0.4"/><rect x="2.2" y="2.2" width="16" height="8.6" rx="2" fill="currentColor"/><path d="M24.5 4.2c1 .4 1 3.2 0 3.6V4.2Z" fill="currentColor" fillOpacity="0.5"/></svg>
      </div>
    </div>
  );
}

function HomeIndicator() {
  return (
    <div style={{ height: 28, flex: '0 0 auto', display: 'flex', alignItems: 'flex-end',
      justifyContent: 'center', paddingBottom: 9 }}>
      <div style={{ width: 138, height: 5, borderRadius: 3, background: 'var(--text)', opacity: 0.92 }} />
    </div>
  );
}

/* ---------- Large-title header ---------- */
function Header({ title, trailing, leading, sub, theme }) {
  return (
    <div style={{ padding: '4px 22px 12px', flex: '0 0 auto' }}>
      {leading && <div style={{ marginBottom: 14 }}>{leading}</div>}
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12 }}>
        <div>
          <div style={{ fontSize: 32, lineHeight: '37px', fontWeight: 700, letterSpacing: -0.6 }}>{title}</div>
          {sub && <div style={{ fontSize: 15, color: 'var(--text-2)', marginTop: 3 }}>{sub}</div>}
        </div>
        {trailing && <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>{trailing}</div>}
      </div>
    </div>
  );
}

/* ---------- glass round icon button ---------- */
function GlassIconBtn({ name, size = 38, icon = 20, weight = 1.8, active, onClick, fill }) {
  return (
    <button onClick={onClick} style={{
      width: size, height: size, borderRadius: R.pill, flex: '0 0 auto',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: active ? 'var(--invert)' : 'var(--glass)',
      color: active ? 'var(--on-invert)' : 'var(--icon)',
      border: '0.5px solid var(--glass-border)', cursor: 'pointer',
      backdropFilter: 'blur(20px) saturate(1.4)', WebkitBackdropFilter: 'blur(20px) saturate(1.4)',
    }}>
      <Icon name={name} size={icon} weight={weight} fill={fill} />
    </button>
  );
}

/* ---------- buttons ---------- */
function Btn({ children, kind = 'primary', icon, full, size = 'md', onClick, danger }) {
  const h = size === 'lg' ? 54 : size === 'sm' ? 36 : 48;
  const base = {
    height: h, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
    padding: size === 'sm' ? '0 16px' : '0 22px', borderRadius: R.pill, cursor: 'pointer',
    fontSize: size === 'sm' ? 15 : 17, fontWeight: 600, letterSpacing: -0.2,
    width: full ? '100%' : 'auto', border: 'none', whiteSpace: 'nowrap',
  };
  const styles = {
    primary: { background: danger ? 'var(--red)' : 'var(--invert)', color: danger ? '#fff' : 'var(--on-invert)' },
    glass: { background: 'var(--glass)', color: 'var(--text)', border: '0.5px solid var(--glass-border)',
      backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)' },
    tonal: { background: 'var(--fill)', color: 'var(--text)' },
    ghost: { background: 'transparent', color: danger ? 'var(--red)' : 'var(--text)' },
  };
  return (
    <button onClick={onClick} style={{ ...base, ...styles[kind] }}>
      {icon && <Icon name={icon} size={19} weight={2} />}{children}
    </button>
  );
}

/* ---------- register tag (monochrome, fill-density coded) ---------- */
const REGISTERS = {
  formal:  { label: 'formal',  ru: 'формально', fill: 'var(--text)',      fg: 'var(--on-invert)', border: 'transparent' },
  casual:  { label: 'casual',  ru: 'нейтрально', fill: 'var(--surface-2)', fg: 'var(--text)',      border: 'var(--hairline-strong)' },
  slang:   { label: 'slang',   ru: 'сленг',      fill: 'transparent',      fg: 'var(--text-2)',    border: 'var(--hairline-strong)' },
};
function RegisterTag({ level = 'casual', dot }) {
  const r = REGISTERS[level];
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, height: 22, padding: '0 9px',
      borderRadius: R.tag, background: r.fill, color: r.fg, border: `1px solid ${r.border}`,
      fontSize: 11, fontWeight: 700, letterSpacing: 0.4, textTransform: 'uppercase', flex: '0 0 auto' }}>
      {dot && <span style={{ width: 5, height: 5, borderRadius: 3, background: 'currentColor' }} />}
      {r.label}
    </span>
  );
}

/* ---------- chip / filter pill ---------- */
function Chip({ children, active, icon, onClick }) {
  return (
    <button onClick={onClick} style={{
      height: 34, padding: '0 14px', borderRadius: R.pill, display: 'inline-flex', alignItems: 'center', gap: 6,
      background: active ? 'var(--invert)' : 'var(--surface)', color: active ? 'var(--on-invert)' : 'var(--text-2)',
      border: active ? 'none' : '0.5px solid var(--hairline)', fontSize: 14, fontWeight: 600, cursor: 'pointer',
    }}>
      {icon && <Icon name={icon} size={15} weight={2} />}{children}
    </button>
  );
}

/* ---------- segmented output toggle ---------- */
function SegToggle({ value = 0, options = ['Варианты', 'Один ответ'], onChange, width }) {
  return (
    <div style={{ display: 'inline-flex', padding: 3, borderRadius: R.pill, background: 'var(--fill)',
      border: '0.5px solid var(--hairline)', width: width || 'auto' }}>
      {options.map((o, i) => (
        <button key={o} onClick={() => onChange && onChange(i)} style={{
          flex: width ? 1 : 'initial', height: 36, padding: '0 18px', borderRadius: R.pill, border: 'none', cursor: 'pointer',
          background: i === value ? 'var(--invert)' : 'transparent', color: i === value ? 'var(--on-invert)' : 'var(--text-2)',
          fontSize: 14.5, fontWeight: 600, letterSpacing: -0.1, transition: 'all .2s cubic-bezier(.2,.7,.3,1)',
          boxShadow: i === value ? 'var(--shadow)' : 'none',
        }}>{o}</button>
      ))}
    </div>
  );
}

/* ---------- bottom tab bar (glass) ---------- */
function TabBar({ active = 0 }) {
  const tabs = [
    { name: 'mic.fill', label: 'Голос' },
    { name: 'rectangle.stack', label: 'Изучаю' },
    { name: 'camera', label: 'Камера' },
  ];
  return (
    <div style={{ flex: '0 0 auto', padding: '6px 16px 0', display: 'flex', justifyContent: 'center' }}>
      <div style={{ display: 'flex', gap: 4, padding: 6, borderRadius: R.pill,
        background: 'var(--glass-strong)', border: '0.5px solid var(--glass-border)',
        backdropFilter: 'blur(24px) saturate(1.5)', WebkitBackdropFilter: 'blur(24px) saturate(1.5)',
        boxShadow: 'var(--shadow)' }}>
        {tabs.map((t, i) => (
          <div key={t.label} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
            padding: '8px 20px', borderRadius: R.pill, background: i === active ? 'var(--fill)' : 'transparent',
            color: i === active ? 'var(--text)' : 'var(--text-3)' }}>
            <Icon name={t.name} size={22} weight={1.9} />
            <span style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: 0.1 }}>{t.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { R, REGISTERS, Screen, StatusBar, HomeIndicator, Header, GlassIconBtn, Btn, RegisterTag, Chip, SegToggle, TabBar });
