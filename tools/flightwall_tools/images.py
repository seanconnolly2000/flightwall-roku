"""Generate the channel's static artwork: plane sprites, markers, mask, icons, splash."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SPRITE_SIZE = 32
SPRITE_STEP_DEG = 10
SUPERSAMPLE = 4
MAP_SIZE = 700
MAP_RADIUS = 340

WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)
BLACK = (0, 0, 0, 255)
RING = (70, 84, 110, 255)
ACCENT = (88, 166, 255, 255)
MUTED = (139, 148, 158, 255)

# Top-down airliner silhouette pointing north, in a 32x32 box.
PLANE_OUTLINE = [
    (16, 1),
    (18, 5),
    (18, 12),
    (30, 19),
    (30, 22),
    (18, 18),
    (18, 25),
    (22, 28),
    (22, 30),
    (16, 28),
    (10, 30),
    (10, 28),
    (14, 25),
    (14, 18),
    (2, 22),
    (2, 19),
    (14, 12),
    (14, 5),
]

ICON_SIZES = {
    "icon_focus_fhd.png": (540, 405),
    "icon_focus_hd.png": (290, 218),
    "icon_focus_sd.png": (246, 140),
}
SPLASH_SIZES = {
    "splash_fhd.png": (1920, 1080),
    "splash_hd.png": (1280, 720),
    "splash_sd.png": (720, 480),
}


def sprite_headings(step: int = SPRITE_STEP_DEG) -> list[int]:
    return list(range(0, 360, step))


def sprite_filename(heading: int) -> str:
    return f"plane_{heading:03d}.png"


def nearest_sprite_heading(track: float, step: int = SPRITE_STEP_DEG) -> int:
    """Round a track (degrees clockwise from north) to the nearest sprite heading."""
    return int(round(track / step) * step) % 360


def plane_sprite(
    heading: int = 0, size: int = SPRITE_SIZE, color: tuple[int, ...] = WHITE
) -> Image.Image:
    big = size * SUPERSAMPLE
    scale = big / SPRITE_SIZE
    canvas = Image.new("RGBA", (big, big), TRANSPARENT)
    draw = ImageDraw.Draw(canvas)
    draw.polygon([(x * scale, y * scale) for x, y in PLANE_OUTLINE], fill=color)
    rotated = canvas.rotate(-heading, resample=Image.Resampling.BICUBIC)
    return rotated.resize((size, size), Image.Resampling.LANCZOS)


def dot(size: int, color: tuple[int, ...] = WHITE, hollow: bool = False) -> Image.Image:
    big = size * SUPERSAMPLE
    canvas = Image.new("RGBA", (big, big), TRANSPARENT)
    draw = ImageDraw.Draw(canvas)
    if hollow:
        width = max(1, big // 6)
        draw.ellipse((width, width, big - width - 1, big - width - 1), outline=color, width=width)
    else:
        draw.ellipse((0, 0, big - 1, big - 1), fill=color)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def circle_mask(size: int = MAP_SIZE, radius: int = MAP_RADIUS) -> Image.Image:
    """Opaque black outside a centred circle, transparent inside, with a thin ring."""
    big = size * 2
    canvas = Image.new("RGBA", (big, big), BLACK)
    draw = ImageDraw.Draw(canvas)
    c = big // 2
    r = radius * 2
    draw.ellipse((c - r, c - r, c + r, c + r), fill=TRANSPARENT)
    draw.ellipse((c - r, c - r, c + r, c + r), outline=RING, width=4)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def line_segment(length: int = 64, thickness: int = 2) -> Image.Image:
    """A horizontal line fading from opaque (left) to transparent (right)."""
    canvas = Image.new("RGBA", (length, thickness), TRANSPARENT)
    for x in range(length):
        alpha = int(255 * (1 - x / length))
        for y in range(thickness):
            canvas.putpixel((x, y), (255, 255, 255, alpha))
    return canvas


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    return ImageFont.load_default(size=size)


WEATHER_KINDS = ("clear", "partly", "cloudy", "fog", "rain", "snow", "storm")
SUN = (255, 200, 87, 255)
CLOUD = (226, 232, 240, 255)
RAIN = (124, 196, 255, 255)
BOLT = (255, 221, 87, 255)


def _draw_sun(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, s: float) -> None:
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=SUN)
    for i in range(8):
        angle = math.radians(i * 45)
        x0, y0 = cx + math.cos(angle) * r * 1.35, cy + math.sin(angle) * r * 1.35
        x1, y1 = cx + math.cos(angle) * r * 1.8, cy + math.sin(angle) * r * 1.8
        draw.line((x0, y0, x1, y1), fill=SUN, width=max(1, int(1.6 * s)))


def _draw_cloud(draw: ImageDraw.ImageDraw, cx: float, cy: float, w: float) -> None:
    r = w / 4
    draw.ellipse((cx - w / 2, cy - r / 2, cx - w / 2 + 2 * r, cy + 1.5 * r), fill=CLOUD)
    draw.ellipse((cx + w / 2 - 2 * r, cy - r / 2, cx + w / 2, cy + 1.5 * r), fill=CLOUD)
    draw.ellipse((cx - r * 1.2, cy - r * 1.6, cx + r * 1.2, cy + r * 0.8), fill=CLOUD)
    draw.rectangle((cx - w / 2 + r, cy + r / 2, cx + w / 2 - r, cy + 1.5 * r), fill=CLOUD)


def weather_icon(kind: str, size: int = 36) -> Image.Image:
    """Minimal monochrome-ish weather glyph for the forecast strip."""
    if kind not in WEATHER_KINDS:
        msg = f"unknown weather icon kind: {kind}"
        raise ValueError(msg)
    s = SUPERSAMPLE
    big = size * s
    canvas = Image.new("RGBA", (big, big), TRANSPARENT)
    draw = ImageDraw.Draw(canvas)
    c = big / 2
    if kind == "clear":
        _draw_sun(draw, c, c, big * 0.22, s)
    elif kind == "partly":
        _draw_sun(draw, big * 0.36, big * 0.36, big * 0.15, s)
        _draw_cloud(draw, big * 0.56, big * 0.6, big * 0.66)
    else:
        _draw_cloud(draw, c, big * 0.42, big * 0.78)
        _draw_precipitation(draw, kind, big, s)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def _draw_precipitation(draw: ImageDraw.ImageDraw, kind: str, big: float, s: float) -> None:
    """Whatever falls (or hangs) below the cloud for fog, rain, snow and storm icons."""
    base = big * 0.72
    c = big / 2
    width = max(1, int(2 * s))
    if kind == "fog":
        for i in range(2):
            y = base + i * big * 0.12
            draw.line((big * 0.2, y, big * 0.8, y), fill=CLOUD, width=width)
    elif kind == "rain":
        for i in range(3):
            x = big * (0.32 + 0.18 * i)
            draw.line((x, base, x - big * 0.06, base + big * 0.2), fill=RAIN, width=width)
    elif kind == "snow":
        for i in range(3):
            x = big * (0.32 + 0.18 * i)
            rr = big * 0.045
            draw.ellipse(
                (x - rr, base + big * 0.08 - rr, x + rr, base + big * 0.08 + rr), fill=CLOUD
            )
    elif kind == "storm":
        bolt = [
            (c + big * 0.04, base - big * 0.06),
            (c - big * 0.1, base + big * 0.12),
            (c, base + big * 0.12),
            (c - big * 0.04, base + big * 0.3),
            (c + big * 0.12, base + big * 0.06),
            (c + big * 0.02, base + big * 0.06),
        ]
        draw.polygon(bolt, fill=BOLT)


def branded_panel(width: int, height: int, subtitle: str = "") -> Image.Image:
    canvas = Image.new("RGBA", (width, height), BLACK)
    draw = ImageDraw.Draw(canvas)
    plane = plane_sprite(45, size=max(32, height // 3), color=ACCENT)
    px = width // 2 - plane.width // 2
    py = height // 2 - plane.height // 2 - height // 10
    canvas.alpha_composite(plane, (px, py))
    title_font = _font(max(16, height // 8))
    title = "FlightWall"
    tw = draw.textlength(title, font=title_font)
    title_xy = ((width - tw) / 2, py + plane.height + height // 30)
    draw.text(title_xy, title, font=title_font, fill=WHITE)
    if subtitle:
        sub_font = _font(max(10, height // 20))
        sw = draw.textlength(subtitle, font=sub_font)
        draw.text(((width - sw) / 2, height - height // 8), subtitle, font=sub_font, fill=MUTED)
    return canvas


FHD = (1920, 1080)


def ensure_fhd(path: Path, size: tuple[int, int] = FHD) -> tuple[int, int]:
    """Rewrite an image at exactly 1920x1080 (the Channel Store screenshot size)."""
    with Image.open(path) as source:
        image = source.convert("RGB")
    if image.size != size:
        image = image.resize(size, Image.Resampling.LANCZOS)
    if path.suffix.lower() in {".jpg", ".jpeg"}:
        image.save(path, format="JPEG", quality=92)
    else:
        image.save(path)
    return image.size


def build_images(images_dir: Path) -> list[str]:
    """Write every generated image under images_dir and return the file names written."""
    written: list[str] = []
    planes = images_dir / "planes"
    planes.mkdir(parents=True, exist_ok=True)
    for heading in sprite_headings():
        name = sprite_filename(heading)
        plane_sprite(heading).save(planes / name)
        written.append(f"planes/{name}")
    singles = {
        "dot.png": dot(8),
        "trail.png": dot(4),
        "airport.png": dot(12, hollow=True),
        "home.png": dot(14, color=(63, 185, 80, 255)),
        "mask.png": circle_mask(),
        "line.png": line_segment(),
    }
    for name, image in singles.items():
        image.save(images_dir / name)
        written.append(name)
    for name, (w, h) in ICON_SIZES.items():
        branded_panel(w, h).save(images_dir / name)
        written.append(name)
    for name, (w, h) in SPLASH_SIZES.items():
        branded_panel(w, h, "Nearby flights, live on your TV").save(images_dir / name)
        written.append(name)
    weather = images_dir / "weather"
    weather.mkdir(parents=True, exist_ok=True)
    for kind in WEATHER_KINDS:
        weather_icon(kind).save(weather / f"{kind}.png")
        written.append(f"weather/{kind}.png")
    return written
