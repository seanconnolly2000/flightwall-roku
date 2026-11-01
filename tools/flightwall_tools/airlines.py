"""Build the bundled ICAO airline-code table from OpenFlights plus local overrides.

The channel resolves a callsign prefix such as CKK to "China Cargo Airlines" with a
single Instr() over this table, so most flights need no network lookup at all.
"""

from __future__ import annotations

import csv
import io
from pathlib import Path

OVERRIDES_PATH = Path(__file__).parent / "data" / "airline_overrides.csv"
ICAO_LENGTH = 3
MIN_COLUMNS = 8
OPENFLIGHTS_NULL = r"\N"


def parse_openflights(text: str) -> dict[str, str]:
    """ICAO code -> airline name; active airlines win when a code is reused."""
    names: dict[str, str] = {}
    active: set[str] = set()
    for row in csv.reader(io.StringIO(text)):
        if len(row) < MIN_COLUMNS:
            continue
        name, icao, is_active = row[1].strip(), row[4].strip().upper(), row[7].strip() == "Y"
        if len(icao) != ICAO_LENGTH or not icao.isalpha() or icao == OPENFLIGHTS_NULL or not name:
            continue
        if icao in active and not is_active:
            continue
        names[icao] = " ".join(name.split())
        if is_active:
            active.add(icao)
    return names


def parse_overrides(text: str) -> dict[str, str]:
    """`ICAO,Name` lines (comments with #) that correct or extend OpenFlights."""
    names: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "," not in line:
            continue
        icao, name = line.split(",", 1)
        icao, name = icao.strip().upper(), " ".join(name.split())
        if len(icao) == ICAO_LENGTH and icao.isalpha() and name:
            names[icao] = name
    return names


def render_airline_table(names: dict[str, str]) -> str:
    body = "".join(f"{icao},{name}\n" for icao, name in sorted(names.items()))
    return "\n" + body


def build_airlines(dat_path: Path, out_path: Path, overrides_path: Path = OVERRIDES_PATH) -> int:
    names = parse_openflights(dat_path.read_text(encoding="utf-8"))
    if overrides_path.exists():
        names.update(parse_overrides(overrides_path.read_text(encoding="utf-8")))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(render_airline_table(names), encoding="utf-8", newline="\n")
    return len(names)
