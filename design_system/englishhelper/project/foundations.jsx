/* foundations.jsx — Foundations section (colors, type, spacing, radii, motion).
   Exports window.FoundationsSections() -> fragment of <DCSection>. */

function Panel({ theme = 'dark', children, pad = 28, style }) {
  return (
    <div className={`eh eh-${theme}`} style={{ width: '100%', height: '100%', background: 'var(--bg)',
      color: 'var(--text)', padding: pad, overflow: 'hidden', ...style }}>{children}</div>
  );
}
function PanelTitle({ children, sub }) {
  return (
    <div style={{ marginBottom: 22 }}>
      <div style={{ fontSize: 13, fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase', color: 'var(--text-3)' }}>{children}</div>
      {sub && <div style={{ fontSize: 14, color: 'var(--text-2)', marginTop: 6 }}>{sub}</div>}
    </div>
  );
}
function Sw({ c, name, val, border }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div style={{ height: 56, borderRadius: 12, background: c, border: border ? '1px solid var(--hairline)' : 'none' }} />
      <div>
        <div style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--text)' }}>{name}</div>
        <div style={{ fontSize: 11, color: 'var(--text-3)', fontFamily: 'ui-monospace, Menlo, monospace', marginTop: 1 }}>{val}</div>
      </div>
    </div>
  );
}
const SwGrid = ({ children, cols = 4 }) => (
  <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols},1fr)`, gap: 16 }}>{children}</div>
);

function ColorBoard({ theme }) {
  const sysDark = theme === 'dark';
  return (
    <Panel theme={theme}>
      <PanelTitle sub={sysDark ? 'Базовый режим. Чистый чёрный, белая/серая иерархия.' : 'iOS-нейтраль. Белые карточки на сгруппированном фоне.'}>
        {sysDark ? 'Цвета — Dark' : 'Цвета — Light'}
      </PanelTitle>
      <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', marginBottom: 12, letterSpacing: 0.4 }}>ПОВЕРХНОСТИ</div>
      <SwGrid cols={4}>
        <Sw c="var(--bg)" name="bg" val={sysDark ? '#000000' : '#F2F2F7'} border />
        <Sw c="var(--bg-2)" name="bg-2" val={sysDark ? '#0B0B0C' : '#FFFFFF'} border />
        <Sw c="var(--surface)" name="surface" val={sysDark ? 'wht 5.5%' : '#FFFFFF'} border />
        <Sw c="var(--surface-2)" name="surface-2" val={sysDark ? 'wht 10%' : '#FFF'} border />
      </SwGrid>
      <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', margin: '24px 0 12px', letterSpacing: 0.4 }}>ТЕКСТ И ШТРИХ</div>
      <SwGrid cols={4}>
        <Sw c="var(--text)" name="text" val={sysDark ? '#FFFFFF' : '#060607'} border />
        <Sw c="var(--text-2)" name="text-2" val="62%" border />
        <Sw c="var(--text-3)" name="text-3" val="34%" border />
        <Sw c="var(--hairline-strong)" name="hairline" val="separator" border />
      </SwGrid>
      <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', margin: '24px 0 12px', letterSpacing: 0.4 }}>СИГНАЛЫ — ТОЛЬКО ФУНКЦИОНАЛЬНО</div>
      <SwGrid cols={4}>
        <Sw c="var(--live)" name="live · слушаю" val={sysDark ? '#30D158' : '#28BD4E'} />
        <Sw c="var(--green)" name="success" val="выучено" />
        <Sw c="var(--red)" name="danger" val="удалить/ошибка" />
        <Sw c="var(--blue)" name="link · iOS" val="системные" />
      </SwGrid>
      <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', margin: '24px 0 12px', letterSpacing: 0.4 }}>МАТЕРИАЛЫ (LIQUID GLASS)</div>
      <div style={{ display: 'flex', gap: 14 }}>
        {['var(--glass)', 'var(--glass-strong)', 'var(--scrim)'].map((g, i) => (
          <div key={i} style={{ flex: 1, height: 64, borderRadius: 14, position: 'relative', overflow: 'hidden',
            background: 'repeating-linear-gradient(45deg,var(--text-4),var(--text-4) 8px,transparent 8px,transparent 16px)' }}>
            <div style={{ position: 'absolute', inset: 0, background: g, border: '0.5px solid var(--glass-border)',
              backdropFilter: i < 2 ? 'blur(18px)' : 'none', WebkitBackdropFilter: i < 2 ? 'blur(18px)' : 'none',
              display: 'grid', placeItems: 'center', fontSize: 12, fontWeight: 600, color: i === 2 ? '#fff' : 'var(--text)' }}>
              {['glass', 'glass-strong', 'scrim · solid'][i]}
            </div>
          </div>
        ))}
      </div>
      <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 12, lineHeight: 1.4 }}>
        Glass — для плавающих баров и контролов. <b style={{ color: 'var(--text-2)' }}>Scrim — непрозрачный</b>: текст поверх фото/камеры лежит только на нём.
      </div>
    </Panel>
  );
}

function TypeBoard({ theme }) {
  const rows = [
    ['Large Title', '32 / 700 / -0.6', 32, 700, -0.6, 'Как сказать?'],
    ['Title 1', '26 / 700', 26, 700, -0.4, 'Варианты фраз'],
    ['Title 2', '21 / 650', 21, 650, -0.3, 'I appreciate it'],
    ['Headline', '17 / 600', 17, 600, -0.1, 'Отложить в изучаемое'],
    ['Body', '17 / 400', 17, 400, 0, 'Перевод появится здесь.'],
    ['Subhead', '15 / 400 · text-2', 15, 400, 0, 'Контекст на русском'],
    ['Footnote', '13 / 400 · text-3', 13, 400, 0, 'Запись не сохраняется'],
    ['Caption', '11 / 700 · UPPER', 11, 700, 0.4, 'FORMAL'],
  ];
  return (
    <Panel theme={theme}>
      <PanelTitle sub='SF Pro (-apple-system) · кириллица + латиница · tabular numerals'>Типографика</PanelTitle>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        {rows.map((r, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'baseline', gap: 16, borderBottom: '0.5px solid var(--hairline)', paddingBottom: 16 }}>
            <div style={{ width: 150, flex: '0 0 auto' }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text)' }}>{r[0]}</div>
              <div style={{ fontSize: 11, color: 'var(--text-3)', fontFamily: 'ui-monospace, monospace', marginTop: 2 }}>{r[1]}</div>
            </div>
            <div style={{ fontSize: r[2], fontWeight: r[3], letterSpacing: r[4], lineHeight: 1.1,
              color: i >= 5 ? 'var(--text-2)' : 'var(--text)', textTransform: r[0] === 'Caption' ? 'uppercase' : 'none' }}>{r[5]}</div>
          </div>
        ))}
      </div>
    </Panel>
  );
}

function SpacingBoard({ theme }) {
  const steps = [4, 8, 12, 16, 20, 24, 32, 40];
  return (
    <Panel theme={theme}>
      <PanelTitle sub='Базовая сетка 4 / 8 pt. Отступы кратны 4.'>Spacing</PanelTitle>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 13 }}>
        {steps.map((s) => (
          <div key={s} style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <div style={{ width: 42, fontSize: 12, fontWeight: 700, color: 'var(--text-2)', fontVariantNumeric: 'tabular-nums' }}>{s}</div>
            <div style={{ height: 14, width: s * 3.2, borderRadius: 4, background: 'var(--text)' }} />
            <div style={{ fontSize: 11, color: 'var(--text-3)', fontFamily: 'ui-monospace, monospace' }}>{s % 8 === 0 ? '8·' + s / 8 : '4·' + s / 4}</div>
          </div>
        ))}
      </div>
    </Panel>
  );
}

function RadiiBoard({ theme }) {
  const items = [['control', 14], ['card', 22], ['sheet', 30], ['pill', 999]];
  return (
    <Panel theme={theme}>
      <PanelTitle sub='Концентричные скругления Liquid Glass.'>Радиусы</PanelTitle>
      <div style={{ display: 'flex', gap: 16 }}>
        {items.map(([n, v]) => (
          <div key={n} style={{ flex: 1, textAlign: 'center' }}>
            <div style={{ height: 92, borderRadius: Math.min(v, 46), background: 'var(--surface)', border: '0.5px solid var(--hairline-strong)' }} />
            <div style={{ fontSize: 12.5, fontWeight: 600, marginTop: 10 }}>{n}</div>
            <div style={{ fontSize: 11, color: 'var(--text-3)', fontFamily: 'ui-monospace, monospace' }}>{v === 999 ? '∞' : v}</div>
          </div>
        ))}
      </div>
    </Panel>
  );
}

function MotionBoard({ theme }) {
  const rows = [
    ['quick', '140 ms', 'тап-отклик, переключатели'],
    ['standard', '260 ms', 'переходы, появление карточек'],
    ['expressive', '420 ms', 'mic, флип-карта, сцены'],
  ];
  return (
    <Panel theme={theme}>
      <PanelTitle sub='Пружинистый ease — cubic-bezier(.2,.7,.3,1)'>Motion</PanelTitle>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        {rows.map((r, i) => (
          <div key={i}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 7 }}>
              <span style={{ fontSize: 13, fontWeight: 600 }}>{r[0]} · <span style={{ color: 'var(--text-3)', fontWeight: 500 }}>{r[1]}</span></span>
              <span style={{ fontSize: 12, color: 'var(--text-3)' }}>{r[2]}</span>
            </div>
            <div style={{ height: 6, borderRadius: 3, background: 'var(--fill)', position: 'relative', overflow: 'hidden' }}>
              <div style={{ position: 'absolute', top: 0, left: 0, bottom: 0, width: '34%', borderRadius: 3, background: 'var(--text)',
                animation: `eh-slide${i} ${[1.4, 2, 2.8][i]}s cubic-bezier(.2,.7,.3,1) infinite` }} />
            </div>
          </div>
        ))}
      </div>
      <div style={{ marginTop: 26, display: 'flex', gap: 20, alignItems: 'center' }}>
        <MicControl state="listening" size={66} label={null} />
        <div style={{ fontSize: 12.5, color: 'var(--text-2)', lineHeight: 1.5 }}>
          Состояния голоса — через движение, а не цвет: расходящиеся кольца (слушаю), вращение (думаю).
        </div>
      </div>
      <style>{`@keyframes eh-slide0{0%{left:-34%}60%,100%{left:100%}}@keyframes eh-slide1{0%{left:-34%}60%,100%{left:100%}}@keyframes eh-slide2{0%{left:-34%}60%,100%{left:100%}}`}</style>
    </Panel>
  );
}

window.FoundationsSections = function () {
  return (
    <React.Fragment>
      <DCSection id="found-color" title="Foundations · Цвет и материалы" subtitle="Монохром · Liquid Glass · сигналы только функциональны">
        <DCArtboard id="color-dark" label="Цвета · Dark" width={720} height={600} style={{ background: '#000' }}><ColorBoard theme="dark" /></DCArtboard>
        <DCArtboard id="color-light" label="Цвета · Light" width={720} height={600} style={{ background: '#F2F2F7' }}><ColorBoard theme="light" /></DCArtboard>
      </DCSection>
      <DCSection id="found-type" title="Foundations · Тип, сетка, движение" subtitle="SF Pro · 4/8pt · радиусы · motion">
        <DCArtboard id="type" label="Типографика" width={560} height={640} style={{ background: '#000' }}><TypeBoard theme="dark" /></DCArtboard>
        <DCArtboard id="spacing" label="Spacing 4/8" width={420} height={460} style={{ background: '#000' }}><SpacingBoard theme="dark" /></DCArtboard>
        <DCArtboard id="radii" label="Радиусы" width={520} height={320} style={{ background: '#000' }}><RadiiBoard theme="dark" /></DCArtboard>
        <DCArtboard id="motion" label="Motion" width={520} height={420} style={{ background: '#000' }}><MotionBoard theme="dark" /></DCArtboard>
      </DCSection>
    </React.Fragment>
  );
};
