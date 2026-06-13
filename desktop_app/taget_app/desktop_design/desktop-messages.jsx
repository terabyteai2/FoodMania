/* ============================================================
   QuickBytes Desktop — Messages slide-over (Messenger takeover).
   The FB bot auto-answers and escalates; the manager replies in
   OUR UI. Bot bubbles = accent-tint + "BYTES BOT" label;
   escalations = amber banners; manager bubbles = solid ink.
   ============================================================ */
const { useState: dMsgState, useRef: dMsgRef, useEffect: dMsgEffect } = React;

const DK_QUICK = {
  'Photo requested': ['Send Kacchi photo', 'Share full menu'],
  'Delivery quote': ['Quote ৳180 to Uttara', 'Within zone — ৳60'],
  'Catering ask': ['Send catering rates', 'Reserve the date'],
  'Bot handling': ['Take over chat'],
};

function MessagesOverlay() {
  const d = useDesk();
  const lang = d.lang;
  const [openId, setOpenId] = dMsgState(null);
  const chat = d.chats.find((c) => c.id === openId);
  const needs = d.chats.filter((c) => c.status === 'needs').length;

  return (
    <React.Fragment>
      <div className="dk-scrim" style={{ display: 'block', background: 'rgba(20,24,14,.3)' }} onClick={() => d.setMsgOpen(false)} />
      <div className="dk-slideover dk-fadein">
        {!chat ? (
          <React.Fragment>
            <div style={{ flex: '0 0 auto', padding: '18px 20px 14px', borderBottom: '1px solid var(--line)', display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 34, height: 34, borderRadius: 8, background: 'var(--accent-tint)', display: 'grid', placeItems: 'center' }}><Icon name="chat" size={19} color="var(--accent-strong)" /></div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 17, fontWeight: 700 }}>{lang === 'bn' ? 'মেসেজ' : 'Messages'}</div>
                <div style={{ fontSize: 12.5, color: 'var(--muted)' }}>{lang === 'bn' ? 'বট লাইভ · ' : 'Bot live · '}{needs} {lang === 'bn' ? 'টি আপনার সাহায্য চায়' : 'need you'}</div>
              </div>
              <button className="dk-xbtn" style={{ width: 34, height: 34 }} onClick={() => d.setMsgOpen(false)}><Icon name="x" size={17} /></button>
            </div>
            <div className="scrollY noscroll" style={{ flex: 1 }}>
              {d.chats.map((c) => {
                const needsHelp = c.status === 'needs';
                const last = c.messages[c.messages.length - 1];
                return (
                  <div key={c.id} onClick={() => setOpenId(c.id)} style={{ display: 'flex', gap: 12, padding: '14px 20px', borderBottom: '1px solid var(--line)', cursor: 'pointer' }}>
                    <div style={{ width: 42, height: 42, borderRadius: '50%', background: 'var(--surface-3)', display: 'grid', placeItems: 'center', fontSize: 14, fontWeight: 700, color: 'var(--ink-2)', flex: '0 0 42px' }}>{c.init}</div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                        <span style={{ fontSize: 14.5, fontWeight: 700, flex: 1, minWidth: 0 }} className="ell">{c.name}</span>
                        <span style={{ fontSize: 11.5, color: 'var(--placeholder)' }}>{c.mins}m</span>
                      </div>
                      <div style={{ fontSize: 12.5, color: 'var(--muted)', marginTop: 2 }} className="ell">{last.from === 'customer' ? '' : (last.from === 'bot' ? '🤖 ' : '↩ ')}{last.text}</div>
                      <div style={{ marginTop: 6 }}>
                        {needsHelp ? <span className="badge warning"><span className="bd" style={{ background: 'var(--warning)' }} />{c.reason}</span>
                          : c.status === 'replied' ? <span className="badge neutral">{lang === 'bn' ? 'উত্তর দেওয়া হয়েছে' : 'You replied'}</span>
                            : <span className="badge" style={{ background: 'var(--accent-tint)', color: 'var(--accent-strong)' }}><Icon name="bot" size={12} />{lang === 'bn' ? 'বট সামলাচ্ছে' : 'Bot handling'}</span>}
                        {c.unread > 0 && <span className="badge danger" style={{ marginLeft: 6 }}>{c.unread}</span>}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </React.Fragment>
        ) : (
          <ChatThread chat={chat} onBack={() => setOpenId(null)} onClose={() => d.setMsgOpen(false)} />
        )}
      </div>
    </React.Fragment>
  );
}

function ChatThread({ chat, onBack, onClose }) {
  const d = useDesk();
  const lang = d.lang;
  const [text, setText] = dMsgState('');
  const scrollRef = dMsgRef(null);
  dMsgEffect(() => { if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight; }, [chat.messages.length]);
  const quick = DK_QUICK[chat.reason] || [];
  const send = (t) => { if (!t.trim()) return; d.sendReply(chat.id, t.trim()); setText(''); };

  return (
    <React.Fragment>
      <div style={{ flex: '0 0 auto', padding: '14px 16px', borderBottom: '1px solid var(--line)', display: 'flex', alignItems: 'center', gap: 10 }}>
        <button className="dk-xbtn" style={{ width: 34, height: 34 }} onClick={onBack}><Icon name="back" size={18} /></button>
        <div style={{ width: 38, height: 38, borderRadius: '50%', background: 'var(--surface-3)', display: 'grid', placeItems: 'center', fontSize: 13, fontWeight: 700, color: 'var(--ink-2)' }}>{chat.init}</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 15, fontWeight: 700 }} className="ell">{chat.name}</div>
          <div style={{ fontSize: 12, color: 'var(--muted)' }}>{lang === 'bn' ? 'মেসেঞ্জার-এর মাধ্যমে' : 'via Messenger'}</div>
        </div>
        <button className="dk-iconbtn" title={lang === 'bn' ? 'বটের কাছে ফেরত' : 'Hand back to bot'} onClick={() => { d.handBack(chat.id); onBack(); }}><Icon name="bot" size={20} color="var(--accent-strong)" /></button>
      </div>
      <div ref={scrollRef} className="scrollY noscroll" style={{ flex: 1, padding: '16px', display: 'flex', flexDirection: 'column', gap: 10, background: 'var(--bg)' }}>
        {chat.messages.map((m, i) => {
          if (m.from === 'system') return (
            <div key={i} style={{ alignSelf: 'center', maxWidth: '88%', textAlign: 'center', background: 'var(--warning-soft)', color: 'var(--warning)', borderRadius: 'var(--r-md)', padding: '8px 12px', fontSize: 12.5, fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 6 }}><Icon name="warn" size={15} />{m.text}</div>
          );
          if (m.from === 'customer') return (
            <div key={i} className="dk-bubble" style={{ alignSelf: 'flex-start', background: 'var(--surface)', border: '1px solid var(--line)' }}>{m.text}<div style={{ fontSize: 10.5, color: 'var(--placeholder)', marginTop: 3 }}>{m.time}</div></div>
          );
          const isBot = m.from === 'bot';
          return (
            <div key={i} style={{ alignSelf: 'flex-end', maxWidth: '82%' }}>
              {isBot && <div style={{ fontSize: 10, fontWeight: 800, letterSpacing: '.04em', color: 'var(--accent-strong)', textAlign: 'right', marginBottom: 3, display: 'flex', alignItems: 'center', gap: 4, justifyContent: 'flex-end' }}><Icon name="bot" size={12} />BYTES BOT</div>}
              <div className="dk-bubble" style={{ background: isBot ? 'var(--accent-tint)' : 'var(--ink)', color: isBot ? 'var(--ink)' : '#fff', marginLeft: 'auto' }}>
                {m.kind === 'image' ? <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><Icon name="image" size={18} color={isBot ? 'var(--accent-strong)' : '#fff'} />{m.text}</div> : m.text}
                <div style={{ fontSize: 10.5, color: isBot ? 'var(--muted)' : 'rgba(255,255,255,.6)', marginTop: 3 }}>{m.time}</div>
              </div>
            </div>
          );
        })}
      </div>
      <div style={{ flex: '0 0 auto', borderTop: '1px solid var(--line)', padding: '12px 14px', background: 'var(--surface)' }}>
        {chat.status === 'needs' && quick.length > 0 && (
          <div style={{ display: 'flex', gap: 7, marginBottom: 10, flexWrap: 'wrap' }}>
            {quick.map((qr) => <button key={qr} className="chip tint active" onClick={() => send(qr)}>{qr}</button>)}
          </div>
        )}
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <button className="dk-iconbtn" onClick={() => d.sendReply(chat.id, lang === 'bn' ? 'কাচ্চির ছবি' : 'Kacchi Biryani photo', 'image')}><Icon name="image" size={20} /></button>
          <div className="field" style={{ flex: 1 }}><input value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') send(text); }} placeholder={lang === 'bn' ? 'উত্তর লিখুন…' : 'Write a reply…'} /></div>
          <button className="addbtn" onClick={() => send(text)}><Icon name="send" size={19} color="var(--accent-ink)" /></button>
        </div>
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { MessagesOverlay });
