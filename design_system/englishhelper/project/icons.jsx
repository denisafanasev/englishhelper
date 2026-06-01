/* icons.jsx — SF Symbols 7-style line iconography, monochrome.
   <Icon name="mic" size={24} weight={1.7} fill={false} />
   Stroke icons inherit currentColor. */

const EH_ICON_PATHS = {
  // --- voice ---
  mic: (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round">
    <rect x="9" y="2.5" width="6" height="11" rx="3" /><path d="M5.5 11a6.5 6.5 0 0 0 13 0" /><path d="M12 17.5V21" /><path d="M8.5 21h7" /></g>),
  "mic.fill": (w) => (<g><rect x="9" y="2.5" width="6" height="11" rx="3" fill="currentColor" /><g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round"><path d="M5.5 11a6.5 6.5 0 0 0 13 0" /><path d="M12 17.5V21" /><path d="M8.5 21h7" /></g></g>),
  waveform: (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round"><path d="M3 11v2" /><path d="M7 7v10" /><path d="M11 3v18" /><path d="M15 8v8" /><path d="M19 10v4" /></g>),
  stop: (w) => (<rect x="6" y="6" width="12" height="12" rx="3" fill="currentColor" />),
  "speaker.wave": (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M4 9v6h3l4 3.5V5.5L7 9H4Z" fill="currentColor" stroke="none" /><path d="M14.5 8.5a5 5 0 0 1 0 7" /><path d="M17.5 6a8.5 8.5 0 0 1 0 12" /></g>),
  // --- nav / chrome ---
  "arrow.left": (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M11 5l-6 7 6 7" /><path d="M5 12h14" /></g>),
  "chevron.right": (w) => (<path d="M9 5l7 7-7 7" fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round" />),
  "chevron.down": (w) => (<path d="M5 9l7 7 7-7" fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round" />),
  xmark: (w) => (<path d="M6 6l12 12M18 6L6 18" fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" />),
  plus: (w) => (<path d="M12 5v14M5 12h14" fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" />),
  ellipsis: (w) => (<g fill="currentColor"><circle cx="5" cy="12" r="1.6" /><circle cx="12" cy="12" r="1.6" /><circle cx="19" cy="12" r="1.6" /></g>),
  // --- status ---
  checkmark: (w) => (<path d="M4.5 12.5l5 5 10-11" fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round" />),
  "checkmark.circle.fill": (w) => (<g><circle cx="12" cy="12" r="10" fill="currentColor" /><path d="M7.5 12.3l3 3 6-6.6" fill="none" stroke="var(--on-invert)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></g>),
  "exclamationmark.triangle": (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M12 3.5L22 19.5H2L12 3.5Z" /><path d="M12 9.5v4.5" /><circle cx="12" cy="17" r="0.6" fill="currentColor" stroke="none" /></g>),
  // --- study ---
  bookmark: (w) => (<path d="M7 4h10v16l-5-3.6L7 20V4Z" fill="none" stroke="currentColor" strokeWidth={w} strokeLinejoin="round" />),
  "bookmark.fill": (w) => (<path d="M7 4h10v16l-5-3.6L7 20V4Z" fill="currentColor" />),
  trash: (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M5 7h14" /><path d="M9 7V5h6v2" /><path d="M7 7l1 13h8l1-13" /><path d="M10 11v6M14 11v6" /></g>),
  "rectangle.stack": (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinejoin="round"><rect x="4" y="8.5" width="16" height="11" rx="2.5" /><path d="M6.5 5.5h11M8 3h8" strokeLinecap="round" /></g>),
  "arrow.2.circlepath": (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M4.5 9a7.5 7.5 0 0 1 13-2.5L20 8" /><path d="M20 4v4h-4" /><path d="M19.5 15a7.5 7.5 0 0 1-13 2.5L4 16" /><path d="M4 20v-4h4" /></g>),
  // --- camera / ocr ---
  camera: (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinejoin="round"><path d="M3 8.5A2 2 0 0 1 5 6.5h2l1.3-2h7.4L17 6.5h2a2 2 0 0 1 2 2V18a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8.5Z" /><circle cx="12" cy="13" r="3.6" /></g>),
  "camera.viewfinder": (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2" /><circle cx="12" cy="12" r="3.2" /></g>),
  photo: (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinejoin="round"><rect x="3.5" y="5" width="17" height="14" rx="2.5" /><circle cx="8.5" cy="10" r="1.6" /><path d="M5 17l4.5-4.5L13 16l3-2.7 3.5 3.2" strokeLinecap="round" /></g>),
  "photo.stack": (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinejoin="round"><rect x="6" y="6.5" width="14" height="11" rx="2.2" /><circle cx="10" cy="11" r="1.3" /><path d="M8 15l3-3 2.5 2.3 2-1.8 3 2.7" strokeLinecap="round" /><path d="M16 20H6a2 2 0 0 1-2-2v-8" strokeLinecap="round" /></g>),
  "square.and.arrow.up": (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M12 3.5v11" /><path d="M8 7l4-4 4 4" /><path d="M6 11.5H5a1.5 1.5 0 0 0-1.5 1.5v6A1.5 1.5 0 0 0 5 20.5h14a1.5 1.5 0 0 0 1.5-1.5v-6A1.5 1.5 0 0 0 19 11.5h-1" /></g>),
  // --- misc ---
  sparkles: (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinejoin="round" strokeLinecap="round"><path d="M12 3.5l1.6 4.3 4.4 1.7-4.4 1.7L12 15.5l-1.6-4.3L6 9.5l4.4-1.7L12 3.5Z" /><path d="M18.5 14.5l.7 1.9 1.8.7-1.8.7-.7 1.9-.7-1.9-1.8-.7 1.8-.7.7-1.9Z" /></g>),
  gearshape: (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinejoin="round"><circle cx="12" cy="12" r="3" /><path d="M12 2.6v2.2M12 19.2v2.2M21.4 12h-2.2M4.8 12H2.6M18.6 5.4l-1.6 1.6M7 17l-1.6 1.6M18.6 18.6 17 17M7 7 5.4 5.4" strokeLinecap="round" /></g>),
  globe: (w) => (<g fill="none" stroke="currentColor" strokeWidth={w}><circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3c2.6 2.4 4 5.6 4 9s-1.4 6.6-4 9c-2.6-2.4-4-5.6-4-9s1.4-6.6 4-9Z" /></g>),
  info: (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round"><circle cx="12" cy="12" r="9" /><path d="M12 11v5" /><circle cx="12" cy="8" r="0.6" fill="currentColor" stroke="none" /></g>),
  "hand.raised": (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M8 11V5.5a1.6 1.6 0 0 1 3.2 0V10M11.2 10V4.4a1.6 1.6 0 0 1 3.2 0V10M14.4 10.4V6.2a1.5 1.5 0 0 1 3 0V14a6 6 0 0 1-6 6h-.5a5 5 0 0 1-3.8-1.8L5 15.4c-.8-1-.6-1.9.2-2.5.7-.5 1.6-.4 2.3.3L8 13.6V5.8a1.6 1.6 0 0 1 3.2 0" /></g>),
  pencil: (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinejoin="round"><path d="M14.5 5.5l4 4M4 20l1-4L16 5a1.4 1.4 0 0 1 2 0l1 1a1.4 1.4 0 0 1 0 2L8 19l-4 1Z" /></g>),
  "line.3.horizontal": (w) => (<path d="M4 7h16M4 12h16M4 17h16" fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" />),
  "speaker.minimal": (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M4 9v6h3l4 3.5V5.5L7 9H4Z" fill="currentColor" stroke="none" /><path d="M14.5 9.5a4 4 0 0 1 0 5" /></g>),
  "text.bubble": (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinejoin="round"><path d="M4 6.5A2.5 2.5 0 0 1 6.5 4h11A2.5 2.5 0 0 1 20 6.5v7A2.5 2.5 0 0 1 17.5 16H9l-4 4v-4H6.5A2.5 2.5 0 0 1 4 13.5Z" /></g>),
  flag: (w) => (<g fill="none" stroke="currentColor" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round"><path d="M6 21V4" /><path d="M6 5h11l-2 3.5L17 12H6" /></g>),
};

function Icon({ name, size = 24, weight = 1.7, color, style, className }) {
  const draw = EH_ICON_PATHS[name];
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className}
      style={{ display: 'block', color: color || 'inherit', flex: '0 0 auto', ...style }}
      aria-hidden="true">
      {draw ? draw(weight) : <rect x="4" y="4" width="16" height="16" rx="3" fill="none" stroke="currentColor" strokeWidth={weight} />}
    </svg>
  );
}

Object.assign(window, { Icon, EH_ICON_PATHS });
