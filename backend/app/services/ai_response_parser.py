import json
import re
from typing import Any


def parse_json_object(text: str, fallback: dict[str, Any]) -> dict[str, Any]:
    cleaned = text.strip()
    cleaned = re.sub(r"^```(?:json)?", "", cleaned).strip()
    cleaned = re.sub(r"```$", "", cleaned).strip()

    if not cleaned:
        return fallback

    try:
        parsed = json.loads(cleaned)
        return parsed if isinstance(parsed, dict) else fallback
    except json.JSONDecodeError:
        start = cleaned.find("{")
        end = cleaned.rfind("}")
        if start != -1 and end != -1 and end > start:
            fragment = cleaned[start : end + 1]
            try:
                parsed = json.loads(fragment)
                return parsed if isinstance(parsed, dict) else fallback
            except json.JSONDecodeError:
                return fallback

    return fallback
