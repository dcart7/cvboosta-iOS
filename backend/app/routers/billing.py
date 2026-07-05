from __future__ import annotations

from fastapi import APIRouter, Depends

from ..auth import get_current_user
from ..models import User
from ..schemas import BillingStatusResponse


router = APIRouter(prefix="/billing", tags=["billing"])


@router.get("/status", response_model=BillingStatusResponse)
def billing_status(current_user: User = Depends(get_current_user)) -> BillingStatusResponse:
    del current_user
    return BillingStatusResponse(
        plan="free",
        entitlement="free",
        is_active=False,
        source="local-dev",
        scans_daily_limit=5,
        scans_used_today=0,
        scans_remaining_today=5,
        cover_letter_daily_limit=2,
        cover_letter_used_today=0,
        cover_letter_remaining_today=2,
        interview_prep_daily_limit=2,
        interview_prep_used_today=0,
        interview_prep_remaining_today=2,
    )
