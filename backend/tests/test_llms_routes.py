from __future__ import annotations

import unittest

from fastapi.testclient import TestClient

import backend.app.main as main_module
from backend.app.main import create_app


class LLMSRoutesTestCase(unittest.TestCase):
    @classmethod
    def tearDownClass(cls) -> None:
        main_module.app.state.engine.dispose()

    def setUp(self) -> None:
        self.app = create_app("sqlite+pysqlite:///:memory:")
        self.client = TestClient(self.app)

    def tearDown(self) -> None:
        self.client.close()
        self.app.state.engine.dispose()

    def test_llms_txt_is_served_with_h1_and_links(self) -> None:
        response = self.client.get("/llms.txt")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.text.startswith("# CVBoosta"))
        self.assertIn("> CVBoosta", response.text)
        self.assertIn("](https://cvboosta.com/", response.text)

    def test_llms_full_txt_is_served(self) -> None:
        response = self.client.get("/llms-full.txt")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.text.startswith("# CVBoosta"))
        self.assertIn("## Brand and Product", response.text)

    def test_robots_txt_declares_sitemap(self) -> None:
        response = self.client.get("/robots.txt")
        self.assertEqual(response.status_code, 200)
        self.assertIn("User-agent: *", response.text)
        self.assertIn("Allow: /", response.text)
        self.assertIn("Sitemap: https://cvboosta.com/sitemap.xml", response.text)

    def test_sitemap_xml_lists_public_seo_urls(self) -> None:
        response = self.client.get("/sitemap.xml")
        self.assertEqual(response.status_code, 200)
        self.assertIn("<urlset", response.text)
        self.assertIn("<loc>https://cvboosta.com/ats</loc>", response.text)
        self.assertIn("<loc>https://cvboosta.com/ats/workday-resume-format</loc>", response.text)
        self.assertIn("<loc>https://cvboosta.com/resume-keywords/software-engineer</loc>", response.text)


if __name__ == "__main__":
    unittest.main()
