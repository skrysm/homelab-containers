#
# Build this container image locally with:
#
#     docker build -t homelab-unbound:local .
#
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

RUN apk add --no-cache unbound

EXPOSE 53/tcp 53/udp

# Query the root zone SOA record through the local resolver to verify that Unbound answers DNS requests.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD nslookup -type=SOA . 127.0.0.1 > /dev/null || exit 1

ENTRYPOINT ["unbound"]
CMD ["-d"]
