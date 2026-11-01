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


def test_build_package_requires_manifest(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        package.build_package(tmp_path, tmp_path / "out.zip")


def test_build_package_variants(channel: Path, tmp_path: Path) -> None:
    out = tmp_path / "dist" / "app.zip"
    included = package.build_package(channel, out)
    assert "manifest" in included
    assert "source/main.brs" in included
    assert not any(p.startswith("source/tests/") for p in included)
    with zipfile.ZipFile(out) as zf:
        assert sorted(zf.namelist()) == included

    with_tests = package.build_package(channel, tmp_path / "t.zip", with_tests=True)
    assert "source/tests/Test__Lib.brs" in with_tests
    assert "source/testFramework/UnitTestFramework.brs" in with_tests

    saver = package.build_package(channel, tmp_path / "s.zip", screensaver_only=True)
    assert "source/main.brs" not in saver
    assert "manifest" in saver
