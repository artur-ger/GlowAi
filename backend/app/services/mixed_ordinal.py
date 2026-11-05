"""Interpretable mixed ordinal sensation model (PDF §8.1).

Fixed effects: UTCI, wind, humidity, activity, age, sex, worn clo proxy.
Random intercept u_i per client_key (online update from feedback residuals).
Place intercept p_j from aggregated local feedback + weak static elevation prior.

Latent score maps to 7-point sensation (-3…+3) via fixed thresholds.
"""

from __future__ import annotations

from dataclasses import dataclass

from app.schemas.climate import ClimateProfileIn


# Thresholds on latent → ordinal (≈2.5 °C UTCI per step around comfort)
_THRESHOLDS = (-7.5, -5.0, -2.5, 2.5, 5.0, 7.5)  # 6 cuts → 7 classes


@dataclass(frozen=True)
class MixedPrediction:
    latent: float
    sensation: int
    random_intercept: float
    place_intercept: float
    fixed_part: float


def _activity_effect(activity: str) -> float:
    if activity == "high":
        return 1.2
    if activity == "low":
        return -0.7
    return 0.0


def _age_effect(age_band: str) -> float:
    if age_band == "over_50":
        return -0.9
    if age_band == "under_30":
        return 0.35
    return 0.0


def _sex_effect(sex: str) -> float:
    if sex == "female":
        return -0.35
    if sex == "male":
        return 0.15
    return 0.0


def _dress_clo(dress_bias: str) -> float:
    """Baseline clo from onboarding dress habit (lighter / typical / warmer)."""
    if dress_bias == "lighter":
        return 0.5
    if dress_bias == "warmer":
        return 0.95
    return 0.7


def _acclimation_effect(acclimation: str) -> float:
    """Newcomers in cold climate feel colder (negative latent)."""
    if acclimation == "temporary":
        return -0.8
    if acclimation == "recent":
        return -0.5
    return 0.0


def _vignette_effect(vignette_sensation: str) -> float:
    """Anchor vignette at ~+5 °C / light wind / jacket → latent prior."""
    if vignette_sensation == "cold":
        return -1.5
    if vignette_sensation == "warm":
        return 1.2
    return 0.0


def fixed_effects(
    *,
    utci_c: float,
    wind_ms: float,
    rh: float,
    profile: ClimateProfileIn,
    worn_clo: float | None = None,
) -> float:
    """Linear predictor without random effects (units ≈ UTCI °C)."""
    # Onboarding biases as fixed offsets (cold_bias>0 → feels colder → lower latent)
    bias = -1.2 * profile.cold_bias + 1.0 * profile.heat_bias
    wind_term = -0.15 * max(0.0, wind_ms - 3.0)
    rh_term = 0.02 * (rh - 50.0)
    # Explicit worn clo from feedback/plan wins; else dress habit prior
    effective_clo = worn_clo if worn_clo is not None else _dress_clo(profile.dress_bias)
    clo_term = 2.0 * (effective_clo - 0.7)
    return (
        utci_c
        + bias
        + _activity_effect(profile.activity)
        + _age_effect(profile.age_band)
        + _sex_effect(profile.sex)
        + _acclimation_effect(profile.acclimation)
        + _vignette_effect(profile.vignette_sensation)
        + wind_term
        + rh_term
        + clo_term
    )


def latent_to_sensation(latent: float) -> int:
    cuts = _THRESHOLDS
    if latent < cuts[0]:
        return -3
    if latent < cuts[1]:
        return -2
    if latent < cuts[2]:
        return -1
    if latent <= cuts[3]:
        return 0
    if latent <= cuts[4]:
        return 1
    if latent <= cuts[5]:
        return 2
    return 3


def predict(
    *,
    utci_c: float,
    wind_ms: float,
    rh: float,
    profile: ClimateProfileIn,
    random_intercept: float = 0.0,
    place_intercept: float = 0.0,
    worn_clo: float | None = None,
) -> MixedPrediction:
    fixed = fixed_effects(
        utci_c=utci_c,
        wind_ms=wind_ms,
        rh=rh,
        profile=profile,
        worn_clo=worn_clo,
    )
    # profile.feedback_offset is the client-held mirror of random intercept
    u = random_intercept + profile.feedback_offset
    latent = fixed + u + place_intercept
    return MixedPrediction(
        latent=round(latent, 3),
        sensation=latent_to_sensation(latent),
        random_intercept=u,
        place_intercept=place_intercept,
        fixed_part=round(fixed, 3),
    )


def feedback_random_delta(
    *,
    predicted_sensation: int,
    actual_sensation: int,
    worn_tier: str,
) -> float:
    """Online update for u_i: residual in sensation steps → °C-scale intercept."""
    step = 2.5
    delta = float(actual_sensation - predicted_sensation) * step * 0.35
    if worn_tier == "warmer":
        delta -= 0.4
    elif worn_tier == "lighter":
        delta += 0.4
    return max(-1.5, min(1.5, delta))


def place_static_prior(*, elevation_m: float | None) -> float:
    """Weak static place prior: higher altitude → slightly cooler feel."""
    if elevation_m is None:
        return 0.0
    if elevation_m >= 800:
        return -0.6
    if elevation_m >= 400:
        return -0.3
    if elevation_m <= 15:
        return 0.15  # coastal / lowland mild prior
    return 0.0
