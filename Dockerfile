# syntax=docker/dockerfile:1
# Packaging-only image for DonSeTch release binaries (linux/x86_64).
# Upstream: https://github.com/dondai44423/donsetch (AGPL-3.0-only)
#
# Build context must contain the release artifacts already extracted:
#   donsetch            (executable)
#   libonnxruntime.so   (ONNX Runtime, dlopen'd for OCR)
#
# Mirrors the runtime stage of upstream's own Dockerfile (same Debian
# generation: the release binaries need glibc >= 2.35, trixie has 2.41).

FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libgcc-s1 \
    && apt-get clean

# ONNX Runtime is searched next to the executable first (upstream comment
# on /usr/local/bin staging), so keep the two files side by side.
COPY donsetch libonnxruntime.so /usr/local/bin/
RUN chmod 0755 /usr/local/bin/donsetch

# Non-root; cache dir must exist and be owned before the VOLUME line or
# fresh named volumes stay root-owned (upstream Dockerfile note).
RUN useradd -m -u 1000 donsetch \
    && mkdir -p /home/donsetch/.cache/donsetch \
    && chown -R donsetch:donsetch /home/donsetch/.cache
USER donsetch
WORKDIR /home/donsetch

VOLUME /home/donsetch/.cache/donsetch

RUN donsetch --version

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD donsetch --version || exit 1

# HTTP MCP server by default for this packaging image (upstream ships
# stdio as its default). Set DONSETCH_HTTP_TOKEN before publishing the
# port beyond localhost; /health stays open for probes.
ENV DONSETCH_HTTP_HOST=0.0.0.0 \
    DONSETCH_TRANSPORT=http
EXPOSE 8765

# Graceful drain is built into the binary (SIGTERM -> drain in-flight).
STOPSIGNAL SIGTERM
CMD ["donsetch", "mcp", "--http", "--port", "8765"]
