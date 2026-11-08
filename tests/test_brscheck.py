from __future__ import annotations

from pathlib import Path

from conftest import make_channel
from skytraffic_tools import brscheck


def test_strip_code() -> None:
    assert brscheck.strip_code("x = \"it's\" ' trailing comment") == 'x = ""'
    assert brscheck.strip_code("REM whole line comment") == ""
    assert brscheck.strip_code("  rem indented") == ""
    assert brscheck.strip_code("remove = 1") == "remove = 1"
    assert brscheck.strip_code("x = arem") == "x = arem"
    assert brscheck.strip_code("y = 2 rem") == "y = 2"
    assert brscheck.strip_code('a = "unterminated') == 'a = ""'


def _check(text: str) -> list[str]:
    return [issue.message for issue in brscheck.check_blocks(text, "x.brs")]


def test_balanced_blocks_pass() -> None:
    text = """
sub init()
    if m.ready then
        for each item in m.items
            while true
                exit while
            end while
        next
    else if m.other then
        print "x"
    else
        try
            n = 1
        catch e
            n = 2
        end try
    end if
    if m.quick then return
    m.handler = function(a as Integer) as Integer
        return a
    end function
    doIt = sub()
    end sub
end sub

function Helper(a as Object) as String
    if a = invalid
        return ""
    endif
    return "ok"
end function
"""
    assert _check(text) == []


def test_unclosed_and_unopened_blocks() -> None:
    assert _check("sub a()\n  if x then\n") == [
        "'if' block is never closed",
        "'sub' block is never closed",
    ]
    assert _check("end if\n") == ["'end if' closes a block that was never opened"]


def test_mismatched_terminator() -> None:
    assert _check("function f()\nend sub\n") == ["'end sub' closes 'function' opened on line 1"]
    assert _check("sub f()\n    for i = 1 to 2\n    end if\nend sub\n") == [
        "'end if' closes 'for' opened on line 2",
    ]


def test_terminators_followed_by_colon() -> None:
    assert _check("sub f()\n    if a then\n    end if: print 1\nend sub\n") == []


def test_pkg_refs(tmp_path: Path) -> None:
    (tmp_path / "images").mkdir()
    (tmp_path / "images" / "ok.png").write_bytes(b"")
    text = (
        'a = "pkg:/images/ok.png"\n'
        'b = "pkg:/images/missing.png"\n'
        'c = "pkg:/images/planes/plane_" + name + ".png"\n'
        "d = pkg:/images/ok.png\n"
    )
    issues = brscheck.check_pkg_refs(text, "a.brs", tmp_path)
    assert [(i.line, i.message) for i in issues] == [
        (2, "referenced file does not exist: images/missing.png")
    ]
    assert str(issues[0]) == "a.brs:2: referenced file does not exist: images/missing.png"


def _xml(root: Path, body: str) -> Path:
    path = root / "components" / "Widget.xml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")
    return path


def test_component_xml_checks(tmp_path: Path) -> None:
    good = _xml(
        tmp_path,
        '<component name="Widget" extends="Group">'
        '<script type="text/brightscript" uri="pkg:/components/Widget.brs"/></component>',
    )
    (tmp_path / "components" / "Widget.brs").write_text("sub init()\nend sub\n", encoding="utf-8")
    assert brscheck.check_component_xml(good, tmp_path) == []

    broken = _xml(tmp_path, "<component name='Widget'>")
    assert "XML parse error" in brscheck.check_component_xml(broken, tmp_path)[0].message

    wrong_root = _xml(tmp_path, "<thing/>")
    assert [i.message for i in brscheck.check_component_xml(wrong_root, tmp_path)] == [
        "root element must be <component>"
    ]

    bad = _xml(
        tmp_path,
        '<component name="Other"><script uri="components/Widget.brs"/>'
        '<script uri="pkg:/components/Nope.brs"/></component>',
    )
    messages = [i.message for i in brscheck.check_component_xml(bad, tmp_path)]
    assert messages == [
        "component name 'Other' must match file name",
        "component must declare extends=",
        "script uri must start with pkg:/ (got 'components/Widget.brs')",
        "script file does not exist: pkg:/components/Nope.brs",
    ]


def test_manifest_checks(tmp_path: Path) -> None:
    assert brscheck.check_manifest(tmp_path)[0].message == "manifest file is missing"
    (tmp_path / "manifest").write_text(
        "# comment\n\ntitle=X\nnot-a-pair\nmm_icon_focus_hd=pkg:/images/none.png\n",
        encoding="utf-8",
    )
    messages = [i.message for i in brscheck.check_manifest(tmp_path)]
    assert messages == [
        "required entry missing: major_version",
        "required entry missing: minor_version",
        "required entry missing: build_version",
        "required entry missing: splash_screen_hd",
        "mm_icon_focus_hd points to a missing file: pkg:/images/none.png",
    ]


def test_check_channel_end_to_end(tmp_path: Path) -> None:
    roku = make_channel(tmp_path)
    assert brscheck.check_channel(roku) == []
    (roku / "components" / "MainScene.brs").write_text("sub init()\n", encoding="utf-8")
    (roku / "components" / "MainScene.xml").write_text(
        '<component name="MainScene" extends="Scene">'
        '<script type="text/brightscript" uri="pkg:/components/MainScene.brs"/>'
        '<Poster uri="pkg:/images/nothing.png"/></component>',
        encoding="utf-8",
    )
    messages = sorted(i.message for i in brscheck.check_channel(roku))
    assert messages == [
        "'sub' block is never closed",
        "referenced file does not exist: images/nothing.png",
    ]
