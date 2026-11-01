"""Shared fixtures: tiny synthetic data sets and a minimal valid channel tree."""

from __future__ import annotations

import io
import json
import zipfile
from pathlib import Path
from typing import Any

import pytest
from PIL import Image


def square(lon0: float, lat0: float, lon1: float, lat1: float) -> list[list[float]]:
    return [[lon0, lat0], [lon1, lat0], [lon1, lat1], [lon0, lat1], [lon0, lat0]]


@pytest.fixture
def land_geojson() -> dict[str, Any]:
    """Land covering the eastern half of a 2x1 degree region (lon 0..2, lat 0..1)."""
    return {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "properties": {},
                "geometry": {"type": "Polygon", "coordinates": [square(1.0, -1.0, 3.0, 2.0)]},
            },
            {
                "type": "Feature",
                "properties": {},
                "geometry": {
                    "type": "MultiPolygon",
                    "coordinates": [[square(0.2, 0.2, 0.4, 0.4)], [square(40, 40, 41, 41)]],
                },
            },
            {"type": "Feature", "properties": {}, "geometry": None},
            {
                "type": "Feature",
                "properties": {},
                "geometry": {"type": "Polygon", "coordinates": [[[0.5, 0.5], [0.6, 0.6]]]},
            },
        ],
    }


@pytest.fixture
def lakes_geojson() -> dict[str, Any]:
    """One lake with an island, inside the land half."""
    return {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "properties": {"name": "Test Lake"},
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [square(1.5, 0.5, 1.9, 0.9), square(1.6, 0.6, 1.7, 0.7)],
                },
            }
        ],
    }


@pytest.fixture
def places_geojson() -> dict[str, Any]:
    return {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "properties": {
                    "name": "Bigcity",
                    "adm0_a3": "USA",
                    "adm1name": "State",
                    "pop_max": 500000,
                },
                "geometry": {"type": "Point", "coordinates": [-100.12345, 40.54321]},
            },
            {
                "type": "Feature",
                "properties": {"name": "Smalltown", "adm0_a3": "USA", "pop_max": 999},
                "geometry": {"type": "Point", "coordinates": [-101.0, 41.0]},
            },
            {
                "type": "Feature",
                "properties": {"name": "Abroad", "adm0_a3": "CAN", "pop_max": 900000},
                "geometry": {"type": "Point", "coordinates": [-79.0, 43.0]},
            },
            {
                "type": "Feature",
                "properties": {"name": "Nopop", "adm0_a3": "USA", "pop_max": None},
                "geometry": {"type": "Point", "coordinates": [-102.0, 42.0]},
            },
            {
                "type": "Feature",
                "properties": {"name": "Area", "adm0_a3": "USA", "pop_max": 1},
                "geometry": {"type": "Polygon", "coordinates": [square(0, 0, 1, 1)]},
            },
            {"type": "Feature", "properties": {"name": "Nogeom"}, "geometry": None},
            {"type": "Feature", "geometry": {"type": "Point", "coordinates": [1.0, 2.0, 3.0]}},
        ],
    }


AIRPORTS_CSV = (
    '"id","ident","type","name","latitude_deg","longitude_deg","elevation_ft","continent",'
    '"iso_country","iso_region","municipality","scheduled_service","icao_code","iata_code",'
    '"gps_code","local_code","home_link","wikipedia_link","keywords"\n'
    '1,"KSFO","large_airport","San Francisco International Airport",37.618999,-122.375,13,"NA",'
    '"US","US-CA","San Francisco","yes","KSFO","SFO","KSFO","SFO",,,\n'
    '2,"KSQL","medium_airport","San Carlos Airport",37.5119,-122.2495,5,"NA","US","US-CA",'
    '"San Carlos","no",,,"KSQL","SQL",,,\n'
    '3,"XYZ1","medium_airport","Ident Only Field",30.0,-90.0,5,"NA","US","US-LA","Nowhere",'
    '"no",,,,,,,\n'
    '4,"EGLL","large_airport","London Heathrow Airport",51.4706,-0.461941,83,"EU","GB","GB-ENG",'
    '"London","yes","EGLL","LHR","EGLL",,,,\n'
    '5,"00AA","small_airport","Aero B Ranch Airport",38.704022,-101.473911,3435,"NA","US",'
    '"US-KS","Leoti","no",,,"00AA","00AA",,,\n'
)

GAZETTEER_TXT = (
    "GEOID\tALAND\tAWATER\tALAND_SQMI\tAWATER_SQMI\tINTPTLAT\tINTPTLONG                 \n"
    "94110\t1\t2\t3\t4\t37.748495\t-122.415291                 \n"
    "00601\t1\t2\t3\t4\t18.180555\t-66.749961\n"
    "\n"
    "ABCDE\t1\t2\t3\t4\t1.0\t2.0\n"
    "1234\t1\t2\t3\t4\t1.0\t2.0\n"
)


@pytest.fixture
def gazetteer_zip(tmp_path: Path) -> Path:
    archive = tmp_path / "zcta.zip"
    with zipfile.ZipFile(archive, "w") as zf:
        zf.writestr("2023_Gaz_zcta_national.txt", "﻿" + GAZETTEER_TXT)
    return archive


def write_png(path: Path, size: tuple[int, int] = (4, 4)) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGBA", size, (0, 0, 0, 255)).save(path)


def make_channel(root: Path) -> Path:
    """Create a minimal, internally consistent channel tree under root/roku."""
    roku = root / "roku"
    (roku / "source").mkdir(parents=True)
    (roku / "components").mkdir()
    (roku / "source" / "tests").mkdir()
    (roku / "source" / "testFramework").mkdir()
    write_png(roku / "images" / "icon_focus_hd.png")
    write_png(roku / "images" / "splash_hd.png")
    (roku / "manifest").write_text(
        "title=Test\nmajor_version=1\nminor_version=0\nbuild_version=1\n"
        "mm_icon_focus_hd=pkg:/images/icon_focus_hd.png\n"
        "splash_screen_hd=pkg:/images/splash_hd.png\n"
        "screensaver_title=Test\nscreensaver_private=1\n",
        encoding="utf-8",
    )
    (roku / "source" / "main.brs").write_text(
        'sub Main(args as Object)\n    print "hi"\nend sub\n', encoding="utf-8"
    )
    (roku / "source" / "screensaver.brs").write_text(
        'sub RunScreenSaver(args as Object)\n    print "ss"\nend sub\n', encoding="utf-8"
    )
    (roku / "source" / "lib.brs").write_text(
        "function Add(a as Integer, b as Integer) as Integer\n    return a + b\nend function\n",
        encoding="utf-8",
    )
    (roku / "source" / "tests" / "Test__Lib.brs").write_text(
        "' @Test\nsub TestAdd()\n    UTF_assertEqual(Add(1, 2), 3)\nend sub\n", encoding="utf-8"
    )
    (roku / "source" / "testFramework" / "UnitTestFramework.brs").write_text(
        "function TestRunner()\n    return {}\nend function\n", encoding="utf-8"
    )
    (roku / "components" / "MainScene.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<component name="MainScene" extends="Scene">\n'
        '  <script type="text/brightscript" uri="pkg:/components/MainScene.brs"/>\n'
        "  <children/>\n</component>\n",
        encoding="utf-8",
    )
    (roku / "components" / "MainScene.brs").write_text(
        'sub init()\n    m.top.backgroundColor = "0x000000FF"\nend sub\n', encoding="utf-8"
    )
    return roku


@pytest.fixture
def channel(tmp_path: Path) -> Path:
    return make_channel(tmp_path)


def fake_sources(
    cache: Path, land: dict[str, Any], lakes: dict[str, Any], places: dict[str, Any]
) -> None:
    """Populate a cache directory so build-data never touches the network."""
    cache.mkdir(parents=True, exist_ok=True)
    (cache / "ne_10m_land.geojson").write_text(json.dumps(land), encoding="utf-8")
    (cache / "ne_10m_lakes.geojson").write_text(json.dumps(lakes), encoding="utf-8")
    (cache / "ne_10m_populated_places_simple.geojson").write_text(
        json.dumps(places), encoding="utf-8"
    )
    (cache / "airports.csv").write_text(AIRPORTS_CSV, encoding="utf-8")
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as zf:
        zf.writestr("2023_Gaz_zcta_national.txt", GAZETTEER_TXT)
    (cache / "2023_Gaz_zcta_national.zip").write_bytes(buffer.getvalue())
