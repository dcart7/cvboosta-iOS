from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.routes import auth as auth_routes
from app.db.models import (
    Application,
    PasswordResetToken,
    RefreshToken,
    Resume,
    ResumeScan,
    ScanFinding,
    Subscription,
    User,
    UserCredential,
)
from app.db.session import get_db


def build_client() -> TestClient:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    for table in (
        User.__table__,
        UserCredential.__table__,
        RefreshToken.__table__,
        PasswordResetToken.__table__,
        Resume.__table__,
        ResumeScan.__table__,
        ScanFinding.__table__,
        Application.__table__,
        Subscription.__table__,
    ):
        table.create(bind=engine, checkfirst=True)

    app = FastAPI()
    app.include_router(auth_routes.router, prefix="/auth")

    def override_get_db():
        db_session = SessionLocal()
        try:
            yield db_session
        finally:
            db_session.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app)


def test_register_login_refresh_logout_flow() -> None:
    client = build_client()

    register_payload = {
        "email": "auth.user@cvboosta.com",
        "password": "secure-pass-123",
        "display_name": "Auth User",
    }
    register_response = client.post("/auth/register", json=register_payload)
    assert register_response.status_code == 201
    register_body = register_response.json()
    assert register_body["token_type"] == "bearer"
    assert register_body["access_token"]
    assert register_body["refresh_token"]
    assert register_body["me"]["user"]["email"] == "auth.user@cvboosta.com"

    login_response = client.post(
        "/auth/login",
        json={"email": "auth.user@cvboosta.com", "password": "secure-pass-123"},
    )
    assert login_response.status_code == 200
    login_body = login_response.json()
    access_token = login_body["access_token"]
    refresh_token = login_body["refresh_token"]

    me_response = client.get("/auth/me", headers={"Authorization": f"Bearer {access_token}"})
    assert me_response.status_code == 200
    assert me_response.json()["user"]["email"] == "auth.user@cvboosta.com"

    refresh_response = client.post("/auth/refresh", json={"refresh_token": refresh_token})
    assert refresh_response.status_code == 200
    refreshed_body = refresh_response.json()
    assert refreshed_body["access_token"] != access_token
    assert refreshed_body["refresh_token"] != refresh_token

    logout_response = client.post(
        "/auth/logout",
        json={"refresh_token": refreshed_body["refresh_token"]},
        headers={"Authorization": f"Bearer {refreshed_body['access_token']}"},
    )
    assert logout_response.status_code == 200

    rejected_refresh = client.post("/auth/refresh", json={"refresh_token": refreshed_body["refresh_token"]})
    assert rejected_refresh.status_code == 401


def test_forgot_password_returns_generic_message() -> None:
    client = build_client()
    client.post(
        "/auth/register",
        json={
            "email": "forgot.user@cvboosta.com",
            "password": "secure-pass-123",
            "display_name": "Forgot User",
        },
    )

    response = client.post("/auth/forgot-password", json={"email": "forgot.user@cvboosta.com"})
    assert response.status_code == 200
    body = response.json()
    assert "message" in body
