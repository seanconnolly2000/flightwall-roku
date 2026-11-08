from __future__ import annotations

import urllib.request
from pathlib import Path
from typing import Any, Self

import pytest

from skytraffic_tools import sources


class _Response:
    def __init__(self, body: bytes) -> None:
        self.body = body

    def read(self) -> bytes:
        return self.body

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *_: object) -> None:
        return None


def test_http_fetch_rejects_plain_http() -> None:
    with pytest.raises(ValueError, match="non-HTTPS"):
        sources.http_fetch("http://example.com/x")


def test_http_fetch_reads_body(monkeypatch: pytest.MonkeyPatch) -> None:
    seen: dict[str, Any] = {}

    def fake_urlopen(request: urllib.request.Request, timeout: float) -> _Response:
        seen["url"] = request.full_url
        seen["ua"] = request.get_header("User-agent")
        seen["timeout"] = timeout
        return _Response(b"payload")

    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    assert sources.http_fetch("https://example.com/data") == b"payload"
    assert seen == {"url": "https://example.com/data", "ua": sources.USER_AGENT, "timeout": 180}


def test_ensure_downloads_once(tmp_path: Path) -> None:
    calls: list[str] = []

    def fetch(url: str) -> bytes:
        calls.append(url)
        return b"abc"

    source = sources.SOURCES["airports"]
    cache = tmp_path / "cache"
    first = sources.ensure(source, cache, fetch)
    second = sources.ensure(source, cache, fetch)
    assert first == second == cache / "airports.csv"
    assert first.read_bytes() == b"abc"
    assert calls == [source.url]


def test_every_source_is_https() -> None:
    for source in sources.SOURCES.values():
        assert source.url.startswith("https://")
        assert source.filename
        assert source.license_note
