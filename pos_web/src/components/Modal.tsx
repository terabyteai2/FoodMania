import type { ReactNode } from 'react';

export function Modal(props: {
  title: string;
  onClose: () => void;
  width?: number;
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <div className="modal-backdrop" onMouseDown={(e) => { if (e.target === e.currentTarget) props.onClose(); }}>
      <div className="modal" style={{ width: props.width ?? 520 }}>
        <div className="modal-head">
          <h3>{props.title}</h3>
          <button className="modal-x" onClick={props.onClose} aria-label="Close">✕</button>
        </div>
        <div className="modal-body">{props.children}</div>
        {props.footer && <div className="modal-foot">{props.footer}</div>}
      </div>
    </div>
  );
}
