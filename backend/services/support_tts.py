"""Spoken delivery of support-assistant (Volt Assistant) replies.

After an assistant reply is persisted and broadcast as text, this module
synthesises it with Sarvam TTS and relays the audio over the same per-outlet
WebSocket room the chat already uses:

    {"type": "support_audio", "data": {"messageId": str, "audio": "<base64 mp3>"}}
    {"type": "support_audio_done", "data": {"messageId": str}}

The outlet can mute spoken output by sending a ``support_tts_mute`` message
over the WebSocket; mute state is in-memory per outlet.
"""

import asyncio
import json
import logging

from config import settings
from services.sarvam_tts import SarvamTtsWsClient, split_sentences

logger = logging.getLogger(__name__)

_muted_outlets: set[str] = set()

_READ_TIMEOUT_SECONDS = 30.0


def set_muted(outlet_id: str, muted: bool) -> None:
    if muted:
        _muted_outlets.add(outlet_id)
    else:
        _muted_outlets.discard(outlet_id)


def is_muted(outlet_id: str) -> bool:
    return outlet_id in _muted_outlets


def tts_enabled() -> bool:
    return bool(settings.SARVAM_API_KEY.strip())


async def stream_support_audio(outlet_id: str, message_id: str, text: str) -> None:
    """Synthesize ``text`` with Sarvam TTS and relay audio frames to the outlet.

    Fire-and-forget friendly: every failure is logged and never raised, so a
    TTS problem never breaks the chat pipeline. Skips entirely while the
    outlet is muted or no Sarvam key is configured.
    """
    if is_muted(outlet_id) or not tts_enabled():
        return
    sentences = split_sentences(text)
    if not sentences:
        return
    from routers.ws import manager

    client = SarvamTtsWsClient()
    try:
        if not await client.connect():
            logger.warning(
                "[support_tts] skipped outlet=%s message=%s reason=tts_connect_failed",
                outlet_id,
                message_id,
            )
            return
        for sentence in sentences:
            if is_muted(outlet_id):
                break
            if not await client.send_text(sentence):
                break
            if not await _relay_until_final(client, outlet_id, message_id):
                break
        await manager.broadcast(
            outlet_id,
            {"type": "support_audio_done", "data": {"messageId": message_id}},
        )
    except asyncio.CancelledError:
        raise
    except Exception as exc:
        logger.error(
            "[support_tts] failed outlet=%s message=%s: %s",
            outlet_id,
            message_id,
            exc,
            exc_info=True,
        )
    finally:
        await client.close()


async def _relay_until_final(client: SarvamTtsWsClient, outlet_id: str, message_id: str) -> bool:
    """Forward audio frames until Sarvam signals the flush is complete.

    Returns False when the connection died or Sarvam reported an error.
    """
    from routers.ws import manager

    while True:
        try:
            raw = await asyncio.wait_for(client.ws.recv(), timeout=_READ_TIMEOUT_SECONDS)
        except asyncio.TimeoutError:
            try:
                await client.ws.send(json.dumps({"type": "ping"}))
            except Exception:
                return False
            continue
        except Exception:
            return False
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            continue
        mtype = msg.get("type")
        if mtype == "audio":
            audio = ((msg.get("data") or {}).get("audio") or "")
            if audio:
                await manager.broadcast(
                    outlet_id,
                    {"type": "support_audio", "data": {"messageId": message_id, "audio": audio}},
                )
        elif mtype == "event":
            if (msg.get("data") or {}).get("event_type") == "final":
                return True
        elif mtype == "error":
            inner = msg.get("data") or {}
            logger.error(
                "[support_tts] Sarvam error: %s", inner.get("message") or inner
            )
            return False
    return True