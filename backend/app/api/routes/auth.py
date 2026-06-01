from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.security import (
    SecurityError,
    create_access_token,
    create_password_reset_token,
    create_refresh_token,
    decode_token,
    hash_password,
    hash_token,
    normalize_email,
    verify_password,
)
from app.db.models import PasswordResetToken, RefreshToken, User, UserCredential
from app.db.session import get_db
from app.schemas.auth import (
    AuthMeResponse,
    AuthTokenEnvelope,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
)
from app.services.user_state import build_auth_me_response

router = APIRouter()


@router.post("/register", response_model=AuthTokenEnvelope, status_code=status.HTTP_201_CREATED)
def register(
    payload: RegisterRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> AuthTokenEnvelope:
    email = _validated_email(payload.email)

    user = db.query(User).filter(func.lower(User.email) == email).first()
    credentials = user.credentials if user else None
    if credentials is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User already exists.")

    if user is None:
        user = User(
            apple_sub=f"email:{uuid4().hex}",
            email=email,
            display_name=payload.display_name,
        )
        db.add(user)
        db.flush()
    else:
        user.email = email
        if payload.display_name:
            user.display_name = payload.display_name

    credentials = UserCredential(user_id=user.id, password_hash=hash_password(payload.password))
    db.add(credentials)
    db.commit()
    db.refresh(user)

    return _issue_tokens_for_user(db=db, user=user, request=request)


@router.post("/login", response_model=AuthTokenEnvelope)
def login(
    payload: LoginRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> AuthTokenEnvelope:
    email = _validated_email(payload.email)

    user = db.query(User).filter(func.lower(User.email) == email).first()
    credentials = user.credentials if user else None

    if user is None or credentials is None or not verify_password(payload.password, credentials.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    return _issue_tokens_for_user(db=db, user=user, request=request)


@router.post("/logout")
def logout(
    payload: LogoutRequest | None = None,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    now = datetime.now(UTC)

    refresh_token = payload.refresh_token if payload else None

    if refresh_token:
        try:
            decoded = decode_token(refresh_token, expected_type="refresh")
            refresh_user_id = UUID(decoded["sub"])
            refresh_jti = decoded["jti"]
        except (SecurityError, ValueError, KeyError):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token.")

        if refresh_user_id != user.id:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token does not match user.")

        token_hash = hash_token(refresh_token)
        record = (
            db.query(RefreshToken)
            .filter(
                RefreshToken.user_id == user.id,
                RefreshToken.jti == refresh_jti,
                RefreshToken.token_hash == token_hash,
                RefreshToken.revoked_at.is_(None),
            )
            .first()
        )
        if record:
            record.revoked_at = now
    else:
        (
            db.query(RefreshToken)
            .filter(RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None))
            .update({RefreshToken.revoked_at: now}, synchronize_session=False)
        )

    db.commit()
    return {"message": "Logged out."}


@router.get("/me", response_model=AuthMeResponse)
def me(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AuthMeResponse:
    return build_auth_me_response(db, user)


@router.post("/refresh", response_model=AuthTokenEnvelope)
def refresh(
    payload: RefreshRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> AuthTokenEnvelope:
    try:
        decoded = decode_token(payload.refresh_token, expected_type="refresh")
        user_id = UUID(decoded["sub"])
        jti = decoded["jti"]
    except (SecurityError, ValueError, KeyError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token.")

    token_hash_value = hash_token(payload.refresh_token)
    now = datetime.now(UTC)
    record = (
        db.query(RefreshToken)
        .filter(
            RefreshToken.user_id == user_id,
            RefreshToken.jti == jti,
            RefreshToken.token_hash == token_hash_value,
            RefreshToken.revoked_at.is_(None),
            RefreshToken.expires_at > now,
        )
        .first()
    )
    if record is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token expired or revoked.")

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found.")

    record.revoked_at = now
    db.flush()

    response = _issue_tokens_for_user(db=db, user=user, request=request, commit=False)
    db.commit()
    return response


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
def forgot_password(
    payload: ForgotPasswordRequest,
    db: Session = Depends(get_db),
) -> ForgotPasswordResponse:
    email = _validated_email(payload.email)
    user = db.query(User).filter(func.lower(User.email) == email).first()
    credentials = user.credentials if user else None

    reset_token_preview: str | None = None
    if user is not None and credentials is not None:
        reset_token = create_password_reset_token()
        token_record = PasswordResetToken(
            user_id=user.id,
            token_hash=hash_token(reset_token),
            expires_at=datetime.now(UTC) + timedelta(minutes=settings.password_reset_token_expire_minutes),
        )
        db.add(token_record)
        db.commit()

        if settings.app_env != "prod":
            reset_token_preview = reset_token

    return ForgotPasswordResponse(
        message="If your account exists, password reset instructions have been generated.",
        reset_token_preview=reset_token_preview,
    )


def _issue_tokens_for_user(
    db: Session,
    user: User,
    request: Request,
    commit: bool = True,
) -> AuthTokenEnvelope:
    access = create_access_token(user.id)
    refresh = create_refresh_token(user.id)

    refresh_row = RefreshToken(
        user_id=user.id,
        jti=refresh.jti,
        token_hash=hash_token(refresh.token),
        expires_at=refresh.expires_at,
        user_agent=request.headers.get("User-Agent"),
        ip_address=request.client.host if request.client else None,
    )
    db.add(refresh_row)
    db.flush()
    if commit:
        db.commit()

    me_payload = build_auth_me_response(db, user)
    return AuthTokenEnvelope(
        access_token=access.token,
        refresh_token=refresh.token,
        token_type="bearer",
        expires_in=int((access.expires_at - datetime.now(UTC)).total_seconds()),
        me=me_payload,
    )


def _validated_email(value: str) -> str:
    email = normalize_email(value)
    if "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid email format.")
    return email
