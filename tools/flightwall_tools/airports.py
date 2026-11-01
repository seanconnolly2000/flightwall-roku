"""Select US large and medium airports from OurAirports for the bundled airport layer."""

from __future__ import annotations

import csv
import io
import json
from pathlib import Path
from typing import Any

SIZE_BY_TYPE = {"large_airport": "L", "medium_airport": "M"}


def select_airports(csv_text: str, country: str = "US") -> list[dict[str, Any]]:
    airports: list[dict[str, Any]] = []
    for row in csv.DictReader(io.StringIO(csv_text)):
        size = SIZE_BY_TYPE.get(row["type"])
        if size is None or row["iso_country"] != country:
            continue
        code = row["iata_code"] or row["local_code"] or row["ident"]
        airports.append(
            {
                "c": code,
                "i": row["icao_code"] or row["ident"],
                "n": row["name"],
                "m": row["municipality"],
                "lat": round(float(row["latitude_deg"]), 4),
                "lon": round(float(row["longitude_deg"]), 4),
                "s": size,
            }
        )
    airports.sort(key=lambda a: (a["s"], a["c"]))
    return airports


def build_airports(csv_path: Path, out_path: Path) -> int:
    airports = select_airports(csv_path.read_text(encoding="utf-8"))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps({"airports": airports}, separators=(",", ":")), encoding="utf-8")
    return len(airports)
