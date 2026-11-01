from __future__ import annotations

import urllib.error
import urllib.request
from email.message import Message
from pathlib import Path
from typing import Any, Self

import pytest

from flightwall_tools import device

SUCCESS_HTML = "<html><body><font color='red'>Install Success.</font></body></html>"
FAILURE_HTML = "<html><body><font color='red'>Install Failure: bad zip</font></body></html>"
CHALLENGE = 'Digest qop="auth", realm="rokudev", nonce="1793511681"'
TEST_OUTPUT = """
***   Total  =  3 ; Passed  =  2 ; Failed   =  1 ; Skipped   =  0 ; Crashes  =  0
*************             End testing                *************
"""


class FakeSocket:
    def __init__(self, chunks: list[bytes], raise_timeout_first: bool = False) -> None:
        self.chunks = list(chunks)
        self.raise_timeout_first = raise_timeout_first
        self.closed = False
        self.address: tuple[str, int] | None = None
        self.timeout: float | None = None

    def connect(self, address: tuple[str, int], /) -> None:
        self.address = address

    def settimeout(self, timeout: float | None, /) -> None:
        self.timeout = timeout

    def recv(self, size: int, /) -> bytes:
        if self.raise_timeout_first:
            self.raise_timeout_first = False
            raise TimeoutError
        return self.chunks.pop(0) if self.chunks else b""

    def send(self, data: bytes, /) -> int:
        self.sent = data
        return len(data)

    def close(self) -> None:
        self.closed = True


class FakeClock:
    def __init__(self, step: float = 0.5) -> None:
        self.now = 0.0
        self.step = step

    def __call__(self) -> float:
        self.now += self.step
        return self.now


def make_device(
    installer_html: str = SUCCESS_HTML,
    sock: FakeSocket | None = None,
    clock: Any = None,
    challenge: str | None = CHALLENGE,
    probe_status: int = 401,
    post_status: int = 200,
    inspect_html: str = '<img src="pkgs/dev.png?time=1">',
    image_bytes: bytes = b"\x89PNGfake",
    package_html: str = '<a href="pkgs/FlightWall.pkg">download</a>',
    package_bytes: bytes = b"PKG" * 500,
) -> tuple[device.RokuDevice, list[urllib.request.Request]]:
    requests: list[urllib.request.Request] = []

    def opener(request: urllib.request.Request) -> device.HttpResponse:
        requests.append(request)
        url = request.full_url
        unauthenticated = request.get_header("Authorization") is None
        if ":80/" in url and request.get_method() == "GET" and unauthenticated:
            headers = {"www-authenticate": challenge} if challenge else {}
            return device.HttpResponse(probe_status, headers, b"")
        if url.endswith("/plugin_install"):
            return device.HttpResponse(post_status, {}, installer_html.encode())
        if url.endswith("/plugin_inspect"):
            return device.HttpResponse(200, {}, inspect_html.encode())
        if url.endswith("/plugin_package"):
            return device.HttpResponse(200, {}, package_html.encode())
        if url.endswith(".pkg"):
            return device.HttpResponse(200, {}, package_bytes)
        if "/pkgs/dev." in url:
            return device.HttpResponse(200, {}, image_bytes)
        return device.HttpResponse(200, {}, b"")

    dev = device.RokuDevice(
        "10.0.0.5",
        "pw",
        opener=opener,
        socket_factory=lambda: sock or FakeSocket([]),
        clock=clock or FakeClock(),
        nonce_factory=lambda: "cafe",
    )
    return dev, requests


def test_encode_multipart() -> None:
    content_type, body = device.encode_multipart(
        {"mysubmit": "Install"}, "archive", "a.zip", b"ZIP"
    )
    boundary = content_type.split("boundary=")[1]
    assert body.startswith(f"--{boundary}\r\n".encode())
    assert b'name="mysubmit"\r\n\r\nInstall\r\n' in body
    assert (
        b'name="archive"; filename="a.zip"\r\nContent-Type: application/zip\r\n\r\nZIP\r\n' in body
    )
    assert body.endswith(f"--{boundary}--\r\n".encode())
    _, no_file = device.encode_multipart({"mysubmit": "Delete"}, None, "", b"")
    assert b"filename=" not in no_file


def test_parse_digest_challenge() -> None:
    parsed = device.parse_digest_challenge(CHALLENGE)
    assert parsed == {"qop": "auth", "realm": "rokudev", "nonce": "1793511681"}
    assert device.parse_digest_challenge('Digest realm=x, opaque="o"') == {
        "realm": "x",
        "opaque": "o",
    }
    with pytest.raises(device.DeviceError, match="unsupported"):
        device.parse_digest_challenge("Basic realm=x")


def test_digest_authorization_matches_rfc2617_example() -> None:
    challenge = {
        "realm": "testrealm@host.com",
        "qop": "auth,auth-int",
        "nonce": "dcd98b7102dd2f0e8b11d0f600bfb0c093",
        "opaque": "5ccc069c403ebaf9f0171e9517f40e41",
    }
    header = device.digest_authorization(
        "Mufasa", "Circle Of Life", "GET", "/dir/index.html", challenge, "0a4f113b"
    )
    assert 'response="6629fae49393a05397450978507c4ef1"' in header
    assert "qop=auth, nc=00000001" in header
    assert 'opaque="5ccc069c403ebaf9f0171e9517f40e41"' in header
    legacy = device.digest_authorization("u", "p", "POST", "/x", {"realm": "r", "nonce": "n"}, "c")
    assert "qop=" not in legacy
    assert legacy.startswith('Digest username="u", realm="r", nonce="n", uri="/x", response="')


def test_summarize_installer_response() -> None:
    assert device.summarize_installer_response(SUCCESS_HTML) == "Install Success."
    assert device.summarize_installer_response("<p>nothing</p><p>here</p>") == "nothing here"
    with_script = (
        "<p>Install Success.</p><script>\nvar params = JSON.parse('{\"Install Success\": 1}');\n"
        "function f() {}\nRoku.x = 1;\n</script>"
    )
    assert device.summarize_installer_response(with_script) == "Install Success."


def test_parse_test_report() -> None:
    report = device.parse_test_report(TEST_OUTPUT)
    assert (report.total, report.passed, report.failed, report.skipped, report.crashes) == (
        3,
        2,
        1,
        0,
        0,
    )
    assert not report.ok
    assert device.parse_test_report("no totals here").total == 0
    assert not device.parse_test_report("").ok
    good = device.TestReport("", 2, 2, 0, 0, 0)
    assert good.ok


def test_install_and_delete(tmp_path: Path) -> None:
    archive = tmp_path / "pkg.zip"
    archive.write_bytes(b"PK")
    dev, requests = make_device()
    assert dev.install(archive) == "Install Success."
    probe, upload = requests[0], requests[1]
    assert probe.get_method() == "GET"
    assert upload.full_url == "http://10.0.0.5:80/plugin_install"
    assert upload.get_method() == "POST"
    authorization = upload.get_header("Authorization")
    assert authorization is not None
    assert authorization.startswith('Digest username="rokudev", realm="rokudev"')
    assert 'cnonce="cafe"' in authorization
    upload_body = upload.data
    assert isinstance(upload_body, bytes)
    assert b"PK" in upload_body
    assert dev.delete() == "Install Success."
    delete_body = requests[3].data
    assert isinstance(delete_body, bytes)
    assert b"Delete" in delete_body


def test_install_failures(tmp_path: Path) -> None:
    archive = tmp_path / "pkg.zip"
    archive.write_bytes(b"PK")
    dev, _ = make_device(FAILURE_HTML)
    with pytest.raises(device.DeviceError, match="bad zip"):
        dev.install(archive)
    dev, _ = make_device(post_status=401)
    with pytest.raises(device.DeviceError, match="rejected the developer password"):
        dev.install(archive)
    dev, _ = make_device(probe_status=200, challenge=None)
    with pytest.raises(device.DeviceError, match="developer mode"):
        dev.install(archive)
    dev, _ = make_device(challenge=None)
    with pytest.raises(device.DeviceError, match="developer mode"):
        dev.install(archive)


def test_screenshot(tmp_path: Path) -> None:
    dev, requests = make_device()
    out = dev.screenshot(tmp_path / "shots" / "a.png")
    assert out.read_bytes() == b"\x89PNGfake"
    urls = [r.full_url for r in requests]
    assert urls[1] == "http://10.0.0.5:80/plugin_inspect"
    assert urls[3] == "http://10.0.0.5:80/pkgs/dev.png"
    assert requests[1].get_method() == "POST"
    inspect_body = requests[1].data
    assert isinstance(inspect_body, bytes)
    assert b'name="mysubmit"\r\n\r\nScreenshot' in inspect_body

    dev, requests = make_device(inspect_html="<p>no image tag</p>", image_bytes=b"\xff\xd8jpeg")
    dev.screenshot(tmp_path / "b.jpg")
    assert requests[3].full_url == "http://10.0.0.5:80/pkgs/dev.jpg"

    dev, _ = make_device(image_bytes=b"<html>not an image</html>")
    with pytest.raises(device.DeviceError, match="did not return a screenshot"):
        dev.screenshot(tmp_path / "c.jpg")


def test_genkey() -> None:
    sock = FakeSocket(
        [b"Generating developer key...\r\nPassword: s3cret\r\n", b"DevID: deadbeef01\r\n"]
    )
    dev, _ = make_device(sock=sock, clock=FakeClock(0.5))
    key = dev.genkey(timeout=30)
    assert key == device.SigningKey("deadbeef01", "s3cret")
    assert sock.address == ("10.0.0.5", 8080)
    assert sock.sent == b"genkey\r\n"
    assert sock.closed
    dev, _ = make_device(sock=FakeSocket([b"nothing useful\r\n"]), clock=FakeClock(0.5))
    with pytest.raises(device.DeviceError, match="did not return a key"):
        dev.genkey(timeout=3)


def test_sign(tmp_path: Path) -> None:
    dev, requests = make_device()
    out = dev.sign("FlightWall/1.0", "s3cret", tmp_path / "out" / "fw.pkg")
    assert out.read_bytes() == b"PKG" * 500
    post = requests[1]
    assert post.full_url == "http://10.0.0.5:80/plugin_package"
    post_body = post.data
    assert isinstance(post_body, bytes)
    assert b'name="app_name"\r\n\r\nFlightWall/1.0' in post_body
    assert b'name="passwd"\r\n\r\ns3cret' in post_body
    assert requests[3].full_url == "http://10.0.0.5:80/pkgs/FlightWall.pkg"

    dev, _ = make_device(package_html="<p>Failed: wrong password</p>")
    with pytest.raises(device.DeviceError, match="packaging failed"):
        dev.sign("FlightWall/1.0", "bad", tmp_path / "a.pkg")
    dev, _ = make_device(package_bytes=b"<html>oops</html>")
    with pytest.raises(device.DeviceError, match="did not return a signed package"):
        dev.sign("FlightWall/1.0", "s3cret", tmp_path / "b.pkg")


def test_ecp_commands() -> None:
    dev, requests = make_device()
    dev.launch_dev()
    dev.launch_dev({"RunTests": "true", "x": "1"})
    dev.press_home()
    assert [r.full_url for r in requests] == [
        "http://10.0.0.5:8060/launch/dev",
        "http://10.0.0.5:8060/launch/dev?RunTests=true&x=1",
        "http://10.0.0.5:8060/keypress/Home",
    ]


def test_read_console_stops_after_marker_grace() -> None:
    sock = FakeSocket([b"line1\n", b"End testing\n", b"after\n", b"more\n", b"x\n", b"y\n"], True)
    dev, _ = make_device(sock=sock, clock=FakeClock(0.5))
    opened = dev.open_console()
    assert opened is sock
    assert sock.address == ("10.0.0.5", 8085)
    assert sock.timeout == 1.0
    text = dev.read_console(opened, timeout=100, stop_marker="End testing", grace=1.0)
    assert text.startswith("line1\nEnd testing\n")
    assert sock.closed


def test_read_console_timeout_and_eof() -> None:
    sock = FakeSocket([b"a"] * 100)
    dev, _ = make_device(sock=sock, clock=FakeClock(1.0))
    assert dev.read_console(sock, timeout=3, stop_marker=None) == "aaa"
    eof = FakeSocket([b"z"])
    dev, _ = make_device(sock=eof, clock=FakeClock(0.1))
    assert dev.read_console(eof, timeout=50, stop_marker="never") == "z"


def test_run_device_tests(tmp_path: Path) -> None:
    archive = tmp_path / "tests.zip"
    archive.write_bytes(b"PK")
    sock = FakeSocket([TEST_OUTPUT.encode()])
    dev, requests = make_device(sock=sock)
    report = device.run_device_tests(dev, archive, timeout=10)
    assert report.total == 3
    assert [r.full_url for r in requests][2:] == [
        "http://10.0.0.5:8060/keypress/Home",
        "http://10.0.0.5:8060/launch/dev?RunTests=true",
    ]


class _Response:
    def __init__(self, body: bytes, status: int = 200) -> None:
        self.body = body
        self.status = status
        self.headers = Message()
        self.headers["Content-Type"] = "text/html"

    def read(self) -> bytes:
        return self.body

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *_: object) -> None:
        return None


def test_plain_opener(monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_urlopen(request: urllib.request.Request, timeout: float) -> _Response:
        if request.full_url.endswith("/denied"):
            headers = Message()
            headers["WWW-Authenticate"] = CHALLENGE
            raise urllib.error.HTTPError(request.full_url, 401, "Unauthorized", headers, None)
        return _Response(b"plain")

    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    send = device.plain_opener()
    ok = send(urllib.request.Request("http://1.2.3.4:8060/x"))
    assert (ok.status, ok.body, ok.headers) == (200, b"plain", {"content-type": "text/html"})
    assert ok.text == "plain"
    denied = send(urllib.request.Request("http://1.2.3.4/denied"))
    assert denied.status == 401
    assert denied.headers["www-authenticate"] == CHALLENGE


def test_default_construction_uses_real_socket_and_nonce() -> None:
    dev = device.RokuDevice("1.2.3.4", "pw")
    assert dev.host == "1.2.3.4"
    assert dev._socket_factory.__name__ == "socket"
    assert len(dev._nonce_factory()) == 32
