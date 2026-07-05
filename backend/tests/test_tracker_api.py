from __future__ import annotations

import unittest
from datetime import datetime, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from backend.app.main import create_app


class TrackerAPITestCase(unittest.TestCase):
    def setUp(self) -> None:
        app = create_app("sqlite+pysqlite:///:memory:")
        self.client = TestClient(app)

        response = self.client.post(
            "/auth/register",
            json={
                "email": "denys@example.com",
                "password": "secret-123",
                "full_name": "Denys",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.token = response.json()["access_token"]
        self.headers = {"Authorization": f"Bearer {self.token}"}

    def test_tracker_application_and_folder_sync_contract(self) -> None:
        folder_id = str(uuid4())
        application_id = str(uuid4())

        folder_response = self.client.post(
            "/tracker/folders",
            json={"id": folder_id, "name": "Backend", "emoji": "🛠"},
            headers=self.headers,
        )
        self.assertEqual(folder_response.status_code, 201)
        self.assertEqual(folder_response.json()["name"], "Backend")

        application_response = self.client.post(
            "/tracker/applications",
            json={
                "id": application_id,
                "company": "CVBoosta",
                "role": "Backend Engineer",
                "status": "applied",
                "source": "iOS",
                "applied_at": datetime.now(timezone.utc).isoformat(),
                "folder_id": folder_id,
                "notes": "Shipped tracker sync.",
                "resume_used": "Backend Resume",
                "job_link": "https://example.com/jobs/1",
            },
            headers=self.headers,
        )
        self.assertEqual(application_response.status_code, 201)
        self.assertEqual(application_response.json()["folder_id"], folder_id)

        patch_response = self.client.patch(
            f"/tracker/applications/{application_id}",
            json={
                "status": "interview",
                "interview_reflection_rating": 5,
                "interview_reflection_outcome": "moved_forward",
            },
            headers=self.headers,
        )
        self.assertEqual(patch_response.status_code, 200)
        self.assertEqual(patch_response.json()["status"], "interview")

        me_response = self.client.get("/auth/me", headers=self.headers)
        self.assertEqual(me_response.status_code, 200)
        payload = me_response.json()
        self.assertEqual(len(payload["applications"]), 1)
        self.assertEqual(len(payload["tracker_folders"]), 1)
        self.assertEqual(payload["applications"][0]["role"], "Backend Engineer")

        delete_response = self.client.delete(f"/tracker/applications/{application_id}", headers=self.headers)
        self.assertEqual(delete_response.status_code, 204)

        final_me_response = self.client.get("/auth/me", headers=self.headers)
        self.assertEqual(final_me_response.status_code, 200)
        self.assertEqual(final_me_response.json()["applications"], [])


if __name__ == "__main__":
    unittest.main()
