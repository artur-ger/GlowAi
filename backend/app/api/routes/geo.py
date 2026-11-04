from __future__ import annotations

import httpx
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from app.services.geocoding import PlaceHitData, popular_places, search_places

router = APIRouter(prefix="/api/v1/geo", tags=["geo"])


class PlaceHit(BaseModel):
    name: str
    country: str
    country_code: str
    admin1: str | None = None
    latitude: float
    longitude: float
    label: str


class PlaceSearchResponse(BaseModel):
    query: str
    country_code: str | None = None
    results: list[PlaceHit] = Field(default_factory=list)
    suggestions: list[PlaceHit] = Field(
        default_factory=list,
        description="Города с тем же запросом в других странах (если фильтр страны пуст)",
    )
    source: str = "open-meteo"


class PopularPlacesResponse(BaseModel):
    country_code: str
    results: list[PlaceHit] = Field(default_factory=list)
    source: str = "open-meteo"


def _to_model(hit: PlaceHitData) -> PlaceHit:
    return PlaceHit(
        name=hit.name,
        country=hit.country,
        country_code=hit.country_code,
        admin1=hit.admin1,
        latitude=hit.latitude,
        longitude=hit.longitude,
        label=hit.label,
    )


@router.get("/places", response_model=PlaceSearchResponse)
async def places_search(
    q: str = Query(..., min_length=1, max_length=80, description="Название города"),
    country_code: str | None = Query(
        None,
        min_length=2,
        max_length=2,
        description="ISO-3166-1 alpha-2, например RU / TR / AE",
    ),
    limit: int = Query(12, ge=1, le=30),
) -> PlaceSearchResponse:
    """Поиск города через Open-Meteo Geocoding (+ транслит / Nominatim fallback)."""
    try:
        results, suggestions = await search_places(
            q, country_code=country_code, limit=limit
        )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Geocoding upstream error: {exc}") from exc

    return PlaceSearchResponse(
        query=q.strip(),
        country_code=country_code.strip().upper() if country_code else None,
        results=[_to_model(h) for h in results],
        suggestions=[_to_model(h) for h in suggestions],
        source="open-meteo",
    )


@router.get("/popular", response_model=PopularPlacesResponse)
async def places_popular(
    country_code: str = Query(..., min_length=2, max_length=2),
    limit: int = Query(10, ge=1, le=20),
) -> PopularPlacesResponse:
    """Популярные города страны: имена-запросы → живой Open-Meteo (координаты не хардкод)."""
    code = country_code.strip().upper()
    try:
        results = await popular_places(code, limit=limit)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Geocoding upstream error: {exc}") from exc
    return PopularPlacesResponse(
        country_code=code,
        results=[_to_model(h) for h in results],
        source="open-meteo",
    )
