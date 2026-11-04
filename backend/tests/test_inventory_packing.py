from app.schemas.analyze import ClimateSummary
from app.services.planner import _rule_based_plan


def test_owned_spf_skips_duplicate() -> None:
    climate = ClimateSummary(
        home_city="Москва",
        destination_city="Анталия",
        home_temp_c=5,
        destination_temp_c=28,
        home_humidity=70,
        destination_humidity=55,
        destination_uv=8,
        delta_temp_c=23,
        delta_humidity=-15,
        risks=["высокий UV"],
    )
    plan = _rule_based_plan(
        mode="pre_trip",
        climate=climate,
        skin_type="Нормальная",
        concerns="Сухость",
        trip_start="2026-11-10",
        trip_end="2026-11-17",
        owned_items="SPF, Cleanser",
        avoid_items="Acids",
    )
    take = [i.item.lower() for i in plan.packing_kit if i.action == "take"]
    skip_reasons = " ".join(i.reason.lower() for i in plan.packing_kit if i.action == "skip")
    assert not any("spf" in t for t in take)
    assert "кейсе" in skip_reasons or "избегать" in skip_reasons
    assert plan.owned_items
    assert "Acids" in plan.avoid_items or "acids" in [a.lower() for a in plan.avoid_items]


def test_return_home_plan_steps() -> None:
    climate = ClimateSummary(
        home_city="Анталия",
        destination_city="Москва",
        home_temp_c=28,
        destination_temp_c=5,
        delta_temp_c=-23,
        risks=["похолодание"],
    )
    plan = _rule_based_plan(
        mode="return_home",
        climate=climate,
        skin_type="Комбинированная",
        concerns="Сухость",
        trip_start="",
        trip_end="",
    )
    assert plan.mode == "return_home"
    assert any("стабилизац" in s.title.lower() or "день" in s.title.lower() for s in plan.care_plan)
