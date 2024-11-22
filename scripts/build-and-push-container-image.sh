#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$MY_DIR"/_utils.sh

KIND="${1:?container kind must be specified on command-line}"
: "${ARCADE_COMMIT:=95f50458d71ce267ba1537569cfeec9ff5d51cb6}"
: "${BUILD_TIMESTAMP:="$(date -u '+%Y%m%dT%H%M%SZ')"}"

ARGS=(
    --rm
    --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP"
)

is_rootfs=false
libc_kind=
case "$KIND" in
builder)
    IMAGE_TAG="$(builder_image_tag "$BUILD_TIMESTAMP")"
    ;;
rootfs)
    is_rootfs=true
    libc_kind=glibc
    ;;
rootfs-musl)
    is_rootfs=true
    libc_kind=musl
    ;;
*)
    echo "usage: $0 <builder|rootfs>" >&2
    exit 1
esac

if "$is_rootfs"; then
    IMAGE_TAG="$(rootfs_image_tag "$ARCADE_COMMIT" "$BUILD_TIMESTAMP" "$libc_kind")"
    ARGS+=(
        --platform "linux/loong64"
        --build-arg ARCADE_COMMIT="$ARCADE_COMMIT"
        --ulimit nofile=2048:2048  # otherwise it can go up to ~1Gi, causing apt-get to apparently hang
    )
fi

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
