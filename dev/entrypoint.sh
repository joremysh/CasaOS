#!/usr/bin/env bash
# Start the CasaOS services in the order systemd would, waiting for each one
# to come up before starting the next. The container stops as soon as any
# service exits.
set -euo pipefail

RUNTIME=/var/run/casaos
mkdir -p "$RUNTIME" /etc/casaos /var/log/casaos /var/lib/casaos/db /DATA

# AppManagement uses the local app store from dev/build.sh as its default
# store, refreshed on every start; its config drops the public store URLs.
[ -f /etc/casaos/app-management.conf ] ||
    sed '/^appstore = /d' /usr/share/casaos/dev/app-management.conf.sample > /etc/casaos/app-management.conf
rm -rf /var/lib/casaos/appstore/default
mkdir -p /var/lib/casaos/appstore
cp -R /usr/share/casaos/dev/appstore /var/lib/casaos/appstore/default
[ -f /etc/casaos/env ] || cp /usr/share/casaos/dev/env /etc/casaos/env

wait_for() { # <url file>
    for _ in $(seq 1 30); do
        [ -s "$RUNTIME/$1" ] && return
        sleep 1
    done
    echo "timed out waiting for $RUNTIME/$1" >&2
    exit 1
}

wait_for_route() { # <path> - registered once the gateway stops answering 404
    for _ in $(seq 1 30); do
        [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1$1")" != 404 ] && return
        sleep 1
    done
    echo "timed out waiting for gateway route $1" >&2
    exit 1
}

casaos-gateway -w /usr/share/casaos/www &
wait_for management.url
casaos-message-bus -c /etc/casaos/message-bus.conf &
wait_for message-bus.url
casaos-user-service -c /etc/casaos/user-service.conf &
wait_for user-service.url
casaos-local-storage -c /etc/casaos/local-storage.conf &
wait_for_route /v1/disks
casaos-app-management -c /etc/casaos/app-management.conf &
wait_for app-management.url
casaos -c /etc/casaos/casaos.conf &
wait_for casaos.url

echo "CasaOS is up: http://localhost:${HOST_PORT:-8080}"
wait -n
