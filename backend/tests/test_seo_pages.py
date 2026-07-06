from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SEO_ROOT = ROOT / "seo_pages"
CONTENT_ROOT = SEO_ROOT / "content"
MANIFEST_PATH = SEO_ROOT / "manifest.json"


class SEOPageContentTestCase(unittest.TestCase):
    def test_generated_pack_exists_and_has_500_pages(self) -> None:
        self.assertTrue(MANIFEST_PATH.exists(), "manifest.json was not generated")
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        self.assertEqual(len(manifest), 500)

        files = sorted(CONTENT_ROOT.rglob("*.md"))
        self.assertEqual(len(files), 500)

    def test_metadata_and_word_counts_are_valid(self) -> None:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        seen_paths: set[str] = set()

        for item in manifest:
            url_path = item["url_path"]
            self.assertNotIn(url_path, seen_paths)
            seen_paths.add(url_path)
            self.assertLessEqual(len(item["seo_title"]), 60)
            self.assertGreaterEqual(len(item["meta_description"]), 140)
            self.assertLessEqual(len(item["meta_description"]), 160)

            file_path = SEO_ROOT / item["file_path"]
            self.assertTrue(file_path.exists(), f"Missing file for {url_path}")
            content = file_path.read_text(encoding="utf-8")
            self.assertIn("---", content[:10])
            self.assertIn("\n# ", content)

            body = content.split("---", 2)[-1]
            words = len(re.findall(r"\b[\w/+-]+\b", body))
            self.assertGreaterEqual(words, 800, f"{url_path} is too short")
            self.assertLessEqual(words, 1400, f"{url_path} is too long")


if __name__ == "__main__":
    unittest.main()
