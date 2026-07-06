# CVBoosta Programmatic SEO Pages

This folder contains a generated content pack of 500 SEO pages for CVBoosta.

## Structure

- `content/`: Generated markdown pages grouped by route family.
- `manifest.json`: Index of all generated pages with metadata.
- `generate_pages.py`: Deterministic generator for rebuilding the content pack.

## Route Families

- `/ats/...`
- `/ats-comparisons/...`
- `/resume-keywords/...`
- `/skills/...`
- `/tools/...`
- `/datasets/...`

## File Format

Each page is stored as markdown with YAML frontmatter:

- `seo_title`
- `meta_description`
- `url_path`
- `page_type`
- `primary_keyword`

The body starts with the page H1 and is written for long-tail ATS and resume search intent.

## Rebuild

```bash
python3 seo_pages/generate_pages.py
```
