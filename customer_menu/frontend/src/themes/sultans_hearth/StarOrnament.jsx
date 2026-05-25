import React from 'react'

// 8-point arabesque star: two overlapping squares (one rotated 45deg)
// plus a center dot. Used as section divider, hero medallion backdrop,
// category title flourish, success-screen ornament.
export default function StarOrnament({
  size = 22,
  stroke = '#C9A24B',
  fill = 'none',
  strokeWidth = 1.25,
  withDot = true,
  spin = false,
  style,
}) {
  const half = size / 2
  const inset = size * 0.08
  const a = inset
  const b = size - inset
  return (
    <svg
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      aria-hidden="true"
      style={style}
      className={spin ? 'hearth-star-spin' : undefined}
    >
      <g transform={`translate(${half} ${half})`}>
        {/* outer 8-point star = two rotated squares */}
        <rect
          x={-half + a} y={-half + a}
          width={b - a} height={b - a}
          fill={fill} stroke={stroke} strokeWidth={strokeWidth}
        />
        <rect
          x={-half + a} y={-half + a}
          width={b - a} height={b - a}
          fill={fill} stroke={stroke} strokeWidth={strokeWidth}
          transform="rotate(45)"
        />
        {withDot && <circle r={size * 0.05} fill={stroke} />}
      </g>
    </svg>
  )
}

// Section divider: centered star ornament with optional flanking gold rules.
export function StarDivider({ flank = true, color = '#C9A24B', size = 18 }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      gap: 14, margin: '0 auto', maxWidth: 360, padding: '8px 0',
    }}>
      {flank && <span style={{ flex: 1, height: 1, background: `linear-gradient(90deg, transparent, ${color}66, ${color})` }} />}
      <StarOrnament size={size} stroke={color} />
      {flank && <span style={{ flex: 1, height: 1, background: `linear-gradient(90deg, ${color}, ${color}66, transparent)` }} />}
    </div>
  )
}

// Single small flame glyph for the spice meter.
export function FlameGlyph({ size = 11, color = '#E26B2C', dim = false }) {
  return (
    <svg width={size} height={size} viewBox="0 0 12 12" aria-hidden="true"
      style={{ opacity: dim ? 0.22 : 1, marginRight: 1 }}>
      <path
        d="M6 1.2c.6 1.7 2.6 2.6 2.6 5 0 1.9-1.2 3.4-2.6 3.4S3.4 8.1 3.4 6.2c0-1.3.6-2 1.2-2.6.4-.4.6-1 .4-1.6.4.4.8.8 1 1.2z"
        fill={color}
      />
    </svg>
  )
}
