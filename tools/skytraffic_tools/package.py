"""Zip the channel directory into a side-loadable package.

Three variants share one source tree:

- combined (default): channel entry point plus screensaver entry points, for local
  side-loading where one developer slot has to do both jobs;
- channel-only: no screensaver code or manifest attributes (Roku forbids in-channel
  screensavers for Channel Store channels);
- screensaver-only: no Main(), for a Channel Store screensaver.

The two store variants also get their own splash screen (images/splash_app_* and
images/splash_screensaver_*), so a viewer who launches the screensaver from its store
page, where it has no Main() to run, reads what it is and how to turn it on.
"""

from __future__ import annotations

import zipfile
from pathlib import Path

TEST_PATHS = ("source/tests/", "source/testFramework/")
APP_ENTRY = "source/main.brs"
SCREENSAVER_ENTRY = "source/screensaver.brs"
SCREENSAVER_MANIFEST_PREFIX = "screensaver_"
KEY_HANDLER_SUFFIX = "Keys.brs"  # remote-key handlers; forbidden in screensavers
SKIP_NAMES = {".DS_Store", "Thumbs.db", ".gitkeep", "LICENSE"}


def should_include(
    relative: str, with_tests: bool, screensaver_only: bool, channel_only: bool = False
) -> bool:
    name = relative.rsplit("/", 1)[-1]
    if name in SKIP_NAMES:
        return False
    if not with_tests and relative.startswith(TEST_PATHS):
        return False
    if screensaver_only and (relative == APP_ENTRY or name.endswith(KEY_HANDLER_SUFFIX)):
        return False
    return not (channel_only and relative == SCREENSAVER_ENTRY)


def strip_key_handler_scripts(xml_text: str) -> str:
    """Remove <script> references to *Keys.brs files from component XML (screensaver build)."""
    kept = [
        line
        for line in xml_text.splitlines()
        if not ("<script" in line and KEY_HANDLER_SUFFIX in line)
    ]
    return "\n".join(kept).rstrip("\n") + "\n"


SPLASH_SCREEN_PREFIX = "splash_screen_"


def retarget_splash(text: str, variant: str) -> str:
    """Point every splash_screen_<res> line at images/splash_<variant>_<res>.png."""
    out = []
    for line in text.splitlines():
        key, sep, _value = line.partition("=")
        key = key.strip()
        entry = line
        if sep and key.startswith(SPLASH_SCREEN_PREFIX):
            res = key[len(SPLASH_SCREEN_PREFIX) :]
            entry = f"{key}=pkg:/images/splash_{variant}_{res}.png"
        out.append(entry)
    return "\n".join(out).rstrip("\n") + "\n"


def strip_screensaver_manifest(text: str) -> str:
    """Manifest for the channel build: no screensaver_* attributes, the app splash."""
    kept = [
        line
        for line in text.splitlines()
        if not line.strip().startswith(SCREENSAVER_MANIFEST_PREFIX)
    ]
    return retarget_splash("\n".join(kept), "app")


VERSION_KEYS = ("major_version", "minor_version", "build_version")


def manifest_version(text: str) -> str:
    """major.minor.build from manifest text, e.g. "1.0.4"; a missing part reads as 0."""
    values: dict[str, str] = {}
    for line in text.splitlines():
        key, sep, value = line.partition("=")
        if sep:
            values[key.strip()] = value.strip()
    return ".".join(values.get(key, "0") for key in VERSION_KEYS)


SCREENSAVER_DROPPED_PREFIXES = ("title=",)


def screensaver_manifest(text: str) -> str:
    """Manifest for the screensaver build.

    Drops `title` (Roku classifies a package with both `title` and `screensaver_title`
    as a channel) and points the splash at the screensaver artwork, which tells a viewer
    who launched it from the store page that it runs when the Roku is idle.
    """
    kept = [
        line
        for line in text.splitlines()
        if not line.strip().startswith(SCREENSAVER_DROPPED_PREFIXES)
    ]
    return retarget_splash("\n".join(kept), "screensaver")


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
            elif screensaver_only and relative == "manifest":
                zf.writestr(relative, screensaver_manifest(file.read_text(encoding="utf-8")))
            elif screensaver_only and relative.endswith(".xml"):
                zf.writestr(relative, strip_key_handler_scripts(file.read_text(encoding="utf-8")))
            else:
                zf.write(file, relative)
            included.append(relative)
    return included
