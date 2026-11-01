from __future__ import annotations

from typing import Any

from flightwall_tools.geometry import BBox, iter_points, iter_polygons, ring_bbox


def test_bbox_intersects() -> None:
    a = BBox(0, 0, 10, 10)
    assert a.intersects(BBox(5, 5, 15, 15))
    assert a.intersects(BBox(10, 10, 12, 12))
    assert not a.intersects(BBox(11, 0, 12, 1))
    assert not a.intersects(BBox(-5, 0, -1, 1))
    assert not a.intersects(BBox(0, 11, 1, 12))
    assert not a.intersects(BBox(0, -5, 1, -1))


def test_ring_bbox() -> None:
    assert ring_bbox([(1.0, 2.0), (-3.0, 4.0), (0.5, -1.0)]) == BBox(-3.0, -1.0, 1.0, 4.0)


def test_iter_polygons(land_geojson: dict[str, Any]) -> None:
    polys = list(iter_polygons(land_geojson))
    assert len(polys) == 4
    assert polys[0][0][0] == (1.0, -1.0)
    assert len(polys[1]) == 1
    assert polys[3][0] == [(0.5, 0.5), (0.6, 0.6)]


def test_iter_polygons_skips_points() -> None:
    geojson = {
        "features": [
            {"geometry": {"type": "Point", "coordinates": [1.0, 2.0]}},
            {"geometry": {"type": "Polygon", "coordinates": [[[0, 0], [1, 0], [1, 1]]]}},
        ]
    }
    assert list(iter_polygons(geojson)) == [[[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0)]]]


def test_iter_points(places_geojson: dict[str, Any]) -> None:
    points = list(iter_points(places_geojson))
    assert [p[0].get("name") for p in points] == ["Bigcity", "Smalltown", "Abroad", "Nopop", None]
    assert points[-1] == ({}, (1.0, 2.0))
