#
# Build this container image locally with:
#
#     docker build -t homelab-unbound:local .
#
FROM alpine:3.24@sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4

RUN apk add --no-cache unbound

EXPOSE 53/tcp 53/udp

CMD ["unbound", "-d"]
