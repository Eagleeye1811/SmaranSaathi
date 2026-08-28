"""Thin Twilio SMS wrapper.

The service is safe to instantiate even without credentials — it logs a warning
and skips sending rather than raising. This lets the app boot cleanly in local
dev without any Twilio account.
"""

import logging

from app.core.config import get_settings

logger = logging.getLogger(__name__)


def normalize_phone_number(raw: str) -> str:
    cleaned = "".join(c for c in raw if c.isdigit() or c == "+")
    if not cleaned:
        return ""
    if not cleaned.startswith("+"):
        if len(cleaned) == 10:
            cleaned = "+91" + cleaned
        else:
            cleaned = "+" + cleaned
    return cleaned


class SmsService:
    """Sends reminder SMS messages via Twilio."""

    def __init__(self) -> None:
        self._settings = get_settings()
        self._client = None

        if not self._settings.twilio_configured:
            logger.warning(
                "[SMS] Twilio credentials not configured. "
                "Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_FROM_NUMBER "
                "in .env to enable outbound SMS."
            )

    def _get_client(self):
        if self._client is None:
            try:
                from twilio.rest import Client

                self._client = Client(
                    self._settings.twilio_account_sid,
                    self._settings.twilio_auth_token,
                )
            except ImportError as exc:
                raise RuntimeError(
                    "twilio package is not installed. "
                    "Run: pip install twilio>=9.0"
                ) from exc
        return self._client

    async def send_with_details(self, to: str, body: str) -> tuple[bool, str]:
        settings = get_settings()
        if not settings.twilio_configured:
            return False, "Twilio credentials not configured in backend/.env (TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER)"

        target = normalize_phone_number(to)
        if not target or not target.startswith("+"):
            return False, f"Invalid phone number format '{to}'"

        if "YOUR_TWILIO" in (settings.twilio_account_sid or ""):
            return False, "TWILIO_ACCOUNT_SID in backend/.env still contains placeholder text 'YOUR_TWILIO_ACCOUNT_SID_HERE'"
        if "YOUR_TWILIO" in (settings.twilio_auth_token or ""):
            return False, "TWILIO_AUTH_TOKEN in backend/.env still contains placeholder text 'YOUR_TWILIO_AUTH_TOKEN_HERE'"

        try:
            from twilio.rest import Client
            client = Client(settings.twilio_account_sid, settings.twilio_auth_token)
            import asyncio

            loop = asyncio.get_event_loop()
            
            # Attempt sending full rich body first
            try:
                message = await loop.run_in_executor(
                    None,
                    lambda: client.messages.create(
                        to=target,
                        from_=settings.twilio_from_number,
                        body=body,
                    ),
                )
                logger.info("[SMS] Sent sid=%s to=%s body=%r", message.sid, target, body)
                return True, f"Sent successfully (sid: {message.sid})"
            except Exception as first_exc:
                err_msg = str(first_exc)
                if "Invalid template name" in err_msg or "predefined SMS templates" in err_msg:
                    logger.warning("[SMS] Twilio Trial account detected. Sending single trial template message.")
                    message = await loop.run_in_executor(
                        None,
                        lambda: client.messages.create(
                            to=target,
                            from_=settings.twilio_from_number,
                            body="sms_appointment_reminders",
                        ),
                    )
                    logger.info("[SMS] Trial SMS sent sid=%s to=%s", message.sid, target)
                    return True, f"Sent via Twilio Trial Template (sid: {message.sid})"
                raise first_exc
        except Exception as exc:  # noqa: BLE001
            logger.error("[SMS] Failed to send to=%s: %s", to, exc)
            return False, str(exc)

    async def send(self, to: str, body: str) -> bool:
        success, _ = await self.send_with_details(to, body)
        return success


# Module-level singleton — shared by the scheduler and any API route that
# needs to send an ad-hoc SMS.
sms_service = SmsService()
