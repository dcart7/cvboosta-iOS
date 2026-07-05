from __future__ import annotations

from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import get_bearer_token, get_current_user, hash_password, issue_access_token, normalize_email, verify_password
from ..database import get_db
from ..models import AccessToken, TrackerApplication, TrackerFolder, User
from ..schemas import (
    AuthAppleLoginRequest,
    AuthForgotPasswordRequest,
    AuthLoginRequest,
    AuthMeResponse,
    AuthRegisterRequest,
    AuthTokenResponse,
    TrackerApplicationResponse,
    TrackerFolderResponse,
    UserResponse,
)


router = APIRouter(prefix="/auth", tags=["auth"])


def build_me_payload(db: Session, user: User) -> AuthMeResponse:
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

    return AuthMeResponse(
        user=UserResponse.model_validate(user),
        applications=[TrackerApplicationResponse.model_validate(item) for item in applications],
        tracker_folders=[TrackerFolderResponse.model_validate(item) for item in folders],
        saved_resumes=[],
    )


@router.post("/register", response_model=AuthTokenResponse)
def register(payload: AuthRegisterRequest, db: Session = Depends(get_db)) -> AuthTokenResponse:
    email = normalize_email(payload.email)
    existing = db.scalar(select(User).where(User.email == email))
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="An account with that email already exists.")

    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        full_name=payload.full_name.strip() if payload.full_name else None,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    token = issue_access_token(db, user)
    return AuthTokenResponse(access_token=token, email=user.email)


@router.post("/login", response_model=AuthTokenResponse)
def login(payload: AuthLoginRequest, db: Session = Depends(get_db)) -> AuthTokenResponse:
    email = normalize_email(payload.email)
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password.")

    token = issue_access_token(db, user)
    return AuthTokenResponse(access_token=token, email=user.email)


@router.post("/oauth/apple", response_model=AuthTokenResponse)
def apple_login(payload: AuthAppleLoginRequest, db: Session = Depends(get_db)) -> AuthTokenResponse:
    email = normalize_email(payload.email) if payload.email else f"apple-{uuid4().hex[:12]}@cvboosta.local"
    user = db.scalar(select(User).where(User.email == email))
    if user is None:
        user = User(
            email=email,
            password_hash=None,
            full_name=payload.full_name.strip() if payload.full_name else None,
            apple_subject=payload.id_token or payload.access_token,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    token = issue_access_token(db, user)
    return AuthTokenResponse(access_token=token, email=user.email)


@router.get("/me", response_model=AuthMeResponse)
def me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> AuthMeResponse:
    return build_me_payload(db, current_user)


@router.post("/logout")
def logout(
    token: str = Depends(get_bearer_token),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    del current_user
    access_token = db.get(AccessToken, token)
    if access_token is not None:
        db.delete(access_token)
        db.commit()
    return {"status": "ok"}


@router.post("/forgot-password")
def forgot_password(payload: AuthForgotPasswordRequest) -> dict[str, str]:
    del payload
    return {"status": "ok"}
