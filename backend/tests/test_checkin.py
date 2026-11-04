def _auth(client, email: str = "checkin@glow.ai"):
    r = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "secret12", "display_name": "C", "accept_terms": True},
    )
    assert r.status_code == 200, r.text
    code = r.json()["dev_verify_code"]
    v = client.post("/api/v1/auth/verify-email", json={"email": email, "code": code})
    assert v.status_code == 200
    return v.json()["access_token"]


def test_structured_checkin(client) -> None:
    token = _auth(client)
    headers = {"Authorization": f"Bearer {token}"}
    created = client.post(
        "/api/v1/checks",
        headers=headers,
        json={
            "payload": {
                "mode": "pre_trip",
                "climate": {"destination_city": "Анталия"},
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
            },
            "home_city": "Москва",
            "dest_city": "Анталия",
            "mode": "pre_trip",
            "remind_in_hours": 1,
        },
    )
    assert created.status_code == 201, created.text
    cid = created.json()["id"]

    cin = client.post(
        f"/api/v1/checks/{cid}/checkin",
        headers=headers,
        json={"dryness": 4, "oiliness": 2, "calmness": 4, "redness": 3, "note": "стянутость"},
    )
    assert cin.status_code == 201, cin.text
    body = cin.json()
    assert "advice" in body and body["advice"]
    assert body["dryness"] == 4
    assert body.get("revised_check_id")
    assert body.get("revised_payload")
    assert body.get("suggest_sos") is True

    listed = client.get(f"/api/v1/checks/{cid}/checkins", headers=headers)
    assert listed.status_code == 200
    assert len(listed.json()) >= 1
