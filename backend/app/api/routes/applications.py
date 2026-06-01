from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.models import Application, User
from app.db.session import get_db
from app.schemas.application import ApplicationCreate, ApplicationResponse, ApplicationUpdate

router = APIRouter()


@router.post("", response_model=ApplicationResponse)
def create_application(
    payload: ApplicationCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Application:
    application = Application(
        user_id=user.id,
        company=payload.company,
        role=payload.role,
        status=payload.status,
        source=payload.source,
        salary_band=payload.salary_band,
        applied_at=payload.applied_at or datetime.utcnow(),
        interview_at=payload.interview_at,
    )
    db.add(application)
    db.commit()
    db.refresh(application)
    return application


@router.get("/me", response_model=list[ApplicationResponse])
def list_my_applications(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Application]:
    return (
        db.query(Application)
        .filter(Application.user_id == user.id)
        .order_by(Application.applied_at.desc())
        .all()
    )


@router.get("", response_model=list[ApplicationResponse])
def list_my_applications_alias(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Application]:
    return (
        db.query(Application)
        .filter(Application.user_id == user.id)
        .order_by(Application.applied_at.desc())
        .all()
    )


@router.get("/{user_id}", response_model=list[ApplicationResponse])
def list_applications(
    user_id: UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Application]:
    if user_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden.")
    return (
        db.query(Application)
        .filter(Application.user_id == user_id)
        .order_by(Application.applied_at.desc())
        .all()
    )


@router.patch("/{application_id}", response_model=ApplicationResponse)
def update_application(
    application_id: UUID,
    payload: ApplicationUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Application:
    application = (
        db.query(Application)
        .filter(Application.id == application_id, Application.user_id == user.id)
        .first()
    )
    if application is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Application not found.")

    updates = payload.model_dump(exclude_unset=True, exclude_none=True)
    for key, value in updates.items():
        if hasattr(application, key):
            setattr(application, key, value)

    db.commit()
    db.refresh(application)
    return application


@router.delete("/{application_id}")
def delete_application(
    application_id: UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    application = (
        db.query(Application)
        .filter(Application.id == application_id, Application.user_id == user.id)
        .first()
    )
    if application is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Application not found.")

    db.delete(application)
    db.commit()
    return {"message": "Application deleted."}
