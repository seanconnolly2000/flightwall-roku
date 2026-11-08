"""Select major US cities from Natural Earth populated places for map labels."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .geometry import iter_points

DEFAULT_MIN_POPULATION = 100_000


def select_cities(
    geojson: dict[str, Any], min_population: int = DEFAULT_MIN_POPULATION, country: str = "USA"
) -> list[dict[str, Any]]:
    cities: list[dict[str, Any]] = []
    for props, (lon, lat) in iter_points(geojson):
        population = int(props.get("pop_max") or 0)
        if props.get("adm0_a3") != country or population < min_population:
            continue
        cities.append(
            {
                "n": props.get("name") or "",
                "a": props.get("adm1name") or "",
                "lat": round(lat, 4),
                "lon": round(lon, 4),
                "p": population,
            }
        )
    cities.sort(key=lambda c: (-c["p"], c["n"]))
    return cities


def build_cities(
    geojson_path: Path, out_path: Path, min_population: int = DEFAULT_MIN_POPULATION
) -> int:
    geojson = json.loads(geojson_path.read_text(encoding="utf-8"))
    cities = select_cities(geojson, min_population)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps({"cities": cities}, separators=(",", ":")), encoding="utf-8")
    return len(cities)
