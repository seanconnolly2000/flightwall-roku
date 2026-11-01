"""Small GeoJSON polygon helpers (no third-party GIS dependency)."""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass
from typing import Any

Point = tuple[float, float]
Ring = list[Point]
Polygon = list[Ring]


@dataclass(frozen=True)
class BBox:
    lon_min: float
    lat_min: float
    lon_max: float
    lat_max: float

    def intersects(self, other: BBox) -> bool:
        return not (
            other.lon_min > self.lon_max
            or other.lon_max < self.lon_min
            or other.lat_min > self.lat_max
            or other.lat_max < self.lat_min
        )


def ring_bbox(ring: Ring) -> BBox:
    lons = [p[0] for p in ring]
    lats = [p[1] for p in ring]
    return BBox(min(lons), min(lats), max(lons), max(lats))


def _as_ring(coords: list[Any]) -> Ring:
    return [(float(c[0]), float(c[1])) for c in coords]


def iter_polygons(geojson: dict[str, Any]) -> Iterator[Polygon]:
    """Yield every polygon (exterior ring first, holes after) in a FeatureCollection."""
    for feature in geojson.get("features", []):
        geometry = feature.get("geometry")
        if not geometry:
            continue
        kind = geometry.get("type")
        if kind == "Polygon":
            yield [_as_ring(r) for r in geometry["coordinates"]]
        elif kind == "MultiPolygon":
            for poly in geometry["coordinates"]:
                yield [_as_ring(r) for r in poly]


def iter_points(geojson: dict[str, Any]) -> Iterator[tuple[dict[str, Any], Point]]:
    """Yield (properties, (lon, lat)) for every Point feature."""
    for feature in geojson.get("features", []):
        geometry = feature.get("geometry")
        if not geometry or geometry.get("type") != "Point":
            continue
        lon, lat = geometry["coordinates"][:2]
        yield feature.get("properties", {}), (float(lon), float(lat))
