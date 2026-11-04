from __future__ import annotations

import logging
import re
from dataclasses import dataclass

import httpx

logger = logging.getLogger(__name__)

OPEN_METEO_GEOCODE = "https://geocoding-api.open-meteo.com/v1/search"
NOMINATIM_SEARCH = "https://nominatim.openstreetmap.org/search"

# Подсказки для «популярных» городов: только имена-запросы.
# Координаты и официальные названия всегда приходят из Open-Meteo.
POPULAR_CITY_QUERIES: dict[str, list[str]] = {
    "RU": ["Moscow", "Saint Petersburg", "Sochi", "Kazan", "Kaliningrad"],
    "TR": ["Antalya", "Istanbul", "Bodrum", "Alanya", "Side", "Marmaris", "Ankara"],
    "AE": ["Dubai", "Abu Dhabi", "Sharjah", "Ajman", "Ras Al Khaimah"],
    "EG": ["Cairo", "Hurghada", "Sharm El Sheikh", "Alexandria"],
    "TH": ["Bangkok", "Phuket", "Pattaya", "Chiang Mai", "Samui"],
    "ID": ["Bali", "Jakarta", "Denpasar", "Ubud"],
    "GE": ["Tbilisi", "Batumi", "Kutaisi"],
    "GR": ["Athens", "Crete", "Rhodes", "Santorini", "Thessaloniki"],
    "CY": ["Limassol", "Larnaca", "Paphos", "Nicosia"],
    "IT": ["Rome", "Milan", "Venice", "Florence", "Naples"],
    "ES": ["Barcelona", "Madrid", "Malaga", "Valencia", "Seville"],
    "FR": ["Paris", "Nice", "Lyon", "Marseille"],
    "DE": ["Berlin", "Munich", "Hamburg", "Frankfurt"],
    "US": ["New York", "Los Angeles", "Miami", "Chicago", "San Francisco"],
    "GB": ["London", "Manchester", "Edinburgh"],
    "MV": ["Male", "Maldives"],
    "QA": ["Doha"],
    "SA": ["Riyadh", "Jeddah", "Mecca"],
    "CN": ["Beijing", "Shanghai", "Guangzhou"],
    "JP": ["Tokyo", "Osaka", "Kyoto"],
    "KR": ["Seoul", "Busan"],
    "VN": ["Ho Chi Minh City", "Hanoi", "Da Nang", "Nha Trang"],
    "IN": ["Goa", "Delhi", "Mumbai", "Bangalore"],
    "KZ": ["Almaty", "Astana"],
    "UZ": ["Tashkent", "Samarkand", "Bukhara"],
    "AM": ["Yerevan"],
    "AZ": ["Baku"],
    "IL": ["Tel Aviv", "Jerusalem", "Eilat"],
    "MA": ["Marrakesh", "Casablanca", "Agadir"],
    "TN": ["Tunis", "Sousse", "Djerba"],
    "PT": ["Lisbon", "Porto", "Faro"],
    "PL": ["Warsaw", "Krakow", "Gdansk"],
    "CZ": ["Prague"],
    "AT": ["Vienna", "Salzburg"],
    "CH": ["Zurich", "Geneva"],
    "NL": ["Amsterdam"],
    "AU": ["Sydney", "Melbourne", "Brisbane"],
    "MX": ["Cancun", "Mexico City", "Tulum"],
    "BR": ["Rio de Janeiro", "Sao Paulo"],
    "ZA": ["Cape Town", "Johannesburg"],
}

_CYR_TO_LAT = {
    "а": "a",
    "б": "b",
    "в": "v",
    "г": "g",
    "д": "d",
    "е": "e",
    "ё": "e",
    "ж": "zh",
    "з": "z",
    "и": "i",
    "й": "y",
    "к": "k",
    "л": "l",
    "м": "m",
    "н": "n",
    "о": "o",
    "п": "p",
    "р": "r",
    "с": "s",
    "т": "t",
    "у": "u",
    "ф": "f",
    "х": "kh",
    "ц": "ts",
    "ч": "ch",
    "ш": "sh",
    "щ": "shch",
    "ъ": "",
    "ы": "y",
    "ь": "",
    "э": "e",
    "ю": "yu",
    "я": "ya",
}

# Частые русские написания курортов → запрос, который понимает Open-Meteo
_ALIAS_QUERIES: dict[str, list[str]] = {
    "анталья": ["Antalya", "Анталия"],
    "анталия": ["Antalya", "Анталия"],
    "стамбул": ["Istanbul", "Стамбул"],
    "истанбул": ["Istanbul"],
    "дубай": ["Dubai", "Дубай"],
    "дубаи": ["Dubai"],
    "абу-даби": ["Abu Dhabi"],
    "абу даби": ["Abu Dhabi"],
    "шарм": ["Sharm El Sheikh"],
    "шарм-эль-шейх": ["Sharm El Sheikh"],
    "хургада": ["Hurghada"],
    "пхукет": ["Phuket"],
    "паттайя": ["Pattaya"],
    "паттая": ["Pattaya"],
    "бали": ["Bali", "Denpasar"],
    "баттуми": ["Batumi"],
    "батуми": ["Batumi"],
    "тбилиси": ["Tbilisi"],
}


@dataclass(frozen=True)
class PlaceHitData:
    name: str
    country: str
    country_code: str
    admin1: str | None
    latitude: float
    longitude: float
    label: str
    population: int = 0


def _transliterate_ru(text: str) -> str:
    out: list[str] = []
    for ch in text.lower():
        if ch in _CYR_TO_LAT:
            out.append(_CYR_TO_LAT[ch])
        else:
            out.append(ch)
    return "".join(out)


def _query_variants(q: str) -> list[str]:
    raw = q.strip()
    if not raw:
        return []
    variants: list[str] = [raw]
    key = raw.lower().replace("ё", "е")
    for alias in _ALIAS_QUERIES.get(key, []):
        if alias not in variants:
            variants.append(alias)
    # мягкий знак / и↔ь для курортов вроде Анталья/Анталия
    if re.search(r"[а-яё]", key):
        swapped = key.replace("ья", "ия").replace("ьи", "ии")
        if swapped != key and swapped.capitalize() not in variants:
            variants.append(swapped if swapped[:1].islower() else swapped)
            # keep original casing style loosely
            variants.append(swapped[0].upper() + swapped[1:] if swapped else swapped)
        latin = _transliterate_ru(raw)
        if latin and latin.lower() != key and latin not in variants:
            variants.append(latin)
            # title-ish
            variants.append(latin[0].upper() + latin[1:] if len(latin) > 1 else latin.upper())
    # unique preserve order
    seen: set[str] = set()
    ordered: list[str] = []
    for v in variants:
        vv = v.strip()
        if not vv:
            continue
        low = vv.lower()
        if low in seen:
            continue
        seen.add(low)
        ordered.append(vv)
    return ordered[:8]


_CITY_FEATURE_CODES = {
    "PPL",
    "PPLA",
    "PPLA2",
    "PPLA3",
    "PPLA4",
    "PPLC",
    "PPLG",
    "PPLS",
    "PPLX",
}


def _item_to_hit(item: dict, *, cities_only: bool = False) -> PlaceHitData | None:
    name = str(item.get("name") or "").strip()
    if not name:
        return None
    feature = str(item.get("feature_code") or "").upper()
    if cities_only and feature and feature not in _CITY_FEATURE_CODES:
        return None
    country = str(item.get("country") or "").strip()
    code = str(item.get("country_code") or "").strip().upper()
    admin1 = item.get("admin1")
    admin = str(admin1).strip() if admin1 else None
    label_parts = [name]
    if admin:
        label_parts.append(admin)
    if country:
        label_parts.append(country)
    try:
        lat = float(item["latitude"])
        lon = float(item["longitude"])
    except (KeyError, TypeError, ValueError):
        return None
    pop = 0
    try:
        pop = int(item.get("population") or 0)
    except (TypeError, ValueError):
        pop = 0
    return PlaceHitData(
        name=name,
        country=country or code or "—",
        country_code=code,
        admin1=admin,
        latitude=lat,
        longitude=lon,
        label=", ".join(label_parts),
        population=pop,
    )


def _merge_hits(rows: list[PlaceHitData], limit: int) -> list[PlaceHitData]:
    seen: set[tuple[str, str, float, float]] = set()
    out: list[PlaceHitData] = []
    for hit in sorted(rows, key=lambda h: (-h.population, h.name)):
        key = (hit.name.lower(), hit.country_code, round(hit.latitude, 3), round(hit.longitude, 3))
        if key in seen:
            continue
        seen.add(key)
        out.append(hit)
        if len(out) >= limit:
            break
    return out


async def _open_meteo_search(
    client: httpx.AsyncClient,
    name: str,
    *,
    country_code: str | None,
    limit: int,
    cities_only: bool = False,
) -> list[PlaceHitData]:
    params: dict[str, object] = {
        "name": name,
        "count": max(limit, 5),
        "language": "ru",
        "format": "json",
    }
    if country_code:
        params["countryCode"] = country_code.upper()
    response = await client.get(OPEN_METEO_GEOCODE, params=params)
    response.raise_for_status()
    data = response.json()
    hits: list[PlaceHitData] = []
    for item in data.get("results") or []:
        hit = _item_to_hit(item, cities_only=cities_only)
        if hit:
            hits.append(hit)
        if len(hits) >= limit:
            break
    return hits


async def _nominatim_search(
    client: httpx.AsyncClient,
    name: str,
    *,
    country_code: str | None,
    limit: int,
) -> list[PlaceHitData]:
    params: dict[str, object] = {
        "q": name,
        "format": "json",
        "addressdetails": 1,
        "limit": limit,
        "featuretype": "city",
    }
    if country_code:
        params["countrycodes"] = country_code.lower()
    response = await client.get(
        NOMINATIM_SEARCH,
        params=params,
        headers={"User-Agent": "GlowAi-MVP/1.0 (travel skincare; local)"},
    )
    response.raise_for_status()
    data = response.json()
    hits: list[PlaceHitData] = []
    for item in data or []:
        address = item.get("address") or {}
        city_name = (
            address.get("city")
            or address.get("town")
            or address.get("village")
            or address.get("municipality")
            or item.get("name")
            or ""
        )
        city_name = str(city_name).strip()
        if not city_name:
            continue
        code = str(address.get("country_code") or "").upper()
        country = str(address.get("country") or code or "—")
        admin = address.get("state") or address.get("region")
        try:
            lat = float(item["lat"])
            lon = float(item["lon"])
        except (KeyError, TypeError, ValueError):
            continue
        label_parts = [city_name]
        if admin:
            label_parts.append(str(admin))
        label_parts.append(country)
        hits.append(
            PlaceHitData(
                name=city_name,
                country=country,
                country_code=code,
                admin1=str(admin) if admin else None,
                latitude=lat,
                longitude=lon,
                label=", ".join(label_parts),
                population=0,
            )
        )
    return hits


def _name_related(query: str, place_name: str) -> bool:
    """Грубый фильтр ложных совпадений Nominatim (кириллица ≠ случайный город)."""
    q = re.sub(r"[^a-zа-яё0-9]+", "", query.lower().replace("ё", "е"))
    n = re.sub(r"[^a-zа-яё0-9]+", "", place_name.lower().replace("ё", "е"))
    if not q or not n:
        return False
    if q in n or n in q:
        return True
    q_lat = re.sub(r"[^a-z0-9]+", "", _transliterate_ru(query).lower())
    n_lat = re.sub(r"[^a-z0-9]+", "", _transliterate_ru(place_name).lower())
    if q_lat and n_lat and (q_lat in n_lat or n_lat in q_lat):
        return True
    # общий префикс ≥ 4 символов
    prefix = 0
    for a, b in zip(q_lat or q, n_lat or n):
        if a != b:
            break
        prefix += 1
    return prefix >= 4


async def search_places(
    query: str,
    *,
    country_code: str | None = None,
    limit: int = 12,
) -> tuple[list[PlaceHitData], list[PlaceHitData]]:
    """Возвращает (результаты в стране/мире, подсказки из других стран)."""
    variants = _query_variants(query)
    if not variants:
        return [], []

    code = country_code.strip().upper() if country_code else None
    gathered: list[PlaceHitData] = []
    elsewhere: list[PlaceHitData] = []

    async with httpx.AsyncClient(timeout=20.0) as client:
        # 1) Open-Meteo в выбранной стране (и варианты написания)
        for variant in variants:
            try:
                hits = await _open_meteo_search(
                    client, variant, country_code=code, limit=limit
                )
                gathered.extend(hits)
            except httpx.HTTPError as exc:
                logger.warning("open-meteo search failed for %s: %s", variant, exc)
            if len(gathered) >= limit:
                break

        # 2) Если пусто при фильтре страны — ищем мир и кладём в suggestions
        if code and not gathered:
            for variant in variants[:4]:
                try:
                    hits = await _open_meteo_search(
                        client,
                        variant,
                        country_code=None,
                        limit=limit,
                        cities_only=True,
                    )
                    for hit in hits:
                        if hit.country_code == code:
                            gathered.append(hit)
                        else:
                            elsewhere.append(hit)
                except httpx.HTTPError:
                    continue
                if elsewhere or gathered:
                    break

        # 3) Nominatim только если совсем пусто; только latin-варианты + проверка имени
        if not gathered and not elsewhere:
            latin_variants = [
                v for v in variants if re.search(r"[A-Za-z]", v) and not re.search(r"[А-Яа-яЁё]", v)
            ] or variants[:2]
            for variant in latin_variants[:3]:
                try:
                    hits = await _nominatim_search(
                        client, variant, country_code=code, limit=limit
                    )
                    related = [h for h in hits if _name_related(variant, h.name)]
                    gathered.extend(related)
                except httpx.HTTPError as exc:
                    logger.warning("nominatim search failed for %s: %s", variant, exc)
                if gathered:
                    break

    return _merge_hits(gathered, limit), _merge_hits(elsewhere, limit)


async def popular_places(country_code: str, *, limit: int = 12) -> list[PlaceHitData]:
    code = country_code.strip().upper()
    seeds = POPULAR_CITY_QUERIES.get(code) or []
    if not seeds:
        # Без хардкода: берём столицу/крупные через короткий латинский префикс страны
        # Open-Meteo плохо отвечает на 1 букву — пробуем известные короткие запросы
        seeds = [code.lower()]

    gathered: list[PlaceHitData] = []
    async with httpx.AsyncClient(timeout=20.0) as client:
        for seed in seeds:
            try:
                hits = await _open_meteo_search(
                    client,
                    seed,
                    country_code=code,
                    limit=3,
                    cities_only=True,
                )
                if hits:
                    # один лучший город на seed (по населению)
                    best = max(hits, key=lambda h: (h.population, h.name))
                    gathered.append(best)
            except httpx.HTTPError as exc:
                logger.warning("popular geocode failed %s/%s: %s", code, seed, exc)
            if len(gathered) >= limit:
                break
    return _merge_hits(gathered, limit)
