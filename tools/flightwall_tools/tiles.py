"""Rasterize Natural Earth land and lake polygons into 1-degree map tiles.

Each tile is a 2-colour PNG (land black, water dark blue) covering one degree of
latitude and longitude.  Tiles that are entirely land or entirely water are not
written; the index records them so the channel can draw a plain rectangle instead.
"""

from __future__ import annotations

import json
from collections.abc import Callable, Iterable, Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

from .geometry import BBox, Polygon, iter_polygons, ring_bbox

PX_PER_DEG = 512
LAND_RGB = (0, 0, 0)
WATER_RGB = (10, 26, 58)
LAND = 255
WATER = 0
MIN_RING_POINTS = 3

TILE_LAND = "l"
TILE_WATER = "w"
TILE_COASTAL = "c"


@dataclass(frozen=True)
class Region:
    name: str
    lat_min: int
    lat_max: int
    lon_min: int
    lon_max: int

    def tiles(self) -> Iterator[tuple[int, int]]:
        for lat in range(self.lat_min, self.lat_max):
            for lon in range(self.lon_min, self.lon_max):
                yield lat, lon

    def band_bbox(self, lat: int) -> BBox:
        return BBox(self.lon_min, lat, self.lon_max, lat + 1)

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "lat_min": self.lat_min,
            "lat_max": self.lat_max,
            "lon_min": self.lon_min,
            "lon_max": self.lon_max,
        }


REGIONS: dict[str, Region] = {
    "conus": Region("conus", 24, 50, -125, -66),
    "hawaii": Region("hawaii", 18, 23, -161, -154),
    "alaska": Region("alaska", 51, 72, -180, -129),
}
DEFAULT_REGIONS = ("conus", "hawaii")


def tile_key(lat: int, lon: int) -> str:
    return f"{lat}_{lon}"


def tile_filename(lat: int, lon: int) -> str:
    return f"t_{lat}_{lon}.png"


def hex_rgb(rgb: tuple[int, int, int]) -> str:
    return "#{:02X}{:02X}{:02X}".format(*rgb)


@dataclass(frozen=True)
class _Shape:
    polygon: Polygon
    bbox: BBox


def _shapes(geojson: dict[str, Any]) -> list[_Shape]:
    return [_Shape(poly, ring_bbox(poly[0])) for poly in iter_polygons(geojson) if poly and poly[0]]


class Rasterizer:
    """Draw land and lake polygons into one-degree-tall raster bands."""

    def __init__(
        self, land: dict[str, Any], lakes: dict[str, Any], px_per_deg: int = PX_PER_DEG
    ) -> None:
        self.land = _shapes(land)
        self.lakes = _shapes(lakes)
        self.px = px_per_deg

    def _draw(
        self, draw: ImageDraw.ImageDraw, shape: _Shape, bbox: BBox, fill: int, hole: int
    ) -> None:
        if not shape.bbox.intersects(bbox):
            return
        for index, ring in enumerate(shape.polygon):
            xy = [
                ((lon - bbox.lon_min) * self.px, (bbox.lat_max - lat) * self.px)
                for lon, lat in ring
            ]
            if len(xy) < MIN_RING_POINTS:
                continue
            draw.polygon(xy, fill=fill if index == 0 else hole)

    def render_band(self, region: Region, lat: int) -> Image.Image:
        """Render one row of tiles (all longitudes of the region at latitude lat)."""
        bbox = region.band_bbox(lat)
        width = (region.lon_max - region.lon_min) * self.px
        band = Image.new("L", (width, self.px), WATER)
        draw = ImageDraw.Draw(band)
        for shape in self.land:
            self._draw(draw, shape, bbox, LAND, WATER)
        for shape in self.lakes:
            self._draw(draw, shape, bbox, WATER, LAND)
        return band


def classify(tile: Image.Image) -> str:
    low, high = tile.getextrema()
    if high == WATER:
        return TILE_WATER
    if low == LAND:
        return TILE_LAND
    return TILE_COASTAL


def to_palette(tile: Image.Image) -> Image.Image:
    """Convert a 0/255 'L' tile into a 2-colour palette image."""
    indexed = tile.point(lambda v: 1 if v else 0)
    out = Image.frombytes("P", tile.size, indexed.tobytes())
    out.putpalette([*WATER_RGB, *LAND_RGB])
    return out


def build_tiles(
    land: dict[str, Any],
    lakes: dict[str, Any],
    regions: Iterable[Region],
    out_dir: Path,
    px_per_deg: int = PX_PER_DEG,
    progress: Callable[[str], None] | None = None,
) -> dict[str, Any]:
    """Write tiles plus index.json into out_dir and return the index."""
    out_dir.mkdir(parents=True, exist_ok=True)
    rasterizer = Rasterizer(land, lakes, px_per_deg)
    tiles: dict[str, str] = {}
    region_list = list(regions)
    for region in region_list:
        for lat in range(region.lat_min, region.lat_max):
            band = rasterizer.render_band(region, lat)
            for lon in range(region.lon_min, region.lon_max):
                x0 = (lon - region.lon_min) * px_per_deg
                tile = band.crop((x0, 0, x0 + px_per_deg, px_per_deg))
                kind = classify(tile)
                tiles[tile_key(lat, lon)] = kind
                if kind == TILE_COASTAL:
                    to_palette(tile).save(
                        out_dir / tile_filename(lat, lon), format="PNG", optimize=True, bits=1
                    )
            if progress is not None:
                progress(f"{region.name}: latitude {lat} done")
    index: dict[str, Any] = {
        "px_per_deg": px_per_deg,
        "land_rgb": hex_rgb(LAND_RGB),
        "water_rgb": hex_rgb(WATER_RGB),
        "regions": [r.as_dict() for r in region_list],
        "tiles": tiles,
    }
    (out_dir / "index.json").write_text(json.dumps(index, separators=(",", ":")), encoding="utf-8")
    return index
