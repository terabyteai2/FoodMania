// Realtime socket to the backend (WS /ws/{outlet}?token=). The server pushes JSON
// events on order/menu/settings changes and sends periodic pings. We don't trust the
// event body for state — any order-shaped event just triggers a refetch (server wins).

export interface WsEvent {
  type?: string;
  entity?: string;
  event?: string;
  [k: string]: unknown;
}

export interface RealtimeHandle {
  close: () => void;
  isOpen: () => boolean;
}

interface RealtimeOptions {
  url: string;
  onEvent: (ev: WsEvent) => void;
  onStatus?: (open: boolean) => void;
}

/**
 * Connect with exponential backoff (capped) and auto-reconnect. Returns a handle;
 * call close() on teardown to stop reconnecting.
 */
export function connectRealtime({ url, onEvent, onStatus }: RealtimeOptions): RealtimeHandle {
  let ws: WebSocket | null = null;
  let closedByUs = false;
  let retry = 0;
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

  const open = () => {
    if (closedByUs) return;
    try {
      ws = new WebSocket(url);
    } catch {
      scheduleReconnect();
      return;
    }

    ws.onopen = () => {
      retry = 0;
      onStatus?.(true);
    };

    ws.onmessage = (msg) => {
      if (typeof msg.data !== 'string') return;
      // keepalive frames may be plain "ping"/"pong" text, not JSON
      if (msg.data === 'ping' || msg.data === 'pong') {
        try { ws?.send('pong'); } catch { /* ignore */ }
        return;
      }
      try {
        const parsed = JSON.parse(msg.data) as WsEvent;
        if (parsed && (parsed.type === 'ping' || parsed.type === 'pong')) return;
        onEvent(parsed);
      } catch {
        /* non-JSON frame — ignore */
      }
    };

    ws.onclose = () => {
      onStatus?.(false);
      scheduleReconnect();
    };

    ws.onerror = () => {
      try { ws?.close(); } catch { /* onclose handles reconnect */ }
    };
  };

  const scheduleReconnect = () => {
    if (closedByUs || reconnectTimer) return;
    const delay = Math.min(1000 * 2 ** retry, 15000) + Math.random() * 500;
    retry += 1;
    reconnectTimer = setTimeout(() => {
      reconnectTimer = null;
      open();
    }, delay);
  };

  open();

  return {
    close: () => {
      closedByUs = true;
      if (reconnectTimer) clearTimeout(reconnectTimer);
      try { ws?.close(); } catch { /* ignore */ }
    },
    isOpen: () => ws?.readyState === WebSocket.OPEN,
  };
}
