from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from conftest import AIRPORTS_CSV, GAZETTEER_TXT
from flightwall_tools import airports, cities, zips


def test_parse_gazetteer_filters_and_sorts() -> None:
    rows = zips.parse_gazetteer(GAZETTEER_TXT)
    assert rows == [("00601", 18.180555, -66.749961), ("94110", 37.748495, -122.415291)]
    assert zips.parse_gazetteer("") == []


def test_render_zip_table_is_searchable() -> None:
    table = zips.render_zip_table([("94110", 37.748495, -122.415291)])
    assert table == "\n94110,37.7485,-122.4153\n"
    assert table.find("\n94110,") == 0


def test_build_zips(gazetteer_zip: Path, tmp_path: Path) -> None:
    out = tmp_path / "data" / "zips.txt"
    assert zips.build_zips(gazetteer_zip, out) == 2
    assert out.read_text(encoding="ascii") == "\n00601,18.1806,-66.7500\n94110,37.7485,-122.4153\n"


def test_select_airports() -> None:
    selected = airports.select_airports(AIRPORTS_CSV)
    assert [a["c"] for a in selected] == ["SFO", "SQL", "XYZ1"]
    sfo = selected[0]
    assert sfo == {
        "c": "SFO",
        "i": "KSFO",
        "n": "San Francisco International Airport",
        "m": "San Francisco",
        "lat": 37.619,
        "lon": -122.375,
        "s": "L",
    }
    assert selected[1]["i"] == "KSQL"
    assert selected[2]["i"] == "XYZ1"
    assert airports.select_airports(AIRPORTS_CSV, country="GB")[0]["c"] == "LHR"


def test_build_airports(tmp_path: Path) -> None:
    src = tmp_path / "airports.csv"
    src.write_text(AIRPORTS_CSV, encoding="utf-8")
    out = tmp_path / "out" / "airports.json"
    assert airports.build_airports(src, out) == 3
    assert len(json.loads(out.read_text(encoding="utf-8"))["airports"]) == 3


def test_select_cities(places_geojson: dict[str, Any]) -> None:
    selected = cities.select_cities(places_geojson)
    assert selected == [
        {"n": "Bigcity", "a": "State", "lat": 40.5432, "lon": -100.1235, "p": 500000}
    ]
    assert [c["n"] for c in cities.select_cities(places_geojson, min_population=0)] == [
        "Bigcity",
        "Smalltown",
        "Nopop",
    ]


def test_build_cities(tmp_path: Path, places_geojson: dict[str, Any]) -> None:
    src = tmp_path / "places.geojson"
    src.write_text(json.dumps(places_geojson), encoding="utf-8")
    out = tmp_path / "out" / "cities.json"
    assert cities.build_cities(src, out) == 1
    assert json.loads(out.read_text(encoding="utf-8"))["cities"][0]["n"] == "Bigcity"
