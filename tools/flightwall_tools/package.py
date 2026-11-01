"""Zip the channel directory into a side-loadable package.

Three variants share one source tree:

- combined (default): channel entry point plus screensaver entry points, for local
  side-loading where one developer slot has to do both jobs;
- channel-only: no screensaver code or manifest attributes (Roku forbids in-channel
  screensavers for Channel Store channels);
- screensaver-only: no Main(), for a Channel Store screensaver.
"""

from __future__ import annotations

import zipfile
from pathlib import Path

TEST_PATHS = ("source/tests/", "source/testFramework/")
APP_ENTRY = "source/main.brs"
SCREENSAVER_ENTRY = "source/screensaver.brs"
SCREENSAVER_MANIFEST_PREFIX = "screensaver_"
SKIP_NAMES = {".DS_Store", "Thumbs.db", ".gitkeep", "LICENSE"}


def should_include(
    relative: str, with_tests: bool, screensaver_only: bool, channel_only: bool = False
) -> bool:
    name = relative.rsplit("/", 1)[-1]
    if name in SKIP_NAMES:
        return False
    if not with_tests and relative.startswith(TEST_PATHS):
        return False
    if screensaver_only and relative == APP_ENTRY:
        return False
    return not (channel_only and relative == SCREENSAVER_ENTRY)


def strip_screensaver_manifest(text: str) -> str:
    """Remove the screensaver_* attributes from manifest text."""
    kept = [
        line
        for line in text.splitlines()
        if not line.strip().startswith(SCREENSAVER_MANIFEST_PREFIX)
    ]
    return "\n".join(kept).rstrip("\n") + "\n"


def build_package(
    roku_dir: Path,
    out_path: Path,
    with_tests: bool = False,
    screensaver_only: bool = False,
    channel_only: bool = False,
) -> list[str]:
    """Create the zip and return the sorted list of paths that were included."""
    if screensaver_only and channel_only:
        msg = "a package cannot be both screensaver-only and channel-only"
        raise ValueError(msg)
    if not (roku_dir / "manifest").exists():
        msg = f"no manifest in {roku_dir}"
        raise FileNotFoundError(msg)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    included: list[str] = []
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file in sorted(p for p in roku_dir.rglob("*") if p.is_file()):
            relative = file.relative_to(roku_dir).as_posix()
            if not should_include(relative, with_tests, screensaver_only, channel_only):
                continue
            if channel_only and relative == "manifest":
                zf.writestr(relative, strip_screensaver_manifest(file.read_text(encoding="utf-8")))
            else:
                zf.write(file, relative)
            included.append(relative)
    return included
