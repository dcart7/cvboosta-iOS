from __future__ import annotations

import unittest

from fastapi.testclient import TestClient

from backend.app.main import create_app


class LLMSRoutesTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(create_app("sqlite+pysqlite:///:memory:"))

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


if __name__ == "__main__":
    unittest.main()
