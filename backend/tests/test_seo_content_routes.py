from __future__ import annotations

import unittest

from fastapi.testclient import TestClient

import backend.app.main as main_module
from backend.app.main import create_app


class SEOContentRoutesTestCase(unittest.TestCase):
    @classmethod
    def tearDownClass(cls) -> None:
        main_module.app.state.engine.dispose()

    def setUp(self) -> None:
        self.app = create_app("sqlite+pysqlite:///:memory:")
        self.client = TestClient(self.app)

    def tearDown(self) -> None:
        self.client.close()
        self.app.state.engine.dispose()

    def test_library_index_route_is_crawlable(self) -> None:
        response = self.client.get("/resume-keywords")
        self.assertEqual(response.status_code, 200)
        self.assertIn("Resume Keywords by Role", response.text)
        self.assertIn('href="/resume-keywords/software-engineer"', response.text)
        self.assertIn("/sitemap.xml", response.text)

    def test_detail_page_has_title_meta_canonical_and_internal_links(self) -> None:
        response = self.client.get("/ats/workday-resume-format")
        self.assertEqual(response.status_code, 200)
        self.assertIn("<title>Workday ATS Resume Format Checklist</title>", response.text)
        self.assertIn('meta name="description"', response.text)
        self.assertIn('rel="canonical" href="https://cvboosta.com/ats/workday-resume-format"', response.text)
        self.assertIn("Workday ATS Resume Format: What Actually Passes", response.text)
        self.assertIn('href="/tools/ats-format-validator"', response.text)

    def test_missing_seo_page_returns_404(self) -> None:
        response = self.client.get("/tools/does-not-exist")
        self.assertEqual(response.status_code, 404)


if __name__ == "__main__":
    unittest.main()
