from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes import resume as resume_routes


def build_client() -> TestClient:
    app = FastAPI()
    app.include_router(resume_routes.router, prefix="/v1/resume")
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
