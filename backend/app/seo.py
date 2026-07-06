from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import UTC, datetime
from functools import lru_cache
from html import escape
from pathlib import Path

from .config import site_base_url


REPO_ROOT = Path(__file__).resolve().parents[2]
SEO_ROOT = REPO_ROOT / "seo_pages"
MANIFEST_PATH = SEO_ROOT / "manifest.json"

LIBRARY_METADATA: dict[str, dict[str, str]] = {
    "ats": {
        "title": "ATS Resume Guides",
        "description": "Parser-specific ATS resume guides for formatting, keyword placement, section headings, and date parsing.",
    },
    "ats-comparisons": {
        "title": "ATS Comparison Pages",
        "description": "Side-by-side ATS comparison pages that explain how common applicant tracking systems differ in parsing behavior.",
    },
    "resume-keywords": {
        "title": "Resume Keywords by Role",
        "description": "Role-specific resume keyword pages focused on ATS matching, recruiter scanning behavior, and keyword placement.",
    },
    "skills": {
        "title": "Skill Frequency Pages",
        "description": "Skill-frequency pages showing where specific skills strengthen ATS matching across different role families.",
    },
    "tools": {
        "title": "Resume Tool Guides",
        "description": "Guides for CVBoosta-style resume tools, including format validators, keyword scanners, and recruiter-scan previews.",
    },
    "datasets": {
        "title": "Resume Skills Datasets",
        "description": "Resume optimization dataset pages that surface high-signal skills, missing terms, and formatting patterns by industry.",
    },
}

LIBRARY_ORDER = (
    "ats",
    "ats-comparisons",
    "resume-keywords",
    "skills",
    "tools",
    "datasets",
)


@dataclass(frozen=True)
class SeoPage:
    url_path: str
    page_type: str
    primary_keyword: str
    seo_title: str
    meta_description: str
    word_count: int
    file_path: str

    @property
    def family(self) -> str:
        return self.url_path.strip("/").split("/", 1)[0]

    @property
    def content_path(self) -> Path:
        return SEO_ROOT / self.file_path

    @property
    def absolute_url(self) -> str:
        return f"{site_base_url()}{self.url_path}"


@lru_cache(maxsize=1)
def load_manifest() -> tuple[SeoPage, ...]:
    if not MANIFEST_PATH.exists():
        return ()

    raw_items = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    return tuple(
        SeoPage(
            url_path=item["url_path"],
            page_type=item["page_type"],
            primary_keyword=item["primary_keyword"],
            seo_title=item["seo_title"],
            meta_description=item["meta_description"],
            word_count=item["word_count"],
            file_path=item["file_path"],
        )
        for item in raw_items
    )


@lru_cache(maxsize=1)
def pages_by_url() -> dict[str, SeoPage]:
    return {page.url_path: page for page in load_manifest()}


@lru_cache(maxsize=1)
def pages_by_family() -> dict[str, tuple[SeoPage, ...]]:
    grouped: dict[str, list[SeoPage]] = {family: [] for family in LIBRARY_ORDER}
    for page in load_manifest():
        grouped.setdefault(page.family, []).append(page)
    return {family: tuple(grouped.get(family, [])) for family in LIBRARY_ORDER}


@lru_cache(maxsize=None)
def markdown_body(url_path: str) -> str:
    page = pages_by_url().get(url_path)
    if page is None:
        raise KeyError(url_path)
    text = page.content_path.read_text(encoding="utf-8")
    return strip_frontmatter(text)


def strip_frontmatter(text: str) -> str:
    if not text.startswith("---"):
        return text.strip()

    lines = text.splitlines()
    for index, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            return "\n".join(lines[index + 1 :]).strip()
    return text.strip()


def page_last_modified(page: SeoPage) -> str:
    timestamp = page.content_path.stat().st_mtime
    return datetime.fromtimestamp(timestamp, tz=UTC).date().isoformat()


def library_last_modified(family: str) -> str:
    pages = pages_by_family().get(family, ())
    if not pages:
        return datetime.now(tz=UTC).date().isoformat()
    return max(page_last_modified(page) for page in pages)


def render_inline(text: str) -> str:
    token_pattern = re.compile(r"\[([^\]]+)\]\(([^)]+)\)|`([^`]+)`|\*\*([^*]+)\*\*")
    chunks: list[str] = []
    cursor = 0

    for match in token_pattern.finditer(text):
        chunks.append(escape(text[cursor : match.start()]))
        label, href, code, bold = match.groups()
        if label is not None and href is not None:
            safe_href = escape(href, quote=True)
            rel = ' rel="noopener noreferrer"' if href.startswith("http") else ""
            chunks.append(f'<a href="{safe_href}"{rel}>{escape(label)}</a>')
        elif code is not None:
            if code.startswith("/"):
                safe_href = escape(code, quote=True)
                chunks.append(f'<a href="{safe_href}" class="route-link"><code>{escape(code)}</code></a>')
            else:
                chunks.append(f"<code>{escape(code)}</code>")
        elif bold is not None:
            chunks.append(f"<strong>{escape(bold)}</strong>")
        cursor = match.end()

    chunks.append(escape(text[cursor:]))
    return "".join(chunks)


def render_table(lines: list[str]) -> str:
    rows = [parse_table_row(line) for line in lines if line.strip()]
    if not rows:
        return ""

    header = rows[0]
    body_rows = [row for row in rows[1:] if not is_separator_row(row)]
    header_html = "".join(f"<th>{render_inline(cell)}</th>" for cell in header)
    body_html = "".join(
        "<tr>" + "".join(f"<td>{render_inline(cell)}</td>" for cell in row) + "</tr>"
        for row in body_rows
    )
    return (
        '<div class="table-wrap"><table>'
        f"<thead><tr>{header_html}</tr></thead>"
        f"<tbody>{body_html}</tbody>"
        "</table></div>"
    )


def parse_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_separator_row(cells: list[str]) -> bool:
    return all(re.fullmatch(r":?-{3,}:?", cell or "") for cell in cells)


def render_markdown(markdown: str) -> str:
    html_parts: list[str] = []
    paragraph_lines: list[str] = []
    lines = markdown.splitlines()
    index = 0

    def flush_paragraph() -> None:
        if paragraph_lines:
            html_parts.append(f"<p>{render_inline(' '.join(paragraph_lines))}</p>")
            paragraph_lines.clear()

    while index < len(lines):
        line = lines[index].rstrip()
        stripped = line.strip()

        if not stripped:
            flush_paragraph()
            index += 1
            continue

        if stripped.startswith("|"):
            flush_paragraph()
            table_lines: list[str] = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                table_lines.append(lines[index].strip())
                index += 1
            html_parts.append(render_table(table_lines))
            continue

        if re.match(r"^#{1,6}\s+", stripped):
            flush_paragraph()
            hashes, title = stripped.split(" ", 1)
            level = len(hashes)
            html_parts.append(f"<h{level}>{render_inline(title.strip())}</h{level}>")
            index += 1
            continue

        if stripped.startswith("- "):
            flush_paragraph()
            items: list[str] = []
            while index < len(lines) and lines[index].strip().startswith("- "):
                items.append(lines[index].strip()[2:].strip())
                index += 1
            items_html = "".join(f"<li>{render_inline(item)}</li>" for item in items)
            html_parts.append(f"<ul>{items_html}</ul>")
            continue

        paragraph_lines.append(stripped)
        index += 1

    flush_paragraph()
    return "\n".join(html_parts)


def breadcrumb_label(family: str) -> str:
    return LIBRARY_METADATA[family]["title"]


def library_links_html(current_family: str | None = None) -> str:
    links: list[str] = []
    for family in LIBRARY_ORDER:
        css_class = "active" if family == current_family else ""
        links.append(
            f'<a href="/{family}" class="nav-link {css_class}">{escape(LIBRARY_METADATA[family]["title"])}</a>'
        )
    links.append('<a href="/sitemap.xml" class="nav-link">Sitemap</a>')
    links.append('<a href="/llms.txt" class="nav-link">llms.txt</a>')
    return "".join(links)


def render_document(*, title: str, meta_description: str, canonical_path: str, body_html: str, current_family: str | None) -> str:
    canonical_url = f"{site_base_url()}{canonical_path}"
    structured_data = json.dumps(
        {
            "@context": "https://schema.org",
            "@type": "WebPage",
            "name": title,
            "description": meta_description,
            "url": canonical_url,
            "isPartOf": {"@type": "WebSite", "name": "CVBoosta", "url": site_base_url()},
        }
    )
    return f"""<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{escape(title)}</title>
    <meta name="description" content="{escape(meta_description, quote=True)}">
    <meta name="robots" content="index,follow,max-image-preview:large">
    <meta property="og:type" content="article">
    <meta property="og:title" content="{escape(title, quote=True)}">
    <meta property="og:description" content="{escape(meta_description, quote=True)}">
    <meta property="og:url" content="{escape(canonical_url, quote=True)}">
    <link rel="canonical" href="{escape(canonical_url, quote=True)}">
    <script type="application/ld+json">{structured_data}</script>
    <style>
      :root {{
        color-scheme: light;
        --bg: #f4f7fb;
        --card: rgba(255, 255, 255, 0.94);
        --line: rgba(30, 41, 59, 0.12);
        --text: #172033;
        --muted: #5f7191;
        --accent: #1f7cff;
        --accent-soft: rgba(31, 124, 255, 0.08);
      }}
      * {{ box-sizing: border-box; }}
      body {{
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background:
          radial-gradient(circle at top left, rgba(31, 124, 255, 0.12), transparent 28rem),
          linear-gradient(180deg, #f9fbff 0%, var(--bg) 100%);
        color: var(--text);
      }}
      a {{ color: var(--accent); text-decoration: none; }}
      a:hover {{ text-decoration: underline; }}
      .shell {{ max-width: 1040px; margin: 0 auto; padding: 32px 20px 80px; }}
      .topbar {{
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        margin-bottom: 20px;
        padding: 14px;
        border: 1px solid var(--line);
        border-radius: 20px;
        background: rgba(255, 255, 255, 0.82);
        backdrop-filter: blur(18px);
      }}
      .nav-link {{
        padding: 10px 14px;
        border-radius: 999px;
        background: transparent;
        color: var(--text);
        border: 1px solid transparent;
      }}
      .nav-link.active {{
        background: var(--accent-soft);
        border-color: rgba(31, 124, 255, 0.18);
      }}
      .card {{
        padding: 28px;
        border-radius: 28px;
        border: 1px solid var(--line);
        background: var(--card);
        box-shadow: 0 24px 60px rgba(15, 23, 42, 0.08);
      }}
      .eyebrow {{
        font-size: 0.82rem;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: var(--muted);
        margin: 0 0 16px;
      }}
      .article h1, .article h2, .article h3 {{
        color: #101a2e;
        line-height: 1.15;
      }}
      .article h1 {{ font-size: clamp(2rem, 4vw, 3rem); margin: 0 0 18px; }}
      .article h2 {{ font-size: clamp(1.35rem, 2vw, 1.75rem); margin: 30px 0 12px; }}
      .article h3 {{ font-size: 1.1rem; margin: 20px 0 10px; }}
      .article p, .article li {{
        font-size: 1.02rem;
        line-height: 1.72;
        color: var(--text);
      }}
      .article p {{ margin: 0 0 14px; }}
      .article ul {{ margin: 10px 0 16px 20px; padding: 0; }}
      .article li {{ margin-bottom: 8px; }}
      .article code {{
        padding: 0.12rem 0.38rem;
        border-radius: 0.45rem;
        background: rgba(15, 23, 42, 0.06);
        color: #0f172a;
      }}
      .route-link code {{
        background: var(--accent-soft);
      }}
      .table-wrap {{
        overflow-x: auto;
        margin: 18px 0 20px;
        border: 1px solid var(--line);
        border-radius: 18px;
      }}
      table {{
        width: 100%;
        border-collapse: collapse;
        min-width: 540px;
        background: rgba(255, 255, 255, 0.88);
      }}
      th, td {{
        padding: 14px 16px;
        text-align: left;
        vertical-align: top;
        border-bottom: 1px solid var(--line);
      }}
      th {{
        background: rgba(15, 23, 42, 0.04);
        font-weight: 600;
      }}
      .library-list {{
        list-style: none;
        margin: 24px 0 0;
        padding: 0;
        display: grid;
        gap: 14px;
      }}
      .library-item {{
        padding: 18px 20px;
        border: 1px solid var(--line);
        border-radius: 20px;
        background: rgba(255, 255, 255, 0.72);
      }}
      .library-item p {{
        margin: 8px 0 0;
        color: var(--muted);
      }}
      .meta-row {{
        display: flex;
        flex-wrap: wrap;
        gap: 10px 18px;
        margin: 16px 0 22px;
        color: var(--muted);
        font-size: 0.95rem;
      }}
      .footer-note {{
        margin-top: 24px;
        color: var(--muted);
        font-size: 0.92rem;
      }}
    </style>
  </head>
  <body>
    <main class="shell">
      <nav class="topbar">{library_links_html(current_family)}</nav>
      <section class="card article">
        {body_html}
      </section>
    </main>
  </body>
</html>"""


def render_library_index(family: str) -> str:
    pages = pages_by_family().get(family, ())
    metadata = LIBRARY_METADATA[family]
    items_html = "".join(
        f"""
        <li class="library-item">
          <a href="{escape(page.url_path, quote=True)}"><strong>{escape(page.seo_title)}</strong></a>
          <p>{escape(page.meta_description)}</p>
        </li>
        """
        for page in pages
    )
    body_html = f"""
    <p class="eyebrow">CVBoosta SEO Library</p>
    <h1>{escape(metadata["title"])}</h1>
    <p>{escape(metadata["description"])}</p>
    <div class="meta-row">
      <span>{len(pages)} indexable pages</span>
      <span>Canonical domain: {escape(site_base_url())}</span>
      <span>Built for ATS and recruiter search intent</span>
    </div>
    <ul class="library-list">{items_html}</ul>
    <p class="footer-note">Use <a href="/sitemap.xml">/sitemap.xml</a> for the full crawlable URL set and <a href="/llms.txt">/llms.txt</a> for compact LLM guidance.</p>
    """
    return render_document(
        title=metadata["title"],
        meta_description=metadata["description"],
        canonical_path=f"/{family}",
        body_html=body_html,
        current_family=family,
    )


def render_seo_page(url_path: str) -> str:
    page = pages_by_url()[url_path]
    article_html = render_markdown(markdown_body(url_path))
    body_html = f"""
    <p class="eyebrow">{escape(breadcrumb_label(page.family))}</p>
    <div class="meta-row">
      <a href="/{page.family}">Back to {escape(LIBRARY_METADATA[page.family]["title"])}</a>
      <span>{page.word_count} words</span>
      <span>Primary keyword: {escape(page.primary_keyword)}</span>
    </div>
    {article_html}
    <p class="footer-note">This page is part of the CVBoosta SEO content library and is included in the public sitemap for crawler discovery.</p>
    """
    return render_document(
        title=page.seo_title,
        meta_description=page.meta_description,
        canonical_path=page.url_path,
        body_html=body_html,
        current_family=page.family,
    )


def library_paths() -> tuple[str, ...]:
    return tuple(f"/{family}" for family in LIBRARY_ORDER)


def sitemap_entries() -> list[tuple[str, str]]:
    entries = [(path, library_last_modified(path.strip("/"))) for path in library_paths()]
    entries.extend((page.url_path, page_last_modified(page)) for page in load_manifest())
    entries.extend(
        [
            ("/llms.txt", file_last_modified(REPO_ROOT / "llms.txt")),
            ("/llms-full.txt", file_last_modified(REPO_ROOT / "llms-full.txt")),
        ]
    )
    return entries


def file_last_modified(path: Path) -> str:
    timestamp = path.stat().st_mtime
    return datetime.fromtimestamp(timestamp, tz=UTC).date().isoformat()

