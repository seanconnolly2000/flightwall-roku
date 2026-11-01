from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PIL import Image

from flightwall_tools import tiles
from flightwall_tools.geometry import BBox

REGION = tiles.Region("test", 0, 1, 0, 2)
PX = 16


def test_region_helpers() -> None:
    assert list(REGION.tiles()) == [(0, 0), (0, 1)]
    assert REGION.band_bbox(0) == BBox(0, 0, 2, 1)
    assert REGION.as_dict() == {
        "name": "test",
        "lat_min": 0,
        "lat_max": 1,
        "lon_min": 0,
        "lon_max": 2,
    }
    assert tiles.tile_key(37, -123) == "37_-123"
    assert tiles.tile_filename(37, -123) == "t_37_-123.png"
    assert tiles.hex_rgb((10, 26, 58)) == "#0A1A3A"
    assert set(tiles.DEFAULT_REGIONS) <= set(tiles.REGIONS)


def test_render_band_land_water_and_lake(
    land_geojson: dict[str, Any], lakes_geojson: dict[str, Any]
) -> None:
    rasterizer = tiles.Rasterizer(land_geojson, lakes_geojson, PX)
    band = rasterizer.render_band(REGION, 0)
    assert band.size == (2 * PX, PX)
    # West tile: water except the small island at lon 0.2..0.4, lat 0.2..0.4.
    assert band.getpixel((1, 1)) == tiles.WATER
    assert band.getpixel((int(0.3 * PX), int((1 - 0.3) * PX))) == tiles.LAND
    # East tile: land, except the lake (lon 1.5..1.9, lat 0.5..0.9) with its island.
    assert band.getpixel((PX + 2, PX - 2)) == tiles.LAND
    assert band.getpixel((int(1.55 * PX), int((1 - 0.85) * PX))) == tiles.WATER
    assert band.getpixel((int(1.65 * PX), int((1 - 0.65) * PX))) == tiles.LAND


def test_classify_and_palette() -> None:
    water = Image.new("L", (4, 4), tiles.WATER)
    land = Image.new("L", (4, 4), tiles.LAND)
    mixed = land.copy()
    mixed.putpixel((0, 0), tiles.WATER)
    assert tiles.classify(water) == tiles.TILE_WATER
    assert tiles.classify(land) == tiles.TILE_LAND
    assert tiles.classify(mixed) == tiles.TILE_COASTAL
    palette = tiles.to_palette(mixed)
    assert palette.mode == "P"
    assert palette.getpixel((0, 0)) == 0
    assert palette.getpixel((1, 1)) == 1
    rgb = palette.convert("RGB")
    assert rgb.getpixel((0, 0)) == tiles.WATER_RGB
    assert rgb.getpixel((1, 1)) == tiles.LAND_RGB


def test_build_tiles_writes_index_and_coastal_tiles(
    tmp_path: Path, land_geojson: dict[str, Any], lakes_geojson: dict[str, Any]
) -> None:
    messages: list[str] = []
    out = tmp_path / "tiles"
    index = tiles.build_tiles(land_geojson, lakes_geojson, [REGION], out, PX, messages.append)
    assert index["px_per_deg"] == PX
    assert index["regions"] == [REGION.as_dict()]
    assert index["tiles"] == {"0_0": tiles.TILE_COASTAL, "0_1": tiles.TILE_COASTAL}
    assert (out / "t_0_0.png").exists()
    assert (out / "t_0_1.png").exists()
    assert json.loads((out / "index.json").read_text(encoding="utf-8")) == index
    assert messages == ["test: latitude 0 done"]


def test_build_tiles_solid_tiles_are_not_written(tmp_path: Path) -> None:
    all_land = {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "properties": {},
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [[[-5, -5], [5, -5], [5, 5], [-5, 5], [-5, -5]]],
                },
            }
        ],
    }
    empty = {"type": "FeatureCollection", "features": []}
    region = tiles.Region("solid", 0, 1, 0, 3)
    index = tiles.build_tiles(all_land, empty, [region], tmp_path / "t", 4)
    assert index["tiles"] == {"0_0": "l", "0_1": "l", "0_2": "l"}
    assert sorted(p.name for p in (tmp_path / "t").iterdir()) == ["index.json"]
    index = tiles.build_tiles(empty, empty, [region], tmp_path / "w", 4)
    assert set(index["tiles"].values()) == {"w"}
