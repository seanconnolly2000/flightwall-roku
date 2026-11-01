"""Public data sources used to build the bundled map and lookup data."""

from __future__ import annotations

import urllib.request
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

USER_AGENT = "FlightWall-tools/1.0"
NATURAL_EARTH = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"

Fetcher = Callable[[str], bytes]


@dataclass(frozen=True)
class Source:
    name: str
    url: str
    filename: str
    license_note: str


SOURCES: dict[str, Source] = {
    "land": Source(
        "Natural Earth 1:10m land polygons",
        NATURAL_EARTH + "ne_10m_land.geojson",
        "ne_10m_land.geojson",
        "Public domain",
    ),
    "lakes": Source(
        "Natural Earth 1:10m lakes",
        NATURAL_EARTH + "ne_10m_lakes.geojson",
        "ne_10m_lakes.geojson",
        "Public domain",
    ),
    "places": Source(
        "Natural Earth 1:10m populated places (simple)",
        NATURAL_EARTH + "ne_10m_populated_places_simple.geojson",
        "ne_10m_populated_places_simple.geojson",
        "Public domain",
    ),
    "airports": Source(
        "OurAirports airports.csv",
        "https://davidmegginson.github.io/ourairports-data/airports.csv",
        "airports.csv",
        "Public domain (unlicense)",
    ),
    "airlines": Source(
        "OpenFlights airlines.dat",
        "https://raw.githubusercontent.com/jpatokal/openflights/master/data/airlines.dat",
        "airlines.dat",
        "Open Database License (ODbL)",
    ),
    "zcta": Source(
        "US Census Bureau 2023 ZCTA gazetteer",
        "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2023_Gazetteer/"
        "2023_Gaz_zcta_national.zip",
        "2023_Gaz_zcta_national.zip",
        "US government work, public domain",
    ),
}


def http_fetch(url: str) -> bytes:
    """Download one URL over HTTPS and return the body."""
    if not url.startswith("https://"):
        msg = f"refusing to fetch non-HTTPS url: {url}"
        raise ValueError(msg)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=180) as response:
        return bytes(response.read())


def ensure(source: Source, cache_dir: Path, fetch: Fetcher = http_fetch) -> Path:
    """Return the cached file for a source, downloading it first if needed."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    path = cache_dir / source.filename
    if not path.exists():
        path.write_bytes(fetch(source.url))
    return path
