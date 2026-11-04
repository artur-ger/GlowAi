from __future__ import annotations

from datetime import date, timedelta
from unittest.mock import AsyncMock, patch

import pytest

from app.services.weather import build_climate_summary


@pytest.mark.asyncio
async def test_pre_trip_near_dates_use_forecast_window() -> None:
    start = date.today() + timedelta(days=2)
    end = start + timedelta(days=3)
    metrics = {"temp": 28.0, "humidity": 55.0, "uv": 8.0}
    home_metrics = {"temp": 5.0, "humidity": 70.0, "uv": 1.0}

    with (
        patch(
            "app.services.weather._resolve_place",
            new_callable=AsyncMock,
            side_effect=[
                (55.75, 37.62, "Москва"),
                (36.91, 30.70, "Анталия"),
            ],
        ),
        patch(
            "app.services.weather._metrics_for_window",
            new_callable=AsyncMock,
            side_effect=[
                (home_metrics, "current", "дом сейчас"),
                (metrics, "forecast", "прогноз на даты"),
            ],
        ),
    ):
        climate = await build_climate_summary(
            "Москва",
            "Анталья",
            home_lat=55.75,
            home_lon=37.62,
            dest_lat=36.91,
            dest_lon=30.70,
            trip_start=start.isoformat(),
            trip_end=end.isoformat(),
            mode="pre_trip",
        )

    assert climate.window == "forecast"
    assert "прогноз" in climate.window_note
    assert climate.destination_temp_c == 28.0
    assert climate.delta_temp_c == 23.0
    assert "forecast" in climate.source


@pytest.mark.asyncio
async def test_sos_uses_current_window() -> None:
    with (
        patch(
            "app.services.weather._resolve_place",
            new_callable=AsyncMock,
            side_effect=[
                (55.75, 37.62, "Москва"),
                (36.91, 30.70, "Анталия"),
            ],
        ),
        patch(
            "app.services.weather._metrics_for_window",
            new_callable=AsyncMock,
            side_effect=[
                ({"temp": 5.0, "humidity": 70.0, "uv": 1.0}, "current", "дом"),
                ({"temp": 22.0, "humidity": 60.0, "uv": 4.0}, "current", "sos сейчас"),
            ],
        ) as metrics_mock,
    ):
        climate = await build_climate_summary(
            "Москва",
            "Анталья",
            trip_start="2030-06-01",
            trip_end="2030-06-10",
            mode="sos",
        )

    assert climate.window == "current"
    # dest call prefer_current=True for sos
    dest_call = metrics_mock.await_args_list[1]
    assert dest_call.kwargs["prefer_current"] is True
