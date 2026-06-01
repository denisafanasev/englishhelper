/* screens.jsx — full screens for flows A (Voice), B (Study), C (Camera OCR).
   Light + Dark. Exports window.ScreenSections(). */

/* small helpers */
function TopBar({ title, onBack, trailing, big }) {
  return (
    <div style={{ flex: '0 0 auto', padding: '2px 16px 10px', display: 'flex', alignItems: 'center', gap: 10 }}>
      {onBack !== undefined && <GlassIconBtn name="arrow.left" size={38} icon={20} />}
      <div style={{ fontSize: big ? 22 : 17, fontWeight: 700, letterSpacing: -0.3, flex: 1, textAlign: onBack !== undefined ? 'center' : 'left' }}>{title}</div>
      {onBack !== undefined && <div style={{ width: 38 }} />}
      {trailing}
    </div>
  );
}
function RecentRow({ ru, en }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px', background: 'var(--surface)',
      border: '0.5px solid var(--hairline)', borderRadius: R.control }}>
      <div style={{ width: 30, height: 30, borderRadius: R.pill, background: 'var(--fill)', display: 'grid', placeItems: 'center', color: 'var(--text-3)', flex: '0 0 auto' }}>
        <Icon name="speaker.minimal" size={15} weight={1.8} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{en}</div>
        <div style={{ fontSize: 12.5, color: 'var(--text-3)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{ru}</div>
      </div>
      <Icon name="chevron.right" size={16} weight={2} color="var(--text-4)" />
    </div>
  );
}
function FloatMic({ state = 'idle' }) {
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 30, display: 'flex', justifyContent: 'center' }}>
      <div style={{ width: 72, height: 72, borderRadius: R.pill, display: 'grid', placeItems: 'center',
        background: 'var(--invert)', color: 'var(--on-invert)', boxShadow: 'var(--shadow)' }}>
        <Icon name="mic.fill" size={30} weight={1.6} />
      </div>
    </div>
  );
}

/* ============ FLOW A — VOICE ============ */
function A_Idle({ theme }) {
  return (
    <Screen theme={theme}>
      <StatusBar />
      <TopBar title="Как сказать?" trailing={<GlassIconBtn name="gearshape" size={38} icon={19} />} big />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4 }}>
        <div style={{ fontSize: 15, color: 'var(--text-2)', marginBottom: 26, textAlign: 'center', maxWidth: 240, textWrap: 'balance' }}>
          Скажите фразу по-русски — подскажу, как это звучит по-английски
        </div>
        <MicControl state="idle" size={184} />
      </div>
      <div style={{ flex: '0 0 auto', padding: '0 16px 6px' }}>
        <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-3)', letterSpacing: 0.4, margin: '0 4px 10px' }}>НЕДАВНЕЕ</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <RecentRow en="I appreciate it" ru="Спасибо, ценю это" />
          <RecentRow en="Could you help me out?" ru="Не могли бы вы помочь?" />
        </div>
      </div>
      <TabBar active={0} />
      <HomeIndicator />
    </Screen>
  );
}

function A_Listening({ theme }) {
  return (
    <Screen theme={theme}>
      <StatusBar />
      <TopBar title="Как сказать?" trailing={<GlassIconBtn name="gearshape" size={38} icon={19} />} big />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 30, padding: '0 28px' }}>
        <div style={{ background: 'var(--surface)', border: '0.5px solid var(--hairline)', borderRadius: R.card, padding: '16px 18px', width: '100%' }}>
          <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', letterSpacing: 0.5, marginBottom: 6 }}>РАСПОЗНАЮ РЕЧЬ</div>
          <div style={{ fontSize: 19, fontWeight: 600, letterSpacing: -0.2, lineHeight: 1.3 }}>
            Как мне вежливо попросить о помощи<span style={{ color: 'var(--text-3)' }}>…</span>
            <span style={{ display: 'inline-block', width: 2, height: 18, background: 'var(--live)', marginLeft: 2, verticalAlign: 'middle', animation: 'eh-blink 1s steps(1) infinite' }} />
          </div>
        </div>
        <MicControl state="listening" size={184} />
        <button style={{ display: 'inline-flex', alignItems: 'center', gap: 8, height: 46, padding: '0 22px', borderRadius: R.pill,
          background: 'var(--fill)', border: '0.5px solid var(--hairline)', color: 'var(--text)', fontSize: 16, fontWeight: 600, cursor: 'pointer' }}>
          <Icon name="stop" size={15} /> Стоп
        </button>
      </div>
      <HomeIndicator />
    </Screen>
  );
}

function A_Variants({ theme }) {
  return (
    <Screen theme={theme}>
      <StatusBar />
      <TopBar title="Перевод" onBack trailing={null} />
      <div style={{ flex: 1, overflow: 'hidden', padding: '0 16px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ background: 'var(--fill-2)', borderRadius: R.control, padding: '12px 14px', marginBottom: 14 }}>
          <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', letterSpacing: 0.4, marginBottom: 3 }}>ВЫ СКАЗАЛИ</div>
          <div style={{ fontSize: 16, fontWeight: 600 }}>«Как вежливо попросить о помощи»</div>
        </div>
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 16 }}>
          <SegToggle value={0} width={320} />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <PhraseVariantCard register="formal" en="Could you possibly help me with something?" ru="Максимально вежливо — к незнакомым, в письмах, на работе." compact />
          <PhraseVariantCard register="casual" en="Can you give me a hand?" ru="Нейтрально и дружелюбно — для коллег и приятелей." playing compact />
          <PhraseVariantCard register="slang" en="Mind helping me out real quick?" ru="Неформально — для близких друзей." compact />
        </div>
      </div>
      <FloatMic />
      <HomeIndicator />
    </Screen>
  );
}

function A_One({ theme }) {
  return (
    <Screen theme={theme}>
      <StatusBar />
      <TopBar title="Перевод" onBack trailing={null} />
      <div style={{ flex: 1, padding: '0 16px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ background: 'var(--fill-2)', borderRadius: R.control, padding: '12px 14px', marginBottom: 14 }}>
          <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', letterSpacing: 0.4, marginBottom: 3 }}>ВЫ СКАЗАЛИ</div>
          <div style={{ fontSize: 16, fontWeight: 600 }}>«Как вежливо попросить о помощи»</div>
        </div>
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 18 }}>
          <SegToggle value={1} width={320} />
        </div>
        <OneAnswerCard register="casual" en="Could you give me a hand?" ru="Тёплая, естественная просьба — подходит почти всегда, звучит вежливо и не сухо." />
        <button style={{ marginTop: 16, alignSelf: 'center', display: 'inline-flex', alignItems: 'center', gap: 6, height: 40, padding: '0 16px',
          borderRadius: R.pill, background: 'transparent', border: 'none', color: 'var(--text-2)', fontSize: 14, fontWeight: 600, cursor: 'pointer' }}>
          Показать ещё 3 варианта <Icon name="chevron.down" size={15} weight={2.2} />
        </button>
      </div>
      <FloatMic />
      <HomeIndicator />
    </Screen>
  );
}

/* ============ FLOW B — STUDY ============ */
function B_List({ theme }) {
  return (
    <Screen theme={theme}>
      <StatusBar />
      <Header title="Изучаю" sub="12 фраз · 5 выучено"
        trailing={<><GlassIconBtn name="rectangle.stack" size={38} icon={20} /><GlassIconBtn name="plus" size={38} icon={20} weight={2.2} /></>} />
      <div style={{ display: 'flex', gap: 8, padding: '0 18px 14px', flex: '0 0 auto' }}>
        <Chip active>Все</Chip><Chip>Учить · 7</Chip><Chip>Выучено · 5</Chip>
      </div>
      <div style={{ flex: 1, overflow: 'hidden', padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <StudyItem en="Could you give me a hand?" ru="Не могли бы вы помочь?" register="casual" />
        <StudyItem en="I appreciate it" ru="Спасибо, ценю это" register="formal" />
        <StudyItem en="No worries at all" ru="Ничего страшного" register="casual" />
        <StudyItem en="Let's grab a coffee" ru="Давай выпьем кофе" register="slang" />
        <StudyItem en="I'm running late" ru="Я опаздываю" register="casual" learned />
        <StudyItem en="Sounds good to me" ru="Меня устраивает" register="casual" learned />
      </div>
      <TabBar active={1} />
      <HomeIndicator />
    </Screen>
  );
}

function B_Cards({ theme }) {
  return (
    <Screen theme={theme}>
      <StatusBar />
      <div style={{ flex: '0 0 auto', padding: '2px 16px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <GlassIconBtn name="xmark" size={38} icon={18} weight={2} />
        <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--text-2)', fontVariantNumeric: 'tabular-nums' }}>3 / 12</span>
        <GlassIconBtn name="arrow.2.circlepath" size={38} icon={19} />
      </div>
      <div style={{ flex: '0 0 auto', padding: '4px 30px 0' }}>
        <div style={{ height: 5, borderRadius: 3, background: 'var(--fill)', overflow: 'hidden' }}>
          <div style={{ width: '25%', height: '100%', background: 'var(--text)', borderRadius: 3 }} />
        </div>
      </div>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '0 28px' }}>
        <FlipCard side="back" en="I'm running late" context="Casual · самый частый способ сказать, что опаздываешь." register="casual" w={320} h={400} />
      </div>
      <div style={{ flex: '0 0 auto', padding: '0 20px 24px', display: 'flex', gap: 12 }}>
        <button style={{ flex: 1, height: 54, borderRadius: R.pill, background: 'var(--fill)', border: '0.5px solid var(--hairline)',
          color: 'var(--text)', fontSize: 16, fontWeight: 600, cursor: 'pointer' }}>Повторить</button>
        <button style={{ flex: 1, height: 54, borderRadius: R.pill, background: 'var(--green)', border: 'none',
          color: '#fff', fontSize: 16, fontWeight: 700, cursor: 'pointer', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
          <Icon name="checkmark" size={18} weight={2.6} />Выучил</button>
      </div>
      <HomeIndicator />
    </Screen>
  );
}

/* ============ FLOW C — CAMERA OCR ============ */
function C_Live({ theme }) {
  return (
    <Screen theme={theme} style={{ background: '#000' }}>
      <OcrPhoto />
      {/* live scrims */}
      <OcrScrim en="TODAY'S SPECIAL" ru="Блюдо дня" style={{ top: 250, left: 54 }} w={150} />
      <OcrScrim en="Slow-roasted beef brisket" ru="Говяжья грудинка медленного запекания" style={{ top: 392, left: 54 }} w={250} />
      <OcrScrim en="Served with mashed potatoes" ru="С картофельным пюре и зеленью" style={{ top: 500, left: 54 }} w={240} />
      {/* chrome (glass is fine for chrome) */}
      <div className="eh eh-dark" style={{ position: 'absolute', top: 0, left: 0, right: 0 }}>
        <StatusBar />
        <div style={{ padding: '0 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <GlassIconBtn name="xmark" size={40} icon={19} weight={2} />
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7, height: 36, padding: '0 14px', borderRadius: R.pill,
            background: 'rgba(20,20,22,0.55)', border: '0.5px solid rgba(255,255,255,0.16)', backdropFilter: 'blur(20px)', color: '#fff', fontSize: 13, fontWeight: 600 }}>
            <span style={{ width: 7, height: 7, borderRadius: 4, background: 'var(--live)' }} />Перевожу вживую
          </div>
          <GlassIconBtn name="globe" size={40} icon={19} />
        </div>
      </div>
      {/* bottom controls */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, paddingBottom: 34 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-around', padding: '0 36px' }}>
          <div style={{ width: 50, height: 50, borderRadius: 14, background: 'rgba(255,255,255,0.12)', border: '1px solid rgba(255,255,255,0.3)',
            display: 'grid', placeItems: 'center', color: '#fff' }}><Icon name="photo.stack" size={24} weight={1.7} /></div>
          <div style={{ width: 78, height: 78, borderRadius: R.pill, background: 'rgba(255,255,255,0.18)', display: 'grid', placeItems: 'center', border: '2px solid rgba(255,255,255,0.5)' }}>
            <div style={{ width: 64, height: 64, borderRadius: R.pill, background: '#fff' }} />
          </div>
          <div style={{ width: 50, height: 50, borderRadius: R.pill, background: 'rgba(255,255,255,0.12)', border: '1px solid rgba(255,255,255,0.3)',
            display: 'grid', placeItems: 'center', color: '#fff' }}><Icon name="bookmark" size={22} weight={1.8} /></div>
        </div>
      </div>
    </Screen>
  );
}

function C_Review({ theme }) {
  return (
    <Screen theme={theme}>
      {/* frozen photo top half */}
      <div style={{ position: 'relative', height: 430, flex: '0 0 auto' }}>
        <OcrPhoto />
        <OcrScrim en="TODAY'S SPECIAL" ru="Блюдо дня" style={{ top: 150, left: 50 }} w={150} />
        <OcrScrim en="Slow-roasted beef brisket" ru="Говяжья грудинка" style={{ top: 270, left: 50 }} w={220} />
        <div className="eh eh-dark" style={{ position: 'absolute', top: 0, left: 0, right: 0 }}>
          <StatusBar />
          <div style={{ padding: '0 16px', display: 'flex', justifyContent: 'space-between' }}>
            <GlassIconBtn name="arrow.left" size={40} icon={20} />
            <GlassIconBtn name="square.and.arrow.up" size={40} icon={19} />
          </div>
        </div>
      </div>
      {/* result sheet */}
      <div style={{ flex: 1, marginTop: -26, borderRadius: '28px 28px 0 0', background: 'var(--bg)', position: 'relative', zIndex: 2,
        padding: '10px 16px 0', display: 'flex', flexDirection: 'column' }}>
        <div style={{ width: 38, height: 5, borderRadius: 3, background: 'var(--text-4)', margin: '0 auto 14px' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <div style={{ fontSize: 21, fontWeight: 700, letterSpacing: -0.4 }}>Распознанный текст</div>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: 'var(--green)', fontSize: 13, fontWeight: 600 }}>
            <Icon name="checkmark.circle.fill" size={18} color="var(--green)" />Сохранено
          </span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {[['TODAY\u2019S SPECIAL', 'Блюдо дня'], ['Slow-roasted beef brisket', 'Говяжья грудинка медленного запекания'], ['Served with mashed potatoes', 'Подаётся с картофельным пюре']].map((r, i) => (
            <div key={i} style={{ background: 'var(--surface)', border: '0.5px solid var(--hairline)', borderRadius: R.control, padding: '12px 14px',
              display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 13, color: 'var(--text-3)', marginBottom: 2 }}>{r[0]}</div>
                <div style={{ fontSize: 16, fontWeight: 600 }}>{r[1]}</div>
              </div>
              <GlassIconBtn name="speaker.minimal" size={34} icon={17} />
            </div>
          ))}
        </div>
      </div>
      <HomeIndicator />
    </Screen>
  );
}

window.ScreenSections = function () {
  const F = ({ theme }) => ({ background: theme === 'dark' ? '#000' : '#F2F2F7' });
  return (
    <React.Fragment>
      <DCSection id="flow-a" title="Flow A · Голос → перевод" subtitle="Голос — primary input · варианты с тегами регистра / один ответ">
        <DCArtboard id="a-idle-d" label="Idle · Dark" width={393} height={852} style={F({ theme: 'dark' })}><A_Idle theme="dark" /></DCArtboard>
        <DCArtboard id="a-listen-d" label="Слушаю · Dark" width={393} height={852} style={F({ theme: 'dark' })}><A_Listening theme="dark" /></DCArtboard>
        <DCArtboard id="a-var-d" label="Варианты · Dark" width={393} height={852} style={F({ theme: 'dark' })}><A_Variants theme="dark" /></DCArtboard>
        <DCArtboard id="a-one-d" label="Один ответ · Dark" width={393} height={852} style={F({ theme: 'dark' })}><A_One theme="dark" /></DCArtboard>
        <DCArtboard id="a-idle-l" label="Idle · Light" width={393} height={852} style={F({ theme: 'light' })}><A_Idle theme="light" /></DCArtboard>
        <DCArtboard id="a-listen-l" label="Слушаю · Light" width={393} height={852} style={F({ theme: 'light' })}><A_Listening theme="light" /></DCArtboard>
        <DCArtboard id="a-var-l" label="Варианты · Light" width={393} height={852} style={F({ theme: 'light' })}><A_Variants theme="light" /></DCArtboard>
        <DCArtboard id="a-one-l" label="Один ответ · Light" width={393} height={852} style={F({ theme: 'light' })}><A_One theme="light" /></DCArtboard>
      </DCSection>
      <DCSection id="flow-b" title="Flow B · Изучаемое" subtitle="Список отложенных · swipe-удалить · выучено · карточки">
        <DCArtboard id="b-list-d" label="Список · Dark" width={393} height={852} style={F({ theme: 'dark' })}><B_List theme="dark" /></DCArtboard>
        <DCArtboard id="b-cards-d" label="Карточки · Dark" width={393} height={852} style={F({ theme: 'dark' })}><B_Cards theme="dark" /></DCArtboard>
        <DCArtboard id="b-list-l" label="Список · Light" width={393} height={852} style={F({ theme: 'light' })}><B_List theme="light" /></DCArtboard>
        <DCArtboard id="b-cards-l" label="Карточки · Light" width={393} height={852} style={F({ theme: 'light' })}><B_Cards theme="light" /></DCArtboard>
      </DCSection>
      <DCSection id="flow-c" title="Flow C · Камера / OCR" subtitle="Распознать EN → перевод поверх кадра на solid scrim → сохранить">
        <DCArtboard id="c-live-d" label="Камера live · Dark" width={393} height={852} style={{ background: '#000' }}><C_Live theme="dark" /></DCArtboard>
        <DCArtboard id="c-rev-d" label="Сохранено · Dark" width={393} height={852} style={F({ theme: 'dark' })}><C_Review theme="dark" /></DCArtboard>
        <DCArtboard id="c-rev-l" label="Сохранено · Light" width={393} height={852} style={F({ theme: 'light' })}><C_Review theme="light" /></DCArtboard>
      </DCSection>
    </React.Fragment>
  );
};
