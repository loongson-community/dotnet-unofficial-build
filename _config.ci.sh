#!/bin/bash

# Config and basic preparations suitable for our GHA environment.

# expect CCACHE_DIR, OUT_DIR and ROOTFS_DIR to be set by the task definition
mkdir -p "$CCACHE_DIR" "$OUT_DIR" "$ROOTFS_DIR"

# enable ccache shims if ccache directory is specified
if [[ -n $CCACHE_DIR ]]; then
    # this is suitable for our builder image
    if [[ -e /usr/lib/ccache ]]; then
        export PATH="/usr/lib/ccache:$PATH"
    fi
fi

# we check out the VMR in the build script because we don't want to hardcode
# the tag/branch in the CI task definition
DOTNET_VMR_CHECKED_OUT=false
DOTNET_VMR_CHECKOUT="/vmr"
DOTNET_VMR_BRANCH="main-9.x-loong"
DOTNET_VMR_REPO=https://github.com/loongson-community/dotnet.git

ROOTFS_IMAGE_TAG="ghcr.io/loongson-community/dotnet-unofficial-build-rootfs:e0a68f5b86f8-20240904T171513Z"

# it may be better to align with dotnet upstream that still sticks with gzip
# so far
# the size savings are not very significant anyway with today's network
# bandwidth
REPACK_TARBALLS=false
