import pytest
from fastapi import HTTPException

from app.core.rate_limit import InMemoryRateLimiter


def test_rate_limiter_blocks_after_max() -> None:
    limiter = InMemoryRateLimiter(max_calls=3, per_seconds=60.0)
    limiter.check("ip-1")
    limiter.check("ip-1")
    limiter.check("ip-1")
    with pytest.raises(HTTPException) as exc:
        limiter.check("ip-1")
    assert exc.value.status_code == 429


def test_rate_limiter_isolated_by_key() -> None:
    limiter = InMemoryRateLimiter(max_calls=1, per_seconds=60.0)
    limiter.check("a")
    limiter.check("b")
    with pytest.raises(HTTPException):
        limiter.check("a")
