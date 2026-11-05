from app.schemas.climate import ClimateFeedbackRequest, ClimateProfileIn
from app.services.mixed_ordinal import feedback_random_delta, predict
from app.services.sensation import apply_feedback, care_for, clothing_from_ireq, look_fail_boost
from app.services.thermal_indices import compute_support, ireq_clo, wind_chill_c
from app.services.utci import compute_utci, utci_to_sensation


def test_utci_reference_point():
    r = compute_utci(tdb_c=25, rh=50, wind_10m_ms=1, shortwave_wm2=0, shade=True)
    assert r.utci_c == 24.6
    assert r.in_range is True
    assert utci_to_sensation(r.utci_c) == 0


def test_tmrt_shortwave_cap():
    r = compute_utci(tdb_c=20, rh=40, wind_10m_ms=2, shortwave_wm2=900, shade=False)
    assert r.tmrt_c <= 20 + 25
    assert r.tmrt_c == 20 + min(25.0, 900 * 0.033)


def test_support_indices_and_ireq():
    s = compute_support(tdb_c=0, rh=80, wind_10m_ms=4, tmrt_c=0, activity="moderate")
    assert s.pet_c is not None
    assert s.wind_chill_c is not None
    assert s.ireq_clo >= 0.9
    assert wind_chill_c(0, 4) is not None
    assert ireq_clo(tdb_c=-5, tmrt_c=-5, wind_10m_ms=3, activity="low") > 1.0


def test_mixed_ordinal_personalization():
    base = ClimateProfileIn()
    cold = ClimateProfileIn(cold_bias=1.4, age_band="over_50", sex="female")
    p0 = predict(utci_c=5, wind_ms=2, rh=50, profile=base)
    p1 = predict(utci_c=5, wind_ms=2, rh=50, profile=cold)
    assert p1.latent < p0.latent


def test_day1_priors_dress_vignette_acclimation():
    base = ClimateProfileIn()
    warmer = ClimateProfileIn(dress_bias="warmer")
    lighter = ClimateProfileIn(dress_bias="lighter")
    vignette_cold = ClimateProfileIn(vignette_sensation="cold")
    newcomer = ClimateProfileIn(acclimation="temporary")
    p0 = predict(utci_c=10, wind_ms=2, rh=50, profile=base)
    assert predict(utci_c=10, wind_ms=2, rh=50, profile=warmer).latent > p0.latent
    assert predict(utci_c=10, wind_ms=2, rh=50, profile=lighter).latent < p0.latent
    assert predict(utci_c=10, wind_ms=2, rh=50, profile=vignette_cold).latent < p0.latent
    assert predict(utci_c=10, wind_ms=2, rh=50, profile=newcomer).latent < p0.latent


def test_feedback_offset_direction():
    res = apply_feedback(
        ClimateFeedbackRequest(
            city="Moscow",
            predicted_sensation=-2,
            actual_sensation=-1,
            worn_tier="as_advised",
            look_preserved="yes",
            moment="leave",
        )
    )
    assert res.suggested_feedback_offset_delta > 0
    assert feedback_random_delta(
        predicted_sensation=0, actual_sensation=-2, worn_tier="lighter"
    ) < 0


def test_ireq_clothing_whitelist():
    items = clothing_from_ireq(1.6, "ru")
    assert items
    assert all(i.catalog_id for i in items)


def test_look_boost_adds_fixative():
    care = care_for(
        utci_c=18,
        uv=3,
        wind=2,
        humidity=50,
        precip=0,
        lang="ru",
        appearance_risk=0,
        look_boost=1,
    )
    ids = {c.catalog_id for c in care}
    assert "hood_fixative" in ids
    care2 = care_for(
        utci_c=18,
        uv=3,
        wind=2,
        humidity=50,
        precip=0,
        lang="en",
        appearance_risk=0,
        look_boost=2,
    )
    assert {c.catalog_id for c in care2} >= {"hood_fixative", "compact_kit"}


def test_look_fail_boost_without_db():
    assert look_fail_boost(None, client_key="u1", city="Moscow", lat=55.7, lon=37.6) == 0
