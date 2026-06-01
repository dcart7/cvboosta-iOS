import asyncio
import hashlib
import time
from collections import deque
from dataclasses import dataclass
from typing import Any

import httpx

from app.core.config import settings
from app.services.ai_response_parser import parse_json_object
from app.services.prompt_templates import render_template
from app.services.token_usage_tracker import TokenUsage, token_usage_tracker


class GeminiServiceError(RuntimeError):
    pass


class GeminiUnavailableError(GeminiServiceError):
    pass


class InMemoryRateLimiter:
    def __init__(self, requests_per_minute: int) -> None:
        self.requests_per_minute = requests_per_minute
        self.calls: deque[float] = deque()
        self.lock = asyncio.Lock()

    async def acquire(self) -> None:
        while True:
            async with self.lock:
                now = time.monotonic()
                while self.calls and now - self.calls[0] > 60:
                    self.calls.popleft()

                if len(self.calls) < self.requests_per_minute:
                    self.calls.append(now)
                    return

                wait_for = 60 - (now - self.calls[0]) + 0.01

            await asyncio.sleep(max(wait_for, 0.01))


@dataclass
class GeminiJSONResult:
    payload: dict[str, Any]
    model_used: str


class GeminiService:
    def __init__(self) -> None:
        self.api_key = settings.gemini_api_key
        self.fast_model = settings.gemini_model_fast
        self.pro_model = settings.gemini_model_pro
        self.timeout_seconds = settings.gemini_timeout_seconds
        self.max_retries = settings.gemini_max_retries
        self.rate_limiter = InMemoryRateLimiter(settings.gemini_requests_per_minute)
        self.cache_ttl_seconds = 600
        self.cache: dict[str, tuple[float, GeminiJSONResult]] = {}
        self.cache_lock = asyncio.Lock()

    async def generate_json(
        self,
        prompt: str,
        model_tier: str,
        fallback_payload: dict[str, Any],
        temperature: float = 0.2,
    ) -> GeminiJSONResult:
        if not self.api_key:
            raise GeminiUnavailableError("GEMINI_API_KEY is not configured")

        cache_key = self._make_cache_key(model_tier=model_tier, prompt=prompt)
        cached = await self._get_cached(cache_key)
        if cached:
            return cached

        models = self._models_for_tier(model_tier)
        last_error: Exception | None = None

        for model in models:
            for attempt in range(self.max_retries + 1):
                try:
                    response_data = await self._call_generate_content(
                        model=model,
                        prompt=prompt,
                        temperature=temperature,
                    )
                    text = self._extract_text(response_data)
                    parsed = parse_json_object(text, fallback=fallback_payload)
                    self._record_usage(model, response_data)
                    result = GeminiJSONResult(payload=parsed, model_used=model)
                    await self._set_cached(cache_key, result)
                    return result
                except Exception as error:  # noqa: PERF203
                    last_error = error
                    if attempt < self.max_retries:
                        await asyncio.sleep(0.35 * (2**attempt))

        raise GeminiServiceError(f"Gemini request failed: {last_error}")

    async def ats_enhancement(
        self,
        target_role: str,
        resume_text: str,
        deterministic_findings: list[str],
    ) -> dict[str, Any]:
        fallback = {
            "priority_fixes": [],
            "keyword_gaps": [],
            "weak_bullet_examples": [],
            "rewrite_suggestions": [],
        }

        prompt = render_template(
            "ats_scan_enhance.txt",
            target_role=target_role,
            resume_text=resume_text[:12000],
            deterministic_findings="\n".join(deterministic_findings),
        )

        result = await self.generate_json(
            prompt=prompt,
            model_tier="fast",
            fallback_payload=fallback,
            temperature=0.15,
        )
        return result.payload

    async def rewrite_bullets(self, target_role: str, bullets: list[str]) -> list[str]:
        fallback = {"rewritten_bullets": bullets}
        prompt = render_template(
            "rewrite_bullets.txt",
            target_role=target_role,
            bullets="\n".join(f"- {b}" for b in bullets),
        )

        result = await self.generate_json(
            prompt=prompt,
            model_tier="pro",
            fallback_payload=fallback,
            temperature=0.35,
        )

        rewritten = result.payload.get("rewritten_bullets", bullets)
        if not isinstance(rewritten, list):
            return bullets

        normalized = [str(item).strip() for item in rewritten if str(item).strip()]
        return normalized[: len(bullets)] if normalized else bullets

    async def _call_generate_content(self, model: str, prompt: str, temperature: float) -> dict[str, Any]:
        await self.rate_limiter.acquire()

        endpoint = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        payload = {
            "contents": [{"role": "user", "parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": temperature,
                "responseMimeType": "application/json",
            },
        }

        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.post(endpoint, params={"key": self.api_key}, json=payload)

        if response.status_code >= 400:
            raise GeminiServiceError(f"Gemini HTTP {response.status_code}: {response.text[:300]}")

        return response.json()

    def _extract_text(self, response_data: dict[str, Any]) -> str:
        candidates = response_data.get("candidates", [])
        if not candidates:
            return ""

        parts = candidates[0].get("content", {}).get("parts", [])
        text_parts = [part.get("text", "") for part in parts if isinstance(part, dict)]
        return "\n".join(text_parts).strip()

    def _record_usage(self, model: str, response_data: dict[str, Any]) -> None:
        usage = response_data.get("usageMetadata", {})
        token_usage_tracker.record(
            model,
            TokenUsage(
                prompt_tokens=int(usage.get("promptTokenCount", 0) or 0),
                completion_tokens=int(usage.get("candidatesTokenCount", 0) or 0),
                total_tokens=int(usage.get("totalTokenCount", 0) or 0),
            ),
        )

    def _models_for_tier(self, model_tier: str) -> list[str]:
        if model_tier == "pro":
            return [self.pro_model, self.fast_model]
        return [self.fast_model, self.pro_model]

    async def _get_cached(self, cache_key: str) -> GeminiJSONResult | None:
        async with self.cache_lock:
            row = self.cache.get(cache_key)
            if not row:
                return None
            created_at, value = row
            if time.time() - created_at > self.cache_ttl_seconds:
                self.cache.pop(cache_key, None)
                return None
            return value

    async def _set_cached(self, cache_key: str, value: GeminiJSONResult) -> None:
        async with self.cache_lock:
            self.cache[cache_key] = (time.time(), value)

    def _make_cache_key(self, model_tier: str, prompt: str) -> str:
        digest = hashlib.sha256(prompt.encode("utf-8")).hexdigest()
        return f"{model_tier}:{digest}"
