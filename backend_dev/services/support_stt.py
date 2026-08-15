"""Voice input for the support assistant (Sarvam STT, batch on release).

The Flutter POS app records a WAV clip (push-to-talk) and ships it over the
outlet WebSocket as a ``support_stt`` message. This module transcribes the
clip with Sarvam's synchronous REST STT (``/speech-to-text``, saaras:v3) and
the caller posts the transcript into the existing support-chat pipeline
(persist -> broadcast ``support_msg`` -> ``support_llm_auto_reply``), so the
Volt Assistant's text + TTS reply fire unchanged.
"""

import base64
import logging

import httpx

from config import settings

logger = logging.getLogger(__name__)

STT_URL = "https://api.sarvam.ai/speech-to-text"
STT_TIMEOUT_SECONDS = 45.0
MAX_AUDIO_BYTES = 10 * 1024 * 1024


def stt_enabled() -> bool:
    return bool(settings.SARVAM_API_KEY.strip())


async def transcribe_audio(base64_audio: str) -> str:
    """Transcribe one voice clip with Sarvam STT.

    Returns the cleaned transcript, or "" when the clip is empty/too large,
    STT is not configured, or Sarvam failed. Errors are logged and never
    raised, so a transcription problem never breaks the chat pipeline.
    """
    if not stt_enabled():
        logger.info("[support_stt] skipped reason=no_api_key")
        return ""
    if not base64_audio:
        return ""
    try:
        audio = base64.b64decode(base64_audio)
    except Exception:
        logger.warning("[support_stt] skipped reason=bad_base64")
        return ""
    if not audio:
        logger.info("[support_stt] skipped reason=empty_audio")
        return ""
    if len(audio) > MAX_AUDIO_BYTES:
        logger.warning("[support_stt] skipped reason=too_large bytes=%d", len(audio))
        return ""
    try:
        async with httpx.AsyncClient(timeout=STT_TIMEOUT_SECONDS) as client:
            resp = await client.post(
                STT_URL,
                headers={"api-subscription-key": settings.SARVAM_API_KEY.strip()},
                data={
                    "model": settings.SARVAM_STT_MODEL,
                    "mode": "transcribe",
                    "language_code": settings.SARVAM_STT_LANGUAGE,
                },
                files={"file": ("recording.wav", audio, "audio/wav")},
            )
    except Exception as exc:
        logger.error("[support_stt] request failed: %s", exc, exc_info=True)
        return ""
    if resp.status_code != 200:
        logger.error(
            "[support_stt] Sarvam error status=%s body=%s",
            resp.status_code,
            resp.text[:300],
        )
        return ""
    try:
        payload = resp.json()
    except Exception:
        logger.error("[support_stt] non-JSON response")
        return ""
    transcript = str(payload.get("transcript") or "").strip()
    if not transcript:
        logger.info("[support_stt] empty transcript (silent clip?)")
        return ""
    logger.info(
        "[support_stt] transcript (%d chars): %s", len(transcript), transcript[:120]
    )
    return transcript