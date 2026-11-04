from __future__ import annotations

from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from app.main import app
from app.schemas.analyze import AnalyzeResponse, CareStep, ClimateSummary, PackingItem, SkinAssessment

client = TestClient(app)


def _fake_climate(*_args: object, **_kwargs: object) -> ClimateSummary:
    return ClimateSummary(
        home_city="Москва",
        destination_city="Анталия",
        home_temp_c=3.0,
        destination_temp_c=20.0,
        home_humidity=60.0,
        destination_humidity=80.0,
        home_uv=1.0,
        destination_uv=3.5,
        delta_temp_c=17.0,
        delta_humidity=20.0,
        risks=["резкое потепление — риск обезвоживания и жирного блеска"],
        source="open-meteo+client-coords",
    )


def _fake_response() -> AnalyzeResponse:
    return AnalyzeResponse(
        mode="pre_trip",
        climate=_fake_climate(),
        skin=SkinAssessment(
            summary="ok",
            concerns=["Сухость"],
            confidence="medium",
            engine="rule_based",
        ),
        care_plan=[CareStep(step=1, title="Очищение", detail="мягко")],
        packing_list=["SPF"],
        packing_kit=[PackingItem(item="SPF", action="take", reason="UV")],
        product_hints=["moisturizer"],
        why_reasons=["ΔT"],
        forecast_summary="тест",
        trip_start="2026-12-01",
        trip_end="2026-12-08",
        trip_days=8,
        follow_up_hint="48-72",
        disclaimer="не медуслуга",
        provider="rule_based",
    )


def test_analyze_passes_client_coords() -> None:
    with (
        patch(
            "app.api.routes.analyze.build_climate_summary",
            new_callable=AsyncMock,
            side_effect=_fake_climate,
        ) as climate_mock,
        patch(
            "app.api.routes.analyze.build_analyze_response",
            new_callable=AsyncMock,
            return_value=_fake_response(),
        ),
    ):
        response = client.post(
            "/api/v1/analyze",
            data={
                "home_city": "Москва",
                "destination_city": "Анталья",
                "skin_type": "Нормальная",
                "concerns": "Сухость",
                "mode": "pre_trip",
                "home_lat": "55.75",
                "home_lon": "37.62",
                "dest_lat": "36.91",
                "dest_lon": "30.70",
            },
        )
    assert response.status_code == 200
    body = response.json()
    assert body["provider"] == "rule_based"
    assert body["skin"]["engine"] == "rule_based"
    assert "care_plan" in body
    climate_mock.assert_awaited()
    call = climate_mock.await_args
    assert call is not None
    assert call.kwargs["home_lat"] == 55.75
    assert call.kwargs["dest_lon"] == 30.70
    assert call.kwargs.get("mode") == "pre_trip"
