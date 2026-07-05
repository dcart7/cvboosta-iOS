from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import get_current_user
from ..database import get_db
from ..models import TrackerApplication, TrackerFolder, User
from ..schemas import (
    TrackerApplicationCreateRequest,
    TrackerApplicationResponse,
    TrackerApplicationUpdateRequest,
    TrackerFolderCreateRequest,
    TrackerFolderResponse,
    TrackerFolderUpdateRequest,
    TrackerSnapshotResponse,
)


router = APIRouter(prefix="/tracker", tags=["tracker"])


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def folder_for_user(db: Session, user_id: int, folder_id: str | None) -> TrackerFolder | None:
    if folder_id is None:
        return None
    folder = db.scalar(
        select(TrackerFolder).where(
            TrackerFolder.id == folder_id,
            TrackerFolder.user_id == user_id,
        )
    )
    if folder is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found.")
    return folder


def application_for_user(db: Session, user_id: int, application_id: str) -> TrackerApplication:
    application = db.scalar(
        select(TrackerApplication).where(
            TrackerApplication.id == application_id,
            TrackerApplication.user_id == user_id,
        )
    )
    if application is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Application not found.")
    return application


def build_tracker_snapshot(db: Session, user: User) -> TrackerSnapshotResponse:
    applications = db.scalars(
        select(TrackerApplication)
        .where(TrackerApplication.user_id == user.id)
        .order_by(TrackerApplication.applied_at.desc(), TrackerApplication.created_at.desc())
    ).all()
    folders = db.scalars(
        select(TrackerFolder)
        .where(TrackerFolder.user_id == user.id)
        .order_by(TrackerFolder.created_at.asc())
    ).all()

    return TrackerSnapshotResponse(
        applications=[TrackerApplicationResponse.model_validate(item) for item in applications],
        folders=[TrackerFolderResponse.model_validate(item) for item in folders],
    )


@router.get("", response_model=TrackerSnapshotResponse)
def tracker_snapshot(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> TrackerSnapshotResponse:
    return build_tracker_snapshot(db, current_user)


@router.post("/folders", response_model=TrackerFolderResponse, status_code=status.HTTP_201_CREATED)
def create_folder(
    payload: TrackerFolderCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TrackerFolderResponse:
    folder = TrackerFolder(
        id=str(payload.id or uuid4()),
        user_id=current_user.id,
        name=payload.name.strip(),
        emoji=payload.emoji.strip() or "🗂",
    )
    db.add(folder)

    for application_id in payload.application_ids:
        application = application_for_user(db, current_user.id, str(application_id))
        application.folder_id = folder.id
        application.updated_at = utc_now()

    db.commit()
    db.refresh(folder)
    return TrackerFolderResponse.model_validate(folder)


@router.patch("/folders/{folder_id}", response_model=TrackerFolderResponse)
def update_folder(
    folder_id: str,
    payload: TrackerFolderUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TrackerFolderResponse:
    folder = folder_for_user(db, current_user.id, folder_id)
    assert folder is not None

    if payload.name is not None:
        folder.name = payload.name.strip()
    if payload.emoji is not None:
        folder.emoji = payload.emoji.strip() or folder.emoji
    folder.updated_at = utc_now()

    db.commit()
    db.refresh(folder)
    return TrackerFolderResponse.model_validate(folder)


@router.delete("/folders/{folder_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_folder(
    folder_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    folder = folder_for_user(db, current_user.id, folder_id)
    assert folder is not None

    applications = db.scalars(
        select(TrackerApplication).where(
            TrackerApplication.user_id == current_user.id,
            TrackerApplication.folder_id == folder.id,
        )
    ).all()
    for application in applications:
        application.folder_id = None
        application.updated_at = utc_now()

    db.delete(folder)
    db.commit()


@router.post("/applications", response_model=TrackerApplicationResponse, status_code=status.HTTP_201_CREATED)
def create_application(
    payload: TrackerApplicationCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TrackerApplicationResponse:
    folder_id = str(payload.folder_id) if payload.folder_id else None
    folder_for_user(db, current_user.id, folder_id)

    application = TrackerApplication(
        id=str(payload.id or uuid4()),
        user_id=current_user.id,
        company=payload.company.strip(),
        role=payload.role.strip(),
        status=payload.status.strip().lower(),
        source=payload.source,
        applied_at=payload.applied_at,
        interview_at=payload.interview_at,
        notes=payload.notes,
        resume_used=payload.resume_used,
        job_link=payload.job_link,
        folder_id=folder_id,
        ats_score=payload.ats_score,
        interview_reflection_rating=payload.interview_reflection_rating,
        interview_reflection_outcome=payload.interview_reflection_outcome,
        interview_reflection_notes=payload.interview_reflection_notes,
        interview_reflection_submitted_at=payload.interview_reflection_submitted_at,
    )
    db.add(application)
    db.commit()
    db.refresh(application)
    return TrackerApplicationResponse.model_validate(application)


@router.patch("/applications/{application_id}", response_model=TrackerApplicationResponse)
def update_application(
    application_id: str,
    payload: TrackerApplicationUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TrackerApplicationResponse:
    application = application_for_user(db, current_user.id, application_id)
    updates = payload.model_dump(exclude_unset=True)

    if "folder_id" in updates:
        folder_value = updates["folder_id"]
        folder_id = str(folder_value) if folder_value else None
        folder_for_user(db, current_user.id, folder_id)
        application.folder_id = folder_id

    if "company" in updates and updates["company"] is not None:
        application.company = updates["company"].strip()
    if "role" in updates and updates["role"] is not None:
        application.role = updates["role"].strip()
    if "status" in updates and updates["status"] is not None:
        application.status = updates["status"].strip().lower()
    if "source" in updates:
        application.source = updates["source"]
    if "applied_at" in updates:
        application.applied_at = updates["applied_at"]
    if "interview_at" in updates:
        application.interview_at = updates["interview_at"]
    if "notes" in updates:
        application.notes = updates["notes"]
    if "resume_used" in updates:
        application.resume_used = updates["resume_used"]
    if "job_link" in updates:
        application.job_link = updates["job_link"]
    if "ats_score" in updates:
        application.ats_score = updates["ats_score"]
    if "interview_reflection_rating" in updates:
        application.interview_reflection_rating = updates["interview_reflection_rating"]
    if "interview_reflection_outcome" in updates:
        application.interview_reflection_outcome = updates["interview_reflection_outcome"]
    if "interview_reflection_notes" in updates:
        application.interview_reflection_notes = updates["interview_reflection_notes"]
    if "interview_reflection_submitted_at" in updates:
        application.interview_reflection_submitted_at = updates["interview_reflection_submitted_at"]

    application.updated_at = utc_now()
    db.commit()
    db.refresh(application)
    return TrackerApplicationResponse.model_validate(application)


@router.delete("/applications/{application_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_application(
    application_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    application = application_for_user(db, current_user.id, application_id)
    db.delete(application)
    db.commit()
