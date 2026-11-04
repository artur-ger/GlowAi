from app.services.geocoding import _name_related, _query_variants


def test_antalya_cyrillic_variants_include_latin() -> None:
    variants = _query_variants("Анталья")
    lower = [v.lower() for v in variants]
    assert any("antalya" in v for v in lower)
    assert any("анталия" in v or "анталья" in v for v in lower)


def test_name_related_filters_false_positives() -> None:
    assert _name_related("Antalya", "Анталия")
    assert not _name_related("Antalya", "Sharjah")
