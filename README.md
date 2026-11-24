# donsetch-docker

> **Archived (Nov 24, 2026) — packaging was upstreamed.** Upstream [DonSeTch](https://github.com/dondai44423/donsetch)
> publishes multi-arch images itself since `v5.5.11`: **`ghcr.io/dondai44423/donsetch`** (`:latest`, `:5`, `:5.5`, patch tags),
> built from the gated, SHA-256-verified release binaries. Use the official image; this repo is kept only as a
> reference implementation of release→GHCR packaging (and a fond memory of covering `5.5.9`–`5.5.10`,
> see issue [#469](https://github.com/dondai44423/donsetch/issues/469)).
> Note: the official image's default Cmd is stdio — pass `donsetch mcp --http --host 0.0.0.0 --port 8765`
> (or `DONSETCH_TRANSPORT__KIND=http`) for HTTP MCP.

Packaging-only repository: turns upstream [DonSeTch](https://github.com/dondai44423/donsetch)
GitHub releases into multi-arch GHCR container images. No source is built
here — the workflow downloads the release tarballs, verifies the `.sha256`
sidecars published alongside them, and bakes thin `debian:trixie-slim`
images that mirror upstream's own runtime stage (non-root, cache volume,
healthcheck).

DonSeTch is a local web-tools MCP server: search, fetch, crawl, screenshot —
one Rust binary, no API keys, no browser in the fetch path. See the upstream
README for the tool docs.

## Images

| Tag | Contents |
|---|---|
| `5.5.9`, `5.5`, `5`, `latest` | multi-arch (linux/amd64, linux/arm64) |
| `5.5.9-amd64` / `5.5.9-arm64` | single-arch |

- **amd64** includes `libonnxruntime.so` → OCR features active.
- **arm64** has no ONNX prebuilt upstream → OCR self-disables at runtime;
  fetch/search/crawl/PDF/screenshot all work.

The default command serves **HTTP MCP** on port `8765` (`/mcp` + `/health`),
unlike upstream's stdio default — this image is meant to run as a server.

## Run

```bash
docker run -d --name donsetch --init --restart unless-stopped \
  -p 127.0.0.1:8765:8765 \
  -e DONSETCH_HTTP_TOKEN="$(openssl rand -hex 16)" \
  -v donsetch-cache:/home/donsetch/.cache/donsetch \
  ghcr.io/<owner>/donsetch-docker:latest
curl http://127.0.0.1:8765/health
```

Set `DONSETCH_HTTP_TOKEN` before publishing the port beyond localhost —
without it, `/mcp` is unauthenticated. `/health` is always open.

Connect an MCP client (OpenCode/Claude Code/Cursor):

```json
{ "mcpServers": { "donsetch": { "url": "http://<host>:8765/mcp",
  "headers": { "Authorization": "Bearer <token>" } } } }
```

Stdio mode also works: override the command with
`["donsetch","mcp","--supervised"]` and run with `docker run -i --rm`.

Caching/limits: idle RSS ≈ 25 MB; the HTTP transport aborts the process on
panic (upstream `panic=abort`, no in-process supervisor for HTTP), so keep
`--restart unless-stopped`. Optional tuning env vars: `DONSEEK_NO_DISK_STATE=1`,
`DONSEEK_PROXIES` — see upstream `docker-compose.yml`.

Screenshots (`web_screenshot`) need a Chromium inside the image, which this
image does not ship (upstream note: +350 MB and needs unprivileged user
namespaces in Docker; untested upstream). Not supported here.

## How publishing works

- `workflow_dispatch`: build any version (blank = latest).
- Cron every 6 h: polls upstream `releases/latest`; skips when the version
  tag already exists on GHCR.
- Each asset's `.sha256` sidecar is verified before extraction (fails the
  build on mismatch). Note the sidecar comes from the same release as the
  artifact — it guards against corruption, not against a compromised
  upstream release.

## License / provenance

Upstream DonSeTch is **AGPL-3.0-only**; this repo contains only packaging
metadata. Images carry `org.opencontainers.image.source` pointing at the
upstream project. Pulling and running AGPL software requires no license
fee; modifying DonSeTch source and serving it to others does — see the
upstream LICENSE.
