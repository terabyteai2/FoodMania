/* ============================================================
   Bytes POS — Messenger inbox + chat thread
   The Facebook chatbot auto-answers; it hands a conversation to
   the manager when it can't resolve something. The manager reads
   the thread and replies in place of the bot — in OUR UI, not FB.
   ============================================================ */

const CHAT_REASON = {
  'Photo requested': 'image',
  'Delivery quote': 'truck',
  'Catering ask': 'users',
  'Bot handling': 'bot',
};

function lastMsg(c) {
  for (let i = c.messages.length - 1; i >= 0; i--) {
    const m = c.messages[i];
    if (m.from === 'system') continue;
    return (m.from === 'manager' ? 'You: ' : m.from === 'bot' ? 'Bot: ' : '') + (m.kind === 'image' ? '📷 Photo' : m.text);
  }
  return '';
}

function MessagesScreen() {
  const b = useBytes();
  const [filter, setFilter] = useState('needs');
  const chats = b.chats || [];
  const needs = chats.filter((c) => c.status === 'needs');
  const list = filter === 'needs' ? needs : chats;

  return (
    <React.Fragment>
      <Header title="Messages" sub="Messenger · auto-reply on" onBack={b.pop}
        right={<span className="badge accent" style={{ height: 26 }}><Icon name="bot" size={14} />Bot live</span>} />

      <div style={{ flex: '0 0 auto', padding: '0 16px 12px' }}>
        <div className="card" style={{ padding: '11px 13px', display: 'flex', alignItems: 'center', gap: 11, background: 'var(--accent-tint)', borderColor: 'var(--accent-tint-2)' }}>
          <div style={{ width: 34, height: 34, borderRadius: 9, background: 'var(--accent)', display: 'grid', placeItems: 'center', flex: '0 0 34px', color: 'var(--accent-ink)' }}><Icon name="bot" size={19} /></div>
          <div style={{ fontSize: 12.5, color: 'var(--ink-2)', lineHeight: 1.4 }}>The chatbot is handling chats. It pulls you in only when it can’t answer.</div>
        </div>
      </div>

      <div style={{ flex: '0 0 auto', padding: '0 16px 12px' }}>
        <div className="seg">
          {[['needs', 'Needs you', needs.length], ['all', 'All chats', chats.length]].map(([id, label, n]) => (
            <button key={id} className={filter === id ? 'active' : ''} onClick={() => setFilter(id)}>{label}<span style={{ marginLeft: 6, minWidth: 18, height: 18, padding: '0 5px', borderRadius: 9, background: filter === id ? (id === 'needs' ? 'var(--warning)' : 'var(--accent)') : 'var(--surface-3)', color: filter === id ? '#fff' : 'var(--muted)', fontSize: 11, fontWeight: 700, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }} className="tab">{n}</span></button>
          ))}
        </div>
      </div>

      <div className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '0 16px 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {list.map((c) => {
          const need = c.status === 'needs';
          return (
            <div key={c.id} className="tile" onClick={() => { b.readChat(c.id); b.push({ screen: 'chatThread', chatId: c.id }); }} style={{ padding: 13, borderColor: need ? '#EAD9A8' : 'var(--line)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
                <div style={{ width: 42, height: 42, borderRadius: 12, background: 'var(--surface-2)', color: 'var(--ink-2)', display: 'grid', placeItems: 'center', fontSize: 15, fontWeight: 700, flex: '0 0 42px' }}>{c.init}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                    <span style={{ fontSize: 15, fontWeight: 700 }} className="ell">{c.name}</span>
                    <span style={{ fontSize: 11.5, color: 'var(--muted)', fontWeight: 500, flex: '0 0 auto' }}>{c.mins}m</span>
                  </div>
                  <div style={{ fontSize: 12.5, color: 'var(--muted)', marginTop: 1, fontWeight: 500 }} className="ell">{lastMsg(c)}</div>
                </div>
                {c.unread > 0 && <span className="tab" style={{ minWidth: 20, height: 20, padding: '0 6px', borderRadius: 10, background: 'var(--danger)', color: '#fff', fontSize: 11, fontWeight: 700, display: 'grid', placeItems: 'center', flex: '0 0 auto' }}>{c.unread}</span>}
              </div>
              <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', gap: 7 }}>
                {need ? (
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: 24, padding: '0 9px', borderRadius: 'var(--r-xs)', background: 'var(--warning-soft)', color: 'var(--warning)', fontSize: 12, fontWeight: 700 }}><Icon name={CHAT_REASON[c.reason] || 'chat'} size={14} />{c.reason}</span>
                ) : c.status === 'replied' ? (
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: 24, padding: '0 9px', borderRadius: 'var(--r-xs)', background: 'var(--surface-2)', color: 'var(--ink-2)', fontSize: 12, fontWeight: 600 }}><Icon name="reply" size={13} />You replied</span>
                ) : (
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: 24, padding: '0 9px', borderRadius: 'var(--r-xs)', background: 'var(--accent-tint)', color: 'var(--accent-strong)', fontSize: 12, fontWeight: 600 }}><Icon name="bot" size={14} />Bot handled</span>
                )}
                {need && <span style={{ marginLeft: 'auto', fontSize: 12.5, fontWeight: 700, color: 'var(--accent-strong)', display: 'inline-flex', alignItems: 'center', gap: 3 }}>Reply<Icon name="chev" size={15} /></span>}
              </div>
            </div>
          );
        })}
        {list.length === 0 && (
          <div style={{ textAlign: 'center', color: 'var(--muted)', padding: '52px 20px', fontSize: 14 }}>
            <div style={{ width: 54, height: 54, borderRadius: 14, background: 'var(--surface-2)', display: 'grid', placeItems: 'center', margin: '0 auto 14px', color: 'var(--placeholder)' }}><Icon name="bot" size={26} /></div>
            All chats handled — the bot has it covered.
          </div>
        )}
      </div>
    </React.Fragment>
  );
}

/* ---------- chat bubble ---------- */
function Bubble({ m }) {
  if (m.from === 'system') {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', margin: '6px 0' }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7, maxWidth: '88%', padding: '8px 12px', borderRadius: 'var(--r-md)', background: 'var(--warning-soft)', color: 'var(--warning)', fontSize: 12, fontWeight: 600, lineHeight: 1.4, textAlign: 'center' }}>
          <Icon name="warn" size={15} style={{ flex: '0 0 15px' }} />{m.text}
        </div>
      </div>
    );
  }
  const me = m.from !== 'customer';
  const bot = m.from === 'bot';
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: me ? 'flex-end' : 'flex-start', gap: 3 }}>
      {me && <span style={{ fontSize: 10.5, fontWeight: 700, letterSpacing: '.03em', color: bot ? 'var(--accent-strong)' : 'var(--muted)', display: 'inline-flex', alignItems: 'center', gap: 4, padding: '0 4px' }}><Icon name={bot ? 'bot' : 'user'} size={12} />{bot ? 'BYTES BOT' : 'YOU'}</span>}
      <div style={{ maxWidth: '78%', padding: m.kind === 'image' ? 5 : '9px 12px', borderRadius: 13, fontSize: 14, lineHeight: 1.42,
        background: me ? (bot ? 'var(--accent-tint)' : 'var(--ink)') : 'var(--surface-2)',
        color: me ? (bot ? 'var(--ink)' : '#fff') : 'var(--ink)',
        border: bot ? '1px solid var(--accent-tint-2)' : 'none',
        borderBottomRightRadius: me ? 4 : 13, borderBottomLeftRadius: me ? 13 : 4 }}>
        {m.kind === 'image' ? (
          <div style={{ width: 168, height: 120, borderRadius: 9, background: 'repeating-linear-gradient(135deg, #ECEFE4, #ECEFE4 7px, #E4E7DC 7px, #E4E7DC 14px)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6, color: '#9AA08C' }}>
            <Icon name="image" size={26} color="#9AA08C" />
            <span style={{ fontFamily: 'ui-monospace, monospace', fontSize: 10.5 }}>{m.text || 'item photo'}</span>
          </div>
        ) : m.text}
      </div>
      <span style={{ fontSize: 10, color: 'var(--placeholder)', padding: '0 4px' }}>{m.time}</span>
    </div>
  );
}

function ChatThread({ chatId }) {
  const b = useBytes();
  const c = (b.chats || []).find((x) => x.id === chatId);
  const [text, setText] = useState('');
  const scrollRef = useRef(null);
  useEffect(() => { const el = scrollRef.current; if (el) el.scrollTop = el.scrollHeight; }, [c && c.messages.length]);
  if (!c) return <div style={{ padding: 20 }}>Chat closed.</div>;

  const need = c.status === 'needs';
  const quick = c.reason === 'Photo requested'
    ? [['Send Kacchi photo', 'image', 'Kacchi Biryani — full plate'], ['Quote price', 'text', 'A full plate of Kacchi Biryani is ৳480, half is ৳260. Would you like to order?']]
    : c.reason === 'Delivery quote'
    ? [['Quote ৳120 (Uttara)', 'text', 'Delivery to Uttara Sector 11 is ৳120 (outside our standard zone). Total would be ৳940. Shall I confirm the order?'], ['Quote ৳150', 'text', 'For that distance the delivery charge is ৳150. Total ৳970 — want me to place it?']]
    : [['Confirm reservation', 'text', 'Done! I’ve reserved 30 plates for Friday. We’ll call to confirm timing. Thank you 🌿']];

  const send = (t, kind) => { if (kind === 'image') b.sendChat(c.id, t, 'image'); else if (t.trim()) { b.sendChat(c.id, t.trim()); setText(''); } };

  return (
    <React.Fragment>
      <Header onBack={b.pop} title={c.name} sub="via Messenger"
        right={<BarBtn icon="bot" onClick={() => b.sendChat(c.id, 'Handed back to the chatbot.', 'handback')} />} />

      <div ref={scrollRef} className="scrollY noscroll" style={{ flex: 1, minHeight: 0, padding: '4px 16px 14px', display: 'flex', flexDirection: 'column', gap: 9 }}>
        <div style={{ textAlign: 'center', fontSize: 11.5, color: 'var(--placeholder)', padding: '4px 0 6px' }}>Conversation started 7:31 PM · Facebook Messenger</div>
        {c.messages.map((m, i) => <Bubble key={i} m={m} />)}
      </div>

      {/* composer */}
      <div style={{ flex: '0 0 auto', borderTop: '1px solid var(--line)', background: 'var(--surface)', boxShadow: 'var(--e-up)' }}>
        {need && (
          <div style={{ padding: '9px 14px 0', display: 'flex', alignItems: 'center', gap: 7, fontSize: 12, color: 'var(--accent-strong)', fontWeight: 600 }}>
            <Icon name="reply" size={15} />You’re replying in place of the bot
          </div>
        )}
        <div className="chiprow noscroll" style={{ padding: '10px 14px 4px' }}>
          {quick.map(([label, kind, payload]) => (
            <button key={label} className="chip tint active" style={{ height: 34 }} onClick={() => kind === 'image' ? send(payload, 'image') : setText(payload)}>
              <Icon name={kind === 'image' ? 'image' : 'sparkle'} size={14} />{label}
            </button>
          ))}
        </div>
        <div style={{ padding: '6px 14px 14px', display: 'flex', alignItems: 'flex-end', gap: 9 }}>
          <button style={{ width: 44, height: 44, flex: '0 0 44px', borderRadius: 'var(--r-md)', border: '1px solid var(--line-2)', background: 'var(--surface)', display: 'grid', placeItems: 'center', cursor: 'pointer', color: 'var(--ink-2)' }} onClick={() => send('item photo', 'image')}><Icon name="image" size={20} /></button>
          <div className="field" style={{ flex: 1, minHeight: 44, height: 'auto', alignItems: 'center' }}>
            <input value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && send(text)} placeholder="Write a reply…" />
          </div>
          <button onClick={() => send(text)} disabled={!text.trim()} style={{ width: 44, height: 44, flex: '0 0 44px', borderRadius: 'var(--r-md)', border: 'none', background: text.trim() ? 'var(--accent)' : 'var(--surface-2)', color: text.trim() ? 'var(--accent-ink)' : 'var(--placeholder)', display: 'grid', placeItems: 'center', cursor: text.trim() ? 'pointer' : 'default', transition: 'background .12s' }}><Icon name="send" size={20} /></button>
        </div>
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { MessagesScreen, ChatThread });
