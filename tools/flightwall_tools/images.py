"""Generate the channel's static artwork: plane sprites, markers, mask, icons, splash."""

from __future__ import annotations

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
    return written
