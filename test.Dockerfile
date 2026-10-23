# syntax=docker/dockerfile:1
# Linux environment for running the Go test suite (service/ only builds on Linux).
# The source is mounted at /src by docker-compose.yml, not copied in.
FROM golang:1.26.10

RUN apt-get update \
    && apt-get install -y --no-install-recommends netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# service.TestPorts expects at least one listening TCP and UDP port,
# which a bare container does not have.
COPY <<'SCRIPT' /usr/local/bin/test-entrypoint
#!/bin/sh
set -e
nc -lk 18080 >/dev/null 2>&1 &
nc -luk 18081 >/dev/null 2>&1 &
[ -f codegen/casaos_api.go ] && [ -f codegen/message_bus/api.go ] || go generate
exec "$@"
SCRIPT
RUN chmod +x /usr/local/bin/test-entrypoint

WORKDIR /src
ENTRYPOINT ["test-entrypoint"]
CMD ["go", "test", "-race", "./..."]
