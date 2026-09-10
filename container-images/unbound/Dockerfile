#
# Build this container image locally with:
#
#     docker build -t homelab-unbound:local .
#
# Run it quickly with:
#
#     docker run --rm -p 127.0.0.1:53:53/tcp -p 127.0.0.1:53:53/udp homelab-unbound:local
#
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

RUN apk add --no-cache unbound

# Copy config overwrites to the image.
COPY files/unbound.conf.d/ /etc/unbound/unbound.conf.d/

EXPOSE 53/tcp 53/udp

# Query the root zone SOA record through the local resolver to verify that Unbound answers DNS requests.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD nslookup -type=SOA . 127.0.0.1 > /dev/null || exit 1

#
# Hardening
#

# We must chown /run or else Unbound will fail to start.
RUN chown unbound:unbound /run
# Start Unbound as non-root instead of relying on its internal privilege drop.
# This also makes any interactive shell inside the container run as non-root.
USER unbound:unbound

#
# Command line
#
# NOTE: Keep the full command in CMD instead of splitting it between ENTRYPOINT
#   and CMD. This lets `docker run IMAGE sh ...` replace the default command,
#   which we use to run helper commands inside the container, such as collecting
#   the Alpine package manifest. With an ENTRYPOINT, those arguments would be
#   appended to `unbound` instead.
#
# Command parameters:
#
# -d    do not fork into the background.
# -v    enables early startup logging before the configuration is loaded.
#       It also adds one to the configured verbosity. This image configures
#       verbosity 0, resulting in effective runtime verbosity 1.
CMD ["unbound", "-d", "-v"]
