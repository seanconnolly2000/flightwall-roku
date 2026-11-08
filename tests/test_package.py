from __future__ import annotations

import zipfile
from pathlib import Path

import pytest

from skytraffic_tools import package


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
    assert package.strip_screensaver_manifest("title=X\nsplash_screen_sd=pkg:/s.png\n") == (
        "title=X\nsplash_screen_sd=pkg:/images/splash_app_sd.png\n"
    )


def test_retarget_splash() -> None:
    text = "splash_screen_hd=pkg:/a.png\n splash_screen_fhd = pkg:/b.png\n"
    text += "splash_color=#000\nno equals\n"
    assert package.retarget_splash(text, "screensaver") == (
        "splash_screen_hd=pkg:/images/splash_screensaver_hd.png\n"
        "splash_screen_fhd=pkg:/images/splash_screensaver_fhd.png\n"
        "splash_color=#000\nno equals\n"
    )


def test_strip_key_handler_scripts() -> None:
    xml = (
        "<component>\n"
        '  <script uri="pkg:/components/MainScene.brs"/>\n'
        '  <script uri="pkg:/components/MainSceneKeys.brs"/>\n'
        "</component>\n"
    )
    assert package.strip_key_handler_scripts(xml) == (
        '<component>\n  <script uri="pkg:/components/MainScene.brs"/>\n</component>\n'
    )


def test_manifest_version() -> None:
    text = "title=X\nmajor_version=1\nminor_version = 0\nbuild_version=4\n"
    assert package.manifest_version(text) == "1.0.4"
    assert package.manifest_version("title=X\nno equals sign here\n") == "0.0.0"
    assert package.manifest_version("") == "0.0.0"


def test_screensaver_manifest_drops_title_and_swaps_splash() -> None:
    text = (
        "title=X\nsubtitle=Y\nscreensaver_title=X\nmm_icon_focus_hd=pkg:/i.png\n"
        "splash_screen_hd=pkg:/s.png\nsplash_color=#000000\n"
    )
    assert package.screensaver_manifest(text) == (
        "subtitle=Y\nscreensaver_title=X\nmm_icon_focus_hd=pkg:/i.png\n"
        "splash_screen_hd=pkg:/images/splash_screensaver_hd.png\nsplash_color=#000000\n"
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
    assert "components/MainSceneKeys.brs" not in saver
    assert "components/MainSceneKeys.brs" in included
    with zipfile.ZipFile(tmp_path / "s.zip") as zf:
        saver_manifest = zf.read("manifest").decode()
        assert "title=Test" not in saver_manifest.replace("screensaver_title=Test", "")
        assert "screensaver_title=Test" in saver_manifest
        assert "mm_icon_focus_hd" in saver_manifest
        assert "splash_screen_hd=pkg:/images/splash_screensaver_hd.png" in saver_manifest
        scene_xml = zf.read("components/MainScene.xml").decode()
        assert "MainSceneKeys.brs" not in scene_xml
        assert 'uri="pkg:/components/MainScene.brs"' in scene_xml
        assert b"onKeyEvent" not in b"".join(
            zf.read(name) for name in zf.namelist() if name.endswith(".brs")
        )

    only_channel = package.build_package(channel, tmp_path / "c.zip", channel_only=True)
    assert "source/main.brs" in only_channel
    assert "source/screensaver.brs" not in only_channel
    with zipfile.ZipFile(tmp_path / "c.zip") as zf:
        manifest = zf.read("manifest").decode()
        assert "screensaver_" not in manifest
        assert "title=Test" in manifest
        assert "splash_screen_hd=pkg:/images/splash_app_hd.png" in manifest
