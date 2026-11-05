from __future__ import annotations

from pathlib import Path

import pytest
from PIL import Image

from flightwall_tools import images


def px(image: Image.Image, xy: tuple[int, int]) -> tuple[int, ...]:
    value = image.getpixel(xy)
    assert isinstance(value, tuple)
    return value


def test_sprite_naming() -> None:
    assert images.sprite_headings()[:3] == [0, 10, 20]
    assert len(images.sprite_headings()) == 36
    assert images.sprite_filename(0) == "plane_000.png"
    assert images.sprite_filename(350) == "plane_350.png"


def test_nearest_sprite_heading() -> None:
    assert images.nearest_sprite_heading(0) == 0
    assert images.nearest_sprite_heading(4.9) == 0
    assert images.nearest_sprite_heading(14) == 10
    assert images.nearest_sprite_heading(355) == 0
    assert images.nearest_sprite_heading(359.9) == 0
    assert images.nearest_sprite_heading(184) == 180


def test_plane_sprite_points_north_then_rotates() -> None:
    north = images.plane_sprite(0)
    assert north.size == (32, 32)
    assert px(north, (16, 3))[3] > 0
    assert px(north, (3, 3))[3] == 0
    east = images.plane_sprite(90)
    assert px(east, (28, 16))[3] > 0
    assert px(east, (16, 3))[3] == 0


def opaque(image: Image.Image) -> int:
    """Number of pixels that are more than half opaque."""
    return sum(image.getchannel("A").histogram()[129:])


def test_heli_sprite_is_smaller_and_rotates() -> None:
    assert images.heli_filename(90) == "heli_090.png"
    north = images.heli_sprite(0)
    plane = images.plane_sprite(0)
    assert north.size == (32, 32)
    assert px(north, (16, 16))[3] > 0
    assert px(north, (0, 0))[3] == 0
    assert px(plane, (16, 3))[3] > 0
    assert px(north, (16, 3))[3] == 0
    assert px(north, (7, 16))[3] == 0
    assert opaque(north) < opaque(plane) * 0.75
    east = images.heli_sprite(90)
    assert px(east, (7, 16))[3] > 0


def test_dots_and_mask() -> None:
    solid = images.dot(8)
    assert px(solid, (4, 4))[3] == 255
    assert px(solid, (0, 0))[3] == 0
    hollow = images.dot(12, hollow=True)
    assert px(hollow, (6, 6))[3] == 0
    assert px(hollow, (6, 2))[3] > 0
    mask = images.circle_mask(100, 40)
    assert px(mask, (50, 50))[3] == 0
    assert px(mask, (1, 1)) == images.BLACK
    assert px(mask, (50, 10))[3] == 255


def test_line_segment_fades() -> None:
    line = images.line_segment(10, 2)
    assert line.size == (10, 2)
    assert px(line, (0, 0))[3] == 255
    assert px(line, (9, 1))[3] < 40


def test_branded_panel() -> None:
    plain = images.branded_panel(120, 90)
    assert plain.size == (120, 90)
    with_subtitle = images.branded_panel(200, 120, "subtitle")
    assert px(with_subtitle, (0, 0)) == images.BLACK


def test_weather_icons() -> None:
    for kind in images.WEATHER_KINDS:
        icon = images.weather_icon(kind)
        assert icon.size == (36, 36)
        alpha = icon.getchannel("A")
        _, high = alpha.getextrema()
        assert isinstance(high, (int, float))
        assert high > 200, kind
    assert px(images.weather_icon("clear", 40), (20, 20))[:3] == images.SUN[:3]
    with pytest.raises(ValueError, match="unknown weather icon"):
        images.weather_icon("hail")


def test_ensure_fhd(tmp_path: Path) -> None:
    jpg = tmp_path / "shot.jpg"
    Image.new("RGB", (1280, 720), (1, 2, 3)).save(jpg, format="JPEG")
    assert images.ensure_fhd(jpg) == (1920, 1080)
    with Image.open(jpg) as reloaded:
        assert reloaded.size == (1920, 1080)
    png = tmp_path / "shot.png"
    Image.new("RGBA", (1920, 1080), (1, 2, 3, 255)).save(png)
    assert images.ensure_fhd(png) == (1920, 1080)
    with Image.open(png) as reloaded:
        assert reloaded.format == "PNG"


def test_build_images(tmp_path: Path) -> None:
    written = images.build_images(tmp_path / "images")
    assert len(written) == 36 + 36 + 6 + len(images.ICON_SIZES) + len(images.SPLASH_SIZES) + len(
        images.WEATHER_KINDS
    )
    for name in written:
        assert (tmp_path / "images" / name).exists()
