import uuid

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user
from app.api.routes import applications as applications_routes
from app.api.routes import mobile as mobile_routes
from app.db.models import (
    Application,
    Resume,
    ResumeScan,
    ScanFinding,
    Subscription,
    User,
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
        Subscription.__table__,
        Resume.__table__,
        ResumeScan.__table__,
        ScanFinding.__table__,
        Application.__table__,
    ):
        table.create(bind=engine, checkfirst=True)

    seeded_user_id = uuid.uuid4()
    db = SessionLocal()
    db.add(
        User(
            id=seeded_user_id,
            apple_sub=f"email:{seeded_user_id.hex}",
            email="mobile@cvboosta.com",
            display_name="Mobile User",
        )
    )
    db.commit()
    db.close()

    app = FastAPI()
    app.include_router(mobile_routes.router)
    app.include_router(applications_routes.router, prefix="/applications")

    def override_get_db():
        db_session = SessionLocal()
        try:
            yield db_session
        finally:
            db_session.close()

    def override_get_current_user() -> User:
        db_session = SessionLocal()
        try:
            user = db_session.query(User).filter(User.id == seeded_user_id).first()
            assert user is not None
            return user
        finally:
            db_session.close()

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    return TestClient(app)


def test_tailoring_generate_returns_expected_payload() -> None:
    client = build_client()

    response = client.post(
        "/tailoring/generate",
        json={
            "resume_text": "Built backend APIs and improved reliability by 35%.",
            "job_title": "Backend Developer",
            "job_description": "Build scalable APIs, improve observability, and partner with product.",
            "tone": "Technical",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert "tailored_summary" in body
    assert isinstance(body["bullet_rewrites"], list)
    assert isinstance(body["missing_keywords"], list)


def test_subscription_status_and_application_crud() -> None:
    client = build_client()

    status_response = client.get("/subscription/status")
    assert status_response.status_code == 200
    assert status_response.json()["plan"] in {"free", "premium"}

    create_response = client.post(
        "/applications",
        json={
            "company": "Stripe",
            "role": "Backend Engineer",
            "status": "applied",
            "source": "iOS",
        },
    )
    assert create_response.status_code == 200
    app_id = create_response.json()["id"]

    list_response = client.get("/applications")
    assert list_response.status_code == 200
    assert len(list_response.json()) == 1

    patch_response = client.patch(
        f"/applications/{app_id}",
        json={"status": "interview"},
    )
    assert patch_response.status_code == 200
    assert patch_response.json()["status"] == "interview"

    delete_response = client.delete(f"/applications/{app_id}")
    assert delete_response.status_code == 200

    after_delete = client.get("/applications")
    assert after_delete.status_code == 200
    assert after_delete.json() == []
