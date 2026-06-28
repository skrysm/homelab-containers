#
# Build this container image locally with:
#
#     docker build -t homelab-unbound:local .
#
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

RUN apk add --no-cache unbound

# Copy config overwrites to the image.
COPY unbound.conf.d/ /etc/unbound/unbound.conf.d/

EXPOSE 53/tcp 53/udp

# Query the root zone SOA record through the local resolver to verify that Unbound answers DNS requests.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD nslookup -type=SOA . 127.0.0.1 > /dev/null || exit 1

#
# Hardening
#

# We must chown /run or else Unbound will fail to start.
RUN chown unbound:unbound /run
# Note that Unbound already does privilege dropping. But this makes it never run
# as root (and also makes any interactive shell inside the container run as non-root).
USER unbound:unbound

#
# Command line
#
# NOTE: Keep the full command in CMD instead of splitting it between ENTRYPOINT
#   and CMD. This lets `docker run IMAGE sh ...` replace the default command,
#   which we use to run helper commands inside the container, such as collecting
#   the Alpine package manifest. With an ENTRYPOINT, those arguments would be
#   appended to `unbound` instead.
CMD ["unbound", "-d"]
