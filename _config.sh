#!/bin/bash
# shellcheck disable=SC2034  # the file is meant to be sourced so no exports needed

# shellcheck disable=SC1091  # this is up to the user
[[ -e .envrc ]] && . .envrc

ROOTFS_GLIBC_IMAGE_TAG="ghcr.io/loongson-community/dotnet-unofficial-build-rootfs:e0a68f5b86f8-20240904T171513Z"
ROOTFS_MUSL_IMAGE_TAG="ghcr.io/loongson-community/dotnet-unofficial-build-rootfs:95f50458d71c-20241122T091814Z-musl"

DOTNET_VMR_BRANCH="main-9.x-loong"
DOTNET_VMR_REPO=https://github.com/loongson-community/dotnet.git

# it may be better to align with dotnet upstream that still sticks with gzip
# so far
# the size savings are not very significant anyway with today's network
# bandwidth
REPACK_TARBALLS=false
