#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$MY_DIR"/_utils.sh

KIND="${1:?container kind must be specified on command-line}"
: "${ARCADE_COMMIT:=e0a68f5b86f8c946197f16c5192ce81b68dfa7a2}"
: "${BUILD_TIMESTAMP:="$(date -u '+%Y%m%dT%H%M%SZ')"}"

ARGS=(
    --rm
    --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP"
)

case "$KIND" in
builder)
    IMAGE_TAG="$(builder_image_tag "$BUILD_TIMESTAMP")"
    ;;
rootfs)
    IMAGE_TAG="$(rootfs_image_tag "$ARCADE_COMMIT" "$BUILD_TIMESTAMP")"
    ARGS+=(
        --platform "linux/loong64"
        --build-arg ARCADE_COMMIT="$ARCADE_COMMIT"
        --ulimit nofile=2048:2048  # otherwise it can go up to ~1Gi, causing apt-get to apparently hang
    )
    ;;
*)
    echo "usage: $0 <builder|rootfs>" >&2
    exit 1
esac

ARGS+=(
    -t "$IMAGE_TAG"
    --push
    .
)

echo
echo "Building $KIND image to be tagged: $IMAGE_TAG"
echo

cd "$MY_DIR/../containers/$KIND"
exec docker buildx build "${ARGS[@]}"
