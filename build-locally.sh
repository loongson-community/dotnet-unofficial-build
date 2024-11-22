#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$MY_DIR"/scripts/_utils.sh
. "$MY_DIR"/_functions.sh

# keep the image tag synced with GHA
BUILDER_IMAGE_TAG="ghcr.io/loongson-community/dotnet-unofficial-build-builder:20241120T105715Z"

main() {
    cd "$MY_DIR"
    mkdir -p out tmp/ccache tmp/rootfs tmp/rootfs-musl tmp/vmr

    # provision the rootfs outside of Docker in order to avoid DinD operation
    local rootfs_glibc_image_tag="$(cat "$MY_DIR"/rootfs-glibc-image-tag.txt)"
    local rootfs_musl_image_tag="$(cat "$MY_DIR"/rootfs-musl-image-tag.txt)"
    provision_loong_rootfs "$rootfs_glibc_image_tag" tmp/rootfs sudo
    provision_loong_rootfs "$rootfs_musl_image_tag" tmp/rootfs-musl sudo

    local args=(
        --rm
        --platform linux/amd64

        -v "$MY_DIR":/work
        -v "$MY_DIR"/tmp/ccache:/tmp/ccache
        -v "$MY_DIR"/out:/tmp/out
        -v "$MY_DIR"/tmp/rootfs:/tmp/rootfs
        -v "$MY_DIR"/tmp/rootfs-musl:/tmp/rootfs-musl
        -v "$MY_DIR"/tmp/vmr:/vmr

        -e ALSO_FINALIZE=true
        -e CI=true
        # keep in line with GHA definitions for consistency
        -e BUILD_CONFIG=_config.ci.sh
        -e CCACHE_DIR=/tmp/ccache
        -e OUT_DIR=/tmp/out
        -e ROOTFS_GLIBC_DIR=/tmp/rootfs
        -e ROOTFS_MUSL_DIR=/tmp/rootfs-musl

        --init
        -u b
        -w /work
        "$BUILDER_IMAGE_TAG"
        ./build.sh
    )

    exec docker run "${args[@]}"
}

main
