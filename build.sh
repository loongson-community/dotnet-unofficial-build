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

    if [[ -e "$destdir/.provisioned" ]]; then
        # TODO: check against the build info
        echo "found existing rootfs, skipping provision"
        endgroup
        return
    fi

    docker pull --platform="$platform" "$tag"
    container_id="$(docker create --platform="$platform" "$tag" /bin/true)"
    echo "temp container ID is $(_term green)${container_id}$(_term reset)"

    mkdir -p "$destdir" || true
    pushd "$destdir" > /dev/null
    docker export "$container_id" | tar -xf -
    touch .provisioned
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

build_runtime() {
    local runtime_root="$1"
    local target_arch="loongarch64"
    local target_rid="linux-$target_arch"
    local build_configuration=Release

    group "building runtime"
    pushd "$runtime_root" > /dev/null
    ./build.sh clr+libs+packs --ci -c "$build_configuration" --cross --arch "$target_arch"
    popd > /dev/null
    endgroup
}

organize_runtime_artifacts() {
    local runtime_root="$1"
    local target_arch="loongarch64"
    local target_rid="linux-$target_arch"
    local build_configuration=Release

    group "organizing runtime artifacts"
    pushd "$runtime_root/artifacts/packages/$build_configuration/Shipping" > /dev/null

    local packages_dir_sources=(
        Microsoft.NETCore.App.Host."$target_rid".*.nupkg
        Microsoft.NETCore.App.Runtime."$target_rid".*.nupkg
    )

    local out_dir_sources=(
        dotnet-runtime-*-"$target_rid".tar.gz
        Microsoft.DotNet.ILCompiler.*.nupkg
        Microsoft.NETCore.App.Crossgen2."$target_rid".*.nupkg
        Microsoft.NETCore.App.Host."$target_rid".*.nupkg
        Microsoft.NETCore.App.Ref.*.nupkg
        Microsoft.NETCore.App.Runtime."$target_rid".*.nupkg
        Microsoft.NETCore.ILAsm.*.nupkg
        Microsoft.NETCore.ILDAsm.*.nupkg
        runtime."$target_rid".Microsoft.DotNet.ILCompiler.*.nupkg
        runtime."$target_rid".Microsoft.NETCore.ILAsm.*.nupkg
        runtime."$target_rid".Microsoft.NETCore.ILDAsm.*.nupkg

        # not produced for loongarch64 or net9:
        # (either may be the reason but I don't know)
        #
        #runtime."$target_rid".Microsoft.NETCore.DotNetHost.*.nupkg
        #runtime."$target_rid".Microsoft.NETCore.DotNetHostPolicy.*.nupkg
        #runtime."$target_rid".Microsoft.NETCore.DotNetHostResolver.*.nupkg
    )

    local download_runtime_dir_sources=(
        dotnet-runtime-*-"$target_rid".tar.gz
    )

    local download_runtime_dir="${DOWNLOADS_DIR}/Runtime/${DOTNET_RUNTIME_BRANCH}"

    mkdir -p "$download_runtime_dir"
    mkdir -p "$OUT_DIR"
    mkdir -p "$PACKAGES_DIR"

    cp -v "${packages_dir_sources[@]}" "$PACKAGES_DIR"
    cp -v "${download_runtime_dir_sources[@]}" "$download_runtime_dir"
    cp -v "${out_dir_sources[@]}" "$OUT_DIR"

    popd > /dev/null
    endgroup
}

main() {
    dump_config
    provision_loong_rootfs "$ROOTFS_IMAGE_TAG" "$ROOTFS_DIR"
    prepare_sources
    build_runtime "$DOTNET_RUNTIME_CHECKOUT"
    organize_runtime_artifacts "$DOTNET_RUNTIME_CHECKOUT"
}

main
