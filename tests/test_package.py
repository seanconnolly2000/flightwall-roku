from __future__ import annotations

import zipfile
from pathlib import Path

import pytest

from flightwall_tools import package


def test_should_include() -> None:
    assert package.should_include("manifest", False, False)
    assert not package.should_include("images/.DS_Store", True, False)
    assert not package.should_include("source/testFramework/LICENSE", True, False)
    assert not package.should_include("source/tests/Test__X.brs", False, False)
    assert package.should_include("source/tests/Test__X.brs", True, False)
    assert package.should_include("source/main.brs", False, False)
    assert not package.should_include("source/main.brs", False, True)
    assert package.should_include("source/screensaver.brs", False, True)
    assert package.should_include("source/screensaver.brs", False, False)
    assert not package.should_include("source/screensaver.brs", False, False, channel_only=True)
    assert package.should_include("source/main.brs", False, False, channel_only=True)


def test_strip_screensaver_manifest() -> None:
    text = "title=X\nscreensaver_title=X\n  screensaver_private=1\nrsg_version=1.3\n"
    assert package.strip_screensaver_manifest(text) == "title=X\nrsg_version=1.3\n"
    assert package.strip_screensaver_manifest("title=X") == "title=X\n"


def test_screensaver_manifest_drops_title_only() -> None:
    text = "title=X\nsubtitle=Y\nscreensaver_title=X\nmm_icon_focus_hd=pkg:/i.png\n"
    assert package.screensaver_manifest(text) == (
        "subtitle=Y\nscreensaver_title=X\nmm_icon_focus_hd=pkg:/i.png\n"
    )


def test_build_package_requires_manifest(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        package.build_package(tmp_path, tmp_path / "out.zip")


def test_build_package_rejects_conflicting_variants(channel: Path, tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="both"):
        package.build_package(channel, tmp_path / "x.zip", screensaver_only=True, channel_only=True)


def test_build_package_variants(channel: Path, tmp_path: Path) -> None:
    out = tmp_path / "dist" / "app.zip"
    included = package.build_package(channel, out)
    assert "manifest" in included
    assert "source/main.brs" in included
    assert "source/screensaver.brs" in included
    assert not any(p.startswith("source/tests/") for p in included)
    with zipfile.ZipFile(out) as zf:
        assert sorted(zf.namelist()) == included
        assert b"screensaver_title=Test" in zf.read("manifest")

    with_tests = package.build_package(channel, tmp_path / "t.zip", with_tests=True)
    assert "source/tests/Test__Lib.brs" in with_tests
    assert "source/testFramework/UnitTestFramework.brs" in with_tests

    saver = package.build_package(channel, tmp_path / "s.zip", screensaver_only=True)
    assert "source/main.brs" not in saver
    assert "source/screensaver.brs" in saver
    assert "manifest" in saver
    with zipfile.ZipFile(tmp_path / "s.zip") as zf:
        saver_manifest = zf.read("manifest").decode()
        assert "title=Test" not in saver_manifest.replace("screensaver_title=Test", "")
        assert "screensaver_title=Test" in saver_manifest
        assert "mm_icon_focus_hd" in saver_manifest

    only_channel = package.build_package(channel, tmp_path / "c.zip", channel_only=True)
    assert "source/main.brs" in only_channel
    assert "source/screensaver.brs" not in only_channel
    with zipfile.ZipFile(tmp_path / "c.zip") as zf:
        manifest = zf.read("manifest").decode()
        assert "screensaver_" not in manifest
        assert "title=Test" in manifest
