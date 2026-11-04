from __future__ import annotations

from app.schemas.analyze import ClimateSummary


def tip_from_climate(climate: ClimateSummary, *, status: str = "on_site") -> str:
    uv = climate.destination_uv
    hum = climate.destination_humidity
    temp = climate.destination_temp_c
    parts: list[str] = []

    if status == "return_home":
        parts.append("День адаптации дома: только база (очищение → увлажнение → SPF), без новых активов.")
    elif status == "pre_trip":
        parts.append("До поездки: соберите travel-kit и не начинайте новые кислоты/ретиноид за 3–5 дней.")
    else:
        parts.append("На месте: держите короткий travel-план без новинок.")

    if uv is not None and uv >= 7:
        parts.append(f"UV {uv:.1f} — обновляйте SPF каждые 2–3 часа на солнце.")
    elif uv is not None and uv >= 4:
        parts.append(f"UV {uv:.1f} — SPF утром и при долгом выходе.")

    if hum is not None and hum <= 40:
        parts.append(f"Влажность ~{hum:.0f}% — усильте увлажнение / mist.")
    elif hum is not None and hum >= 75:
        parts.append(f"Влажность ~{hum:.0f}% — лёгкие текстуры, не перегружайте кремом.")

    if temp is not None and temp >= 30:
        parts.append(f"Жарко (~{temp:.0f}°): меньше плотных средств, больше воды.")
    elif temp is not None and temp <= 5:
        parts.append(f"Холодно (~{temp:.0f}°): барьерный крем, не пересушивайте очищением.")

    return " ".join(parts)
