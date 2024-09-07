#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$MY_DIR"/scripts/_utils.sh

: "${BUILD_CONFIG:=$1}"
: "${BUILD_CONFIG:=$MY_DIR/_config.sh}"

echo "sourcing build config from $(_term green)${BUILD_CONFIG}$(_term reset)"
. "$BUILD_CONFIG"
echo

: "${DOWNLOADS_DIR:?DOWNLOADS_DIR must be set}"
: "${OUT_DIR:?OUT_DIR must be set}"
: "${PACKAGES_DIR:?PACKAGES_DIR must be set}"
: "${ROOTFS_DIR:?ROOTFS_DIR must be set}"
: "${ROOTFS_IMAGE_TAG:?ROOTFS_IMAGE_TAG must be set}"

: "${DOTNET_RUNTIME_BRANCH:?DOTNET_RUNTIME_BRANCH must be set}"
: "${DOTNET_RUNTIME_REPO:=https://github.com/dotnet/runtime.git}"
: "${DOTNET_SDK_BRANCH:?DOTNET_SDK_BRANCH must be set}"
: "${DOTNET_SDK_REPO:=https://github.com/dotnet/sdk.git}"

if [[ -n $DOTNET_RUNTIME_CHECKOUT ]]; then
    DOTNET_RUNTIME_CHECKED_OUT=true
else
    DOTNET_RUNTIME_CHECKED_OUT=false
    : "${DOTNET_RUNTIME_CHECKOUT:=/tmp/dotnet-runtime}"
fi

if [[ -n $DOTNET_SDK_CHECKOUT ]]; then
    DOTNET_SDK_CHECKED_OUT=true
else
    DOTNET_SDK_CHECKED_OUT=false
    : "${DOTNET_SDK_CHECKOUT:=/tmp/dotnet-sdk}"
fi

dump_config() {
    group "build config dump"
    echo_kv DOWNLOADS_DIR "$DOWNLOADS_DIR"
    echo_kv OUT_DIR "$OUT_DIR"
    echo_kv PACKAGES_DIR "$PACKAGES_DIR"
    echo_kv ROOTFS_DIR "$ROOTFS_DIR"
    echo_kv ROOTFS_IMAGE_TAG "$ROOTFS_IMAGE_TAG"
    endgroup

    group "source versions"
    echo "$(_term bold yellow)dotnet/runtime:$(_term reset)"
    echo_kv "  repo" "$DOTNET_RUNTIME_REPO"
    echo_kv "  branch" "$DOTNET_RUNTIME_BRANCH"
    echo_kv "  checkout" "$DOTNET_RUNTIME_CHECKOUT"
    echo

    echo "$(_term bold yellow)dotnet/sdk:$(_term reset)"
    echo_kv "  repo" "$DOTNET_SDK_REPO"
    echo_kv "  branch" "$DOTNET_SDK_BRANCH"
    echo_kv "  checkout" "$DOTNET_SDK_CHECKOUT"
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

_do_checkout() {
    local repo="$1"
    local branch="$2"
    local dest="$3"
    local skip="${4:=false}"

    if "$skip"; then
        echo "skipping checkout into $dest, assuming correct contents"
        return
    fi

    git clone --depth 1 -b "$branch" "$repo" "$dest"
}

prepare_sources() {
    group "preparing sources"
    _do_checkout "$DOTNET_RUNTIME_REPO" "$DOTNET_RUNTIME_BRANCH" "$DOTNET_RUNTIME_CHECKOUT" "$DOTNET_RUNTIME_CHECKED_OUT"
    _do_checkout "$DOTNET_SDK_REPO" "$DOTNET_SDK_BRANCH" "$DOTNET_SDK_CHECKOUT" "$DOTNET_SDK_CHECKED_OUT"
    endgroup
}

main() {
    dump_config
    provision_loong_rootfs "$ROOTFS_IMAGE_TAG" "$ROOTFS_DIR"
    prepare_sources
}

main
