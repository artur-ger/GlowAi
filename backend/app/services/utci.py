"""Universal Thermal Climate Index (UTCI) — Bröde et al. polynomial approximation.

Official applicability (UTCI a002): −50≤Ta≤50 °C, 0.5≤v≤17 m/s (10 m),
0≤RH≤100 %, −30≤Tmrt−Ta≤70 °C. Wind is taken at 10 m as required by UTCI.
Mean radiant temperature is estimated from shortwave radiation when available:
Tmrt ≈ Ta + 0.033 · SW (°C per W/m², cap +25); shade → Tmrt ≈ Ta.
"""

from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass(frozen=True)
class UtciResult:
    utci_c: float
    stress_category: str
    tdb_c: float
    tmrt_c: float
    wind_10m_ms: float
    rh: float
    in_range: bool


def _saturation_vapor_pressure_hpa(tdb_c: float) -> float:
    """Magnus / Goff–Gratch style used in UTCI reference code (hPa)."""
    g = [
        -2836.5744,
        -6028.076559,
        19.54263612,
        -0.02737830188,
        0.000016261698,
        7.0229056e-10,
        -1.8680009e-13,
    ]
    tk = tdb_c + 273.15
    es = 2.7150305 * math.log(tk)
    for count, coef in enumerate(g):
        es += coef * (tk ** (count - 2))
    return math.exp(es) * 0.01


def _utci_polynomial(tdb: float, v: float, delta_t_tr: float, pa_kpa: float) -> float:
    """Bröde et al. 6th-order approximation (same coefficients as UTCI Program)."""
    # Compact evaluation matching official polynomial (ta, va, D_tmrt, pa).
    # Source: UTCI Program Code / pythermalcomfort _utci_optimized.
    ta, va, d, pa = tdb, v, delta_t_tr, pa_kpa
    return (
        ta
        + 0.607562052
        + (-0.0227712343) * ta
        + (8.06470249e-4) * ta * ta
        + (-1.54271372e-4) * ta * ta * ta
        + (-3.24651735e-6) * ta**4
        + (7.32602852e-8) * ta**5
        + (1.35959073e-9) * ta**6
        + (-2.25836520) * va
        + 0.0880326035 * ta * va
        + 0.00216844454 * ta * ta * va
        + (-1.53347087e-5) * ta**3 * va
        + (-5.72983704e-7) * ta**4 * va
        + (-2.55090145e-9) * ta**5 * va
        + (-0.751269505) * va * va
        + (-0.00408350271) * ta * va * va
        + (-5.21670675e-5) * ta * ta * va * va
        + (1.94544667e-6) * ta**3 * va * va
        + (1.14099531e-8) * ta**4 * va * va
        + 0.158137256 * va**3
        + (-6.57263143e-5) * ta * va**3
        + (2.22697524e-7) * ta * ta * va**3
        + (-4.16117031e-8) * ta**3 * va**3
        + (-0.0127762753) * va**4
        + (9.66891875e-6) * ta * va**4
        + (2.52785852e-9) * ta * ta * va**4
        + (4.56306672e-4) * va**5
        + (-1.74202546e-7) * ta * va**5
        + (-5.91491269e-6) * va**6
        + 0.398374029 * d
        + (1.83945314e-4) * ta * d
        + (-1.73754510e-4) * ta * ta * d
        + (-7.60781159e-7) * ta**3 * d
        + (3.77830287e-8) * ta**4 * d
        + (5.43079673e-10) * ta**5 * d
        + (-0.0200518269) * va * d
        + (8.92859837e-4) * ta * va * d
        + (3.45433048e-6) * ta * ta * va * d
        + (-3.77925774e-7) * ta**3 * va * d
        + (-1.69699377e-9) * ta**4 * va * d
        + (1.69992415e-4) * va * va * d
        + (-4.99204314e-5) * ta * va * va * d
        + (2.47417178e-7) * ta * ta * va * va * d
        + (1.07596466e-8) * ta**3 * va * va * d
        + (8.49242932e-5) * va**3 * d
        + (1.35191328e-6) * ta * va**3 * d
        + (-6.21531254e-9) * ta * ta * va**3 * d
        + (-4.99410301e-6) * va**4 * d
        + (-1.89489258e-8) * ta * va**4 * d
        + (8.15300114e-8) * va**5 * d
        + (7.55043090e-4) * d * d
        + (-5.65095215e-5) * ta * d * d
        + (-4.52166564e-7) * ta * ta * d * d
        + (2.46688878e-8) * ta**3 * d * d
        + (2.42674348e-10) * ta**4 * d * d
        + (1.54547250e-4) * va * d * d
        + (5.24110970e-6) * ta * va * d * d
        + (-8.75874982e-8) * ta * ta * va * d * d
        + (-1.50743064e-9) * ta**3 * va * d * d
        + (-1.56236307e-5) * va * va * d * d
        + (-1.33895614e-7) * ta * va * va * d * d
        + (2.49709824e-9) * ta * ta * va * va * d * d
        + (6.51711721e-7) * va**3 * d * d
        + (1.94960053e-9) * ta * va**3 * d * d
        + (-1.00361113e-8) * va**4 * d * d
        + (-1.21206673e-5) * d**3
        + (-2.18203660e-7) * ta * d**3
        + (7.51269482e-9) * ta * ta * d**3
        + (9.79063848e-11) * ta**3 * d**3
        + (1.25006734e-6) * va * d**3
        + (-1.81584736e-9) * ta * va * d**3
        + (-3.52197671e-10) * ta * ta * va * d**3
        + (-3.36514630e-8) * va * va * d**3
        + (1.35908359e-10) * ta * va * va * d**3
        + (4.17032620e-10) * va**3 * d**3
        + (-1.30369025e-9) * d**4
        + (4.13908461e-10) * ta * d**4
        + (9.22652254e-12) * ta * ta * d**4
        + (-5.08220384e-9) * va * d**4
        + (-2.24730961e-11) * ta * va * d**4
        + (1.17139133e-10) * va * va * d**4
        + (6.62154879e-10) * d**5
        + (4.03863260e-13) * ta * d**5
        + (1.95087203e-12) * va * d**5
        + (-4.73602469e-12) * d**6
        + 5.12733497 * pa
        + (-0.312788561) * ta * pa
        + (-0.0196701861) * ta * ta * pa
        + (9.99690870e-4) * ta**3 * pa
        + (9.51738512e-6) * ta**4 * pa
        + (-4.66426341e-7) * ta**5 * pa
        + 0.548050612 * va * pa
        + (-0.00330552823) * ta * va * pa
        + (-0.00164119440) * ta * ta * va * pa
        + (-5.16670694e-6) * ta**3 * va * pa
        + (9.52692432e-7) * ta**4 * va * pa
        + (-0.0429223622) * va * va * pa
        + 0.00500845667 * ta * va * va * pa
        + (1.00601257e-6) * ta * ta * va * va * pa
        + (-1.81748644e-6) * ta**3 * va * va * pa
        + (-1.25813502e-3) * va**3 * pa
        + (-1.79330391e-4) * ta * va**3 * pa
        + (2.34994441e-6) * ta * ta * va**3 * pa
        + (1.29735808e-4) * va**4 * pa
        + (1.29064870e-6) * ta * va**4 * pa
        + (-2.28558686e-6) * va**5 * pa
        + (-0.0369476348) * d * pa
        + 0.00162325322 * ta * d * pa
        + (-3.14279680e-5) * ta * ta * d * pa
        + (2.59835559e-6) * ta**3 * d * pa
        + (-4.77136523e-8) * ta**4 * d * pa
        + (8.64203390e-3) * va * d * pa
        + (-6.87405181e-4) * ta * va * d * pa
        + (-9.13863872e-6) * ta * ta * va * d * pa
        + (5.15916806e-7) * ta**3 * va * d * pa
        + (-3.59217476e-5) * va * va * d * pa
        + (3.28696511e-5) * ta * va * va * d * pa
        + (-7.10542454e-7) * ta * ta * va * va * d * pa
        + (-1.24382300e-5) * va**3 * d * pa
        + (-7.38584400e-9) * ta * va**3 * d * pa
        + (2.20609296e-7) * va**4 * d * pa
        + (-7.32469180e-4) * d * d * pa
        + (-1.87381964e-5) * ta * d * d * pa
        + (4.80925239e-6) * ta * ta * d * d * pa
        + (-8.75492040e-8) * ta**3 * d * d * pa
        + (2.77862930e-5) * va * d * d * pa
        + (-5.06004592e-6) * ta * va * d * d * pa
        + (1.14325367e-7) * ta * ta * va * d * d * pa
        + (2.53016723e-6) * va * va * d * d * pa
        + (-1.72857035e-8) * ta * va * va * d * d * pa
        + (-3.95079398e-8) * va**3 * d * d * pa
        + (-3.59413173e-7) * d**3 * pa
        + (7.04388046e-7) * ta * d**3 * pa
        + (-1.89309167e-8) * ta * ta * d**3 * pa
        + (-4.79768731e-7) * va * d**3 * pa
        + (7.96079978e-9) * ta * va * d**3 * pa
        + (1.62897058e-9) * va * va * d**3 * pa
        + (3.94367674e-8) * d**4 * pa
        + (-1.18566247e-9) * ta * d**4 * pa
        + (3.34678041e-10) * va * d**4 * pa
        + (-1.15606447e-10) * d**5 * pa
        + (-2.80626406) * pa * pa
        + 0.548712484 * ta * pa * pa
        + (-0.00399428410) * ta * ta * pa * pa
        + (-9.54009191e-4) * ta**3 * pa * pa
        + (1.93090978e-5) * ta**4 * pa * pa
        + (-0.308806365) * va * pa * pa
        + 0.0116952364 * ta * va * pa * pa
        + (4.95271903e-4) * ta * ta * va * pa * pa
        + (-1.90710882e-5) * ta**3 * va * pa * pa
        + 0.00210787756 * va * va * pa * pa
        + (-6.98445738e-4) * ta * va * va * pa * pa
        + (2.30109073e-5) * ta * ta * va * va * pa * pa
        + (4.17856590e-4) * va**3 * pa * pa
        + (-1.27043871e-5) * ta * va**3 * pa * pa
        + (-3.04620472e-6) * va**4 * pa * pa
        + 0.0514507424 * d * pa * pa
        + (-0.00432510997) * ta * d * pa * pa
        + (8.99281156e-5) * ta * ta * d * pa * pa
        + (-7.14663943e-7) * ta**3 * d * pa * pa
        + (-2.66016305e-4) * va * d * pa * pa
        + (2.63789586e-4) * ta * va * d * pa * pa
        + (-7.01199003e-6) * ta * ta * va * d * pa * pa
        + (-1.06823306e-4) * va * va * d * pa * pa
        + (3.61341136e-6) * ta * va * va * d * pa * pa
        + (2.29748967e-7) * va**3 * d * pa * pa
        + (3.04788893e-4) * d * d * pa * pa
        + (-6.42070836e-5) * ta * d * d * pa * pa
        + (1.16257971e-6) * ta * ta * d * d * pa * pa
        + (7.68023384e-6) * va * d * d * pa * pa
        + (-5.47446896e-7) * ta * va * d * d * pa * pa
        + (-3.59937910e-8) * va * va * d * d * pa * pa
        + (-4.36497725e-6) * d**3 * pa * pa
        + (1.68737969e-7) * ta * d**3 * pa * pa
        + (2.67489271e-8) * va * d**3 * pa * pa
        + (3.23926897e-9) * d**4 * pa * pa
        + (-0.0353874123) * pa**3
        + (-0.221201190) * ta * pa**3
        + 0.0155126038 * ta * ta * pa**3
        + (-2.63917279e-4) * ta**3 * pa**3
        + 0.0453433455 * va * pa**3
        + (-0.00432943862) * ta * va * pa**3
        + (1.45389826e-4) * ta * ta * va * pa**3
        + (2.17508610e-4) * va * va * pa**3
        + (-6.66724702e-5) * ta * va * va * pa**3
        + (3.33217140e-5) * va**3 * pa**3
        + (-0.00226921615) * d * pa**3
        + (3.80261982e-4) * ta * d * pa**3
        + (-5.45314314e-9) * ta * ta * d * pa**3
        + (-7.96355448e-4) * va * d * pa**3
        + (2.53458034e-5) * ta * va * d * pa**3
        + (-6.31223658e-6) * va * va * d * pa**3
        + (3.02122035e-4) * d * d * pa**3
        + (-4.77403547e-6) * ta * d * d * pa**3
        + (1.73825715e-6) * va * d * d * pa**3
        + (-4.09087898e-7) * d**3 * pa**3
        + 0.614155345 * pa**4
        + (-0.0616755931) * ta * pa**4
        + 0.00133374846 * ta * ta * pa**4
        + 0.00355375387 * va * pa**4
        + (-5.13027851e-4) * ta * va * pa**4
        + (1.02449757e-4) * va * va * pa**4
        + (-0.00148526421) * d * pa**4
        + (-4.11469183e-5) * ta * d * pa**4
        + (-6.80434415e-6) * va * d * pa**4
        + (-9.77675906e-6) * d * d * pa**4
        + 0.0882773108 * pa**5
        + (-0.00301859306) * ta * pa**5
        + 0.00104452989 * va * pa**5
        + (2.47090539e-4) * d * pa**5
        + 0.00148348065 * pa**6
    )


def estimate_tmrt_c(tdb_c: float, shortwave_wm2: float | None, *, shade: bool = False) -> float:
    """Approximate mean radiant temperature from global shortwave (W/m²).

    Coefficient ~0.033 °C per W/m², capped at +25 °C (outdoor sun exposure).
    Shade → Tmrt ≈ air temperature.
    """
    if shade or shortwave_wm2 is None:
        return tdb_c
    delta = min(25.0, max(0.0, float(shortwave_wm2) * 0.033))
    return tdb_c + delta


def stress_category(utci_c: float) -> str:
    # Official UTCI stress categories (°C).
    if utci_c < -40:
        return "extreme_cold_stress"
    if utci_c < -27:
        return "very_strong_cold_stress"
    if utci_c < -13:
        return "strong_cold_stress"
    if utci_c < 0:
        return "moderate_cold_stress"
    if utci_c < 9:
        return "slight_cold_stress"
    if utci_c <= 26:
        return "no_thermal_stress"
    if utci_c <= 32:
        return "moderate_heat_stress"
    if utci_c <= 38:
        return "strong_heat_stress"
    if utci_c <= 46:
        return "very_strong_heat_stress"
    return "extreme_heat_stress"


def compute_utci(
    *,
    tdb_c: float,
    rh: float,
    wind_10m_ms: float,
    shortwave_wm2: float | None = None,
    shade: bool = False,
) -> UtciResult:
    tmrt = estimate_tmrt_c(tdb_c, shortwave_wm2, shade=shade)
    # UTCI wind applicability: clamp into [0.5, 17] for polynomial validity,
    # but record whether original was out of range.
    v_raw = max(0.0, float(wind_10m_ms))
    v = min(17.0, max(0.5, v_raw))
    rh_c = min(100.0, max(0.0, float(rh)))
    eh_pa = _saturation_vapor_pressure_hpa(tdb_c) * (rh_c / 100.0)
    pa_kpa = eh_pa / 10.0
    delta = tmrt - tdb_c
    in_range = (
        -50.0 <= tdb_c <= 50.0
        and -30.0 <= delta <= 70.0
        and 0.5 <= v_raw <= 17.0
        and 0.0 <= rh_c <= 100.0
        and 0.0 <= pa_kpa <= 5.0
    )
    utci_c = _utci_polynomial(tdb_c, v, delta, pa_kpa)
    return UtciResult(
        utci_c=round(utci_c, 1),
        stress_category=stress_category(utci_c),
        tdb_c=tdb_c,
        tmrt_c=round(tmrt, 1),
        wind_10m_ms=v_raw,
        rh=rh_c,
        in_range=in_range,
    )


def utci_to_sensation(utci_c: float) -> int:
    """Map UTCI °C onto product scale −3…+3 using official category edges."""
    if utci_c < -13:
        return -3
    if utci_c < 0:
        return -2
    if utci_c < 9:
        return -1
    if utci_c <= 26:
        return 0
    if utci_c <= 32:
        return 1
    if utci_c <= 38:
        return 2
    return 3
