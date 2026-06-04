// comments.jsx — community comments bottom sheet
// Pops up over a feed item or report. Shows confirms / disputes / context / questions
// as a threaded list. Anonymous token IDs. Up/down votes, reply, sort.

const { useState: useStateCm, useMemo: useMemoCm } = React;

function CommentsSheet({ open, onClose, threadId, reportTitle, reportSource }) {
  const { COMMENTS } = window.GT_DATA;
  const [sort, setSort] = useStateCm('top');     // 'top' | 'new' | 'confirm' | 'dispute'
  const [draft, setDraft] = useStateCm('');
  const [voted, setVoted] = useStateCm({});      // { commentId: 1 | -1 }
  const [showReply, setShowReply] = useStateCm(null);

  const all = COMMENTS[threadId] || [];
  const sorted = useMemoCm(() => {
    let list = [...all];
    if (sort === 'top') list.sort((a, b) => (b.votes + (voted[b.id]||0)) - (a.votes + (voted[a.id]||0)));
    if (sort === 'confirm') list = list.filter(c => c.type === 'confirm');
    if (sort === 'dispute') list = list.filter(c => c.type === 'dispute');
    return list;
  }, [sort, threadId, voted]);

  const confirms = all.filter(c => c.type === 'confirm').length;
  const disputes = all.filter(c => c.type === 'dispute').length;
  const contexts = all.filter(c => c.type === 'context' || c.type === 'question').length;

  const totalReplies = all.reduce((n, c) => n + (c.replies?.length || 0), 0);
  const totalCount = all.length + totalReplies;

  const voteOn = (id, dir) => {
    setVoted(v => {
      const cur = v[id] || 0;
      return { ...v, [id]: cur === dir ? 0 : dir };
    });
  };

  return (
    <>
      {/* dimming backdrop */}
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0,
        background: 'rgba(8,11,20,0.55)',
        opacity: open ? 1 : 0,
        pointerEvents: open ? 'auto' : 'none',
        transition: 'opacity 250ms ease',
        zIndex: 50,
      }}></div>

      {/* sheet */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        background: 'var(--surface)',
        borderTopLeftRadius: 20, borderTopRightRadius: 20,
        boxShadow: '0 -12px 40px rgba(0,0,0,0.25)',
        transform: open ? 'translateY(0)' : 'translateY(100%)',
        transition: 'transform 320ms cubic-bezier(0.16, 1, 0.3, 1)',
        zIndex: 51,
        maxHeight: 'calc(100% - 50px)',
        display: 'flex', flexDirection: 'column',
      }}>
        {/* handle */}
        <div style={{ padding: '10px 0 4px', display: 'flex', justifyContent: 'center', flexShrink: 0 }}>
          <div style={{ width: 36, height: 4, borderRadius: 999, background: 'var(--hairline-strong)' }}></div>
        </div>

        {/* header */}
        <div style={{ padding: '6px 16px 12px', flexShrink: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 10.5, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase', color: 'var(--ink-tertiary)' }}>
                Community discussion
              </div>
              <div style={{
                fontSize: 14, fontWeight: 600, color: 'var(--ink)',
                marginTop: 2, lineHeight: 1.35,
                display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
              }}>{reportTitle}</div>
            </div>
            <button onClick={onClose} style={{
              width: 32, height: 32, borderRadius: '50%',
              background: 'var(--surface-raised)', border: 'none',
              color: 'var(--ink-secondary)', cursor: 'pointer', flexShrink: 0,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <i className="ph-bold ph-x" style={{ fontSize: 15 }}></i>
            </button>
          </div>

          {/* Summary bar */}
          <div style={{
            marginTop: 12, display: 'flex', alignItems: 'center', gap: 12,
            padding: '10px 12px', borderRadius: 10,
            background: 'var(--surface-card)', border: '1px solid var(--hairline-soft)',
          }}>
            <SummaryStat icon="ph-fill ph-check-circle" color="var(--gt-verified)" value={confirms} label="confirms" />
            <span style={{ width: 1, height: 18, background: 'var(--hairline)' }}></span>
            <SummaryStat icon="ph-fill ph-warning-octagon" color="var(--gt-disputed)" value={disputes} label="disputes" />
            <span style={{ width: 1, height: 18, background: 'var(--hairline)' }}></span>
            <SummaryStat icon="ph-fill ph-info" color="var(--ink-secondary)" value={contexts} label="context" />
            <div style={{ marginLeft: 'auto', fontSize: 11, color: 'var(--ink-tertiary)', fontWeight: 600 }}>{totalCount} total</div>
          </div>
        </div>

        {/* sort tabs */}
        <div style={{
          display: 'flex', gap: 6, padding: '0 16px 10px',
          flexShrink: 0,
        }}>
          {[
            { id: 'top',     label: 'Top' },
            { id: 'new',     label: 'New' },
            { id: 'confirm', label: 'Confirms' },
            { id: 'dispute', label: 'Disputes' },
          ].map(s => (
            <button
              key={s.id}
              onClick={() => setSort(s.id)}
              style={{
                padding: '6px 12px', borderRadius: 999,
                fontSize: 12, fontWeight: 600,
                background: sort === s.id ? 'var(--ink)' : 'transparent',
                color: sort === s.id ? 'var(--canvas)' : 'var(--ink-secondary)',
                border: sort === s.id ? '1px solid var(--ink)' : '1px solid var(--hairline)',
                cursor: 'pointer',
              }}
            >{s.label}</button>
          ))}
        </div>

        {/* comments list (scrollable) */}
        <div style={{
          flex: 1, overflowY: 'auto', padding: '0 16px 12px',
        }}>
          {sorted.length === 0 ? (
            <div style={{
              padding: '40px 20px', textAlign: 'center',
              color: 'var(--ink-tertiary)', fontSize: 13,
            }}>
              No comments in this filter.
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {sorted.map(c => (
                <CommentItem
                  key={c.id}
                  c={c}
                  voted={voted}
                  onVote={voteOn}
                  showReply={showReply === c.id}
                  onToggleReply={() => setShowReply(showReply === c.id ? null : c.id)}
                />
              ))}
            </div>
          )}

          <div style={{
            marginTop: 16, padding: '10px 12px', borderRadius: 8,
            background: 'var(--surface-raised)', fontSize: 11,
            color: 'var(--ink-tertiary)', lineHeight: 1.5,
            display: 'flex', alignItems: 'flex-start', gap: 8,
          }}>
            <i className="ph ph-info" style={{ fontSize: 14, marginTop: 1, flexShrink: 0 }}></i>
            <div>Comments are anonymous — each commenter gets a random token. Replying does not link you to the original commenter.</div>
          </div>
        </div>

        {/* composer */}
        <div style={{
          flexShrink: 0,
          padding: '10px 14px 22px',
          background: 'var(--surface-card)',
          borderTop: '1px solid var(--hairline-soft)',
        }}>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 10 }}>
            <div style={{
              width: 32, height: 32, borderRadius: '50%',
              background: 'var(--surface-raised)', color: 'var(--ink-secondary)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 10, fontWeight: 700, letterSpacing: 0.2,
              flexShrink: 0,
            }}>YOU</div>
            <textarea
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              placeholder="Add context, confirm, or dispute…"
              rows={1}
              style={{
                flex: 1, padding: '8px 12px', borderRadius: 18,
                fontFamily: 'inherit', fontSize: 13.5, lineHeight: 1.4,
                background: 'var(--surface-raised)',
                border: '1px solid transparent', resize: 'none',
                color: 'var(--ink)',
                outline: 'none',
              }}
            />
            <button
              disabled={!draft.trim()}
              onClick={() => setDraft('')}
              style={{
                width: 36, height: 36, borderRadius: '50%',
                background: draft.trim() ? 'var(--gt-navy)' : 'var(--surface-overlay)',
                color: draft.trim() ? 'white' : 'var(--ink-tertiary)',
                border: 'none', cursor: draft.trim() ? 'pointer' : 'not-allowed',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                flexShrink: 0,
              }}
            >
              <i className="ph-fill ph-paper-plane-tilt" style={{ fontSize: 16 }}></i>
            </button>
          </div>
          <div style={{
            display: 'flex', gap: 8, marginTop: 10,
            fontSize: 11, color: 'var(--ink-tertiary)',
          }}>
            <button style={pillBtnStyle()}><i className="ph-fill ph-check" style={{ fontSize: 11, color: 'var(--gt-verified)' }}></i> Mark as confirm</button>
            <button style={pillBtnStyle()}><i className="ph-fill ph-warning" style={{ fontSize: 11, color: 'var(--gt-disputed)' }}></i> Mark as dispute</button>
          </div>
        </div>
      </div>
    </>
  );
}

function pillBtnStyle() {
  return {
    display: 'inline-flex', alignItems: 'center', gap: 4,
    padding: '4px 9px', borderRadius: 999,
    background: 'var(--surface-raised)',
    border: '1px solid var(--hairline-soft)',
    color: 'var(--ink-secondary)', cursor: 'pointer',
    fontSize: 11, fontWeight: 500,
  };
}

function SummaryStat({ icon, color, value, label }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
      <i className={icon} style={{ fontSize: 14, color }}></i>
      <div style={{ display: 'flex', flexDirection: 'column', lineHeight: 1 }}>
        <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink)', fontVariantNumeric: 'tabular-nums' }}>{value}</span>
        <span style={{ fontSize: 10, color: 'var(--ink-tertiary)', marginTop: 2 }}>{label}</span>
      </div>
    </div>
  );
}

function CommentItem({ c, voted, onVote, showReply, onToggleReply, isReply = false }) {
  const myVote = voted[c.id] || 0;
  const score = c.votes + myVote;

  const typeStyle = {
    confirm:  { color: 'var(--gt-verified)', label: 'Confirms',   icon: 'ph-fill ph-check-circle',     bg: '#ecfdf5' },
    dispute:  { color: 'var(--gt-disputed)', label: 'Disputes',   icon: 'ph-fill ph-warning-octagon',  bg: '#fef2f2' },
    context:  { color: 'var(--ink-secondary)', label: 'Context',  icon: 'ph-fill ph-info',             bg: 'var(--surface-raised)' },
    question: { color: 'var(--gt-flag)',     label: 'Asks',       icon: 'ph-fill ph-question',         bg: '#fff7ed' },
  };
  const ts = typeStyle[c.type] || typeStyle.context;

  return (
    <div style={{
      background: 'var(--surface-card)', borderRadius: 12,
      border: '1px solid var(--hairline-soft)',
      borderLeft: `3px solid ${ts.color}`,
      padding: '10px 12px 10px 11px',
      marginLeft: isReply ? 28 : 0,
    }}>
      {/* author + tag */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
        <div style={{
          width: 22, height: 22, borderRadius: '50%',
          background: 'var(--surface-raised)',
          color: 'var(--ink-secondary)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 9, fontWeight: 700, letterSpacing: 0.2,
          fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
        }}>
          {(c.author.match(/#([a-z0-9]+)/i)?.[1] || 'XX').slice(0, 2).toUpperCase()}
        </div>
        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
          <div style={{ fontSize: 11.5, color: 'var(--ink-secondary)', fontWeight: 600, fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace' }}>
            {c.author}
          </div>
          <div style={{ fontSize: 10, color: 'var(--ink-tertiary)', marginTop: 1 }}>{c.time}</div>
        </div>
        {!isReply && (
          <span style={{
            display: 'inline-flex', alignItems: 'center', gap: 3,
            padding: '2px 7px', borderRadius: 999,
            background: ts.bg, color: ts.color,
            fontSize: 10, fontWeight: 700, letterSpacing: 0.4, textTransform: 'uppercase',
          }}>
            <i className={ts.icon} style={{ fontSize: 10 }}></i>
            {ts.label}
          </span>
        )}
      </div>

      {/* body */}
      <div style={{ fontSize: 13.5, color: 'var(--ink)', lineHeight: 1.55, textWrap: 'pretty' }}>
        {c.body}
      </div>

      {/* footer: vote + reply */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 10 }}>
        <div style={{
          display: 'inline-flex', alignItems: 'center',
          background: 'var(--surface-raised)', borderRadius: 999,
          border: '1px solid var(--hairline-soft)',
        }}>
          <button onClick={() => onVote(c.id, 1)} style={voteBtn(myVote === 1, 'up')}>
            <i className={myVote === 1 ? 'ph-fill ph-arrow-fat-up' : 'ph ph-arrow-fat-up'} style={{ fontSize: 13 }}></i>
          </button>
          <span style={{
            fontSize: 11.5, fontWeight: 700, padding: '0 4px',
            color: score > 0 ? 'var(--gt-verified)' : score < 0 ? 'var(--gt-disputed)' : 'var(--ink-secondary)',
            fontVariantNumeric: 'tabular-nums', minWidth: 16, textAlign: 'center',
          }}>{score}</span>
          <button onClick={() => onVote(c.id, -1)} style={voteBtn(myVote === -1, 'down')}>
            <i className={myVote === -1 ? 'ph-fill ph-arrow-fat-down' : 'ph ph-arrow-fat-down'} style={{ fontSize: 13 }}></i>
          </button>
        </div>
        {!isReply && (
          <>
            <button onClick={onToggleReply} style={ghostMicroBtn()}>
              <i className="ph ph-arrow-bend-up-left" style={{ fontSize: 13 }}></i>
              Reply
            </button>
            {c.replies?.length > 0 && (
              <button onClick={onToggleReply} style={{ ...ghostMicroBtn(), color: 'var(--gt-navy)' }}>
                {c.replies.length} {c.replies.length === 1 ? 'reply' : 'replies'}
              </button>
            )}
          </>
        )}
        <button style={{ ...ghostMicroBtn(), marginLeft: 'auto' }}>
          <i className="ph ph-flag" style={{ fontSize: 13 }}></i>
        </button>
      </div>

      {/* replies */}
      {!isReply && showReply && c.replies?.length > 0 && (
        <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
          {c.replies.map(r => (
            <CommentItem
              key={r.id}
              c={{ ...r, type: r.type || 'context' }}
              voted={voted}
              onVote={onVote}
              isReply
            />
          ))}
          <button style={{
            alignSelf: 'flex-start', marginLeft: 28,
            padding: '6px 10px', fontSize: 11.5, fontWeight: 500,
            background: 'transparent', border: '1px dashed var(--hairline)',
            borderRadius: 8, color: 'var(--ink-secondary)', cursor: 'pointer',
          }}>+ add reply</button>
        </div>
      )}
    </div>
  );
}

function voteBtn(active, dir) {
  return {
    width: 26, height: 26, borderRadius: '50%',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    background: 'transparent', border: 'none', cursor: 'pointer',
    color: active
      ? (dir === 'up' ? 'var(--gt-verified)' : 'var(--gt-disputed)')
      : 'var(--ink-secondary)',
  };
}

function ghostMicroBtn() {
  return {
    display: 'inline-flex', alignItems: 'center', gap: 4,
    padding: '4px 8px', borderRadius: 6,
    background: 'transparent', border: 'none', cursor: 'pointer',
    color: 'var(--ink-secondary)', fontSize: 11.5, fontWeight: 500,
  };
}

Object.assign(window, { CommentsSheet });
