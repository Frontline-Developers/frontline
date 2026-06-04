// ui.jsx — shared GroundTruth primitives

const { useState, useEffect, useRef, useMemo } = React;

const SOURCES = window.GT_DATA.SOURCES;

// ─────────────────────────────────────────
// Small badge: VERIFIED / DISPUTED / CITIZEN / PENDING / SOURCE
// ─────────────────────────────────────────
function GTBadge({ kind, children, icon }) {
  return (
    <span className={`gt-badge gt-badge--${kind}`}>
      {icon && <i className={icon} style={{ fontSize: 11 }}></i>}
      {children}
    </span>
  );
}

// Source label line: small color dot + uppercase name + dot + location + dot + time
function SourceLine({ sourceId, location, time }) {
  const src = SOURCES[sourceId] || SOURCES.citizen;
  return (
    <div className="gt-source-line">
      <span className="gt-source-dot" style={{ background: src.color }}></span>
      <span>{src.name}</span>
      {location && <>
        <span className="dot" style={{ width: 3, height: 3, borderRadius: '50%', background: 'var(--ink-tertiary)', opacity: 0.6 }}></span>
        <span style={{ fontWeight: 500, textTransform: 'none', letterSpacing: 0.2, color: 'var(--ink-tertiary)' }}>{location}</span>
      </>}
      {time && <>
        <span className="dot" style={{ width: 3, height: 3, borderRadius: '50%', background: 'var(--ink-tertiary)', opacity: 0.6 }}></span>
        <span style={{ fontWeight: 500, textTransform: 'none', letterSpacing: 0.2, color: 'var(--ink-tertiary)' }}>{time}</span>
      </>}
    </div>
  );
}

// ─────────────────────────────────────────
// Verification meter — horizontal bar of upvotes vs flags
// ─────────────────────────────────────────
function VerifyMeter({ up, flags, compact = false }) {
  const total = up + flags || 1;
  const pct = (up / total) * 100;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flex: 1, minWidth: 0 }}>
      <div style={{
        height: compact ? 3 : 4, borderRadius: 999,
        background: 'var(--surface-overlay)', overflow: 'hidden',
        display: 'flex',
      }}>
        <div style={{ height: '100%', width: `${pct}%`, background: 'var(--gt-verified)' }}></div>
        <div style={{ height: '100%', width: `${100-pct}%`, background: 'var(--gt-disputed)', opacity: flags ? 0.85 : 0 }}></div>
      </div>
      {!compact && (
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, color: 'var(--ink-tertiary)' }}>
          <span><i className="ph ph-check-circle" style={{ marginRight: 3, color: 'var(--gt-verified)' }}></i>{up} verified</span>
          <span><i className="ph ph-flag" style={{ marginRight: 3, color: 'var(--gt-disputed)' }}></i>{flags} flagged</span>
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────
// Press-fade button
// ─────────────────────────────────────────
function ActionBtn({ icon, label, active, count, onClick }) {
  return (
    <button className="gt-action-btn" data-active={active ? 'true' : 'false'} onClick={onClick}>
      <i className={icon} style={{ fontSize: 15 }}></i>
      {count != null && <span style={{ fontVariantNumeric: 'tabular-nums' }}>{count}</span>}
      {label && <span>{label}</span>}
    </button>
  );
}

// ─────────────────────────────────────────
// IconBtn — round, used in top bars
// ─────────────────────────────────────────
function IconBtn({ icon, onClick, ariaLabel, badge }) {
  return (
    <button onClick={onClick} aria-label={ariaLabel} style={{
      width: 38, height: 38, borderRadius: '50%',
      background: 'var(--surface-raised)', border: 'none',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      color: 'var(--ink-secondary)', cursor: 'pointer', position: 'relative',
    }}>
      <i className={icon} style={{ fontSize: 18 }}></i>
      {badge && (
        <span style={{
          position: 'absolute', top: 6, right: 6,
          width: 7, height: 7, borderRadius: '50%',
          background: '#ef4444', border: '1.5px solid var(--surface)',
        }}></span>
      )}
    </button>
  );
}

// ─────────────────────────────────────────
// Bottom sheet (for details overlay)
// ─────────────────────────────────────────
function BottomSheet({ open, onClose, children, height = 'auto' }) {
  return (
    <>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, background: 'rgba(8,11,20,0.5)',
        opacity: open ? 1 : 0, pointerEvents: open ? 'auto' : 'none',
        transition: 'opacity 250ms ease', zIndex: 40,
      }}></div>
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        background: 'var(--surface-card)',
        borderTopLeftRadius: 20, borderTopRightRadius: 20,
        boxShadow: '0 -8px 32px rgba(0,0,0,0.2)',
        transform: open ? 'translateY(0)' : 'translateY(100%)',
        transition: 'transform 320ms cubic-bezier(0.16, 1, 0.3, 1)',
        zIndex: 41,
        maxHeight: '78%',
        display: 'flex', flexDirection: 'column',
        paddingBottom: 30,
      }}>
        <div style={{ padding: '10px 0 6px', display: 'flex', justifyContent: 'center' }}>
          <div style={{ width: 36, height: 4, borderRadius: 999, background: 'var(--hairline-strong)' }}></div>
        </div>
        <div style={{ overflowY: 'auto', flex: 1 }}>
          {children}
        </div>
      </div>
    </>
  );
}

Object.assign(window, {
  GTBadge, SourceLine, VerifyMeter, ActionBtn, IconBtn, BottomSheet,
});
