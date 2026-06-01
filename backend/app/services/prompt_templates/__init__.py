from functools import lru_cache
from pathlib import Path

PROMPT_DIR = Path(__file__).resolve().parent


@lru_cache(maxsize=16)
def load_template(name: str) -> str:
    path = PROMPT_DIR / name
    return path.read_text(encoding="utf-8")


def render_template(name: str, **kwargs: str) -> str:
    template = load_template(name)
    return template.format(**kwargs)
