def _auth(client, email: str = "a@glow.ai"):
    r = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "secret12", "display_name": "A", "accept_terms": True},
    )
    assert r.status_code == 200, r.text
    code = r.json()["dev_verify_code"]
    v = client.post(
        "/api/v1/auth/verify-email",
        json={"email": email, "code": code},
    )
    assert v.status_code == 200, v.text
    return v.json()["access_token"]


def _payload():
    return {
        "mode": "pre_trip",
        "provider": "rule_based",
        "forecast_summary": "тест прогноз",
        "climate": {"home_city": "Москва", "destination_city": "Анталия", "risks": []},
        "skin": {"summary": "ok", "concerns": ["Сухость"], "confidence": "low", "engine": "rule_based"},
        "care_plan": [{"step": 1, "title": "Очищение", "detail": "мягко"}],
        "packing_list": ["SPF"],
        "packing_kit": [{"item": "SPF", "action": "take", "reason": "UV"}],
        "product_hints": [],
        "why_reasons": ["ΔT"],
        "follow_up_hint": "48-72",
        "disclaimer": "не медуслуга",
    }


def test_checks_isolation_parent_remind_and_chat(client) -> None:
    token_a = _auth(client)
    headers_a = {"Authorization": f"Bearer {token_a}"}

    created = client.post(
        "/api/v1/checks",
        headers=headers_a,
        json={
            "payload": _payload(),
            "home_city": "Москва",
            "dest_city": "Анталия",
            "mode": "pre_trip",
            "remind_in_hours": 48,
        },
    )
    assert created.status_code == 201, created.text
    check_id = created.json()["id"]
    assert created.json()["remind_at"]

    follow = client.post(
        "/api/v1/checks",
        headers=headers_a,
        json={
            "payload": _payload(),
            "home_city": "Москва",
            "dest_city": "Анталия",
            "mode": "sos",
            "parent_check_id": check_id,
        },
    )
    assert follow.status_code == 201
    assert follow.json()["parent_check_id"] == check_id

    listed = client.get("/api/v1/checks", headers=headers_a)
    assert listed.status_code == 200
    assert len(listed.json()) == 2

    token_b = _auth(client, email="b@glow.ai")
    headers_b = {"Authorization": f"Bearer {token_b}"}
    forbidden = client.get(f"/api/v1/checks/{check_id}", headers=headers_b)
    assert forbidden.status_code == 404

    chat = client.post(
        f"/api/v1/checks/{check_id}/messages",
        headers=headers_a,
        json={"text": "Кожа стала суше на месте"},
    )
    assert chat.status_code == 200, chat.text
    assert chat.json()["assistant_message"]["role"] == "assistant"

    msgs = client.get(f"/api/v1/checks/{check_id}/messages", headers=headers_a)
    assert msgs.status_code == 200
    assert len(msgs.json()) >= 2
