from __future__ import annotations

import time
from collections import defaultdict, deque
from threading import Lock

from fastapi import HTTPException, Request


class InMemoryRateLimiter:
    """Simple sliding-window limiter (per process). Enough for local/pilot MVP."""

    def __init__(self, *, max_calls: int = 10, per_seconds: float = 60.0) -> None:
        self.max_calls = max_calls
        self.per_seconds = per_seconds
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = Lock()

    def check(self, key: str) -> None:
        now = time.monotonic()
        with self._lock:
            bucket = self._hits[key]
            while bucket and now - bucket[0] > self.per_seconds:
                bucket.popleft()
            if len(bucket) >= self.max_calls:
                raise HTTPException(
                    status_code=429,
                    detail=f"Слишком много запросов. Лимит {self.max_calls} в {int(self.per_seconds)} с.",
                )
            bucket.append(now)


analyze_limiter = InMemoryRateLimiter(max_calls=12, per_seconds=60.0)
auth_limiter = InMemoryRateLimiter(max_calls=20, per_seconds=60.0)


def client_key(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client and request.client.host:
        return request.client.host
    return "unknown"
