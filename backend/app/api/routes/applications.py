from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from uuid import UUID

from app.db.models import Application
from app.db.session import get_db
from app.schemas.application import ApplicationCreate, ApplicationResponse

router = APIRouter()


@router.post("", response_model=ApplicationResponse)
def create_application(payload: ApplicationCreate, db: Session = Depends(get_db)) -> Application:
    application = Application(
        user_id=payload.user_id,
        company=payload.company,
        role=payload.role,
        status=payload.status,
        source=payload.source,
        salary_band=payload.salary_band,
        interview_at=payload.interview_at,
    )
    db.add(application)
    db.commit()
    db.refresh(application)
    return application


@router.get("/{user_id}", response_model=list[ApplicationResponse])
def list_applications(user_id: UUID, db: Session = Depends(get_db)) -> list[Application]:
    return (
        db.query(Application)
        .filter(Application.user_id == user_id)
        .order_by(Application.applied_at.desc())
        .all()
    )
