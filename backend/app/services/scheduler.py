"""SMS Scheduler background task.

Starts on application boot, queries reminders due at the current minute across all
patients, and dispatches SMS alerts for any non-completed, SMS-enabled reminders.
"""

import asyncio
import logging
from datetime import datetime

from app.core.config import get_settings
from app.core.dependencies import get_reminder_repository
from app.services.sms_service import sms_service

logger = logging.getLogger(__name__)

# Track scheduled task reference to prevent clean up
_scheduler_task: asyncio.Task | None = None


async def check_and_send_reminders() -> None:
    """Core scheduler tick.

    Calculates the current hour and minute, queries due reminders, and sends SMS
    messages to patient phone numbers.
    """
    settings = get_settings()
    if not settings.twilio_configured:
        logger.debug("[Scheduler] Twilio is not configured; skipping SMS checks.")
        return

    now = datetime.now()
    hour = now.hour
    minute = now.minute

    logger.debug("[Scheduler] Checking reminders due at %02d:%02d", hour, minute)

    try:
        repo = get_reminder_repository()
        due_reminders = await repo.list_all_due_now(hour, minute)

        if not due_reminders:
            return

        logger.info(
            "[Scheduler] Found %d reminder(s) due at %02d:%02d",
            len(due_reminders),
            hour,
            minute,
        )

        for patient_id, phone, reminder in due_reminders:
            if not phone:
                logger.warning(
                    "[Scheduler] Patient %s has a due reminder %s but no phone number. SMS skipped.",
                    patient_id,
                    reminder.id,
                )
                continue

            # Format interactive, warm companion reminder from Mitra
            glyph = getattr(reminder.kind, "glyph", "⏰")
            kind_val = reminder.kind.value if hasattr(reminder.kind, "value") else str(reminder.kind)

            companion_msg = {
                "medicine": "Time to take your medication to stay healthy!",
                "hydration": "Time for a fresh glass of water!",
                "cognitive": "Mitra is ready for your daily activity!",
                "appointment": "You have a scheduled appointment.",
                "routine": "Time for your daily routine activity.",
                "social": "Time to connect with family or friends!",
            }.get(kind_val, "Here is your scheduled reminder.")

            detail_str = f"\nNote: {reminder.detail}" if reminder.detail else ""

            body = (
                f"Namaste! 🌸 Mitra from SmaranSaathi here.\n"
                f"{glyph} Reminder: {reminder.title}\n"
                f"⏰ Time: {reminder.time}\n"
                f"💬 {companion_msg}{detail_str}\n"
                f"Have a healthy & joyful day! ✨"
            )

            # Fire the SMS delivery task (non-blocking so one slow SMS doesn't block others)
            asyncio.create_task(sms_service.send(to=phone, body=body))

    except Exception as exc:  # noqa: BLE001
        logger.exception("[Scheduler] Error checking/sending reminders: %s", exc)


async def _scheduler_loop() -> None:
    """Repeatedly ticks every 10 seconds to check and dispatch due reminders instantly."""
    logger.info("[Scheduler] Starting background SMS scheduler loop.")
    while True:
        try:
            await check_and_send_reminders()
            await asyncio.sleep(10)
        except asyncio.CancelledError:
            logger.info("[Scheduler] Background scheduler loop cancelled.")
            break
        except Exception as exc:  # noqa: BLE001
            logger.exception("[Scheduler] Exception in scheduler loop: %s", exc)
            await asyncio.sleep(10)


def start_scheduler() -> None:
    """Start the background scheduler task."""
    global _scheduler_task
    if _scheduler_task is not None and not _scheduler_task.done():
        logger.warning("[Scheduler] Scheduler is already running.")
        return
    _scheduler_task = asyncio.create_task(_scheduler_loop())
    logger.info("[Scheduler] Background scheduler task started.")


def stop_scheduler() -> None:
    """Stop the background scheduler task cleanly."""
    global _scheduler_task
    if _scheduler_task is not None:
        _scheduler_task.cancel()
        logger.info("[Scheduler] Background scheduler task stopped.")
        _scheduler_task = None
