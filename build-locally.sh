#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# keep the image tag synced with GHA
BUILDER_IMAGE_TAG="ghcr.io/loongson-community/dotnet-unofficial-build-builder:20240918T124748Z"

main() {
    cd "$MY_DIR"
    mkdir -p out tmp

    local args=(
        --rm
        --platform linux/amd64

        -v "$MY_DIR":/work
        -v "$MY_DIR"/tmp/ccache:/tmp/ccache
        -v "$MY_DIR"/out:/tmp/out
        -v "$MY_DIR"/tmp/rootfs:/tmp/rootfs

        -e ALSO_FINALIZE=true
        # keep in line with GHA definitions for consistency
        -e BUILD_CONFIG=_config.ci.sh
        -e CCACHE_DIR=/tmp/ccache
        -e OUT_DIR=/tmp/out
        -e ROOTFS_DIR=/tmp/rootfs

        -u b
        -w /work
        -ti
        "$BUILDER_IMAGE_TAG"
        ./build.sh
    )

    exec docker run "${args[@]}"
}

main
