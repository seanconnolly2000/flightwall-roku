"""Static checks for the BrightScript / SceneGraph sources.

Roku ships no desktop compiler, so these checks catch the mistakes that would
otherwise only surface when the package is side-loaded: unbalanced blocks,
mismatched block terminators, missing script files, dangling pkg:/ references,
malformed component XML and an incomplete manifest.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

BLOCK_OPENERS = {
    "sub": "sub",
    "function": "function",
    "for": "for",
    "while": "while",
    "try": "try",
}
BLOCK_CLOSERS = {
    "end sub": "sub",
    "endsub": "sub",
    "end function": "function",
    "endfunction": "function",
    "end for": "for",
    "endfor": "for",
    "next": "for",
    "end while": "while",
    "endwhile": "while",
    "end if": "if",
    "endif": "if",
    "end try": "try",
    "endtry": "try",
}
MANIFEST_REQUIRED = (
    "title",
    "major_version",
    "minor_version",
    "build_version",
    "mm_icon_focus_hd",
    "splash_screen_hd",
)
PKG_REF = re.compile(r"pkg:/[A-Za-z0-9_./-]+\.[A-Za-z0-9]+(?=[\"'<\s])")
FUNC_DEF = re.compile(r"\b(sub|function)\b\s*[A-Za-z_][A-Za-z0-9_]*\s*\(")
ANON_FUNC = re.compile(r"\b(sub|function)\b\s*\(")
LEADING_BLOCK = re.compile(r"^(for|while|try)\b")
ONE_LINE_IF = re.compile(r"^if\b.*\bthen\b\s*\S")


@dataclass(frozen=True)
class Issue:
    path: str
    line: int
    message: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: {self.message}"


def strip_code(line: str) -> str:
    """Remove string literals and trailing comments, keeping the code shape."""
    out: list[str] = []
    in_string = False
    i = 0
    while i < len(line):
        ch = line[i]
        if in_string:
            if ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append('""')
            i += 1
            continue
        if ch == "'":
            break
        rest = line[i:].lower()
        if rest.startswith("rem") and (i == 0 or not line[i - 1].isalnum()):
            tail = rest[3:]
            if not tail or tail[0].isspace():
                break
        out.append(ch)
        i += 1
    return "".join(out).strip().lower()


def _classify(code: str) -> tuple[str, str] | None:
    """Return ("open"|"close", kind) when the line changes block depth."""
    for closer, kind in BLOCK_CLOSERS.items():
        if code == closer or code.startswith((closer + " ", closer + ":")):
            return "close", kind
    if code.startswith("else"):
        return None
    if code.startswith("if ") or code == "if":
        return None if ONE_LINE_IF.match(code) else ("open", "if")
    if LEADING_BLOCK.match(code):
        return "open", code.split(maxsplit=1)[0]
    if FUNC_DEF.search(code) or ANON_FUNC.search(code):
        kind = "sub" if re.search(r"\bsub\b", code) else "function"
        return "open", kind
    return None


def check_blocks(text: str, path: str) -> list[Issue]:
    issues: list[Issue] = []
    stack: list[tuple[str, int]] = []
    for number, raw in enumerate(text.splitlines(), start=1):
        code = strip_code(raw)
        if not code:
            continue
        change = _classify(code)
        if change is None:
            continue
        action, kind = change
        if action == "open":
            stack.append((kind, number))
        elif not stack:
            issues.append(Issue(path, number, f"'{code}' closes a block that was never opened"))
        else:
            opened, at = stack.pop()
            if opened != kind:
                issues.append(
                    Issue(path, number, f"'{code}' closes '{opened}' opened on line {at}")
                )
    issues.extend(
        Issue(path, at, f"'{kind}' block is never closed") for kind, at in reversed(stack)
    )
    return issues


def check_pkg_refs(text: str, path: str, root: Path) -> list[Issue]:
    issues: list[Issue] = []
    for number, raw in enumerate(text.splitlines(), start=1):
        for match in PKG_REF.finditer(raw + " "):
            relative = match.group(0)[len("pkg:/") :]
            if not (root / relative).exists():
                issues.append(Issue(path, number, f"referenced file does not exist: {relative}"))
    return issues


def check_component_xml(xml_path: Path, root: Path) -> list[Issue]:
    rel = xml_path.relative_to(root).as_posix()
    try:
        tree = ET.parse(xml_path)  # noqa: S314 - trusted project files
    except ET.ParseError as exc:
        return [Issue(rel, exc.position[0], f"XML parse error: {exc.msg}")]
    element = tree.getroot()
    issues: list[Issue] = []
    if element.tag != "component":
        issues.append(Issue(rel, 1, "root element must be <component>"))
        return issues
    name = element.get("name")
    if name != xml_path.stem:
        issues.append(Issue(rel, 1, f"component name {name!r} must match file name"))
    if not element.get("extends"):
        issues.append(Issue(rel, 1, "component must declare extends="))
    for script in element.iter("script"):
        uri = script.get("uri", "")
        if not uri.startswith("pkg:/"):
            issues.append(Issue(rel, 1, f"script uri must start with pkg:/ (got {uri!r})"))
        elif not (root / uri[len("pkg:/") :]).exists():
            issues.append(Issue(rel, 1, f"script file does not exist: {uri}"))
    return issues


def check_manifest(root: Path) -> list[Issue]:
    manifest = root / "manifest"
    if not manifest.exists():
        return [Issue("manifest", 1, "manifest file is missing")]
    entries: dict[str, str] = {}
    for raw in manifest.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        entries[key.strip()] = value.strip()
    issues = [
        Issue("manifest", 1, f"required entry missing: {key}")
        for key in MANIFEST_REQUIRED
        if key not in entries
    ]
    for key, value in entries.items():
        if value.startswith("pkg:/") and not (root / value[len("pkg:/") :]).exists():
            issues.append(Issue("manifest", 1, f"{key} points to a missing file: {value}"))
    return issues


def check_channel(root: Path) -> list[Issue]:
    """Run every check over a channel source directory."""
    issues = check_manifest(root)
    for brs in sorted(root.rglob("*.brs")):
        rel = brs.relative_to(root).as_posix()
        text = brs.read_text(encoding="utf-8")
        issues.extend(check_blocks(text, rel))
        issues.extend(check_pkg_refs(text, rel, root))
    for xml_path in sorted((root / "components").rglob("*.xml")):
        issues.extend(check_component_xml(xml_path, root))
        issues.extend(
            check_pkg_refs(
                xml_path.read_text(encoding="utf-8"), xml_path.relative_to(root).as_posix(), root
            )
        )
    return issues
