"""Turns a patient's real, already-synced game sessions into the
`ClinicPatient` row a doctor's caseload shows — genuinely computed, not
fabricated. Replaces the old `/doctors/caseload` endpoint, which read a
Firestore `"caseload"` collection nothing ever wrote to.

Ports the *shape* of the frontend's own scoring — `CognitiveMonitoringService.
domainScores` (mean of the most recent few sessions per domain) and
`GamePerformance.overall` (`accuracy*0.5 + focus*0.25 + memory*0.25`,
`frontend/lib/core/models/game.dart`) — into Python. Not required to be
byte-identical to the client's numbers; required to be real: derived from the
same `GameSession` rows the app itself already stores via the ordinary
`gameSession` sync path (`sync_service.py`), not invented.
"""
from __future__ import annotations

from datetime import datetime, timedelta
from typing import Dict, List, Optional

from app.models.clinical import ClinicPatient, ClinicalStatus, CognitiveProfile, TrendDirection
from app.models.game import CognitiveDomain, GameId, GamePerformance, GameSession
from app.models.patient import Patient

# Which domain each activity reports into — mirrors `GameDomains.of` in
# `frontend/lib/core/models/game.dart`. `None` means the activity (Mood
# Canvas) is not a cognitive-skill test and contributes to nothing here.
_GAME_DOMAINS: Dict[GameId, Optional[CognitiveDomain]] = {
    GameId.procedure: CognitiveDomain.procedural,
    GameId.story: CognitiveDomain.reasoning,
    GameId.familiar_place: CognitiveDomain.spatial,
    GameId.melody: CognitiveDomain.auditory,
    GameId.weaves: CognitiveDomain.attention,
    GameId.memory_cards: CognitiveDomain.memory,
    GameId.village_market: CognitiveDomain.procedural,
    GameId.mood_canvas: None,
}

# How many of the most recent sessions per domain feed its current score —
# matches `CognitiveMonitoringService.windowPerDomain` on the client.
_WINDOW_PER_DOMAIN = 4


def _overall(performance: GamePerformance) -> float:
    """The same headline figure the person sees on their own result screen —
    `GamePerformance.overall` in `frontend/lib/core/models/game.dart`."""
    raw = performance.accuracy * 0.5 + performance.focus * 0.25 + performance.memory * 0.25
    return max(0.0, min(100.0, raw))


def _empty_clinic_patient(patient: Patient) -> ClinicPatient:
    return ClinicPatient(
        id=patient.id,
        name=patient.name,
        age=patient.age,
        district=patient.location,
        score=0,
        trend=TrendDirection.flat,
        status=ClinicalStatus.follow_up,
        scene_id=patient.portrait_scene,
        language=patient.language,
        last_session="No activities yet",
        profile=CognitiveProfile(scores={}, overall=0, updated="No activities yet"),
        thirty_day=[],
        adherence=0,
        engagement=0,
    )


async def build_clinic_patient(patient: Patient, sessions: List[GameSession]) -> ClinicPatient:
    scored = [s for s in sessions if _GAME_DOMAINS.get(s.game_id) is not None]
    if not scored:
        return _empty_clinic_patient(patient)

    scored.sort(key=lambda s: s.played_at)
    now = datetime.utcnow()

    # Per-domain mean over the most recent sessions in that domain.
    buckets: Dict[CognitiveDomain, List[GameSession]] = {}
    for s in scored:
        domain = _GAME_DOMAINS[s.game_id]
        assert domain is not None  # filtered above
        buckets.setdefault(domain, []).append(s)

    domain_scores: Dict[CognitiveDomain, int] = {}
    for domain, domain_sessions in buckets.items():
        recent = sorted(domain_sessions, key=lambda s: s.played_at, reverse=True)[:_WINDOW_PER_DOMAIN]
        domain_scores[domain] = round(sum(_overall(s.performance) for s in recent) / len(recent))

    overall = round(sum(domain_scores.values()) / len(domain_scores)) if domain_scores else 0

    # Trend: mean score this week vs. the week before — a clinically legible
    # comparison, not a single noisy session-to-session delta.
    def _period_mean(start: datetime, end: datetime) -> Optional[float]:
        in_period = [_overall(s.performance) for s in scored if start <= s.played_at < end]
        return sum(in_period) / len(in_period) if in_period else None

    recent_mean = _period_mean(now - timedelta(days=7), now + timedelta(days=1))
    prior_mean = _period_mean(now - timedelta(days=14), now - timedelta(days=7))
    if recent_mean is None or prior_mean is None:
        trend = TrendDirection.flat
    elif recent_mean - prior_mean > 3:
        trend = TrendDirection.up
    elif prior_mean - recent_mean > 3:
        trend = TrendDirection.down
    else:
        trend = TrendDirection.flat

    # Adherence: distinct days played in the last 14, as a percentage.
    fourteen_days_ago = now - timedelta(days=14)
    distinct_days = {s.played_at.date() for s in scored if s.played_at >= fourteen_days_ago}
    adherence = max(0, min(100, round((len(distinct_days) / 14) * 100)))

    # Engagement: how close to "played every day this week" they are.
    seven_days_ago = now - timedelta(days=7)
    recent_sessions = [s for s in scored if s.played_at >= seven_days_ago]
    engagement = max(0, min(100, round((len(recent_sessions) / 7) * 100)))

    # 30-day series: mean daily score, 0 on days with nothing played — same
    # shape as the frontend's own trend charts.
    thirty_day: List[float] = []
    for offset in range(29, -1, -1):
        day = (now - timedelta(days=offset)).date()
        day_scores = [_overall(s.performance) for s in scored if s.played_at.date() == day]
        thirty_day.append(round(sum(day_scores) / len(day_scores), 1) if day_scores else 0.0)

    if overall < 50 or trend is TrendDirection.down:
        status = ClinicalStatus.needs_attention
    elif adherence < 40:
        status = ClinicalStatus.follow_up
    else:
        status = ClinicalStatus.stable

    last_session = scored[-1].played_at.strftime("%d %b %Y")

    return ClinicPatient(
        id=patient.id,
        name=patient.name,
        age=patient.age,
        district=patient.location,
        score=overall,
        trend=trend,
        status=status,
        scene_id=patient.portrait_scene,
        language=patient.language,
        last_session=last_session,
        profile=CognitiveProfile(
            scores=domain_scores,
            overall=overall,
            updated=f"From {len(scored)} {'activity' if len(scored) == 1 else 'activities'}",
        ),
        thirty_day=thirty_day,
        adherence=adherence,
        engagement=engagement,
    )
