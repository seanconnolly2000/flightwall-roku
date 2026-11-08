"""Talk to a Roku in developer mode: side-load, launch, and read the debug console.

Only official device interfaces are used: the Development Application Installer
on port 80 (HTTP digest auth), External Control Protocol on port 8060, and the
BrightScript console on port 8085.

Digest authentication is done by hand: the installer closes the connection as soon
as it answers 401, so the upload must already carry the Authorization header.
"""

from __future__ import annotations

import hashlib
import re
import socket
import time
import urllib.error
import urllib.request
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

INSTALLER_PORT = 80
ECP_PORT = 8060
CONSOLE_PORT = 8085
INSTALLER_PATH = "/plugin_install"
INSPECT_PATH = "/plugin_inspect"
PACKAGE_PATH = "/plugin_package"
GENKEY_PORT = 8080
GENKEY_PASSWORD = re.compile(r"Password:\s*(\S+)")
GENKEY_DEVID = re.compile(r"DevID:\s*([0-9A-Fa-f]+)")
PACKAGE_LINK = re.compile(r"(pkgs/[^\"'<>\s]+\.pkg)")
MIN_PACKAGE_BYTES = 1000
SCREENSHOT_PATH = "/pkgs/dev.jpg"
SCREENSHOT_IMAGE = re.compile(r"(pkgs/dev\.(?:jpg|png))")
IMAGE_MAGIC = (b"\xff\xd8", b"\x89PNG")
TEST_END_MARKER = "End testing"
TOTAL_LINE = re.compile(
    r"Total\s*=\s*(\d+)\s*;\s*Passed\s*=\s*(\d+)\s*;\s*Failed\s*=\s*(\d+)"
    r"\s*;\s*Skipped\s*=\s*(\d+)\s*;\s*Crashes\s*=\s*(\d+)"
)
SUCCESS_MARKERS = ("install success", "identical to previous version", "application received")
TAG = re.compile(r"<[^>]+>")
CHALLENGE_PAIR = re.compile(r'(\w+)=("[^"]*"|[^,]*)')
HTTP_UNAUTHORIZED = 401


class DeviceError(RuntimeError):
    """Raised when the device rejects an operation."""


class ConsoleSocket(Protocol):
    def connect(self, address: tuple[str, int], /) -> None: ...
    def settimeout(self, timeout: float | None, /) -> None: ...
    def recv(self, size: int, /) -> bytes: ...
    def send(self, data: bytes, /) -> int: ...
    def close(self) -> None: ...


@dataclass(frozen=True)
class SigningKey:
    dev_id: str
    password: str


@dataclass(frozen=True)
class HttpResponse:
    status: int
    headers: dict[str, str]
    body: bytes

    @property
    def text(self) -> str:
        return self.body.decode("utf-8", errors="replace")


Opener = Callable[[urllib.request.Request], HttpResponse]
SocketFactory = Callable[[], ConsoleSocket]
Clock = Callable[[], float]
NonceFactory = Callable[[], str]


def encode_multipart(
    fields: dict[str, str], file_field: str | None, file_name: str, file_data: bytes
) -> tuple[str, bytes]:
    boundary = uuid.uuid4().hex
    parts: list[bytes] = [
        f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode()
        for key, value in fields.items()
    ]
    if file_field is not None:
        header = (
            f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; '
            f'filename="{file_name}"\r\nContent-Type: application/zip\r\n\r\n'
        ).encode()
        parts.append(header + file_data + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    return f"multipart/form-data; boundary={boundary}", b"".join(parts)


def plain_opener(timeout: float = 120) -> Opener:
    """An opener that returns HTTP error statuses as responses instead of raising."""

    def send(request: urllib.request.Request) -> HttpResponse:
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                headers = {k.lower(): v for k, v in response.headers.items()}
                return HttpResponse(response.status, headers, bytes(response.read()))
        except urllib.error.HTTPError as error:
            headers = {k.lower(): v for k, v in error.headers.items()}
            return HttpResponse(error.code, headers, error.read())

    return send


def parse_digest_challenge(header: str) -> dict[str, str]:
    if not header.lower().startswith("digest "):
        msg = f"unsupported authentication challenge: {header}"
        raise DeviceError(msg)
    return {
        key.lower(): value.strip().strip('"')
        for key, value in CHALLENGE_PAIR.findall(header[len("digest ") :])
    }


def _md5(text: str) -> str:
    return hashlib.md5(text.encode(), usedforsecurity=False).hexdigest()


def digest_authorization(
    user: str,
    password: str,
    method: str,
    uri: str,
    challenge: dict[str, str],
    cnonce: str,
    nc: int = 1,
) -> str:
    """Build an RFC 2617 Digest Authorization header for one request."""
    realm = challenge.get("realm", "")
    nonce = challenge.get("nonce", "")
    ha1 = _md5(f"{user}:{realm}:{password}")
    ha2 = _md5(f"{method}:{uri}")
    qop_options = [q.strip() for q in challenge.get("qop", "").split(",") if q.strip()]
    parts = [f'username="{user}"', f'realm="{realm}"', f'nonce="{nonce}"', f'uri="{uri}"']
    if "auth" in qop_options:
        nc_text = f"{nc:08x}"
        response = _md5(f"{ha1}:{nonce}:{nc_text}:{cnonce}:auth:{ha2}")
        parts += ["qop=auth", f"nc={nc_text}", f'cnonce="{cnonce}"']
    else:
        response = _md5(f"{ha1}:{nonce}:{ha2}")
    parts.append(f'response="{response}"')
    if "opaque" in challenge:
        parts.append(f'opaque="{challenge["opaque"]}"')
    return "Digest " + ", ".join(parts)


def summarize_installer_response(html: str) -> str:
    text = TAG.sub(" ", html)
    lines = [" ".join(ln.split()) for ln in text.splitlines() if ln.strip()]
    lines = [ln for ln in lines if not ln.startswith(("var ", "function ", "Roku."))]
    interesting = [ln for ln in lines if any(m in ln.lower() for m in (*SUCCESS_MARKERS, "fail"))]
    return " | ".join(interesting) if interesting else " ".join(lines)[:300]


@dataclass(frozen=True)
class TestReport:
    output: str
    total: int
    passed: int
    failed: int
    skipped: int
    crashes: int

    @property
    def ok(self) -> bool:
        return self.total > 0 and self.failed == 0 and self.crashes == 0


def parse_test_report(output: str) -> TestReport:
    totals = TOTAL_LINE.findall(output)
    if not totals:
        return TestReport(output, 0, 0, 0, 0, 0)
    total, passed, failed, skipped, crashes = (int(v) for v in totals[-1])
    return TestReport(output, total, passed, failed, skipped, crashes)


def _random_nonce() -> str:
    return uuid.uuid4().hex


class RokuDevice:
    def __init__(
        self,
        host: str,
        password: str,
        user: str = "rokudev",
        opener: Opener | None = None,
        socket_factory: SocketFactory | None = None,
        clock: Clock = time.monotonic,
        nonce_factory: NonceFactory = _random_nonce,
    ) -> None:
        self.host = host
        self.user = user
        self._password = password
        self._opener = opener or plain_opener()
        self._socket_factory = socket_factory or socket.socket
        self._clock = clock
        self._nonce_factory = nonce_factory

    def _url(self, path: str) -> str:
        return f"http://{self.host}:{INSTALLER_PORT}{path}"

    def _challenge(self, path: str) -> dict[str, str]:
        probe = self._opener(urllib.request.Request(self._url(path), method="GET"))
        header = probe.headers.get("www-authenticate", "")
        if probe.status != HTTP_UNAUTHORIZED or not header:
            msg = (
                f"installer at {self.host} did not ask for authentication (HTTP {probe.status}); "
                "is developer mode enabled?"
            )
            raise DeviceError(msg)
        return parse_digest_challenge(header)

    def _digest_request(
        self, method: str, path: str, body: bytes = b"", content_type: str = ""
    ) -> HttpResponse:
        """One authenticated request to the developer web server (probe, then send)."""
        challenge = self._challenge(path)
        headers = {
            "Authorization": digest_authorization(
                self.user, self._password, method, path, challenge, self._nonce_factory()
            )
        }
        if content_type:
            headers["Content-Type"] = content_type
        request = urllib.request.Request(
            self._url(path), data=body if method == "POST" else None, headers=headers, method=method
        )
        response = self._opener(request)
        if response.status == HTTP_UNAUTHORIZED:
            msg = f"the Roku at {self.host} rejected the developer password"
            raise DeviceError(msg)
        return response

    def _installer_post(self, fields: dict[str, str], archive: Path | None = None) -> str:
        file_data = archive.read_bytes() if archive is not None else b""
        content_type, body = encode_multipart(
            fields, "archive" if archive is not None else None, "channel.zip", file_data
        )
        response = self._digest_request("POST", INSTALLER_PATH, body, content_type)
        html = response.text
        summary = summarize_installer_response(html)
        if not any(marker in html.lower() for marker in SUCCESS_MARKERS):
            msg = f"installer did not report success (HTTP {response.status}): {summary}"
            raise DeviceError(msg)
        return summary

    def screenshot(self, out_path: Path) -> Path:
        """Save a screenshot of the running side-loaded channel (installer utility page)."""
        content_type, body = encode_multipart(
            {"mysubmit": "Screenshot", "passwd": ""}, "archive", "", b""
        )
        page = self._digest_request("POST", INSPECT_PATH, body, content_type)
        match = SCREENSHOT_IMAGE.search(page.text)
        image_path = "/" + match.group(1) if match else SCREENSHOT_PATH
        image = self._digest_request("GET", image_path)
        if not image.body.startswith(IMAGE_MAGIC):
            msg = "the Roku did not return a screenshot; is the side-loaded channel running?"
            raise DeviceError(msg)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_bytes(image.body)
        return out_path

    def genkey(self, timeout: float = 90.0) -> SigningKey:
        """Generate a new package-signing key on the device (the 'genkey' console command).

        Run this once per device and keep the password: every later package for the same
        channel must be signed with the same key.
        """
        sock = self._socket_factory()
        sock.settimeout(1.0)
        sock.connect((self.host, GENKEY_PORT))
        sock.send(b"genkey\r\n")
        text = self.read_console(sock, timeout, "DevID:")
        password = GENKEY_PASSWORD.search(text)
        dev_id = GENKEY_DEVID.search(text)
        if password is None or dev_id is None:
            msg = f"genkey did not return a key: {' '.join(text.split())[-300:]}"
            raise DeviceError(msg)
        return SigningKey(dev_id.group(1), password.group(1))

    def sign(self, app_name: str, signing_password: str, out_path: Path) -> Path:
        """Sign the currently side-loaded channel and save the .pkg (installer 'Package' action)."""
        fields = {
            "mysubmit": "Package",
            "app_name": app_name,
            "passwd": signing_password,
            "pkg_time": str(int(time.time())),
        }
        content_type, body = encode_multipart(fields, None, "", b"")
        page = self._digest_request("POST", PACKAGE_PATH, body, content_type)
        match = PACKAGE_LINK.search(page.text)
        if match is None:
            msg = f"packaging failed: {summarize_installer_response(page.text)}"
            raise DeviceError(msg)
        package = self._digest_request("GET", "/" + match.group(1))
        if len(package.body) < MIN_PACKAGE_BYTES or package.body.lstrip().startswith(b"<"):
            msg = "the Roku did not return a signed package"
            raise DeviceError(msg)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_bytes(package.body)
        return out_path

    def install(self, archive: Path) -> str:
        """Side-load a zip package; returns the installer's status text."""
        return self._installer_post({"mysubmit": "Install"}, archive)

    def delete(self) -> str:
        """Remove the side-loaded channel; returns the installer's status text."""
        return self._installer_post({"mysubmit": "Delete"})

    def ecp_post(self, path: str) -> None:
        request = urllib.request.Request(
            f"http://{self.host}:{ECP_PORT}/{path}", data=b"", method="POST"
        )
        self._opener(request)

    def launch_dev(self, params: dict[str, str] | None = None) -> None:
        query = "&".join(f"{k}={v}" for k, v in (params or {}).items())
        self.ecp_post("launch/dev" + (f"?{query}" if query else ""))

    def press_home(self) -> None:
        self.ecp_post("keypress/Home")

    def open_console(self) -> ConsoleSocket:
        sock = self._socket_factory()
        sock.settimeout(1.0)
        sock.connect((self.host, CONSOLE_PORT))
        return sock

    def read_console(
        self, sock: ConsoleSocket, timeout: float, stop_marker: str | None, grace: float = 2.0
    ) -> str:
        """Read console text until the marker appears (plus a grace period) or timeout."""
        chunks: list[bytes] = []
        start = self._clock()
        marker_seen_at: float | None = None
        while True:
            now = self._clock()
            if now - start > timeout:
                break
            if marker_seen_at is not None and now - marker_seen_at > grace:
                break
            try:
                data = sock.recv(4096)
            except TimeoutError:
                continue
            if not data:
                break
            chunks.append(data)
            if stop_marker and marker_seen_at is None:
                text = b"".join(chunks).decode("utf-8", errors="replace")
                if stop_marker in text:
                    marker_seen_at = self._clock()
        sock.close()
        return b"".join(chunks).decode("utf-8", errors="replace")


def run_device_tests(device: RokuDevice, archive: Path, timeout: float = 180.0) -> TestReport:
    """Install a test build, launch it with RunTests=true, and collect the results."""
    device.install(archive)
    device.press_home()
    sock = device.open_console()
    device.launch_dev({"RunTests": "true"})
    output = device.read_console(sock, timeout, TEST_END_MARKER)
    return parse_test_report(output)
