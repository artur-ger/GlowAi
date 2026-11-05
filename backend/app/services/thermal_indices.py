"""Supporting outdoor thermal indices + ISO 11079-style IREQ (required clo).

UTCI remains the primary comfort line; PET / HI / Humidex / Wind Chill are
secondary supports for confidence and explanation (PDF §8.1 / §8.6).
"""

from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass(frozen=True)
class SupportIndices:
    pet_c: float | None
    heat_index_c: float | None
    humidex_c: float | None
    wind_chill_c: float | None
    ireq_clo: float
    met_w_m2: float


def heat_index_c(tdb_c: float, rh: float) -> float | None:
    """NWS Rothfusz regression; valid mainly for T≥27°C, RH≥40% — else None."""
    if tdb_c < 27 or rh < 40:
        return None
    t = tdb_c * 9 / 5 + 32
    r = rh
    hi = (
        -42.379
        + 2.04901523 * t
        + 10.14333127 * r
        - 0.22475541 * t * r
        - 6.83783e-3 * t * t
        - 5.481717e-2 * r * r
        + 1.22874e-3 * t * t * r
        + 8.5282e-4 * t * r * r
        - 1.99e-6 * t * t * r * r
    )
    return round((hi - 32) * 5 / 9, 1)


def humidex_c(tdb_c: float, rh: float) -> float:
    """Canadian Humidex (°C-equivalent)."""
    # Dewpoint via Magnus
    a, b = 17.27, 237.7
    alpha = ((a * tdb_c) / (b + tdb_c)) + math.log(max(rh, 1e-6) / 100.0)
    td = (b * alpha) / (a - alpha)
    e = 6.11 * math.exp(5417.7530 * ((1 / 273.16) - (1 / (273.15 + td))))
    return round(tdb_c + 0.5555 * (e - 10.0), 1)


def wind_chill_c(tdb_c: float, wind_10m_ms: float) -> float | None:
    """Environment Canada wind chill; T≤10°C and wind≥1.3 m/s at 10 m."""
    if tdb_c > 10 or wind_10m_ms < 1.3:
        return None
    v_kmh = wind_10m_ms * 3.6
    wc = (
        13.12
        + 0.6215 * tdb_c
        - 11.37 * (v_kmh**0.16)
        + 0.3965 * tdb_c * (v_kmh**0.16)
    )
    return round(wc, 1)


def pet_approx_c(tdb_c: float, tmrt_c: float, wind_10m_ms: float, rh: float) -> float:
    """Simplified outdoor PET proxy (°C).

    Full MEMI/PET needs a multi-node solver; for MVP we use a published-style
    linear blend of operative temperature with humidity and wind corrections
    calibrated to track UTCI within a few °C in temperate ranges.
    """
    v = max(0.1, min(wind_10m_ms, 17.0))
    to = 0.5 * (tdb_c + tmrt_c)
    # Humidity load (~vapour pressure effect)
    es = 6.112 * math.exp((17.67 * tdb_c) / (tdb_c + 243.5))
    ea = es * (rh / 100.0)
    humid_corr = 0.07 * (ea - 12.0)
    wind_corr = -1.4 * math.log1p(v)
    rad_corr = 0.15 * (tmrt_c - tdb_c)
    return round(to + humid_corr + wind_corr + rad_corr, 1)


def metabolic_rate_w_m2(activity: str) -> float:
    # ISO 8996-ish outdoor bands
    if activity == "high":
        return 180.0  # brisk walk / light sport
    if activity == "low":
        return 90.0  # standing / slow stroll
    return 115.0  # walking


def ireq_clo(
    *,
    tdb_c: float,
    tmrt_c: float,
    wind_10m_ms: float,
    activity: str,
) -> float:
    """Required clothing insulation (clo) — ISO 11079 spirit (IREQ-min approx).

    Analytic outdoor approximation used when a full iterative IREQ solver is
    unavailable: balance metabolic heat against convective/radiative loss at
    skin temperature ~34°C, convert resistance to clo (1 clo = 0.155 m²K/W).
    """
    m = metabolic_rate_w_m2(activity)
    # External work ~0 for walking advice; respiratory/evaporative share ~0.2 M
    h_dry_needed = max(20.0, 0.8 * m)
    t_sk = 34.0
    t_op = 0.5 * (tdb_c + tmrt_c)
    v = max(0.2, min(wind_10m_ms, 12.0))
    # Clothing surface convection rises with wind (m/s → W/m²K order)
    hc = 8.7 * (v**0.6)
    hr = 4.7  # linearised radiation
    h_total = hc + hr
    # Required intrinsic clothing resistance (m²K/W)
    if h_dry_needed <= 1e-6:
        return 0.3
    r_req = (t_sk - t_op) / h_dry_needed
    # Parallel path through clothing + boundary layer
    r_a = 1.0 / max(h_total, 1.0)
    r_cl = max(0.0, r_req - 0.7 * r_a)
    clo = r_cl / 0.155
    return round(max(0.2, min(3.0, clo)), 2)


def clothing_rows_for_clo(target_clo: float, lang: str) -> list[tuple[str, str, str, float]]:
    """Map required clo → garment whitelist rows (id-stable EN keys for LLM)."""
    ru = lang != "en"
    if target_clo >= 2.0:
        rows = [
            ("thermal_base", "термобельё", "thermal base", "base", 0.4),
            ("insulated_mid", "утеплённый mid-layer", "insulated mid-layer", "mid", 0.6),
            ("winter_parka", "зимняя парка", "winter parka", "outer", 1.0),
            ("cold_accessories", "шапка, перчатки, шарф", "hat, gloves, scarf", "accessories", 0.2),
        ]
    elif target_clo >= 1.4:
        rows = [
            ("warm_knit", "плотная кофта", "warm knit", "mid", 0.5),
            ("insulated_jacket", "утеплённая куртка", "insulated jacket", "outer", 0.9),
            ("closed_shoes", "закрытая обувь", "closed shoes", "accessories", 0.1),
        ]
    elif target_clo >= 0.9:
        rows = [
            ("long_sleeve", "лонгслив", "long sleeve", "base", 0.3),
            ("sweater_fleece", "свитер или флис", "sweater or fleece", "mid", 0.4),
            ("light_jacket", "лёгкая куртка", "light jacket", "outer", 0.4),
        ]
    elif target_clo >= 0.55:
        rows = [
            ("tee_shirt", "футболка / рубашка", "t-shirt / shirt", "base", 0.3),
            ("spare_light", "лёгкий верх на всякий случай", "light spare top", "mid", 0.3),
        ]
    elif target_clo >= 0.35:
        rows = [
            ("light_tee", "лёгкая футболка", "light t-shirt", "base", 0.25),
            ("sun_hat", "головной убор от солнца", "sun hat", "accessories", 0.1),
        ]
    else:
        rows = [
            ("minimal", "максимально лёгкая одежда", "lightest clothing", "base", 0.2),
            ("shade_hat", "головной убор и тень", "hat and shade", "accessories", 0.1),
        ]
    return [
        (cid, (a if ru else b), layer, clo_i)
        for cid, a, b, layer, clo_i in rows
    ]


def compute_support(
    *,
    tdb_c: float,
    rh: float,
    wind_10m_ms: float,
    tmrt_c: float,
    activity: str,
) -> SupportIndices:
    return SupportIndices(
        pet_c=pet_approx_c(tdb_c, tmrt_c, wind_10m_ms, rh),
        heat_index_c=heat_index_c(tdb_c, rh),
        humidex_c=humidex_c(tdb_c, rh),
        wind_chill_c=wind_chill_c(tdb_c, wind_10m_ms),
        ireq_clo=ireq_clo(
            tdb_c=tdb_c, tmrt_c=tmrt_c, wind_10m_ms=wind_10m_ms, activity=activity
        ),
        met_w_m2=metabolic_rate_w_m2(activity),
    )
