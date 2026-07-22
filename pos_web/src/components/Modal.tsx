import { t } from '../i18n/strings';
import { useSession } from '../state/session';
import type { ReactNode } from 'react';

export function Modal(props: {
  title: string;
  onClose: () => void;
  width?: number;
  children: ReactNode;
  footer?: ReactNode;
}) {
  const lang = useSession((s) => s.lang);
  return (
    <div className="modal-backdrop" onMouseDown={(e) => { if (e.target === e.currentTarget) props.onClose(); }}>
      <div className="modal" style={{ width: props.width ?? 520 }}>
        <div className="modal-head">
          <h3>{props.title}</h3>
          <button className="modal-x" onClick={props.onClose} aria-label={t('modal.close', lang)}>✕</button>
        </div>
        <div className="modal-body">{props.children}</div>
        {props.footer && <div className="modal-foot">{props.footer}</div>}
      </div>
    </div>
  );
}
