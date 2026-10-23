"""Country-code normalization for Natural Earth map units."""

MINOR_OUTLYING_ISLANDS = frozenset(
    {
        "Johnston Atoll",
        "Jarvis Island",
        "Baker Island",
        "Howland Island",
        "Wake Atoll",
        "Midway Islands",
        "Navassa Island",
        "Palmyra Atoll",
        "Kingman Reef",
    }
)


def resolve_country_code(properties: dict) -> str | None:
    """Resolve a Natural Earth map unit to a BeenAround ISO2 code."""

    code = properties.get("ISO_A2_EH")
    geounit = properties.get("GEOUNIT")

    if not isinstance(code, str):
        return None

    code = code.strip().upper()

    if code == "US" and geounit in MINOR_OUTLYING_ISLANDS:
        return "UM"

    if len(code) != 2 or code == "-99":
        return None

    return code