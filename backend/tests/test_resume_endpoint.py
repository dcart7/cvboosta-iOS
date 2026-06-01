import uuid

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user
from app.api.routes import resume as resume_routes
from app.db.models import Resume, ResumeScan, ScanFinding, Subscription, User
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
    ):
        table.create(bind=engine, checkfirst=True)

    seeded_user_id = uuid.uuid4()
    db = SessionLocal()
    db.add(
        User(
            id=seeded_user_id,
            apple_sub=f"email:{seeded_user_id.hex}",
            email="test@cvboosta.com",
            display_name="Test User",
        )
    )
    db.commit()
    db.close()

    app = FastAPI()
    app.include_router(resume_routes.router, prefix="/v1/resume")

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


def test_scan_resume_returns_analysis_fields() -> None:
    client = build_client()

    payload = {
        "resume_text": (
            "- Built API platform used by 200+ partners and improved onboarding speed by 42%.\n"
            "- Led migration to CI/CD pipelines across 5 services with automated testing.\n"
            "- Reduced incident recovery time by 38% through structured alerting and runbooks.\n"
            "- Designed observability dashboards and improved reliability to 99.95%."
        ),
        "target_role": "Backend Developer",
    }

    response = client.post("/v1/resume/scan", json=payload)

    assert response.status_code == 200
    body = response.json()

    assert isinstance(body["ats_score"], int)
    assert "keyword_gaps" in body
    assert "priority_fixes" in body
    assert "weak_bullet_examples" in body
    assert isinstance(body["findings"], list)


def test_scan_resume_file_rejects_non_pdf() -> None:
    client = build_client()

    response = client.post(
        "/v1/resume/scan-file",
        data={"target_role": "Backend Developer"},
        files={"file": ("resume.txt", b"plain-text", "text/plain")},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Only PDF uploads are supported."


def test_rewrite_endpoint_returns_bullets() -> None:
    client = build_client()
    payload = {
        "target_role": "Backend Developer",
        "bullets": ["Built APIs for internal tools", "Worked with platform team"],
    }

    response = client.post("/v1/resume/rewrite", json=payload)

    assert response.status_code == 200
    body = response.json()
    assert "rewritten_bullets" in body
    assert isinstance(body["rewritten_bullets"], list)
    assert len(body["rewritten_bullets"]) == 2
