from __future__ import annotations

import json
import urllib.request
from pathlib import Path
from typing import Any

import pytest

from conftest import fake_sources, make_channel
from flightwall_tools import cli, device
from flightwall_tools.device import RokuDevice

TEST_OUTPUT = (
    "***   Total  =  1 ; Passed  =  1 ; Failed   =  0 ; Skipped   =  0 ; Crashes  =  0\n"
    "*************             End testing                *************\n"
)


class FakeSocket:
    def __init__(self, chunks: list[bytes]) -> None:
        self.chunks = chunks

    def connect(self, address: tuple[str, int], /) -> None:
        return None

    def settimeout(self, timeout: float | None, /) -> None:
        return None

    def recv(self, size: int, /) -> bytes:
        return self.chunks.pop(0) if self.chunks else b""

    def send(self, data: bytes, /) -> int:
        return len(data)

    def close(self) -> None:
        return None


def fake_factory(
    installer_html: str = "<p>Install Success.</p>",
    console: str = TEST_OUTPUT,
    image_bytes: bytes = b"\xff\xd8jpeg",
    package_bytes: bytes = b"PKG" * 500,
) -> cli.DeviceFactory:
    def factory(host: str, password: str) -> RokuDevice:
        assert password == "pw"

        def opener(request: urllib.request.Request) -> device.HttpResponse:
            url = request.full_url
            if request.get_method() == "GET":
                if request.get_header("Authorization") is not None:
                    if url.endswith(".pkg"):
                        return device.HttpResponse(200, {}, package_bytes)
                    return device.HttpResponse(200, {}, image_bytes)
                challenge = 'Digest qop="auth", realm="rokudev", nonce="1"'
                return device.HttpResponse(401, {"www-authenticate": challenge}, b"")
            if url.endswith("/plugin_package"):
                return device.HttpResponse(200, {}, b'<a href="pkgs/FlightWall.pkg">pkg</a>')
            return device.HttpResponse(200, {}, installer_html.encode())

        return RokuDevice(
            host,
            password,
            opener=opener,
            socket_factory=lambda: FakeSocket([console.encode()]),
        )

    return factory


@pytest.fixture
def project(
    tmp_path: Path,
    land_geojson: dict[str, Any],
    lakes_geojson: dict[str, Any],
    places_geojson: dict[str, Any],
) -> Path:
    make_channel(tmp_path)
    fake_sources(tmp_path / ".cache", land_geojson, lakes_geojson, places_geojson)
    return tmp_path


def run(*argv: str, root: Path, factory: cli.DeviceFactory | None = None) -> int:
    args = ["--project-root", str(root), *argv]
    return cli.main(args, factory) if factory else cli.main(args)


def test_paths_and_default_root() -> None:
    paths = cli.Paths(Path("/p"))
    assert paths.roku == Path("/p/roku")
    assert paths.cache == Path("/p/.cache")
    assert paths.dist == Path("/p/dist")
    assert (cli.default_root() / "pyproject.toml").exists()
    assert isinstance(cli.make_device("1.2.3.4", "pw"), device.RokuDevice)


def test_resolve_password(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv(cli.PASSWORD_ENV, raising=False)
    assert cli.resolve_password("given") == "given"
    assert cli.resolve_password(None, lambda _prompt: "typed") == "typed"
    monkeypatch.setenv(cli.PASSWORD_ENV, "fromenv")
    assert cli.resolve_password("") == "fromenv"


def test_build_data_and_images(project: Path, capsys: pytest.CaptureFixture[str]) -> None:
    code = run("build-data", "--regions", "conus", "--px-per-deg", "2", root=project)
    assert code == 0
    data = project / "roku" / "data"
    assert data.joinpath("zips.txt").read_text().startswith("\n00601,")
    assert len(json.loads(data.joinpath("airports.json").read_text())["airports"]) == 3
    assert json.loads(data.joinpath("cities.json").read_text())["cities"][0]["n"] == "Bigcity"
    index = json.loads((project / "roku" / "images" / "tiles" / "index.json").read_text())
    assert index["px_per_deg"] == 2
    assert len(index["tiles"]) == 26 * 59
    out = capsys.readouterr().out
    assert "ZIP codes" in out
    assert run("images", root=project) == 0
    assert (project / "roku" / "images" / "planes" / "plane_090.png").exists()


def test_build_data_rejects_unknown_region(
    project: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    assert run("build-data", "--regions", "mars", root=project) == 2
    assert "unknown region(s): mars" in capsys.readouterr().out


def test_check_package_and_deploy(project: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert run("check", root=project) == 0
    assert run("package", root=project) == 0
    assert (project / "dist" / "flightwall.zip").exists()
    assert (
        run(
            "package",
            "--with-tests",
            "--screensaver-only",
            "--out",
            str(project / "custom.zip"),
            root=project,
        )
        == 0
    )
    assert (project / "custom.zip").exists()
    assert (
        run("deploy", "--host", "1.2.3.4", "--password", "pw", root=project, factory=fake_factory())
        == 0
    )
    assert "Installed on 1.2.3.4" in capsys.readouterr().out
    assert (
        run(
            "deploy",
            "--host",
            "1.2.3.4",
            "--password",
            "pw",
            root=project,
            factory=fake_factory("<p>Install Failure</p>"),
        )
        == 1
    )
    assert "Deploy failed" in capsys.readouterr().out


def test_run_tests_and_delete(project: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert (
        run(
            "run-tests",
            "--host",
            "h",
            "--password",
            "pw",
            "--timeout",
            "5",
            root=project,
            factory=fake_factory(),
        )
        == 0
    )
    assert "Total 1; passed 1" in capsys.readouterr().out
    failing = TEST_OUTPUT.replace("Failed   =  0", "Failed   =  1")
    assert (
        run(
            "run-tests",
            "--host",
            "h",
            "--password",
            "pw",
            root=project,
            factory=fake_factory(console=failing),
        )
        == 1
    )
    assert (
        run(
            "run-tests",
            "--host",
            "h",
            "--password",
            "pw",
            root=project,
            factory=fake_factory("<p>Install Failure</p>"),
        )
        == 1
    )
    assert "Test run failed" in capsys.readouterr().out
    assert (
        run("delete", "--host", "h", "--password", "pw", root=project, factory=fake_factory()) == 0
    )
    assert (
        run(
            "delete",
            "--host",
            "h",
            "--password",
            "pw",
            root=project,
            factory=fake_factory("<p>fail</p>"),
        )
        == 1
    )
    assert "Delete failed" in capsys.readouterr().out


def test_screenshot_command(project: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert (
        run("screenshot", "--host", "h", "--password", "pw", root=project, factory=fake_factory())
        == 0
    )
    assert (project / "dist" / "screenshot.jpg").read_bytes() == b"\xff\xd8jpeg"
    assert "Saved" in capsys.readouterr().out
    custom = project / "shot.jpg"
    assert (
        run(
            "screenshot",
            "--host",
            "h",
            "--password",
            "pw",
            "--out",
            str(custom),
            root=project,
            factory=fake_factory(),
        )
        == 0
    )
    assert custom.exists()
    assert (
        run(
            "screenshot",
            "--host",
            "h",
            "--password",
            "pw",
            root=project,
            factory=fake_factory(image_bytes=b"nope"),
        )
        == 1
    )
    assert "Screenshot failed" in capsys.readouterr().out


def test_genkey_and_sign_commands(project: Path, capsys: pytest.CaptureFixture[str]) -> None:
    keyed = fake_factory(
        console="Generating developer key...\r\nPassword: s3cret\r\nDevID: abc123\r\n"
    )
    assert run("genkey", "--host", "h", "--password", "pw", root=project, factory=keyed) == 0
    out = capsys.readouterr().out
    assert "DevID:    abc123" in out
    assert "Password: s3cret" in out
    assert (
        run("genkey", "--host", "h", "--password", "pw", root=project, factory=fake_factory()) == 1
    )
    assert "genkey failed" in capsys.readouterr().out

    assert (
        run(
            "sign",
            "--host",
            "h",
            "--password",
            "pw",
            "--signing-password",
            "s3cret",
            root=project,
            factory=fake_factory(),
        )
        == 0
    )
    assert (project / "dist" / "flightwall-screensaver.pkg").read_bytes() == b"PKG" * 500
    assert "Saved signed package" in capsys.readouterr().out
    custom = project / "custom.pkg"
    assert (
        run(
            "sign",
            "--host",
            "h",
            "--password",
            "pw",
            "--signing-password",
            "s3cret",
            "--out",
            str(custom),
            root=project,
            factory=fake_factory(),
        )
        == 0
    )
    assert custom.exists()
    assert (
        run(
            "sign",
            "--host",
            "h",
            "--password",
            "pw",
            "--signing-password",
            "s3cret",
            root=project,
            factory=fake_factory(package_bytes=b"short"),
        )
        == 1
    )
    assert "Signing failed" in capsys.readouterr().out


def test_commands_refuse_broken_channel(project: Path, capsys: pytest.CaptureFixture[str]) -> None:
    (project / "roku" / "source" / "lib.brs").write_text("sub broken()\n", encoding="utf-8")
    assert run("check", root=project) == 1
    assert "never closed" in capsys.readouterr().out
    assert run("package", root=project) == 1
    assert (
        run("deploy", "--host", "h", "--password", "pw", root=project, factory=fake_factory()) == 1
    )
    assert (
        run("run-tests", "--host", "h", "--password", "pw", root=project, factory=fake_factory())
        == 1
    )


def test_all_command(project: Path) -> None:
    assert run("all", "--regions", "conus", "--px-per-deg", "2", root=project) == 0
    assert (project / "dist" / "flightwall.zip").exists()
    assert (project / "dist" / "flightwall-screensaver.zip").exists()
    assert run("all", "--regions", "nowhere", root=project) == 2
    (project / "roku" / "source" / "lib.brs").write_text("sub broken()\n", encoding="utf-8")
    assert run("all", "--regions", "conus", "--px-per-deg", "2", root=project) == 1


def test_version_flag(capsys: pytest.CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit) as exc:
        cli.main(["--version"])
    assert exc.value.code == 0
    assert "1.0.0" in capsys.readouterr().out
