"""Command-line entry point: `flightwall <command>`."""

from __future__ import annotations

import argparse
import getpass
import json
import os
import sys
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path

from . import __version__
from .airlines import build_airlines
from .airports import build_airports
from .brscheck import check_channel
from .cities import DEFAULT_MIN_POPULATION, build_cities
from .device import DeviceError, RokuDevice, run_device_tests
from .images import build_images, ensure_fhd
from .package import build_package, manifest_version
from .sources import SOURCES, ensure
from .tiles import DEFAULT_REGIONS, PX_PER_DEG, REGIONS, build_tiles
from .zips import build_zips

PASSWORD_ENV = "ROKU_DEV_PASSWORD"  # noqa: S105 - name of the variable, not a secret
SIGNING_PASSWORD_ENV = "ROKU_SIGNING_PASSWORD"  # noqa: S105 - name of the variable, not a secret
HOST_ENV = "ROKU_HOST"
DOTENV_NAME = ".env"
EXIT_USAGE = 2


@dataclass(frozen=True)
class Paths:
    root: Path

    @property
    def roku(self) -> Path:
        return self.root / "roku"

    @property
    def cache(self) -> Path:
        return self.root / ".cache"

    @property
    def dist(self) -> Path:
        return self.root / "dist"


def default_root() -> Path:
    return Path(__file__).resolve().parents[2]


DeviceFactory = Callable[[str, str], RokuDevice]


def make_device(host: str, password: str) -> RokuDevice:
    return RokuDevice(host, password)


def load_dotenv(path: Path) -> dict[str, str]:
    """Load KEY=VALUE lines from a .env file into the environment (existing values win)."""
    loaded: dict[str, str] = {}
    if not path.is_file():
        return loaded
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip().removeprefix("export ").strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":  # noqa: PLR2004
            value = value[1:-1]
        if key:
            loaded[key] = value
            os.environ.setdefault(key, value)
    return loaded


def resolve_password(explicit: str | None, prompt: Callable[[str], str] = getpass.getpass) -> str:
    if explicit:
        return explicit
    from_env = os.environ.get(PASSWORD_ENV, "")
    if from_env:
        return from_env
    return prompt("Roku developer password: ")


def resolve_host(explicit: str | None) -> str:
    return explicit or os.environ.get(HOST_ENV, "")


def cmd_build_data(args: argparse.Namespace, paths: Paths) -> int:
    cache = Path(args.cache) if args.cache else paths.cache
    names = [n.strip() for n in args.regions.split(",") if n.strip()]
    unknown = [n for n in names if n not in REGIONS]
    if unknown:
        print(f"unknown region(s): {', '.join(unknown)}; choose from {', '.join(REGIONS)}")
        return 2
    print(f"Fetching sources (cached in {cache})")
    files = {key: ensure(source, cache) for key, source in SOURCES.items()}
    data_dir = paths.roku / "data"
    print("Building ZIP code table")
    n_zips = build_zips(files["zcta"], data_dir / "zips.txt")
    print(f"  {n_zips} ZIP codes")
    print("Building airport list")
    n_airports = build_airports(files["airports"], data_dir / "airports.json")
    print(f"  {n_airports} airports")
    print("Building city labels")
    n_cities = build_cities(files["places"], data_dir / "cities.json", args.min_population)
    print(f"  {n_cities} cities")
    print("Building airline code table")
    n_airlines = build_airlines(files["airlines"], data_dir / "airlines.txt")
    print(f"  {n_airlines} airline codes")
    print("Rasterizing map tiles (this takes a few minutes)")
    land = json.loads(files["land"].read_text(encoding="utf-8"))
    lakes = json.loads(files["lakes"].read_text(encoding="utf-8"))
    index = build_tiles(
        land,
        lakes,
        [REGIONS[n] for n in names],
        paths.roku / "images" / "tiles",
        args.px_per_deg,
        progress=print,
    )
    coastal = sum(1 for kind in index["tiles"].values() if kind == "c")
    print(f"  {len(index['tiles'])} tiles indexed, {coastal} coastal tiles written")
    return 0


def cmd_images(_args: argparse.Namespace, paths: Paths) -> int:
    written = build_images(paths.roku / "images")
    print(f"Wrote {len(written)} images under {paths.roku / 'images'}")
    return 0


def cmd_check(_args: argparse.Namespace, paths: Paths) -> int:
    issues = check_channel(paths.roku)
    for issue in issues:
        print(issue)
    print(f"{len(issues)} issue(s) found" if issues else "Channel sources look consistent")
    return 1 if issues else 0


def _package_name(with_tests: bool, screensaver_only: bool, channel_only: bool = False) -> str:
    base = "flightwall"
    if screensaver_only:
        base = "flightwall-screensaver"
    elif channel_only:
        base = "flightwall-channel"
    return f"{base}-tests.zip" if with_tests else f"{base}.zip"


def _package(
    paths: Paths,
    *,
    with_tests: bool = False,
    screensaver_only: bool = False,
    channel_only: bool = False,
    out: str | None = None,
) -> Path:
    name = _package_name(with_tests, screensaver_only, channel_only)
    out_path = Path(out) if out else paths.dist / name
    included = build_package(
        paths.roku,
        out_path,
        with_tests=with_tests,
        screensaver_only=screensaver_only,
        channel_only=channel_only,
    )
    print(f"Wrote {out_path} ({len(included)} files)")
    return out_path


def cmd_package(args: argparse.Namespace, paths: Paths) -> int:
    if check_channel(paths.roku):
        print("Static checks failed; run `flightwall check` for details")
        return 1
    _package(
        paths,
        with_tests=args.with_tests,
        screensaver_only=args.screensaver_only,
        channel_only=args.channel_only,
        out=args.out,
    )
    return 0


def cmd_deploy(args: argparse.Namespace, paths: Paths, factory: DeviceFactory) -> int:
    if check_channel(paths.roku):
        print("Static checks failed; run `flightwall check` for details")
        return 1
    archive = _package(
        paths,
        with_tests=args.with_tests,
        screensaver_only=args.screensaver_only,
        channel_only=args.channel_only,
    )
    device = factory(args.host, resolve_password(args.password))
    try:
        status = device.install(archive)
    except DeviceError as exc:
        print(f"Deploy failed: {exc}")
        return 1
    print(f"Installed on {args.host}: {status}")
    return 0


def cmd_run_tests(args: argparse.Namespace, paths: Paths, factory: DeviceFactory) -> int:
    if check_channel(paths.roku):
        print("Static checks failed; run `flightwall check` for details")
        return 1
    archive = _package(paths, with_tests=True)
    device = factory(args.host, resolve_password(args.password))
    try:
        report = run_device_tests(device, archive, args.timeout)
    except DeviceError as exc:
        print(f"Test run failed: {exc}")
        return 1
    print(report.output)
    print(
        f"Total {report.total}; passed {report.passed}; failed {report.failed}; "
        f"skipped {report.skipped}; crashes {report.crashes}"
    )
    return 0 if report.ok else 1


def cmd_screenshot(args: argparse.Namespace, paths: Paths, factory: DeviceFactory) -> int:
    device = factory(args.host, resolve_password(args.password))
    out_path = Path(args.out) if args.out else paths.dist / "screenshot.jpg"
    try:
        saved = device.screenshot(out_path)
    except DeviceError as exc:
        print(f"Screenshot failed: {exc}")
        return 1
    width, height = ensure_fhd(saved)
    print(f"Saved {saved} ({width}x{height})")
    return 0


def cmd_genkey(args: argparse.Namespace, _paths: Paths, factory: DeviceFactory) -> int:
    device = factory(args.host, resolve_password(args.password))
    try:
        key = device.genkey()
    except DeviceError as exc:
        print(f"genkey failed: {exc}")
        return 1
    print("Signing key generated on the Roku. Save both values now; every future package")
    print("for this channel must be signed with the same key.")
    print(f"  DevID:    {key.dev_id}")
    print(f"  Password: {key.password}")
    return 0


def cmd_sign(args: argparse.Namespace, paths: Paths, factory: DeviceFactory) -> int:
    signing_password = args.signing_password or os.environ.get(SIGNING_PASSWORD_ENV, "")
    if not signing_password:
        print(f"No signing password: pass --signing-password or set {SIGNING_PASSWORD_ENV} in .env")
        return EXIT_USAGE
    device = factory(args.host, resolve_password(args.password))
    version = manifest_version((paths.roku / "manifest").read_text(encoding="utf-8"))
    app_name = args.app_name or f"FlightWall/{version}"
    out_path = (
        Path(args.out) if args.out else paths.dist / f"flightwall-{args.variant}-{version}.pkg"
    )
    try:
        saved = device.sign(app_name, signing_password, out_path)
    except DeviceError as exc:
        print(f"Signing failed: {exc}")
        return 1
    print(f"Saved signed package {saved} ({saved.stat().st_size} bytes)")
    return 0


def cmd_delete(args: argparse.Namespace, _paths: Paths, factory: DeviceFactory) -> int:
    device = factory(args.host, resolve_password(args.password))
    try:
        status = device.delete()
    except DeviceError as exc:
        print(f"Delete failed: {exc}")
        return 1
    print(f"Removed side-loaded channel from {args.host}: {status}")
    return 0


def cmd_all(args: argparse.Namespace, paths: Paths) -> int:
    code = cmd_build_data(args, paths)
    if code:
        return code
    cmd_images(args, paths)
    code = cmd_check(args, paths)
    if code:
        return code
    _package(paths)
    _package(paths, channel_only=True)
    _package(paths, screensaver_only=True)
    return 0


def _add_device_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--host", help=f"Roku IP address (or set {HOST_ENV} in .env)")
    parser.add_argument(
        "--password",
        help=f"developer password (or set {PASSWORD_ENV} in .env; prompted otherwise)",
    )


def _add_variant_args(parser: argparse.ArgumentParser) -> None:
    variant = parser.add_mutually_exclusive_group()
    variant.add_argument(
        "--screensaver-only",
        action="store_true",
        help="Channel Store screensaver build: no Main()",
    )
    variant.add_argument(
        "--channel-only",
        action="store_true",
        help="Channel Store channel build: no screensaver code or manifest attributes",
    )


def _add_data_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--cache", help="directory for downloaded sources (default .cache)")
    parser.add_argument(
        "--regions",
        default=",".join(DEFAULT_REGIONS),
        help=f"comma-separated map regions to rasterize (available: {', '.join(REGIONS)})",
    )
    parser.add_argument("--px-per-deg", type=int, default=PX_PER_DEG, help="tile resolution")
    parser.add_argument(
        "--min-population",
        type=int,
        default=DEFAULT_MIN_POPULATION,
        help="smallest city population to label",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="flightwall", description=__doc__)
    parser.add_argument("--version", action="version", version=__version__)
    parser.add_argument("--project-root", help="project directory (default: this checkout)")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("build-data", help="download sources and build map/zip/airport data")
    _add_data_args(p)
    sub.add_parser("images", help="generate sprites, markers, icons and splash screens")
    sub.add_parser("check", help="run static checks over the BrightScript/SceneGraph sources")

    p = sub.add_parser("package", help="zip the channel into dist/")
    p.add_argument("--with-tests", action="store_true", help="include the on-device test suite")
    _add_variant_args(p)
    p.add_argument("--out", help="output zip path")

    p = sub.add_parser("deploy", help="package and side-load onto a Roku in developer mode")
    _add_device_args(p)
    p.add_argument("--with-tests", action="store_true")
    _add_variant_args(p)

    p = sub.add_parser("run-tests", help="side-load the test build and run the on-device tests")
    _add_device_args(p)
    p.add_argument("--timeout", type=float, default=180.0, help="seconds to wait for results")

    p = sub.add_parser("screenshot", help="save a screenshot of the running side-loaded channel")
    _add_device_args(p)
    p.add_argument("--out", help="image path (default dist/screenshot.jpg)")

    p = sub.add_parser("genkey", help="generate the package-signing key on the Roku (once)")
    _add_device_args(p)

    p = sub.add_parser("sign", help="sign the installed channel and download the .pkg")
    _add_device_args(p)
    p.add_argument(
        "--signing-password",
        help=f"password printed by genkey (or set {SIGNING_PASSWORD_ENV} in .env)",
    )
    p.add_argument(
        "--variant",
        choices=("screensaver", "channel"),
        default="screensaver",
        help="which build is installed on the Roku; names the output file",
    )
    p.add_argument(
        "--app-name", help="name/version embedded in the package (default FlightWall/<version>)"
    )
    p.add_argument("--out", help="output path (default dist/flightwall-<variant>-<version>.pkg)")

    p = sub.add_parser("delete", help="remove the side-loaded channel from the Roku")
    _add_device_args(p)

    p = sub.add_parser("all", help="build-data + images + check + package (both variants)")
    _add_data_args(p)
    return parser


def main(argv: Sequence[str] | None = None, factory: DeviceFactory = make_device) -> int:
    args = build_parser().parse_args(argv)
    paths = Paths(Path(args.project_root) if args.project_root else default_root())
    load_dotenv(paths.root / DOTENV_NAME)
    simple: dict[str, Callable[[argparse.Namespace, Paths], int]] = {
        "build-data": cmd_build_data,
        "images": cmd_images,
        "check": cmd_check,
        "package": cmd_package,
        "all": cmd_all,
    }
    device_commands: dict[str, Callable[[argparse.Namespace, Paths, DeviceFactory], int]] = {
        "deploy": cmd_deploy,
        "run-tests": cmd_run_tests,
        "screenshot": cmd_screenshot,
        "genkey": cmd_genkey,
        "sign": cmd_sign,
        "delete": cmd_delete,
    }
    if args.command in simple:
        return simple[args.command](args, paths)
    args.host = resolve_host(args.host)
    if not args.host:
        print(f"No Roku address: pass --host or set {HOST_ENV} in .env")
        return EXIT_USAGE
    return device_commands[args.command](args, paths, factory)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
