import json
from pathlib import Path

ROLE_DATA_PATH = Path(__file__).resolve().parents[2] / "data" / "roles" / "role_keywords_seed.json"


def load_role_map() -> dict:
    with ROLE_DATA_PATH.open("r", encoding="utf-8") as file:
        return json.load(file)


def get_role_keywords(target_role: str) -> list[str]:
    role_map = load_role_map()

    if target_role not in role_map:
        return role_map.get("Backend Developer", {}).get("keywords", [])

    return role_map[target_role].get("keywords", [])


def get_role_expectations(target_role: str) -> list[str]:
    role_map = load_role_map()

    if target_role not in role_map:
        return role_map.get("Backend Developer", {}).get("expectations", [])

    return role_map[target_role].get("expectations", [])
