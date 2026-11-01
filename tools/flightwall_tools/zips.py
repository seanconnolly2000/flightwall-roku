"""Build the bundled ZIP-code centroid table from the US Census ZCTA gazetteer."""

from __future__ import annotations

import io
import zipfile
from pathlib import Path

ZCTA_MEMBER = "2023_Gaz_zcta_national.txt"
ZIP_LENGTH = 5

ZipRow = tuple[str, float, float]


def parse_gazetteer(text: str) -> list[ZipRow]:
    """Parse the tab-separated gazetteer into (zip, lat, lon) rows."""
    rows: list[ZipRow] = []
    lines = text.splitlines()
    if not lines:
        return rows
    header = [h.strip().upper() for h in lines[0].split("\t")]
    geoid = header.index("GEOID")
    lat_col = header.index("INTPTLAT")
    lon_col = header.index("INTPTLONG")
    for line in lines[1:]:
        if not line.strip():
            continue
        cols = [c.strip() for c in line.split("\t")]
        code = cols[geoid]
        if len(code) != ZIP_LENGTH or not code.isdigit():
            continue
        rows.append((code, float(cols[lat_col]), float(cols[lon_col])))
    rows.sort()
    return rows


def render_zip_table(rows: list[ZipRow]) -> str:
    """Render rows as a newline-delimited table the channel can search with Instr()."""
    body = "".join(f"{code},{lat:.4f},{lon:.4f}\n" for code, lat, lon in rows)
    return "\n" + body


def read_gazetteer_archive(archive: Path) -> str:
    with zipfile.ZipFile(archive) as zf, zf.open(ZCTA_MEMBER) as member:
        return io.TextIOWrapper(member, encoding="utf-8-sig").read()


def build_zips(archive: Path, out_path: Path) -> int:
    rows = parse_gazetteer(read_gazetteer_archive(archive))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(render_zip_table(rows), encoding="ascii", newline="\n")
    return len(rows)
