from collections import defaultdict
from dataclasses import dataclass
from threading import Lock


@dataclass
class TokenUsage:
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int


class TokenUsageTracker:
    def __init__(self) -> None:
        self._lock = Lock()
        self._totals: dict[str, dict[str, int]] = defaultdict(
            lambda: {
                "requests": 0,
                "prompt_tokens": 0,
                "completion_tokens": 0,
                "total_tokens": 0,
            }
        )

    def record(self, model: str, usage: TokenUsage) -> None:
        with self._lock:
            row = self._totals[model]
            row["requests"] += 1
            row["prompt_tokens"] += usage.prompt_tokens
            row["completion_tokens"] += usage.completion_tokens
            row["total_tokens"] += usage.total_tokens

    def snapshot(self) -> dict[str, dict[str, int]]:
        with self._lock:
            return {model: values.copy() for model, values in self._totals.items()}


token_usage_tracker = TokenUsageTracker()
