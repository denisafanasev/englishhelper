/* kit-parts.jsx — signature components.
   MicControl, WaveBars, PhraseVariantCard, OneAnswerCard, StudyItem,
   FlipCard, OcrPhoto, OcrOverlay, CenteredState, PermissionPrimer,
   IOSAlert. Exported to window. */

/* ---------- live waveform ---------- */
function WaveBars({ n = 7, color = 'var(--text)', h = 26, w = 3.5, gap = 4, animate = true }) {
  const seed = [0.5, 0.85, 0.4, 1, 0.6, 0.9, 0.45, 0.75, 0.55];
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap, height: h }}>
      {Array.from({ length: n }).map((_, i) => (
        <span key={i} style={{
          width: w, height: h, borderRadius: w, background: color, display: 'block',
          transformOrigin: 'center',
          transform: animate ? undefined : `scaleY(${seed[i % seed.length]})`,
          animation: animate ? `eh-bar ${0.7 + (i % 3) * 0.18}s ease-in-out ${i * 0.08}s infinite` : 'none',
        }} />
      ))}
    </div>
  );
}

/* ---------- the primary input: MicControl ---------- */
/* state: idle | listening | processing | error */
function MicControl({ state = 'idle', size = 168, label }) {
  const ring = Math.round(size * 1.18);
  const captions = {
    idle: 'Нажмите и говорите',
    listening: 'Слушаю',
    processing: 'Думаю…',
    error: 'Не расслышал',
  };
  const cap = label !== undefined ? label : captions[state];

  const discBg = {
    idle: 'var(--glass-strong)',
    listening: 'var(--glass-strong)',
    processing: 'var(--glass-strong)',
    error: 'var(--glass-strong)',
  }[state];
  const discBorder = state === 'error' ? 'var(--red)' : (state === 'listening' ? 'var(--live)' : 'var(--glass-border)');

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
      <div style={{ position: 'relative', width: ring, height: ring, display: 'grid', placeItems: 'center' }}>
        {/* ripple rings while listening */}
        {state === 'listening' && [0, 1, 2].map((i) => (
          <span key={i} style={{
            position: 'absolute', width: size * 0.92, height: size * 0.92, borderRadius: '50%',
            border: '2px solid var(--live)',
            animation: `eh-ripple 2.4s cubic-bezier(.2,.7,.3,1) ${i * 0.8}s infinite`,
          }} />
        ))}
        {/* processing rotating arc */}
        {state === 'processing' && (
          <svg width={ring} height={ring} viewBox="0 0 100 100" style={{ position: 'absolute', animation: 'eh-spin 1.05s linear infinite' }}>
            <circle cx="50" cy="50" r="46" fill="none" stroke="var(--text)" strokeWidth="3" strokeLinecap="round" strokeDasharray="70 220" />
          </svg>
        )}
        {/* idle / listening soft outer ring guide */}
        {(state === 'idle') && (
          <span style={{ position: 'absolute', width: ring - 6, height: ring - 6, borderRadius: '50%', border: '1px solid var(--hairline)' }} />
        )}

        {/* the disc */}
        <div style={{
          width: size, height: size, borderRadius: '50%', position: 'relative',
          display: 'grid', placeItems: 'center',
          background: discBg, border: `2px solid ${discBorder}`,
          backdropFilter: 'blur(24px) saturate(1.5)', WebkitBackdropFilter: 'blur(24px) saturate(1.5)',
          boxShadow: state === 'listening'
            ? '0 0 0 6px color-mix(in srgb, var(--live) 16%, transparent), var(--shadow)'
            : 'var(--shadow)',
        }}>
          {state === 'idle' && <Icon name="mic.fill" size={size * 0.4} weight={1.6} />}
          {state === 'listening' && <WaveBars n={7} h={size * 0.34} color="var(--text)" w={size * 0.026} gap={size * 0.03} />}
          {state === 'processing' && (
            <div style={{ display: 'flex', gap: size * 0.045 }}>
              {[0, 1, 2].map((i) => (
                <span key={i} style={{ width: size * 0.07, height: size * 0.07, borderRadius: '50%', background: 'var(--text-2)',
                  animation: `eh-breathe 1s ease-in-out ${i * 0.16}s infinite` }} />
              ))}
            </div>
          )}
          {state === 'error' && <Icon name="exclamationmark.triangle" size={size * 0.34} weight={1.7} color="var(--red)" />}

          {/* live tally dot */}
          {state === 'listening' && (
            <span style={{ position: 'absolute', top: size * 0.13, right: size * 0.16, display: 'flex', alignItems: 'center', gap: 5 }}>
              <span style={{ width: 8, height: 8, borderRadius: 5, background: 'var(--live)', animation: 'eh-blink 1.2s steps(1) infinite' }} />
            </span>
          )}
        </div>
      </div>
      {cap !== null && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, minHeight: 22 }}>
          {state === 'listening' && <span style={{ width: 7, height: 7, borderRadius: 4, background: 'var(--live)' }} />}
          <span style={{ fontSize: 17, fontWeight: 600, letterSpacing: -0.2,
            color: state === 'error' ? 'var(--red)' : (state === 'idle' ? 'var(--text-2)' : 'var(--text)') }}>{cap}</span>
        </div>
      )}
    </div>
  );
}

/* ---------- phrase variant card ---------- */
function PhraseVariantCard({ register = 'casual', en, ru, saved = false, playing = false, compact }) {
  return (
    <div style={{ background: 'var(--surface)', border: '0.5px solid var(--hairline)', borderRadius: R.card,
      padding: compact ? '14px 16px' : '16px 18px', boxShadow: 'var(--shadow-card)' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <RegisterTag level={register} />
        <button style={{ width: 32, height: 32, borderRadius: R.pill, border: 'none', cursor: 'pointer',
          display: 'grid', placeItems: 'center', background: saved ? 'var(--fill)' : 'transparent',
          color: saved ? 'var(--text)' : 'var(--text-3)' }}>
          <Icon name={saved ? 'bookmark.fill' : 'bookmark'} size={19} weight={1.8} />
        </button>
      </div>
      <div style={{ fontSize: compact ? 19 : 21, lineHeight: 1.25, fontWeight: 600, letterSpacing: -0.3,
        color: 'var(--text)', textWrap: 'pretty' }}>{en}</div>
      <div style={{ fontSize: 14, lineHeight: 1.4, color: 'var(--text-2)', marginTop: 7, textWrap: 'pretty' }}>{ru}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 14 }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, height: 36, padding: '0 14px 0 12px',
          borderRadius: R.pill, background: playing ? 'var(--invert)' : 'var(--fill)',
          color: playing ? 'var(--on-invert)' : 'var(--text)', fontSize: 14, fontWeight: 600 }}>
          {playing ? <WaveBars n={4} h={14} w={2.5} gap={2.5} color="var(--on-invert)" /> : <Icon name="speaker.minimal" size={17} weight={1.8} />}
          {playing ? 'Звучит' : 'Озвучить'}
        </div>
      </div>
    </div>
  );
}

/* ---------- single-answer hero ---------- */
function OneAnswerCard({ register = 'casual', en, ru, saved = false }) {
  return (
    <div style={{ background: 'var(--surface)', border: '0.5px solid var(--hairline)', borderRadius: R.sheet,
      padding: '24px 22px', boxShadow: 'var(--shadow-card)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <RegisterTag level={register} />
        <span style={{ fontSize: 13, color: 'var(--text-3)', fontWeight: 500 }}>лучший вариант</span>
      </div>
      <div style={{ fontSize: 27, lineHeight: 1.2, fontWeight: 700, letterSpacing: -0.6, textWrap: 'balance' }}>{en}</div>
      <div style={{ fontSize: 15, lineHeight: 1.45, color: 'var(--text-2)', marginTop: 12, textWrap: 'pretty' }}>{ru}</div>
      <div style={{ display: 'flex', gap: 10, marginTop: 22 }}>
        <div style={{ flex: 1, height: 52, borderRadius: R.pill, background: 'var(--invert)', color: 'var(--on-invert)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9, fontSize: 17, fontWeight: 600 }}>
          <Icon name="speaker.wave" size={20} weight={1.9} />Озвучить
        </div>
        <div style={{ width: 52, height: 52, borderRadius: R.pill, background: saved ? 'var(--fill)' : 'transparent',
          border: '0.5px solid var(--hairline)', display: 'grid', placeItems: 'center', color: 'var(--text)' }}>
          <Icon name={saved ? 'bookmark.fill' : 'bookmark'} size={21} weight={1.8} />
        </div>
      </div>
    </div>
  );
}

/* ---------- study list item ---------- */
function StudyItem({ en, ru, register = 'casual', learned = false, swiped = false }) {
  return (
    <div style={{ position: 'relative', borderRadius: R.card, overflow: 'hidden' }}>
      {/* delete action behind — only while swiped */}
      {swiped && (
        <div style={{ position: 'absolute', inset: 0, background: 'var(--red)', display: 'flex',
          alignItems: 'center', justifyContent: 'flex-end', paddingRight: 26, color: '#fff' }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
            <Icon name="trash" size={22} weight={1.9} /><span style={{ fontSize: 12, fontWeight: 600 }}>Удалить</span>
          </div>
        </div>
      )}
      <div style={{ position: 'relative', background: learned ? 'var(--fill-2)' : 'var(--surface)', border: '0.5px solid var(--hairline)',
        borderRadius: R.card, padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12,
        transform: swiped ? 'translateX(-92px)' : 'none', transition: 'transform .28s cubic-bezier(.2,.7,.3,1)' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
            <span style={{ fontSize: 17, fontWeight: 600, letterSpacing: -0.2, color: learned ? 'var(--text-3)' : 'var(--text)',
              textDecoration: learned ? 'line-through' : 'none', textDecorationColor: 'var(--text-4)',
              overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{en}</span>
          </div>
          <div style={{ fontSize: 14, color: learned ? 'var(--text-4)' : 'var(--text-2)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{ru}</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, flex: '0 0 auto' }}>
          <RegisterTag level={register} />
          <button style={{ width: 30, height: 30, borderRadius: R.pill, border: 'none', cursor: 'pointer', display: 'grid', placeItems: 'center',
            background: learned ? 'var(--green)' : 'var(--fill)', color: learned ? '#fff' : 'var(--text-3)' }}>
            <Icon name="checkmark" size={16} weight={2.4} />
          </button>
        </div>
      </div>
    </div>
  );
}

/* ---------- flashcard (flip) ---------- */
function FlipCard({ ru, en, context, register = 'casual', side = 'front', w = 300, h = 380 }) {
  const faceBase = {
    position: 'absolute', inset: 0, borderRadius: R.sheet, padding: '26px 24px',
    display: 'flex', flexDirection: 'column', backfaceVisibility: 'hidden', WebkitBackfaceVisibility: 'hidden',
    border: '0.5px solid var(--hairline)', boxShadow: 'var(--shadow-card)',
  };
  return (
    <div style={{ width: w, height: h, perspective: 1400 }}>
      <div style={{ position: 'relative', width: '100%', height: '100%', transformStyle: 'preserve-3d',
        transition: 'transform .6s cubic-bezier(.32,.72,0,1)', transform: side === 'back' ? 'rotateY(180deg)' : 'none' }}>
        {/* front: RU prompt */}
        <div style={{ ...faceBase, background: 'var(--surface)', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
          <span style={{ fontSize: 12, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase', color: 'var(--text-3)' }}>как сказать</span>
          <div style={{ fontSize: 26, fontWeight: 700, letterSpacing: -0.4, marginTop: 16, textWrap: 'balance' }}>{ru}</div>
          <div style={{ position: 'absolute', bottom: 22, left: 0, right: 0, fontSize: 13, color: 'var(--text-3)' }}>нажмите, чтобы перевернуть</div>
        </div>
        {/* back: EN answer */}
        <div style={{ ...faceBase, background: 'var(--invert)', color: 'var(--on-invert)', transform: 'rotateY(180deg)', justifyContent: 'center' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'absolute', top: 22, left: 24, right: 24 }}>
            <span style={{ display: 'inline-flex', height: 22, padding: '0 9px', alignItems: 'center', borderRadius: R.tag,
              background: 'color-mix(in srgb, var(--on-invert) 14%, transparent)', color: 'var(--on-invert)', fontSize: 11, fontWeight: 700, letterSpacing: 0.4, textTransform: 'uppercase' }}>{register}</span>
            <Icon name="speaker.wave" size={20} weight={1.9} />
          </div>
          <div style={{ fontSize: 26, fontWeight: 700, letterSpacing: -0.4, textWrap: 'balance' }}>{en}</div>
          {context && <div style={{ fontSize: 14, marginTop: 12, opacity: 0.66, textWrap: 'pretty' }}>{context}</div>}
        </div>
      </div>
    </div>
  );
}

/* ---------- faux photo for OCR ---------- */
function OcrPhoto({ children, style }) {
  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden',
      background: 'linear-gradient(155deg,#3a4654 0%,#2b333d 38%,#1c2127 72%,#141619 100%)', ...style }}>
      {/* faux signage panel */}
      <div style={{ position: 'absolute', top: '24%', left: '12%', right: '14%', bottom: '20%',
        background: 'linear-gradient(180deg,#e9e3d4,#d8d0bd)', borderRadius: 8, transform: 'rotate(-1.4deg)',
        boxShadow: '0 18px 50px rgba(0,0,0,.45)', padding: '26px 24px', color: '#2a2620' }}>
        <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: 0.4, fontFamily: 'Georgia, "Times New Roman", serif' }}>TODAY'S SPECIAL</div>
        <div style={{ height: 2, background: '#2a2620', width: 80, margin: '12px 0 16px', opacity: .5 }} />
        <div style={{ fontSize: 16, fontFamily: 'Georgia, serif', lineHeight: 2 }}>
          Slow-roasted beef brisket<br />Served with mashed potatoes<br />and seasonal greens
        </div>
        <div style={{ position: 'absolute', bottom: 22, left: 24, fontSize: 18, fontWeight: 800, fontFamily: 'Georgia, serif' }}>£ 14.50</div>
      </div>
      {/* light grain */}
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(120% 80% at 50% 0%, rgba(255,255,255,.06), transparent 60%)' }} />
      {children}
    </div>
  );
}

/* ---------- OCR translation overlay (SOLID scrim — never glass) ---------- */
function OcrScrim({ en, ru, style, w }) {
  return (
    <div style={{ position: 'absolute', background: 'var(--scrim)', borderRadius: 12, padding: '10px 13px',
      border: '0.5px solid rgba(255,255,255,0.10)', boxShadow: '0 8px 24px rgba(0,0,0,.4)',
      maxWidth: w || 230, ...style }}>
      <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.55)', fontWeight: 500, marginBottom: 2 }}>{en}</div>
      <div style={{ fontSize: 16, color: '#fff', fontWeight: 600, letterSpacing: -0.2, lineHeight: 1.25 }}>{ru}</div>
    </div>
  );
}

/* ---------- centered states (empty / loading / error) ---------- */
function CenteredState({ icon, title, body, action, secondary, tone }) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      textAlign: 'center', padding: '0 40px', gap: 0 }}>
      <div style={{ width: 76, height: 76, borderRadius: R.pill, display: 'grid', placeItems: 'center', marginBottom: 22,
        background: 'var(--fill)', color: tone === 'error' ? 'var(--red)' : 'var(--text-2)' }}>
        {typeof icon === 'string' ? <Icon name={icon} size={34} weight={1.6} /> : icon}
      </div>
      <div style={{ fontSize: 21, fontWeight: 700, letterSpacing: -0.4 }}>{title}</div>
      {body && <div style={{ fontSize: 15, lineHeight: 1.45, color: 'var(--text-2)', marginTop: 8, maxWidth: 270, textWrap: 'pretty' }}>{body}</div>}
      {action && <div style={{ marginTop: 24, width: '100%', maxWidth: 280 }}>{action}</div>}
      {secondary && <div style={{ marginTop: 10 }}>{secondary}</div>}
    </div>
  );
}

/* loading skeleton block */
function Skeleton({ w = '100%', h = 16, r = 8, mt = 0 }) {
  return <div style={{ width: w, height: h, borderRadius: r, marginTop: mt,
    background: 'linear-gradient(90deg,var(--fill-2),var(--fill),var(--fill-2))', backgroundSize: '200% 100%',
    animation: 'eh-bar 0s', }} />;
}

/* ---------- permission primer (our UI before the system prompt) ---------- */
function PermissionPrimer({ kind = 'mic' }) {
  const data = {
    mic: { icon: 'mic.fill', title: 'Включите микрофон', body: 'EnglishHelper слушает русскую речь, чтобы мгновенно подсказать, как это сказать по-английски. Запись не сохраняется.', cta: 'Разрешить доступ' },
    camera: { icon: 'camera', title: 'Доступ к камере', body: 'Наведите камеру на меню, вывеску или текст — приложение распознает английский и покажет перевод поверх кадра.', cta: 'Открыть камеру' },
  }[kind];
  return (
    <CenteredState icon={data.icon} title={data.title} body={data.body}
      action={<Btn kind="primary" full size="lg">{data.cta}</Btn>}
      secondary={<button style={{ background: 'none', border: 'none', color: 'var(--text-3)', fontSize: 15, fontWeight: 600, cursor: 'pointer' }}>Не сейчас</button>} />
  );
}

/* ---------- native iOS permission alert mock ---------- */
function IOSAlert({ title, body, allow = 'Разрешить', deny = 'Не разрешать' }) {
  return (
    <div style={{ width: 270, borderRadius: 14, overflow: 'hidden', background: 'var(--glass-strong)',
      border: '0.5px solid var(--glass-border)', backdropFilter: 'blur(30px) saturate(1.6)', WebkitBackdropFilter: 'blur(30px) saturate(1.6)',
      boxShadow: '0 30px 80px rgba(0,0,0,.5)', textAlign: 'center' }}>
      <div style={{ padding: '19px 16px 16px' }}>
        <div style={{ fontSize: 17, fontWeight: 600, letterSpacing: -0.2 }}>{title}</div>
        <div style={{ fontSize: 13, lineHeight: 1.35, color: 'var(--text-2)', marginTop: 4 }}>{body}</div>
      </div>
      <div style={{ borderTop: '0.5px solid var(--hairline-strong)', display: 'flex', flexDirection: 'column' }}>
        <button style={{ height: 44, border: 'none', background: 'transparent', color: 'var(--blue)', fontSize: 17, fontWeight: 400, cursor: 'pointer', borderBottom: '0.5px solid var(--hairline-strong)' }}>{deny}</button>
        <button style={{ height: 44, border: 'none', background: 'transparent', color: 'var(--blue)', fontSize: 17, fontWeight: 600, cursor: 'pointer' }}>{allow}</button>
      </div>
    </div>
  );
}

Object.assign(window, { WaveBars, MicControl, PhraseVariantCard, OneAnswerCard, StudyItem, FlipCard, OcrPhoto, OcrScrim, CenteredState, Skeleton, PermissionPrimer, IOSAlert });
