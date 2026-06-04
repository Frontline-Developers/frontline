// feed.jsx — Feed tab: mixed citizen + source feed with filters
const { useState: useStateF, useMemo: useMemoF } = React;

function FeedScreen({ tweaks, onOpenCompare, onOpenComments }) {
  const { FEED, SOURCES } = window.GT_DATA;
  const [filter, setFilter] = useStateF('all');
  const [upvoted, setUpvoted] = useStateF({});
  const [flagged, setFlagged] = useStateF({});
  const [saved, setSaved] = useStateF({});

  const layout = tweaks.feedLayout || 'photo-first';

  const filters = [
    { id: 'all',     label: 'All',                icon: 'ph ph-stack' },
    { id: 'citizen', label: 'On the ground',      icon: 'ph ph-users-three' },
    { id: 'sources', label: 'Major sources',      icon: 'ph ph-newspaper' },
    { id: 'verified',label: 'Verified',           icon: 'ph ph-check-circle' },
    { id: 'disputed',label: 'Disputed',           icon: 'ph ph-warning-octagon' },
  ];

  const items = useMemoF(() => {
    return FEED.filter(item => {
      if (filter === 'all') return true;
      if (filter === 'citizen') return item.source === 'citizen';
      if (filter === 'sources') return item.source !== 'citizen';
      if (filter === 'verified') return item.status === 'verified';
      if (filter === 'disputed') return item.status === 'disputed';
      return true;
    });
  }, [filter]);

  const handleUpvote = (id) => {
    setUpvoted(u => ({ ...u, [id]: !u[id] }));
  };
  const handleFlag = (id) => {
    setFlagged(f => ({ ...f, [id]: !f[id] }));
  };
  const handleSave = (id) => {
    setSaved(s => ({ ...s, [id]: !s[id] }));
  };

  return (
    <>
      <div className="gt-top">
        <div className="gt-top-row" style={{ justifyContent: 'space-between' }}>
          <div className="gt-brand">
            <span className="gt-brand-dot"></span>
            Frontline
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <IconBtn icon="ph ph-magnifying-glass" ariaLabel="Search" />
            <IconBtn icon="ph-fill ph-bell" ariaLabel="Alerts" badge />
          </div>
        </div>
        <h1 className="gt-h1">Ukraine · live</h1>
        <div className="gt-sub" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span className="gt-live-tag"><span className="gt-live-pulse"></span> LIVE</span>
          <span style={{ color: 'var(--ink-tertiary)' }}>·</span>
          <span>17 citizens reporting · 6 sources active</span>
        </div>
      </div>

      <div className="gt-chip-row" style={{ paddingTop: 10, paddingBottom: 4 }}>
        {filters.map(f => (
          <button
            key={f.id}
            className="gt-chip"
            data-active={filter === f.id ? 'true' : 'false'}
            onClick={() => setFilter(f.id)}
          >
            <i className={f.icon} style={{ fontSize: 14 }}></i>
            {f.label}
          </button>
        ))}
      </div>

      <div className="gt-feed">
        {items.length === 0 && (
          <div style={{
            padding: '60px 20px', textAlign: 'center', color: 'var(--ink-tertiary)',
            background: 'var(--surface-card)', borderRadius: 14,
            border: '1px solid var(--hairline-soft)',
          }}>
            <i className="ph-duotone ph-magnifying-glass" style={{ fontSize: 36, color: 'var(--ink-tertiary)' }}></i>
            <div style={{ fontSize: 15, fontWeight: 600, marginTop: 8 }}>No items match</div>
            <div style={{ fontSize: 13, marginTop: 4 }}>Try a different filter</div>
          </div>
        )}

        {items.map(item => (
          <FeedCard
            key={item.id}
            item={item}
            layout={layout}
            upvoted={!!upvoted[item.id]}
            flagged={!!flagged[item.id]}
            saved={!!saved[item.id]}
            onUpvote={() => handleUpvote(item.id)}
            onFlag={() => handleFlag(item.id)}
            onSave={() => handleSave(item.id)}
            onCompare={() => onOpenCompare(item)}
            onComments={() => onOpenComments(item)}
          />
        ))}

        <div style={{
          textAlign: 'center', padding: '20px 0',
          fontSize: 12, color: 'var(--ink-tertiary)',
        }}>
          End of feed · pull to refresh
        </div>
      </div>
    </>
  );
}

function FeedCard({ item, layout, upvoted, flagged, saved, onUpvote, onFlag, onSave, onCompare, onComments }) {
  const { SOURCES } = window.GT_DATA;
  const isCitizen = item.source === 'citizen';
  const baseUp = item.upvotes;
  const baseFlags = item.flagCount;
  const upCount = baseUp + (upvoted ? 1 : 0);
  const flagCount = baseFlags + (flagged ? 1 : 0);

  if (layout === 'compact') {
    return (
      <div className="gt-card" style={{ display: 'flex', gap: 12, padding: 12 }}>
        <div style={{
          width: 90, height: 90, flexShrink: 0,
          borderRadius: 8, overflow: 'hidden',
          background: 'var(--surface-raised)',
        }}>
          <img src={item.photo} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
        </div>
        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
            <span className="gt-source-dot" style={{ background: SOURCES[item.source].color }}></span>
            <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: 0.5, textTransform: 'uppercase', color: 'var(--ink-secondary)' }}>
              {SOURCES[item.source].name}
            </span>
            {item.status === 'verified' && <GTBadge kind="verified">VERIFIED</GTBadge>}
            {item.status === 'disputed' && <GTBadge kind="disputed">DISPUTED</GTBadge>}
            {item.status === 'pending' && isCitizen && <GTBadge kind="pending">PENDING</GTBadge>}
          </div>
          <div style={{
            fontFamily: 'var(--font-en-heading)', fontWeight: 600, fontSize: 14,
            lineHeight: 1.35, letterSpacing: '-0.1px', color: 'var(--ink)',
            textWrap: 'pretty',
            display: '-webkit-box', WebkitLineClamp: 3, WebkitBoxOrient: 'vertical', overflow: 'hidden',
          }}>
            {item.title}
          </div>
          <div style={{
            marginTop: 'auto', paddingTop: 6,
            display: 'flex', alignItems: 'center', gap: 10,
            fontSize: 11, color: 'var(--ink-tertiary)',
          }}>
            <span>{item.location}</span>
            <span>·</span>
            <span>{item.time}</span>
            {isCitizen && item.sourcesMatched > 0 && (
              <>
                <span>·</span>
                <span style={{ color: 'var(--gt-navy)', fontWeight: 600 }}>
                  <i className="ph ph-shuffle" style={{ fontSize: 11, marginRight: 2 }}></i>
                  {item.sourcesMatched} match
                </span>
              </>
            )}
          </div>
        </div>
      </div>
    );
  }

  // photo-first (default)
  return (
    <div className="gt-card">
      <div className="gt-card-media">
        <img src={item.photo} alt="" className="gt-photo" style={{ display: 'block' }} />
        {isCitizen && (
          <div style={{
            position: 'absolute', top: 10, left: 10,
            display: 'flex', gap: 6,
          }}>
            <GTBadge kind="citizen" icon="ph-fill ph-users-three">ON THE GROUND</GTBadge>
            {item.status === 'verified' && <GTBadge kind="verified" icon="ph-fill ph-check-circle">VERIFIED</GTBadge>}
            {item.status === 'disputed' && <GTBadge kind="disputed" icon="ph-fill ph-warning-octagon">DISPUTED</GTBadge>}
            {item.status === 'pending' && <GTBadge kind="pending">PENDING REVIEW</GTBadge>}
          </div>
        )}
        {!isCitizen && (
          <div style={{
            position: 'absolute', top: 10, left: 10,
          }}>
            <GTBadge kind="source"><span className="gt-source-dot" style={{ background: SOURCES[item.source].color, width: 5, height: 5 }}></span> {SOURCES[item.source].name.toUpperCase()}</GTBadge>
          </div>
        )}
      </div>
      <div className="gt-card-body">
        {isCitizen && (
          <SourceLine sourceId={item.source} location={item.location} time={item.time} />
        )}
        {!isCitizen && (
          <div className="gt-source-line">
            <span>{item.location}</span>
            <span className="dot" style={{ background: 'var(--ink-tertiary)', opacity: 0.6 }}></span>
            <span style={{ fontWeight: 500, textTransform: 'none', letterSpacing: 0.2, color: 'var(--ink-tertiary)' }}>{item.time}</span>
          </div>
        )}
        <h3 className="gt-card-title">{item.title}</h3>
        <p className="gt-card-snip">{item.snippet}</p>

        {isCitizen && (
          <div style={{ marginTop: 12 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <VerifyMeter up={upCount} flags={flagCount} />
            </div>
            {item.sourcesMatched > 0 && (
              <button
                onClick={onCompare}
                style={{
                  display: 'flex', alignItems: 'center', gap: 6,
                  marginTop: 10, padding: '7px 10px',
                  background: 'var(--gt-navy-soft)', color: 'var(--gt-navy)',
                  border: '1px solid rgba(30,58,138,0.15)',
                  borderRadius: 8, cursor: 'pointer', width: '100%',
                  fontSize: 12.5, fontWeight: 600, textAlign: 'left',
                }}
              >
                <i className="ph-fill ph-shuffle" style={{ fontSize: 14 }}></i>
                Compare with {item.sourcesMatched} {item.sourcesMatched === 1 ? 'source' : 'sources'} reporting same event
                <i className="ph ph-arrow-right" style={{ fontSize: 14, marginLeft: 'auto' }}></i>
              </button>
            )}
          </div>
        )}

        <div className="gt-feed-actions">
          {isCitizen ? (
            <>
              <ActionBtn icon="ph ph-check-circle" count={upCount} active={upvoted} onClick={onUpvote} />
              <ActionBtn icon="ph ph-flag" count={flagCount} active={flagged} onClick={onFlag} />
              <ActionBtn icon="ph ph-chat-circle" count={item.comments} onClick={onComments} />
            </>
          ) : (
            <>
              <ActionBtn icon="ph ph-arrow-square-out" label="Open source" />
            </>
          )}
          <div style={{ marginLeft: 'auto', display: 'flex', gap: 4 }}>
            <ActionBtn
              icon={saved ? 'ph-fill ph-bookmark-simple' : 'ph ph-bookmark-simple'}
              active={saved}
              onClick={onSave}
            />
            <ActionBtn icon="ph ph-share-network" />
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { FeedScreen });
