from scripts.geography.country_mapping import resolve_country_code


def test_regular_country_keeps_iso2_code():
    assert resolve_country_code(
        {
            "ISO_A2_EH": "PT",
            "GEOUNIT": "Portugal",
        }
    ) == "PT"


def test_us_mainland_keeps_us_code():
    assert resolve_country_code(
        {
            "ISO_A2_EH": "US",
            "GEOUNIT": "United States of America",
        }
    ) == "US"


def test_minor_outlying_island_maps_to_um():
    assert resolve_country_code(
        {
            "ISO_A2_EH": "US",
            "GEOUNIT": "Wake Atoll",
        }
    ) == "UM"


def test_invalid_code_returns_none():
    assert resolve_country_code(
        {
            "ISO_A2_EH": "-99",
            "GEOUNIT": "Unknown",
        }
    ) is None