#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$MY_DIR"/scripts/_utils.sh

: "${DOWNLOADS_DIR:?DOWNLOADS_DIR must be set}"
: "${OUT_DIR:?OUT_DIR must be set}"
: "${PACKAGES_DIR:?PACKAGES_DIR must be set}"
: "${ROOTFS_DIR:?ROOTFS_DIR must be set}"
: "${ROOTFS_IMAGE_TAG:?ROOTFS_IMAGE_TAG must be set}"

dump_config() {
    group "build config dump"
    echo_kv DOWNLOADS_DIR "$DOWNLOADS_DIR"
    echo_kv OUT_DIR "$OUT_DIR"
    echo_kv PACKAGES_DIR "$PACKAGES_DIR"
    echo_kv ROOTFS_DIR "$ROOTFS_DIR"
    echo_kv ROOTFS_IMAGE_TAG "$ROOTFS_IMAGE_TAG"
    endgroup
}

provision_loong_rootfs() {
    local tag="$1"
    local destdir="$2"
    local platform=linux/loong64
    local container_id

    group "provisioning $platform cross rootfs"

    docker pull --platform="$platform" "$tag"
    container_id="$(docker create --platform="$platform" "$tag" /bin/true)"
    echo "temp container ID is $(_term green)${container_id}$(_term reset)"

    mkdir -p "$destdir" || true
    pushd "$destdir" > /dev/null
    docker export "$container_id" | tar -xf -
    popd

    docker rm "$container_id"

    endgroup
}

main() {
    dump_config
    provision_loong_rootfs "$ROOTFS_IMAGE_TAG" "$ROOTFS_DIR"
}

main
