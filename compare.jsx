// compare.jsx — Side-by-side: same event reported by many sources
//   Timeline view = chronological flow of how the story broke
//   Columns view  = direct side-by-side comparison of each source's coverage

const { useState: useStateC, useMemo: useMemoC } = React;

function CompareScreen({ initialEvent }) {
  const { COMPARE_EVENTS, SOURCES } = window.GT_DATA;
  const eventIds = Object.keys(COMPARE_EVENTS);
  const [eventId, setEventId] = useStateC(initialEvent || eventIds[0]);
  const [mode, setMode] = useStateC('timeline'); // 'timeline' | 'columns'
  const event = COMPARE_EVENTS[eventId];

  const sourcesInEvent = [...new Set(event.timeline.map(t => t.source))];
  const hasDispute = event.timeline.some(t => t.match === 'disputed');
  const citizenItems = event.timeline.filter(t => t.source === 'citizen');
  const citizenFirst = event.timeline[0]?.source === 'citizen';

  return (
    <>
      <div className="gt-top" style={{ paddingBottom: 10 }}>
        <div className="gt-top-row" style={{ justifyContent: 'space-between' }}>
          <div className="gt-brand">
            <i className="ph-fill ph-shuffle" style={{ color: 'var(--gt-navy)', fontSize: 18 }}></i>
            Side by side
          </div>
          <IconBtn icon="ph ph-question" ariaLabel="What is this?" />
        </div>
        <div style={{
          marginTop: 8,
          fontSize: 12.5, color: 'var(--ink-secondary)', lineHeight: 1.5,
          textWrap: 'pretty',
        }}>
          One event. Multiple sources. See how a citizen report lines up with — or contradicts — major outlets.
        </div>
      </div>

      {/* Event picker — horizontal chips */}
      <div className="gt-chip-row" style={{ paddingTop: 12, paddingBottom: 0 }}>
        {eventIds.map(id => {
          const ev = COMPARE_EVENTS[id];
          const disputed = ev.timeline.some(t => t.match === 'disputed');
          return (
            <button
              key={id}
              className="gt-chip"
              data-active={id === eventId ? 'true' : 'false'}
              onClick={() => setEventId(id)}
              style={{ paddingLeft: 10 }}
            >
              <span style={{
                width: 6, height: 6, borderRadius: '50%',
                background: disputed ? 'var(--gt-disputed)' : 'var(--gt-verified)',
              }}></span>
              {ev.title}
            </button>
          );
        })}
      </div>

      {/* Event hero card */}
      <div style={{ padding: '14px 16px 0' }}>
        <div style={{
          borderRadius: 14, overflow: 'hidden',
          background: 'var(--surface-card)',
          border: '1px solid var(--hairline)',
        }}>
          {/* Hero band — gradient + title (no photo to avoid implying our own POV) */}
          <div style={{
            padding: 16,
            background: hasDispute
              ? 'linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%)'
              : 'linear-gradient(135deg, var(--gt-navy-soft) 0%, #c7d2fe 100%)',
            borderBottom: '1px solid var(--hairline-soft)',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
              <i className={hasDispute ? "ph-fill ph-warning-octagon" : "ph-fill ph-check-circle"}
                 style={{ fontSize: 14, color: hasDispute ? 'var(--gt-disputed)' : 'var(--gt-verified)' }}></i>
              <span style={{
                fontSize: 10.5, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase',
                color: hasDispute ? 'var(--gt-disputed)' : 'var(--gt-verified)',
              }}>
                {hasDispute ? 'Sources disagree' : 'Sources align'}
              </span>
            </div>
            <div style={{
              fontFamily: 'var(--font-en-heading)', fontSize: 18, fontWeight: 700,
              letterSpacing: '-0.4px', lineHeight: 1.25, color: 'var(--ink)',
              textWrap: 'pretty',
            }}>{event.title}</div>
            <div style={{
              fontSize: 12, color: 'var(--ink-secondary)', marginTop: 6,
              display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap',
            }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                <i className="ph-fill ph-map-pin" style={{ fontSize: 12 }}></i>
                {event.location}
              </span>
              <span style={{ opacity: 0.5 }}>·</span>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                <i className="ph ph-clock" style={{ fontSize: 12 }}></i>
                {event.subtitle.split('·')[1]?.trim() || ''}
              </span>
            </div>
          </div>

          {/* Source row */}
          <div style={{ padding: '12px 14px' }}>
            <div style={{ fontSize: 10.5, fontWeight: 700, color: 'var(--ink-tertiary)', letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: 8 }}>
              Reported by
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
              {sourcesInEvent.map(srcId => {
                const src = SOURCES[srcId];
                const isCitizen = srcId === 'citizen';
                const count = event.timeline.filter(t => t.source === srcId).length;
                return (
                  <div key={srcId} style={{
                    display: 'inline-flex', alignItems: 'center', gap: 5,
                    padding: '5px 10px', borderRadius: 999,
                    background: isCitizen ? '#fef3c7' : 'var(--surface-raised)',
                    border: '1px solid ' + (isCitizen ? 'rgba(181,71,8,0.2)' : 'var(--hairline-soft)'),
                    fontSize: 11.5, fontWeight: 600,
                    color: isCitizen ? 'var(--gt-citizen)' : 'var(--ink-secondary)',
                  }}>
                    <span style={{ width: 7, height: 7, borderRadius: '50%', background: src.color }}></span>
                    {src.name}
                    {count > 1 && (
                      <span style={{ fontSize: 10, opacity: 0.7, marginLeft: 2 }}>×{count}</span>
                    )}
                  </div>
                );
              })}
            </div>
          </div>

          {/* TL;DR row */}
          <div style={{
            padding: '10px 14px 14px',
            borderTop: '1px solid var(--hairline-soft)',
            background: 'var(--surface-raised)',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 12.5 }}>
              <div style={{
                width: 32, height: 32, borderRadius: 8,
                background: 'var(--surface-card)', color: 'var(--gt-navy)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                flexShrink: 0, border: '1px solid var(--hairline-soft)',
              }}>
                <i className="ph-bold ph-lightbulb" style={{ fontSize: 16 }}></i>
              </div>
              <div style={{ color: 'var(--ink-secondary)', lineHeight: 1.5, textWrap: 'pretty' }}>
                {citizenFirst ? (
                  <>A citizen reported this <strong style={{ color: 'var(--ink)' }}>{event.timeline[2]?.delta || 'first'}</strong> before major outlets confirmed.</>
                ) : (
                  <>Citizens added <strong style={{ color: 'var(--ink)' }}>{citizenItems.length} on-the-ground reports</strong> after the initial wire story.</>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* View mode toggle */}
      <div style={{
        padding: '16px 16px 0',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12,
      }}>
        <div className="gt-section-h" style={{ margin: 0 }}>
          {mode === 'timeline' ? 'Report timeline · chronological' : 'Each source · side by side'}
        </div>
        <div style={{
          display: 'inline-flex', padding: 2, borderRadius: 999,
          background: 'var(--surface-raised)', border: '1px solid var(--hairline-soft)',
        }}>
          {[
            { id: 'timeline', label: 'Timeline', icon: 'ph ph-list' },
            { id: 'columns',  label: 'Side',     icon: 'ph ph-columns' },
          ].map(m => (
            <button
              key={m.id}
              onClick={() => setMode(m.id)}
              style={{
                padding: '5px 10px', borderRadius: 999,
                fontSize: 11.5, fontWeight: 600,
                background: mode === m.id ? 'var(--surface-card)' : 'transparent',
                color: mode === m.id ? 'var(--ink)' : 'var(--ink-tertiary)',
                border: 'none', cursor: 'pointer',
                boxShadow: mode === m.id ? '0 1px 3px rgba(0,0,0,0.08)' : 'none',
                display: 'inline-flex', alignItems: 'center', gap: 4,
              }}
            >
              <i className={m.icon} style={{ fontSize: 12 }}></i>
              {m.label}
            </button>
          ))}
        </div>
      </div>

      <div style={{ padding: '12px 16px 24px' }}>
        {mode === 'timeline'
          ? <TimelineView event={event} />
          : <ColumnsView event={event} />}

        <div style={{
          marginTop: 18, padding: 14,
          background: 'var(--surface-raised)', borderRadius: 12,
          border: '1px solid var(--hairline-soft)',
          display: 'flex', alignItems: 'flex-start', gap: 10,
        }}>
          <i className="ph-duotone ph-info" style={{ fontSize: 22, color: 'var(--ink-secondary)', flexShrink: 0 }}></i>
          <div style={{ fontSize: 12, color: 'var(--ink-secondary)', lineHeight: 1.5 }}>
            Frontline pairs citizen reports with major outlets using topic + entity + location clustering. We never edit or rewrite source text — only place them next to each other so you can decide.
          </div>
        </div>
      </div>
    </>
  );
}

// ─────────────────────────────────────
// Timeline view (chronological)
// ─────────────────────────────────────
function TimelineView({ event }) {
  return (
    <div className="gt-tl">
      {event.timeline.map((item, i) => (
        <CompareItem key={i} item={item} />
      ))}
    </div>
  );
}

function CompareItem({ item }) {
  const { SOURCES } = window.GT_DATA;
  const src = SOURCES[item.source];
  const isCitizen = item.source === 'citizen';

  return (
    <div className="gt-tl-item" data-src={item.source}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 6 }}>
        <span style={{
          fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
          fontSize: 12, fontWeight: 700, color: 'var(--ink)',
          fontVariantNumeric: 'tabular-nums',
        }}>{item.time}</span>
        <span style={{ fontSize: 10.5, color: 'var(--ink-tertiary)', fontWeight: 600 }}>
          {item.delta}
        </span>
        {item.match === 'aligned' && (
          <span style={{ marginLeft: 'auto' }}>
            <GTBadge kind="verified" icon="ph-fill ph-check">ALIGNED</GTBadge>
          </span>
        )}
        {item.match === 'disputed' && (
          <span style={{ marginLeft: 'auto' }}>
            <GTBadge kind="disputed" icon="ph-fill ph-warning">DISPUTED</GTBadge>
          </span>
        )}
        {item.match === 'partial' && (
          <span style={{ marginLeft: 'auto' }}>
            <GTBadge kind="pending">PARTIAL</GTBadge>
          </span>
        )}
      </div>

      <div style={{
        background: 'var(--surface-card)', borderRadius: 12,
        border: `1px solid ${isCitizen ? 'rgba(181,71,8,0.18)' : 'var(--hairline)'}`,
        padding: 12,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
          <span className="gt-source-dot" style={{ background: src.color, width: 7, height: 7 }}></span>
          <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: 0.5, textTransform: 'uppercase', color: 'var(--ink-secondary)' }}>
            {src.name}
          </span>
          {item.author && (
            <span style={{ fontSize: 11, color: 'var(--ink-tertiary)', fontWeight: 500 }}>
              · {item.author}
            </span>
          )}
          {item.photo && (
            <span style={{ marginLeft: 'auto', fontSize: 10, color: 'var(--ink-tertiary)', display: 'flex', alignItems: 'center', gap: 3 }}>
              <i className="ph ph-image" style={{ fontSize: 12 }}></i>
              photo
            </span>
          )}
        </div>
        <div style={{
          fontFamily: 'var(--font-en-heading)', fontSize: 14.5, fontWeight: 600,
          color: 'var(--ink)', lineHeight: 1.35, letterSpacing: '-0.2px', textWrap: 'pretty',
        }}>
          {item.title}
        </div>
        <div style={{ fontSize: 13, color: 'var(--ink-secondary)', marginTop: 6, lineHeight: 1.55, textWrap: 'pretty' }}>
          {item.body}
        </div>

        {!isCitizen && (
          <button style={{
            marginTop: 10, padding: '6px 10px',
            background: 'transparent', border: '1px solid var(--hairline)',
            borderRadius: 6, fontSize: 11.5, fontWeight: 500,
            color: 'var(--ink-secondary)', cursor: 'pointer',
            display: 'inline-flex', alignItems: 'center', gap: 5,
          }}>
            <i className="ph ph-arrow-square-out" style={{ fontSize: 12 }}></i>
            Open original on {src.name}
          </button>
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────
// Columns view (side-by-side: one column per source)
// Groups reports by source, then shows them as parallel columns.
// On mobile, this is a horizontally-scrolling row of source columns.
// ─────────────────────────────────────
function ColumnsView({ event }) {
  const { SOURCES } = window.GT_DATA;
  const sourcesInEvent = [...new Set(event.timeline.map(t => t.source))];

  // Order: citizen first, then others
  const ordered = sourcesInEvent.sort((a, b) => {
    if (a === 'citizen') return -1;
    if (b === 'citizen') return 1;
    return 0;
  });

  return (
    <>
      <div style={{
        fontSize: 11.5, color: 'var(--ink-tertiary)',
        marginBottom: 10, lineHeight: 1.5,
        display: 'flex', alignItems: 'center', gap: 6,
      }}>
        <i className="ph ph-arrows-horizontal" style={{ fontSize: 13 }}></i>
        Scroll horizontally to compare how each source covered this event
      </div>
      <div style={{
        display: 'flex', gap: 12,
        overflowX: 'auto',
        scrollSnapType: 'x mandatory',
        margin: '0 -16px', padding: '0 16px 8px',
        scrollbarWidth: 'none',
      }}>
        {ordered.map(srcId => (
          <SourceColumn
            key={srcId}
            src={SOURCES[srcId]}
            items={event.timeline.filter(t => t.source === srcId)}
          />
        ))}
      </div>
    </>
  );
}

function SourceColumn({ src, items }) {
  const isCitizen = src.id === 'citizen';
  return (
    <div style={{
      flex: '0 0 280px',
      scrollSnapAlign: 'start',
      background: 'var(--surface-card)',
      borderRadius: 14,
      border: `1px solid ${isCitizen ? 'rgba(181,71,8,0.2)' : 'var(--hairline)'}`,
      overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Column header */}
      <div style={{
        padding: '12px 14px',
        background: isCitizen ? '#fef3c7' : 'var(--surface-raised)',
        borderBottom: '1px solid var(--hairline-soft)',
        display: 'flex', alignItems: 'center', gap: 8,
      }}>
        <span style={{
          width: 26, height: 26, borderRadius: '50%',
          background: src.color, color: 'white',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 10, fontWeight: 800, letterSpacing: 0.2,
        }}>
          {isCitizen
            ? <i className="ph-fill ph-users-three" style={{ fontSize: 13 }}></i>
            : src.name.split(/[\s.]+/).map(s => s[0]).slice(0,2).join('').toUpperCase()
          }
        </span>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            fontSize: 13, fontWeight: 700,
            color: 'var(--ink)', letterSpacing: -0.1,
          }}>{src.name}</div>
          <div style={{ fontSize: 10.5, color: 'var(--ink-tertiary)', fontWeight: 600 }}>
            {items.length} {items.length === 1 ? 'report' : 'reports'}
          </div>
        </div>
      </div>

      {/* Column body */}
      <div style={{
        padding: 12, display: 'flex', flexDirection: 'column', gap: 12,
        flex: 1, overflowY: 'auto',
        maxHeight: 480,
      }}>
        {items.map((item, i) => (
          <div key={i}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 5 }}>
              <span style={{
                fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
                fontSize: 11, fontWeight: 700, color: 'var(--ink)',
                fontVariantNumeric: 'tabular-nums',
              }}>{item.time}</span>
              <span style={{ fontSize: 10, color: 'var(--ink-tertiary)' }}>{item.delta}</span>
              {item.match === 'disputed' && (
                <span style={{ marginLeft: 'auto', fontSize: 9, fontWeight: 700, color: 'var(--gt-disputed)', textTransform: 'uppercase', letterSpacing: 0.4 }}>DISPUTED</span>
              )}
              {item.match === 'aligned' && (
                <span style={{ marginLeft: 'auto', fontSize: 9, fontWeight: 700, color: 'var(--gt-verified)', textTransform: 'uppercase', letterSpacing: 0.4 }}>ALIGNED</span>
              )}
            </div>
            <div style={{
              fontFamily: 'var(--font-en-heading)', fontSize: 13, fontWeight: 600,
              color: 'var(--ink)', lineHeight: 1.35, letterSpacing: '-0.1px', textWrap: 'pretty',
            }}>{item.title}</div>
            {item.author && (
              <div style={{ fontSize: 10.5, color: 'var(--ink-tertiary)', marginTop: 3, fontFamily: 'ui-monospace' }}>
                {item.author}
              </div>
            )}
            <div style={{ fontSize: 12, color: 'var(--ink-secondary)', marginTop: 6, lineHeight: 1.5, textWrap: 'pretty' }}>
              {item.body}
            </div>
            {i < items.length - 1 && (
              <div style={{ height: 1, background: 'var(--hairline-soft)', marginTop: 10 }}></div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { CompareScreen });
