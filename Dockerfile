# Build container for the FlightWall tooling (data build, static checks, packaging, deploy).
# The Roku channel itself runs on the Roku; nothing here serves traffic.
#
#   docker build -t flightwall-tools .
#   docker run --rm -v "$PWD:/work" flightwall-tools all
#   docker run --rm -v "$PWD:/work" -e ROKU_DEV_PASSWORD flightwall-tools deploy --host 192.168.1.238

FROM python:3.12-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

ENV UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /work
COPY pyproject.toml uv.lock README.md ./
COPY tools ./tools
RUN uv sync --frozen --no-dev

# Run as an unprivileged user; the project directory is mounted at /work.
RUN useradd --create-home --uid 1000 flightwall
USER flightwall

ENTRYPOINT ["/opt/venv/bin/flightwall", "--project-root", "/work"]
CMD ["--help"]
