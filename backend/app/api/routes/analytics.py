from datetime import datetime, timedelta
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.models import Application
from app.db.session import get_db

router = APIRouter()


@router.get("/summary/{user_id}")
def summary(user_id: UUID, db: Session = Depends(get_db)) -> dict:
    week_ago = datetime.utcnow() - timedelta(days=7)

    total = db.query(Application).filter(Application.user_id == user_id).count()
    weekly = (
        db.query(Application)
        .filter(Application.user_id == user_id, Application.applied_at >= week_ago)
        .count()
    )
    interviews = (
        db.query(Application)
        .filter(Application.user_id == user_id, Application.status == "interview")
        .count()
    )
    offers = (
        db.query(Application)
        .filter(Application.user_id == user_id, Application.status == "offer")
        .count()
    )

    interview_rate = round(interviews / total, 3) if total else 0.0
    conversion_rate = round(offers / total, 3) if total else 0.0

    return {
        "applications_total": total,
        "applications_last_7d": weekly,
        "interview_rate": interview_rate,
        "conversion_rate": conversion_rate,
    }
