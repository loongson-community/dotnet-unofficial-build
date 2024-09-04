# this file is meant to be sourced

_IMAGE_TAG_PREFIX="ghcr.io/loongson-community"

builder_image_tag() {
    local timestamp="$1"
    echo "${_IMAGE_TAG_PREFIX}/dotnet-unofficial-build-builder:${timestamp}"
}

rootfs_image_tag() {
    local arcade_commit="${1:0:12}"
    local timestamp="$2"
    echo "${_IMAGE_TAG_PREFIX}/dotnet-unofficial-build-rootfs:${arcade_commit}-${timestamp}"
}
