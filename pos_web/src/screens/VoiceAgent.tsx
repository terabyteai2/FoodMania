import { useEffect, useRef, useState, useCallback } from 'react';
import { useSession } from '../state/session';

type Msg = { type: 'partial' | 'user_text' | 'assistant_text' | 'error'; text: string }
  | { type: 'audio'; data: string }
  | { type: 'tts_done' }
  | { type: 'ping' }
  | { type: 'debug'; text: string };

export function VoiceAgent() {
  const session = useSession((s) => s.session);
  const [connected, setConnected] = useState(false);
  const [wsState, setWsState] = useState('connecting');
  const [wsError, setWsError] = useState('');
  const [wsUrl, setWsUrl] = useState('');
  const [transcript, setTranscript] = useState<{ role: string; text: string }[]>([]);
  const [partial, setPartial] = useState('');
  const [listening, setListening] = useState(false);
  const [micError, setMicError] = useState('');
  const [audioChunks, setAudioChunks] = useState(0);
  const [showDebug, setShowDebug] = useState(true);
  const [backendLog, setBackendLog] = useState<string[]>([]);
  const wsRef = useRef<WebSocket | null>(null);
  const mediaRef = useRef<MediaStream | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const logRef = useRef<string[]>([]);
  const audioChunksRef = useRef<string[]>([]);

  const addLog = useCallback((msg: string) => {
    logRef.current = [...logRef.current.slice(-49), msg];
    setBackendLog(logRef.current);
    console.log('[voice-agent]', msg);
  }, []);

  useEffect(() => {
    if (!session) {
      addLog('No session — not logged in');
      return;
    }
    const token = session.deviceToken;
    const outletId = session.outletId;
    const base = window.location.origin.replace(/^http/, 'ws');
    const url = `${base}/ws/voice/${outletId}?token=${token}`;
    setWsUrl(url);
    addLog(`Connecting to ${url}`);

    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      setConnected(true);
      setWsState('open');
      addLog('WebSocket OPEN');
    };

    ws.onclose = (ev) => {
      setConnected(false);
      setWsState(`closed (code=${ev.code} reason=${ev.reason})`);
      addLog(`WebSocket CLOSE code=${ev.code} reason="${ev.reason}"`);
      if (ev.code === 4001) setWsError('Auth failed — check device token');
      else if (ev.code === 4003) setWsError('Backend: ElevenLabs key not configured');
      else if (ev.code === 4004) setWsError('Backend: outlet not found');
    };

    ws.onerror = () => {
      setWsState('error');
      addLog('WebSocket ERROR (check console for details)');
    };

    ws.onmessage = (ev) => {
      try {
        const msg = JSON.parse(ev.data) as Msg;
        if (msg.type === 'ping') {
          addLog('← ping');
          return;
        }
        if (msg.type === 'partial') {
          addLog(`← partial: "${msg.text.slice(0, 60)}..."`);
          setPartial(msg.text);
        } else if (msg.type === 'user_text') {
          addLog(`← user_text: "${msg.text.slice(0, 80)}"`);
          setTranscript((p) => [...p, { role: 'user', text: msg.text }]);
          setPartial('');
        } else if (msg.type === 'assistant_text') {
          addLog(`← assistant: "${msg.text.slice(0, 80)}"`);
          setTranscript((p) => [...p, { role: 'assistant', text: msg.text }]);
        } else if (msg.type === 'error') {
          addLog(`← error: "${msg.text}"`);
          setTranscript((p) => [...p, { role: 'system', text: '⚠ ' + msg.text }]);
        } else if (msg.type === 'audio') {
          addLog(`← audio chunk (${msg.data.length} bytes base64)`);
          audioChunksRef.current.push(msg.data);
        } else if (msg.type === 'debug') {
          addLog(`← debug: ${msg.text}`);
        } else if (msg.type === 'tts_done') {
          addLog('← tts_done, playing buffered audio');
          playAudio(audioChunksRef.current);
          audioChunksRef.current = [];
        }
      } catch (err) {
        addLog(`← parse error: ${err}`);
      }
    };

    return () => {
      addLog('Cleanup: closing WebSocket');
      ws.close();
    };
  }, [session, addLog]);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [transcript, partial]);

  const playAudio = (chunks: string[]) => {
    if (chunks.length === 0) return;
    try {
      const allBytes: number[] = [];
      for (const b64 of chunks) {
        const binary = atob(b64);
        for (let i = 0; i < binary.length; i++) allBytes.push(binary.charCodeAt(i));
      }
      const blob = new Blob([new Uint8Array(allBytes)], { type: 'audio/mpeg' });
      const url = URL.createObjectURL(blob);
      const el = new Audio(url);
      el.onended = () => URL.revokeObjectURL(url);
      el.play().catch((err) => addLog(`Audio play error: ${err}`));
      addLog(`Playing audio (${allBytes.length} bytes, ${chunks.length} chunks)`);
    } catch (err) {
      addLog(`Audio decode error: ${err}`);
    }
  };

  const startMic = async () => {
    if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) {
      addLog('startMic: WebSocket not open');
      return;
    }
    setMicError('');
    try {
      addLog('Requesting microphone...');
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      addLog('Microphone granted');
      mediaRef.current = stream;
      const ctx = new AudioContext({ sampleRate: 16000 });
      audioCtxRef.current = ctx;
      const source = ctx.createMediaStreamSource(stream);
      const processor = ctx.createScriptProcessor(4096, 1, 1);
      source.connect(processor);
      processor.connect(ctx.destination);

      processor.onaudioprocess = (e) => {
        if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return;
        const input = e.inputBuffer.getChannelData(0);
        const pcm = encodePCM(input);
        wsRef.current.send(JSON.stringify({ type: 'audio', data: pcm }));
        setAudioChunks((c) => c + 1);
      };

      setListening(true);
      addLog('Mic is now active, sending audio chunks');
    } catch (err: any) {
      const msg = err?.name === 'NotAllowedError' ? 'Microphone permission denied' :
                  err?.name === 'NotFoundError' ? 'No microphone found' :
                  `Mic error: ${err?.message || err}`;
      setMicError(msg);
      addLog(msg);
    }
  };

  const stopMic = () => {
    addLog('Stopping microphone');
    if (mediaRef.current) {
      mediaRef.current.getTracks().forEach((t) => t.stop());
      mediaRef.current = null;
    }
    if (audioCtxRef.current) {
      audioCtxRef.current.close();
      audioCtxRef.current = null;
    }
    setListening(false);
  };

  const encodePCM = (samples: Float32Array): string => {
    const buf = new ArrayBuffer(samples.length * 2);
    const view = new DataView(buf);
    for (let i = 0; i < samples.length; i++) {
      const s = Math.max(-1, Math.min(1, samples[i]));
      view.setInt16(i * 2, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
    }
    const bytes = new Uint8Array(buf);
    let bin = '';
    for (let i = 0; i < bytes.length; i++) {
      bin += String.fromCharCode(bytes[i]);
    }
    return btoa(bin);
  };

  return (
    <div style={{ padding: 16, maxWidth: 600, margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
        <h2 style={{ margin: 0 }}>Voice Agent</h2>
        <button className="btn btn-sm btn-outline" onClick={() => setShowDebug((d) => !d)}>
          {showDebug ? 'Hide Debug' : 'Show Debug'}
        </button>
      </div>

      {showDebug && (
        <div style={{
          background: '#111', color: '#0f0', fontFamily: 'monospace', fontSize: 11,
          padding: 8, borderRadius: 6, marginBottom: 12, maxHeight: 200, overflow: 'auto',
        }}>
          <div><strong>WebSocket:</strong> {wsUrl}</div>
          <div><strong>State:</strong> {wsState}</div>
          <div><strong>Connected:</strong> {connected ? '🟢 YES' : '🔴 NO'}</div>
          {wsError && <div><strong>Error:</strong> <span style={{ color: '#f44' }}>{wsError}</span></div>}
          <div><strong>Mic:</strong> {listening ? '🎤 ACTIVE' : '⏸ idle'}{micError && ` (${micError})`}</div>
          <div><strong>Audio chunks sent:</strong> {audioChunks}</div>
          <div><strong>Transcripts received:</strong> {transcript.length}</div>
          <hr style={{ borderColor: '#333', margin: '4px 0' }} />
          <div style={{ maxHeight: 80, overflow: 'auto' }}>
            {backendLog.map((l, i) => <div key={i}>{l}</div>)}
          </div>
        </div>
      )}

      <div
        ref={scrollRef}
        style={{
          height: 300, overflowY: 'auto', border: '1px solid var(--line)',
          borderRadius: 8, padding: 12, marginBottom: 12, background: 'var(--card)',
        }}
      >
        {transcript.length === 0 && !partial && (
          <div style={{ color: 'var(--ink-3)', textAlign: 'center', paddingTop: 50, fontSize: 14 }}>
            Hold the mic button and speak your order
          </div>
        )}
        {transcript.map((m, i) => (
          <div key={i} style={{ marginBottom: 8, lineHeight: 1.4 }}>
            <strong style={{ color: m.role === 'user' ? 'var(--primary)' : 'var(--success)' }}>
              {m.role === 'user' ? 'You' : m.role === 'system' ? 'System' : 'Agent'}:
            </strong>
            <span style={{ marginLeft: 6, color: 'var(--ink-1)' }}>{m.text}</span>
          </div>
        ))}
        {partial && (
          <div style={{ color: 'var(--ink-3)', fontStyle: 'italic' }}>{partial}</div>
        )}
      </div>

      <button
        className={`btn ${listening ? 'btn-danger' : 'btn-primary'}`}
        style={{ width: '100%', padding: '12px 0', fontSize: 16 }}
        onMouseDown={startMic}
        onMouseUp={stopMic}
        onTouchStart={startMic}
        onTouchEnd={stopMic}
        disabled={!connected}
      >
        {listening ? '🔴 Release to stop' : '🎤 Hold to talk'}
      </button>
      {!connected && backendLog.length === 0 && (
        <p style={{ color: 'var(--ink-3)', textAlign: 'center', marginTop: 8, fontSize: 12 }}>
          Try a hard refresh (Ctrl+Shift+R) if the connection stays stuck
        </p>
      )}
    </div>
  );
}