def test_register_verify_login_me(client) -> None:
    reg = client.post(
        "/api/v1/auth/register",
        json={
            "email": "pilot@glow.ai",
            "password": "secret12",
            "display_name": "Pilot",
            "accept_terms": True,
        },
    )
    assert reg.status_code == 200, reg.text
    body = reg.json()
    assert body["verification_required"] is True
    code = body["dev_verify_code"]
    assert code and len(code) == 6

    no_terms = client.post(
        "/api/v1/auth/register",
        json={"email": "x@glow.ai", "password": "secret12", "accept_terms": False},
    )
    assert no_terms.status_code == 400

    dup = client.post(
        "/api/v1/auth/register",
        json={"email": "pilot@glow.ai", "password": "secret12", "accept_terms": True},
    )
    assert dup.status_code == 409

    blocked = client.post(
        "/api/v1/auth/login",
        json={"email": "pilot@glow.ai", "password": "secret12"},
    )
    assert blocked.status_code == 403

    verified = client.post(
        "/api/v1/auth/verify-email",
        json={"email": "pilot@glow.ai", "code": code},
    )
    assert verified.status_code == 200, verified.text
    assert verified.json()["user"]["email_verified"] is True

    login = client.post(
        "/api/v1/auth/login",
        json={"email": "pilot@glow.ai", "password": "secret12"},
    )
    assert login.status_code == 200
    token2 = login.json()["access_token"]

    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token2}"})
    assert me.status_code == 200
    assert me.json()["display_name"] == "Pilot"

    forgot = client.post("/api/v1/auth/forgot-password", json={"email": "pilot@glow.ai"})
    assert forgot.status_code == 200
    reset_code = forgot.json()["dev_verify_code"]
    assert reset_code

    reset = client.post(
        "/api/v1/auth/reset-password",
        json={"email": "pilot@glow.ai", "code": reset_code, "new_password": "secret99"},
    )
    assert reset.status_code == 200, reset.text

    login2 = client.post(
        "/api/v1/auth/login",
        json={"email": "pilot@glow.ai", "password": "secret99"},
    )
    assert login2.status_code == 200

    deleted = client.delete("/api/v1/auth/me", headers={"Authorization": f"Bearer {login2.json()['access_token']}"})
    assert deleted.status_code == 204
