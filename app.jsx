// app.jsx — main app shell, tab routing, iOS frame, tweaks
const { useState: useStateA, useEffect: useEffectA } = React;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "feedLayout": "photo-first",
  "mapStyle": "light",
  "dark": false,
  "showVerification": true
}/*EDITMODE-END*/;

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const [tab, setTab] = useStateA('feed');
  const [compareEvent, setCompareEvent] = useStateA(null);
  const [commentsOpen, setCommentsOpen] = useStateA(false);
  const [commentsThread, setCommentsThread] = useStateA(null); // { id, title, source }

  const tweaks = {
    feedLayout: t.feedLayout,
    mapStyle: t.mapStyle,
    showVerification: t.showVerification,
  };

  const handleOpenCompare = (item) => {
    if (item.id === 'f5' || item.location?.includes('Zaporizhzhia')) {
      setCompareEvent('zaporizhzhia-depot');
    } else {
      setCompareEvent('kharkiv-substation');
    }
    setTab('compare');
  };

  const handleSubmitted = () => {
    setTab('feed');
  };

  const handleOpenComments = (item) => {
    setCommentsThread({
      id: item.id,
      title: item.title,
      source: item.source,
    });
    setCommentsOpen(true);
  };

  return (
    <IOSDevice width={402} height={874} dark={t.dark}>
      <div className="gt-app" data-theme={t.dark ? 'dark' : 'light'} data-lang="en"
           style={{ height: '100%', position: 'relative', overflow: 'hidden' }}>
        <div className="gt-screen" data-screen-label={
          tab === 'feed' ? '01 Feed' :
          tab === 'map' ? '02 Map' :
          tab === 'report' ? '03 Submit' :
          tab === 'compare' ? '04 Compare' :
          '05 My reports'
        }>
          {tab === 'feed'    && <FeedScreen tweaks={tweaks} onOpenCompare={handleOpenCompare} onOpenComments={handleOpenComments} />}
          {tab === 'map'     && <MapScreen tweaks={tweaks} />}
          {tab === 'report'  && <ReportScreen onSubmitted={handleSubmitted} />}
          {tab === 'compare' && <CompareScreen initialEvent={compareEvent} />}
          {tab === 'mine'    && <MyReportsScreen onOpenComments={handleOpenComments} />}
        </div>

        <TabBar tab={tab} setTab={(t) => { setTab(t); setCompareEvent(null); }} />

        {/* Comments overlay — global, can open on any tab */}
        <CommentsSheet
          open={commentsOpen}
          onClose={() => setCommentsOpen(false)}
          threadId={commentsThread?.id}
          reportTitle={commentsThread?.title}
          reportSource={commentsThread?.source}
        />
      </div>

      <TweaksPanel>
        <TweakSection label="Layout" />
        <TweakRadio
          label="Feed cards"
          value={t.feedLayout}
          options={['photo-first', 'compact']}
          onChange={(v) => setTweak('feedLayout', v)}
        />
        <TweakRadio
          label="Map style"
          value={t.mapStyle}
          options={['light', 'dark']}
          onChange={(v) => setTweak('mapStyle', v)}
        />
        <TweakSection label="Appearance" />
        <TweakToggle
          label="Dark mode"
          value={t.dark}
          onChange={(v) => setTweak('dark', v)}
        />
        <TweakSection label="Jump to screen" />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6 }}>
          {[
            { id: 'feed',    label: 'Feed' },
            { id: 'map',     label: 'Map' },
            { id: 'report',  label: 'Submit' },
            { id: 'compare', label: 'Compare' },
            { id: 'mine',    label: 'My reports' },
          ].map(s => (
            <button key={s.id} onClick={() => setTab(s.id)} style={{
              padding: '7px 8px', borderRadius: 6, cursor: 'pointer',
              background: tab === s.id ? '#29261b' : 'rgba(0,0,0,0.06)',
              color: tab === s.id ? 'white' : 'rgba(41,38,27,.78)',
              border: 'none', fontSize: 11, fontWeight: 500,
            }}>{s.label}</button>
          ))}
        </div>
        <TweakSection label="Comments preview" />
        <button onClick={() => {
          setCommentsThread({ id: 'f1', title: 'Strike on substation, Saltivka district — power out across 4 blocks', source: 'citizen' });
          setCommentsOpen(true);
        }} style={{
          padding: '8px 10px', borderRadius: 6, cursor: 'pointer',
          background: '#3B5BDB', color: 'white', border: 'none',
          fontSize: 11.5, fontWeight: 600,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
        }}>
          Open comments demo
        </button>
      </TweaksPanel>
    </IOSDevice>
  );
}

function TabBar({ tab, setTab }) {
  const items = [
    { id: 'feed',    label: 'Feed',     icon: 'ph ph-stack',           iconActive: 'ph-fill ph-stack' },
    { id: 'map',     label: 'Map',      icon: 'ph ph-map-trifold',     iconActive: 'ph-fill ph-map-trifold' },
    { id: 'report',  label: 'Report',   icon: 'ph-fill ph-shield-check', iconActive: 'ph-fill ph-shield-check', center: true },
    { id: 'compare', label: 'Compare',  icon: 'ph ph-shuffle',         iconActive: 'ph-fill ph-shuffle' },
    { id: 'mine',    label: 'My posts', icon: 'ph ph-folder-user',     iconActive: 'ph-fill ph-folder-user' },
  ];
  return (
    <div className="gt-tabbar">
      {items.map(it => {
        const active = it.id === tab;
        if (it.center) {
          return (
            <button
              key={it.id}
              className="gt-tab gt-tab--center"
              data-active={active ? 'true' : 'false'}
              onClick={() => setTab(it.id)}
              aria-label={it.label}
            >
              <div className="gt-tab-cap">
                <i className={it.iconActive}></i>
              </div>
              <span className="gt-tab-label" style={{ marginTop: 2 }}>{it.label}</span>
            </button>
          );
        }
        return (
          <button
            key={it.id}
            className="gt-tab"
            data-active={active ? 'true' : 'false'}
            onClick={() => setTab(it.id)}
            aria-label={it.label}
          >
            <i className={active ? it.iconActive : it.icon}></i>
            <span className="gt-tab-label">{it.label}</span>
          </button>
        );
      })}
    </div>
  );
}

// ───── mount
ReactDOM.createRoot(document.getElementById('app')).render(<App />);
