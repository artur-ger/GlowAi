from unittest.mock import AsyncMock, patch

from app.schemas.analyze import ClimateSummary


def _auth(client, email: str = "trip@glow.ai"):
    r = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "secret12", "display_name": "T", "accept_terms": True},
    )
    code = r.json()["dev_verify_code"]
    v = client.post("/api/v1/auth/verify-email", json={"email": email, "code": code})
    return v.json()["access_token"]


def test_profile_memory_and_trip_lifecycle(client) -> None:
    token = _auth(client)
    headers = {"Authorization": f"Bearer {token}"}

    patched = client.patch(
        "/api/v1/profile/me",
        headers=headers,
        json={
            "skin_type": "Сухая",
            "concerns": ["Сухость"],
            "owned_items": ["SPF", "Cleanser"],
            "avoid_items": ["Acids"],
        },
    )
    assert patched.status_code == 200, patched.text
    assert patched.json()["skin_type"] == "Сухая"
    assert "SPF" in patched.json()["owned_items"]

    created = client.post(
        "/api/v1/checks",
        headers=headers,
        json={
            "payload": {
                "mode": "pre_trip",
                "trip_start": "2026-11-10",
                "trip_end": "2026-11-20",
                "climate": {"home_city": "Москва", "destination_city": "Анталия"},
                "skin": {"summary": "ok", "concerns": [], "confidence": "low", "engine": "rule_based"},
                "care_plan": [],
                "packing_list": [],
                "packing_kit": [],
                "product_hints": [],
                "why_reasons": [],
                "follow_up_hint": "x",
                "disclaimer": "d",
                "provider": "rule_based",
                "forecast_summary": "f",
                "owned_items": ["SPF"],
                "avoid_items": ["Acids"],
            },
            "home_city": "Москва",
            "dest_city": "Анталия",
            "mode": "pre_trip",
        },
    )
    assert created.status_code == 201, created.text
    assert created.json().get("trip_id")

    active = client.get("/api/v1/trips/active", headers=headers)
    assert active.status_code == 200
    trip = active.json()
    assert trip["dest_city"] == "Анталия"
    trip_id = trip["id"]

    on_site = client.patch(
        f"/api/v1/trips/{trip_id}/status",
        headers=headers,
        json={"status": "on_site"},
    )
    assert on_site.status_code == 200
    assert on_site.json()["status"] == "on_site"

    fake = ClimateSummary(
        home_city="Москва",
        destination_city="Анталия",
        home_temp_c=5.0,
        destination_temp_c=28.0,
        home_humidity=70.0,
        destination_humidity=55.0,
        home_uv=1.0,
        destination_uv=8.0,
        delta_temp_c=23.0,
        delta_humidity=-15.0,
        window="current",
        window_note="сейчас",
    )
    with patch(
        "app.api.routes.trips.build_climate_summary",
        new_callable=AsyncMock,
        return_value=fake,
    ):
        tip = client.get(f"/api/v1/trips/{trip_id}/daily-tip", headers=headers)
    assert tip.status_code == 200, tip.text
    assert tip.json()["tip"]
    assert "UV" in tip.json()["tip"] or "SPF" in tip.json()["tip"]

    cid = created.json()["id"]
    deleted = client.delete(f"/api/v1/checks/{cid}", headers=headers)
    assert deleted.status_code == 204
