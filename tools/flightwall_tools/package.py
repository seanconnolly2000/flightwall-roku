"""Zip the channel directory into a side-loadable package."""

from __future__ import annotations

import zipfile
from pathlib import Path

TEST_PATHS = ("source/tests/", "source/testFramework/")
APP_ENTRY = "source/main.brs"
SKIP_NAMES = {".DS_Store", "Thumbs.db", ".gitkeep", "LICENSE"}


def should_include(relative: str, with_tests: bool, screensaver_only: bool) -> bool:
    name = relative.rsplit("/", 1)[-1]
    if name in SKIP_NAMES:
        return False
    if not with_tests and relative.startswith(TEST_PATHS):
        return False
    return not (screensaver_only and relative == APP_ENTRY)


def build_package(
    roku_dir: Path, out_path: Path, with_tests: bool = False, screensaver_only: bool = False
) -> list[str]:
    """Create the zip and return the sorted list of paths that were included."""
    if not (roku_dir / "manifest").exists():
        msg = f"no manifest in {roku_dir}"
        raise FileNotFoundError(msg)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    included: list[str] = []
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file in sorted(p for p in roku_dir.rglob("*") if p.is_file()):
            relative = file.relative_to(roku_dir).as_posix()
            if should_include(relative, with_tests, screensaver_only):
                zf.write(file, relative)
                included.append(relative)
    return included
