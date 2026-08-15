"""Shared Sarvam AI WebSocket TTS client (bulbul:v3).

Used by the voice-agent session and by the in-app support assistant
(Volt Assistant) to synthesize assistant replies into spoken audio.
"""

import json
import logging
import re
import time
import urllib.parse

import websockets

from config import settings

logger = logging.getLogger(__name__)

TTS_WS_URL = "wss://api.sarvam.ai/text-to-speech/ws"

# Sentence boundaries: Bengali danda, ? and ! anywhere; "." only when followed
# by whitespace/end so decimals like "৳2.5" are not split.
_SENTENCE_BOUNDARY_RE = re.compile(r"(?<=[।?!…])[ \t]*|(?<=\.)[ \t]+|\n+")


def split_sentences(text: str) -> list[str]:
    """Split text into complete sentences, keeping the terminating punctuation."""
    text = text.strip()
    if not text:
        return []
    segments = [s.strip() for s in _SENTENCE_BOUNDARY_RE.split(text)]
    return [s for s in segments if s]


class SarvamTtsWsClient:
    """Incremental TTS over the /text-to-speech/ws WebSocket.

    Every fed chunk is sent as a text message followed by a flush, so its audio
    is synthesized immediately instead of waiting for the whole reply.
    """

    def __init__(self):
        self.ws = None
        self.connect_seconds: float | None = None

    async def connect(self) -> bool:
        if self.ws is not None:
            try:
                if self.ws.state.name != "CLOSED":
                    return True
            except AttributeError:
                return True
            self.ws = None
        self.connect_seconds = None
        t0 = time.monotonic()
        try:
            ws = await websockets.connect(
                TTS_WS_URL + "?" + urllib.parse.urlencode({
                    "model": settings.SARVAM_TTS_MODEL,
                    "send_completion_event": "true",
                }),
                additional_headers={"api-subscription-key": settings.SARVAM_API_KEY},
            )
            await ws.send(json.dumps({
                "type": "config",
                "data": {
                    "model": settings.SARVAM_TTS_MODEL,
                    "language_code": settings.SARVAM_TTS_LANGUAGE,
                    "speaker": settings.SARVAM_TTS_SPEAKER,
                    "pace": settings.SARVAM_TTS_PACE,
                    "temperature": settings.SARVAM_TTS_TEMPERATURE,
                    "speech_sample_rate": settings.SARVAM_TTS_SAMPLE_RATE,
                    "output_audio_codec": "mp3",
                    "min_buffer_size": settings.SARVAM_TTS_MIN_BUFFER,
                    "max_chunk_length": settings.SARVAM_TTS_MAX_CHUNK,
                },
            }))
            self.ws = ws
            self.connect_seconds = time.monotonic() - t0
            logger.info("[sarvam:tts-ws] Connected and configured in %.2fs", self.connect_seconds)
            return True
        except Exception as e:
            logger.error("[sarvam:tts-ws] Connect failed: %s", e)
            self.ws = None
            return False

    async def send_text(self, text: str) -> bool:
        if not text.strip():
            return False
        if not await self.connect():
            return False
        try:
            await self.ws.send(json.dumps({"type": "text", "data": {"text": text}}))
            await self.ws.send(json.dumps({"type": "flush"}))
            return True
        except Exception as e:
            logger.error("[sarvam:tts-ws] Send failed: %s", e)
            self.ws = None
            return False

    async def close(self):
        if self.ws is not None:
            try:
                await self.ws.close()
            except Exception:
                pass
            self.ws = None