// Size / option / add-on picker for menu items with modifier tags (petpooja-style
// customizable* items). Result = one cart line with a name suffix + adjusted price.

import { useMemo, useState } from 'react';
import { t, type Lang } from '../i18n/strings';
import { Modal } from './Modal';
import type { PosMenuItem } from '../state/menu';
import { itemDisplayName } from '../state/menu';
import { round2 } from '../core/tags';
import { formatTk } from '../core/money';

export interface CustomizeResult {
  suffix: string | null;
  unitPrice: number;
  note: string | null;
}

export function CustomizeModal(props: {
  item: PosMenuItem;
  lang: Lang;
  bn: boolean;
  onConfirm: (result: CustomizeResult) => void;
  onClose: () => void;
}) {
  const { extras } = props.item;
  const [size, setSize] = useState<number>(extras.sizes.length > 0 ? 0 : -1);
  const [options, setOptions] = useState<Set<number>>(new Set());
  const [addOns, setAddOns] = useState<Set<number>>(new Set());
  const [note, setNote] = useState('');

  const unitPrice = useMemo(() => {
    let price = size >= 0 ? extras.sizes[size].price : props.item.price;
    for (const i of options) price += extras.options[i].priceDelta;
    for (const i of addOns) price += extras.addOns[i].price;
    return round2(Math.max(0, price));
  }, [size, options, addOns, extras, props.item.price]);

  const confirm = () => {
    const parts: string[] = [];
    if (size >= 0) parts.push(extras.sizes[size].name);
    for (const i of options) parts.push(extras.options[i].name);
    for (const i of addOns) parts.push(`+${extras.addOns[i].name}`);
    props.onConfirm({
      suffix: parts.length ? `(${parts.join(', ')})` : null,
      unitPrice,
      note: note.trim() || null,
    });
  };

  const toggle = (set: Set<number>, i: number, update: (s: Set<number>) => void) => {
    const next = new Set(set);
    if (next.has(i)) next.delete(i);
    else next.add(i);
    update(next);
  };

  return (
    <Modal
      title={itemDisplayName(props.item, props.bn)}
      onClose={props.onClose}
      footer={
        <>
          <span className="customize-price">{formatTk(unitPrice)}</span>
          <button className="btn btn-primary" onClick={confirm}>{t('cm.addToOrder', props.lang)}</button>
        </>
      }
    >
      {extras.sizes.length > 0 && (
        <div className="customize-group">
          <div className="customize-group-title">{t('cm.size', props.lang)}</div>
          <div className="customize-choices">
            {extras.sizes.map((s, i) => (
              <button
                key={s.name}
                className={`choice ${size === i ? 'active' : ''}`}
                onClick={() => setSize(i)}
              >
                {s.name} <span className="choice-price">{formatTk(s.price)}</span>
              </button>
            ))}
          </div>
        </div>
      )}
      {extras.options.length > 0 && (
        <div className="customize-group">
          <div className="customize-group-title">{t('cm.options', props.lang)}</div>
          <div className="customize-choices">
            {extras.options.map((o, i) => (
              <button
                key={o.name}
                className={`choice ${options.has(i) ? 'active' : ''}`}
                onClick={() => toggle(options, i, setOptions)}
              >
                {o.name}
                {o.priceDelta !== 0 && (
                  <span className="choice-price">{o.priceDelta > 0 ? '+' : ''}{formatTk(o.priceDelta)}</span>
                )}
              </button>
            ))}
          </div>
        </div>
      )}
      {extras.addOns.length > 0 && (
        <div className="customize-group">
          <div className="customize-group-title">{t('cm.addOns', props.lang)}</div>
          <div className="customize-choices">
            {extras.addOns.map((a, i) => (
              <button
                key={a.name}
                className={`choice ${addOns.has(i) ? 'active' : ''}`}
                onClick={() => toggle(addOns, i, setAddOns)}
              >
                {a.name} <span className="choice-price">+{formatTk(a.price)}</span>
              </button>
            ))}
          </div>
        </div>
      )}
      <div className="customize-group">
        <div className="customize-group-title">{t('cm.noteOptional', props.lang)}</div>
        <input
          className="input" value={note} onChange={(e) => setNote(e.target.value)}
          placeholder={t('cm.extraSpicy', props.lang)}
        />
      </div>
    </Modal>
  );
}
