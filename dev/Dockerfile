# Dev container running CasaOS with Gateway, MessageBus, UserService,
# LocalStorage, AppManagement, a local app store and the web UI, all built
# from local sources by dev/build.sh (see `make dev`).
# Reuses the golang image test.Dockerfile already pulled as a Debian base.
FROM golang:1.26.10

COPY dist/dev/rootfs/ /
COPY dev/entrypoint.sh /usr/local/bin/casaos-dev-entrypoint

EXPOSE 80
ENTRYPOINT ["casaos-dev-entrypoint"]
