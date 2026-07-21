import { useState } from 'react';
import { api } from '../api/client';
import { useSession } from '../state/session';
import { t } from '../i18n/strings';

interface FieldEditorProps {
  label: string;
  subtitle: string;
  initialValue: string;
  placeholder?: string;
  suffix?: string;
  onSave: (v: string) => Promise<unknown>;
}

function FieldEditor({ label, subtitle, initialValue, placeholder, suffix, onSave }: FieldEditorProps) {
  const lang = useSession((s) => s.lang);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(initialValue);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [displayValue, setDisplayValue] = useState(initialValue);

  const begin = () => {
    setDraft(displayValue);
    setEditing(true);
    setMsg(null);
  };

  const save = async () => {
    setSaving(true);
    setMsg(null);
    try {
      await onSave(draft.trim());
      setDisplayValue(draft.trim());
      setEditing(false);
      setMsg(t('settingsSaved', lang));
    } catch (e) {
      setMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setSaving(false);
    }
  };

  const cancel = () => {
    setEditing(false);
    setMsg(null);
  };

  return (
    <div className="settings-field">
      <div className="settings-field-head">
        <span className="settings-field-label">{label}</span>
        {subtitle && <span className="settings-field-sub">{subtitle}</span>}
      </div>
      {editing ? (
        <div className="settings-field-edit">
          <div className="settings-field-input-row">
            <input
              className="input" value={draft} autoFocus
              placeholder={placeholder}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') void save(); if (e.key === 'Escape') cancel(); }}
            />
            {suffix && <span className="settings-field-suffix">{suffix}</span>}
          </div>
          <div className="settings-field-actions">
            <button className="btn btn-primary btn-sm" disabled={saving} onClick={save}>
              {saving ? '…' : t('save', lang)}
            </button>
            <button className="btn btn-outline btn-sm" onClick={cancel}>{t('cancel', lang)}</button>
          </div>
        </div>
      ) : (
        <button className="settings-field-value" onClick={begin}>
          {displayValue || <span className="settings-field-empty">—</span>}
          {suffix && <span className="settings-field-suffix">{suffix}</span>}
        </button>
      )}
      {msg && <div className="settings-field-msg">{msg}</div>}
    </div>
  );
}

export function RestaurantSettings() {
  const session = useSession((s) => s.session)!;
  const lang = useSession((s) => s.lang);

  return (
    <div className="settings-root">
      <div className="card settings-card">
        <h3>{t('settingsRestaurantDetails', lang)}</h3>

        <FieldEditor
          label={t('accountHolderName', lang)}
          subtitle={t('accountHolderNameSubtitle', lang)}
          initialValue={session.account.displayName ?? ''}
          onSave={(v) => api.updateDisplayName(v)}
        />

        <FieldEditor
          label={t('restaurantName', lang)}
          subtitle={t('restaurantNameSubtitle', lang)}
          initialValue={session.restaurantName}
          onSave={(v) => api.updateOutletProfile({ restaurantName: v })}
        />

        <FieldEditor
          label={t('restaurantPhoneLabel', lang)}
          subtitle={t('restaurantPhoneSubtitle', lang)}
          initialValue={session.outletPhone ?? ''}
          placeholder="01XXXXXXXXX"
          onSave={(v) => api.updateOutletProfile({ phone: v })}
        />

        <FieldEditor
          label={t('websiteUrlLabel', lang)}
          subtitle={t('websiteUrlSubtitle', lang)}
          initialValue={session.publicSlug ?? ''}
          suffix=".quickbytes.buzz"
          onSave={(v) => api.updatePublicUrl(v)}
        />
      </div>

      <div className="card settings-card">
        <h3>{t('heroMediaLabel', lang)}</h3>
        <p className="settings-hero-note">
          {t('heroMediaSubtitle', lang)}
        </p>
        <p className="settings-hero-note">
          <a
            className="settings-open-app"
            href={`https://${session.publicSlug ?? ''}.quickbytes.buzz`}
            target="_blank" rel="noopener noreferrer"
          >
            {t('openInApp', lang)}
          </a>
        </p>
      </div>
    </div>
  );
}
