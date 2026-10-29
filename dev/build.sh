#!/usr/bin/env bash
# Build a Linux rootfs for the dev container from local sources:
# this repo plus sibling checkouts of CasaOS-Gateway, CasaOS-MessageBus,
# CasaOS-UserService, CasaOS-LocalStorage, CasaOS-AppManagement,
# CasaOS-AppStore and a prebuilt CasaOS-UI (yarn build).
#
#   CASAOS_SRC=~/src ./dev/build.sh
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=${CASAOS_SRC:-$(dirname "$ROOT")}
OUT=$ROOT/dist/dev/rootfs
GOARCH=${GOARCH:-$(go env GOARCH)}
export GOOS=linux GOARCH CGO_ENABLED=0

for repo in CasaOS-Gateway CasaOS-MessageBus CasaOS-UserService CasaOS-LocalStorage CasaOS-AppManagement CasaOS-AppStore; do
    [ -d "$SRC/$repo" ] || { echo "missing $SRC/$repo" >&2; exit 1; }
done
WWW=$SRC/CasaOS-UI/build/sysroot/var/lib/casaos/www
[ -f "$WWW/index.html" ] || { echo "missing $WWW (run yarn build in CasaOS-UI)" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/usr/bin" "$OUT/usr/share/casaos/www"

OAPI="go run github.com/deepmap/oapi-codegen/cmd/oapi-codegen@v1.12.4"
MESSAGE_BUS_SPEC=$SRC/CasaOS-MessageBus/api/message_bus/openapi.yaml

# Run a repo's codegen like its go:generate does, except that the message bus
# spec, which go:generate fetches from GitHub, comes from the local checkout.
codegen() { # <repo dir> <spec> <output> <message bus oapi-codegen flags...>
    local dir=$1 spec=$2 out=$3
    shift 3
    [ -f "$dir/$out" ] && [ -f "$dir/codegen/message_bus/api.go" ] && return
    echo "generating $(basename "$dir") codegen"
    mkdir -p "$dir/$(dirname "$out")" "$dir/codegen/message_bus"
    (cd "$dir" && GOOS= GOARCH= $OAPI -generate types,server,spec -package codegen "$spec" > "$out")
    (cd "$dir" && GOOS= GOARCH= $OAPI "$@" -package message_bus "$MESSAGE_BUS_SPEC" > codegen/message_bus/api.go)
}

build() { # <repo dir> <binary name>
    echo "building $2"
    (cd "$1" && go build -o "$OUT/usr/bin/$2" .)
}

codegen "$SRC/CasaOS-UserService" api/user-service/openapi.yaml codegen/user_service/user_service_api.go
codegen "$SRC/CasaOS-LocalStorage" api/local_storage/openapi.yaml codegen/local_storage_api.go -generate types,client
codegen "$SRC/CasaOS-AppManagement" api/app_management/openapi.yaml codegen/app_management_api.go -generate types,client
[ -f "$ROOT/codegen/casaos_api.go" ] || (cd "$ROOT" && GOOS= GOARCH= go generate)

build "$ROOT" casaos
build "$SRC/CasaOS-Gateway" casaos-gateway
build "$SRC/CasaOS-MessageBus" casaos-message-bus
build "$SRC/CasaOS-UserService" casaos-user-service
build "$SRC/CasaOS-LocalStorage" casaos-local-storage
build "$SRC/CasaOS-AppManagement" casaos-app-management

cp -R "$ROOT/build/sysroot/usr/share/casaos/shell" "$OUT/usr/share/casaos/"
cp -R "$SRC/CasaOS-LocalStorage/build/sysroot/usr/share/casaos/shell/." "$OUT/usr/share/casaos/shell/"
cp -R "$WWW/." "$OUT/usr/share/casaos/www/"
mkdir -p "$OUT/usr/share/casaos/dev"
cp "$SRC/CasaOS-AppManagement/build/sysroot/etc/casaos/app-management.conf.sample" \
    "$SRC/CasaOS-AppManagement/build/sysroot/etc/casaos/env" "$OUT/usr/share/casaos/dev/"

# Local app store, installed as AppManagement's default store by
# dev/entrypoint.sh so the public stores are never fetched.
mkdir -p "$OUT/usr/share/casaos/dev/appstore"
cp -R "$SRC/CasaOS-AppStore/Apps" "$OUT/usr/share/casaos/dev/appstore/"
for f in category-list.json featured-apps.json recommend-list.json; do
    cp "$SRC/CasaOS-AppStore/$f" "$OUT/usr/share/casaos/dev/appstore/"
done

echo "rootfs ready at $OUT"
