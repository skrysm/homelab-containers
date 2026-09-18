#
# Build this container image locally with:
#
#     docker build -t caddy-cloudflare:local .
#
# Run it with a Caddyfile from the current directory:
#
#     docker run --rm \
#         -p 80:80 -p 443:443 -p 443:443/udp \
#         -e CF_API_TOKEN \
#         -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" \
#         -v caddy-data:/data \
#         -v caddy-config:/config \
#         caddy-cloudflare:local
#

# BuildKit provides BUILDPLATFORM globally: the OS, CPU architecture, and optional variant
# on which Dockerfile build steps run (for example, linux/amd64 in GitHub Actions).
# Pin this stage to that platform so xcaddy runs without emulation while Go compiles Caddy
# for the target image platform. (This reduces the build time on the default GHA runner
# from 40 minutes to just 2 minutes.)
FROM --platform=$BUILDPLATFORM caddy:2.11.4-builder-alpine@sha256:56d2e0b832cdabf43f86f7ec1e241a49fa79a0232588923c6fe84920b9082e45 AS builder

# BuildKit supplies these per target platform; declare them in this stage so RUN below can use them.
# Target CPU architecture (amd64, arm64, or arm)
ARG TARGETARCH
# Target variant (v7 for linux/arm/v7)
ARG TARGETVARIANT

# NOTE: The "--mount" parameters for RUN keeps the specified directories out of the exported
#   build layer (to keep its size and thus upload time down) and also let the directories
#   be reused in different "docker build" calls for within the same GHA job (i.e. for the
#   native and the multi-platform builds).
#   See: https://docs.docker.com/build/cache/optimize/#use-cache-mounts
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    # Set target arch for cross-platform "xcaddy build"
    export GOARCH="$TARGETARCH"; \
    # Map Docker's arm/v7 variant to Go's GOARM=7.
    if [ "$TARGETARCH" = arm ]; then \
        export GOARM="${TARGETVARIANT#v}"; \
    fi; \
    xcaddy build \
    # Pin the module version so custom Caddy builds are reproducible.
    # IMPORTANT: Keep this "--with ..." line's format in sync with the custom manager regex in renovate.jsonc.
    --with github.com/caddy-dns/cloudflare@v0.2.4

FROM caddy:2.11.4-alpine@sha256:de23def33b17fb5d1290b0f6c2add1d70780e52341896c00a4c8a2a2fe9d355e

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
