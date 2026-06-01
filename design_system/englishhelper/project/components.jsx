/* components.jsx — Components section: every key component with all states.
   Exports window.ComponentSections() -> fragment of <DCSection>. */

function Stage({ theme = 'dark', children, pad = 30, style, center }) {
  return (
    <div className={`eh eh-${theme}`} style={{ width: '100%', height: '100%', background: 'var(--bg)',
      color: 'var(--text)', padding: pad, overflow: 'hidden',
      display: 'flex', flexDirection: 'column', justifyContent: center ? 'center' : 'flex-start', ...style }}>{children}</div>
  );
}
function Cap({ children }) {
  return <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-3)', marginTop: 16, textAlign: 'center', letterSpacing: 0.2 }}>{children}</div>;
}
function StageTitle({ children }) {
  return <div style={{ fontSize: 13, fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase', color: 'var(--text-3)', marginBottom: 26 }}>{children}</div>;
}

/* ---- MIC states ---- */
function MicStates({ theme }) {
  const states = ['idle', 'listening', 'processing', 'error'];
  const names = ['idle · покой', 'listening · слушаю', 'processing · думаю', 'error · не расслышал'];
  return (
    <Stage theme={theme}>
      <StageTitle>mic-control · primary input · все состояния</StageTitle>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'space-around', gap: 20 }}>
        {states.map((s, i) => (
          <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <MicControl state={s} size={120} label={null} />
            <Cap>{names[i]}</Cap>
          </div>
        ))}
      </div>
    </Stage>
  );
}

/* ---- phrase variant cards ---- */
function PhraseStates({ theme }) {
  return (
    <Stage theme={theme}>
      <StageTitle>phrase variant card — formal / casual / slang · состояния</StageTitle>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16 }}>
        <div><PhraseVariantCard register="formal" en="Could you help me with this?" ru="Вежливо, для коллег и незнакомых." /><Cap>default</Cap></div>
        <div><PhraseVariantCard register="casual" en="Can you give me a hand?" ru="Нейтрально, для друзей и быта." playing /><Cap>playing · озвучка</Cap></div>
        <div><PhraseVariantCard register="slang" en="Gimme a hand, will ya?" ru="Сленг, очень неформально." saved /><Cap>saved · отложено</Cap></div>
      </div>
    </Stage>
  );
}

/* ---- output toggle + one answer ---- */
function OutputStates({ theme }) {
  return (
    <Stage theme={theme}>
      <StageTitle>output toggle · режим ответа</StageTitle>
      <div style={{ display: 'flex', gap: 18, alignItems: 'center', marginBottom: 14 }}>
        <div><SegToggle value={0} /><Cap>Варианты</Cap></div>
        <div><SegToggle value={1} /><Cap>Один ответ</Cap></div>
      </div>
      <div style={{ marginTop: 18 }}>
        <OneAnswerCard register="casual" en="I appreciate it." ru="Когда хотите тепло поблагодарить за помощь." />
        <Cap>one-answer hero · режим «Один ответ»</Cap>
      </div>
    </Stage>
  );
}

/* ---- study items ---- */
function StudyStates({ theme }) {
  return (
    <Stage theme={theme}>
      <StageTitle>study item · список · состояния</StageTitle>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <StudyItem en="No worries at all" ru="Ничего страшного" register="casual" />
        <StudyItem en="I'm running late" ru="Я опаздываю" register="casual" learned />
        <StudyItem en="Let's grab a coffee" ru="Давай выпьем кофе" register="slang" swiped />
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-around', marginTop: 4 }}>
        <Cap>default</Cap><Cap>выучено</Cap><Cap>swipe → удалить</Cap>
      </div>
    </Stage>
  );
}

/* ---- flip card ---- */
function FlipStates({ theme }) {
  return (
    <Stage theme={theme} center>
      <StageTitle>flip-карта · режим заучивания</StageTitle>
      <div style={{ display: 'flex', gap: 28, justifyContent: 'center', alignItems: 'center' }}>
        <div><FlipCard side="front" ru="Я опаздываю" w={250} h={330} /><Cap>front · RU-подсказка</Cap></div>
        <div><FlipCard side="back" en="I'm running late" context="Casual. Самый частый способ предупредить." register="casual" w={250} h={330} /><Cap>back · ответ + озвучка</Cap></div>
      </div>
    </Stage>
  );
}

/* ---- OCR overlay ---- */
function OcrStates({ theme }) {
  return (
    <Stage theme={theme} pad={0}>
      <div style={{ position: 'relative', flex: 1 }}>
        <OcrPhoto />
        {/* solid scrim translations pinned over recognized english */}
        <OcrScrim en="TODAY'S SPECIAL" ru="Блюдо дня" style={{ top: '27%', left: '14%' }} w={150} />
        <OcrScrim en="Slow-roasted beef brisket" ru="Говяжья грудинка медленного запекания" style={{ top: '46%', left: '14%' }} w={230} />
        <OcrScrim en="Served with mashed potatoes" ru="Подаётся с картофельным пюре" style={{ top: '62%', left: '14%' }} w={220} />
        {/* top toolbar (glass — chrome is fine on glass; translations are not) */}
        <div style={{ position: 'absolute', top: 18, left: 18, right: 18, display: 'flex', justifyContent: 'space-between' }}>
          <div className="eh eh-dark" style={{ display: 'inline-flex', alignItems: 'center', gap: 7, height: 36, padding: '0 14px', borderRadius: 999,
            background: 'rgba(20,20,22,0.6)', border: '0.5px solid rgba(255,255,255,0.16)', backdropFilter: 'blur(20px)', color: '#fff', fontSize: 13, fontWeight: 600 }}>
            <span style={{ width: 7, height: 7, borderRadius: 4, background: 'var(--live)' }} />Распознано · EN
          </div>
        </div>
        <div style={{ position: 'absolute', left: 18, right: 18, bottom: 20, display: 'flex', justifyContent: 'center', gap: 10 }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, height: 46, padding: '0 20px', borderRadius: 999,
            background: '#fff', color: '#000', fontSize: 15, fontWeight: 600 }}>
            <Icon name="bookmark" size={18} weight={1.9} />Сохранить перевод
          </div>
        </div>
        <div style={{ position: 'absolute', top: 64, left: 18, fontSize: 11, fontWeight: 600, color: 'rgba(255,255,255,0.7)' }}>
          ↑ перевод лежит на непрозрачном scrim, не на стекле
        </div>
      </div>
    </Stage>
  );
}

/* ---- loading / empty / error ---- */
function StateBoard({ theme }) {
  return (
    <Stage theme={theme} pad={0}>
      <div style={{ display: 'flex', height: '100%' }}>
        {/* loading */}
        <div style={{ flex: 1, borderRight: '0.5px solid var(--hairline)', padding: 22, display: 'flex', flexDirection: 'column' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-3)', letterSpacing: 1, marginBottom: 20 }}>LOADING</div>
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 26 }}><MicControl state="processing" size={96} label="Думаю…" /></div>
          {[0, 1].map((i) => (
            <div key={i} style={{ background: 'var(--surface)', border: '0.5px solid var(--hairline)', borderRadius: R.card, padding: 14, marginBottom: 12 }}>
              <Skeleton w="38%" h={18} r={9} />
              <Skeleton w="86%" h={14} r={7} mt={12} />
              <Skeleton w="60%" h={12} r={6} mt={8} />
            </div>
          ))}
        </div>
        {/* empty */}
        <div style={{ flex: 1, borderRight: '0.5px solid var(--hairline)', display: 'flex', flexDirection: 'column' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-3)', letterSpacing: 1, padding: '22px 0 0 22px' }}>EMPTY</div>
          <CenteredState icon="rectangle.stack" title="Пока пусто" body="Отложенные фразы появятся здесь. Скажите фразу и нажмите закладку."
            action={<Btn kind="glass" full icon="mic.fill">Сказать фразу</Btn>} />
        </div>
        {/* error */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-3)', letterSpacing: 1, padding: '22px 0 0 22px' }}>ERROR</div>
          <CenteredState tone="error" icon="exclamationmark.triangle" title="Нет связи" body="Не удалось получить перевод. Проверьте интернет и попробуйте снова."
            action={<Btn kind="primary" full icon="arrow.2.circlepath">Повторить</Btn>} />
        </div>
      </div>
    </Stage>
  );
}

/* ---- permissions ---- */
function PermBoard({ theme }) {
  return (
    <Stage theme={theme} pad={0}>
      <div style={{ display: 'flex', height: '100%' }}>
        <div style={{ flex: 1, borderRight: '0.5px solid var(--hairline)', display: 'flex', flexDirection: 'column' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-3)', letterSpacing: 1, padding: '22px 0 0 22px' }}>МИКРОФОН · primer</div>
          <PermissionPrimer kind="mic" />
        </div>
        <div style={{ flex: 1, position: 'relative', display: 'flex', flexDirection: 'column' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-3)', letterSpacing: 1, padding: '22px 0 0 22px' }}>КАМЕРА · primer + системный алерт</div>
          <PermissionPrimer kind="camera" />
          <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.4)', display: 'grid', placeItems: 'center' }}>
            <IOSAlert title="«EnglishHelper» запрашивает доступ к камере" body="Чтобы распознавать и переводить текст с фото." />
          </div>
        </div>
      </div>
    </Stage>
  );
}

window.ComponentSections = function () {
  return (
    <React.Fragment>
      <DCSection id="cmp-voice" title="Компоненты · Голосовой ввод" subtitle="mic — огромный, состояния явные">
        <DCArtboard id="mic-dark" label="mic-control · Dark" width={940} height={320} style={{ background: '#000' }}><MicStates theme="dark" /></DCArtboard>
        <DCArtboard id="mic-light" label="mic-control · Light" width={940} height={320} style={{ background: '#F2F2F7' }}><MicStates theme="light" /></DCArtboard>
      </DCSection>
      <DCSection id="cmp-result" title="Компоненты · Результат" subtitle="карточки фраз, переключатель режима, один ответ">
        <DCArtboard id="phrase-dark" label="Карточки · Dark" width={760} height={380} style={{ background: '#000' }}><PhraseStates theme="dark" /></DCArtboard>
        <DCArtboard id="phrase-light" label="Карточки · Light" width={760} height={380} style={{ background: '#F2F2F7' }}><PhraseStates theme="light" /></DCArtboard>
        <DCArtboard id="output-dark" label="Toggle + один ответ" width={460} height={420} style={{ background: '#000' }}><OutputStates theme="dark" /></DCArtboard>
      </DCSection>
      <DCSection id="cmp-study" title="Компоненты · Изучение" subtitle="список, выучено, swipe, флип-карта">
        <DCArtboard id="study-dark" label="Study item · Dark" width={420} height={340} style={{ background: '#000' }}><StudyStates theme="dark" /></DCArtboard>
        <DCArtboard id="study-light" label="Study item · Light" width={420} height={340} style={{ background: '#F2F2F7' }}><StudyStates theme="light" /></DCArtboard>
        <DCArtboard id="flip-dark" label="Флип-карта · Dark" width={640} height={460} style={{ background: '#000' }}><FlipStates theme="dark" /></DCArtboard>
        <DCArtboard id="flip-light" label="Флип-карта · Light" width={640} height={460} style={{ background: '#F2F2F7' }}><FlipStates theme="light" /></DCArtboard>
      </DCSection>
      <DCSection id="cmp-ocr" title="Компоненты · Камера / OCR" subtitle="перевод на непрозрачном scrim — правило читаемости">
        <DCArtboard id="ocr" label="OCR-оверлей" width={393} height={620} style={{ background: '#000' }}><OcrStates theme="dark" /></DCArtboard>
      </DCSection>
      <DCSection id="cmp-states" title="Компоненты · Состояния и доступ" subtitle="loading · empty · error · permission">
        <DCArtboard id="states-dark" label="Состояния · Dark" width={840} height={560} style={{ background: '#000' }}><StateBoard theme="dark" /></DCArtboard>
        <DCArtboard id="states-light" label="Состояния · Light" width={840} height={560} style={{ background: '#F2F2F7' }}><StateBoard theme="light" /></DCArtboard>
        <DCArtboard id="perm-dark" label="Доступ · Dark" width={760} height={560} style={{ background: '#000' }}><PermBoard theme="dark" /></DCArtboard>
      </DCSection>
    </React.Fragment>
  );
};
