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

: "${DOTNET_ASPNETCORE_REQUESTED_VERSION:?DOTNET_ASPNETCORE_REQUESTED_VERSION must be set}"
: "${DOTNET_RUNTIME_REQUESTED_VERSION:?DOTNET_RUNTIME_REQUESTED_VERSION must be set}"

: "${DOTNET_ASPNETCORE_BRANCH:?DOTNET_ASPNETCORE_BRANCH must be set}"
: "${DOTNET_ASPNETCORE_REPO:=https://github.com/dotnet/aspnetcore.git}"
: "${DOTNET_RUNTIME_BRANCH:?DOTNET_RUNTIME_BRANCH must be set}"
: "${DOTNET_RUNTIME_REPO:=https://github.com/dotnet/runtime.git}"
: "${DOTNET_SDK_BRANCH:?DOTNET_SDK_BRANCH must be set}"
: "${DOTNET_SDK_REPO:=https://github.com/dotnet/sdk.git}"

if [[ -n $DOTNET_ASPNETCORE_CHECKOUT ]]; then
    DOTNET_ASPNETCORE_CHECKED_OUT=true
else
    DOTNET_ASPNETCORE_CHECKED_OUT=false
    : "${DOTNET_ASPNETCORE_CHECKOUT:=/tmp/dotnet-aspnetcore}"
fi

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

: "${TARGET_ARCH:=loongarch64}"
: "${TARGET_RID:=linux-$TARGET_ARCH}"
: "${BUILD_CFG:=Release}"

dump_config() {
    group "build config dump"
    echo_kv TARGET_ARCH "$TARGET_ARCH"
    echo_kv TARGET_RID "$TARGET_RID"
    echo_kv BUILD_CFG "$BUILD_CFG"
    echo
    echo_kv DOWNLOADS_DIR "$DOWNLOADS_DIR"
    echo_kv OUT_DIR "$OUT_DIR"
    echo_kv PACKAGES_DIR "$PACKAGES_DIR"
    echo_kv ROOTFS_DIR "$ROOTFS_DIR"
    echo_kv ROOTFS_IMAGE_TAG "$ROOTFS_IMAGE_TAG"
    endgroup

    group "source versions"
    echo "$(_term bold yellow)dotnet/aspnetcore:$(_term reset)"
    echo_kv "  repo" "$DOTNET_ASPNETCORE_REPO"
    echo_kv "  branch" "$DOTNET_ASPNETCORE_BRANCH"
    echo_kv "  checkout" "$DOTNET_ASPNETCORE_CHECKOUT"
    echo

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

    group "masquerade versions"
    echo_kv "aspnetcore" "$DOTNET_ASPNETCORE_REQUESTED_VERSION"
    echo_kv "   runtime" "$DOTNET_RUNTIME_REQUESTED_VERSION"
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

    # aspnetcore needs submodules, but it's harmless to just unconditionally
    # add --recurse-submodules here
    git clone --depth 1 -b "$branch" --recurse-submodules "$repo" "$dest"
}

prepare_sources() {
    group "preparing sources"
    _do_checkout "$DOTNET_ASPNETCORE_REPO" "$DOTNET_ASPNETCORE_BRANCH" "$DOTNET_ASPNETCORE_CHECKOUT" "$DOTNET_ASPNETCORE_CHECKED_OUT"
    _do_checkout "$DOTNET_RUNTIME_REPO" "$DOTNET_RUNTIME_BRANCH" "$DOTNET_RUNTIME_CHECKOUT" "$DOTNET_RUNTIME_CHECKED_OUT"
    _do_checkout "$DOTNET_SDK_REPO" "$DOTNET_SDK_BRANCH" "$DOTNET_SDK_CHECKOUT" "$DOTNET_SDK_CHECKED_OUT"
    endgroup
}

build_runtime() {
    local runtime_root="$1"

    group "building runtime"
    pushd "$runtime_root" > /dev/null
    ./build.sh clr+libs+host+packs -c "$BUILD_CFG" --cross --arch "$TARGET_ARCH"
    popd > /dev/null
    endgroup
}

# usage: _masquerade_dev_version filename target_ver
#
# e.g.
#
# _masquerade_dev_version \
#     Microsoft.NETCore.App.Host.linux-loongarch64.9.0.0-dev.nupkg \
#     9.0.0-rc.1.24414.5
#
# output: Microsoft.NETCore.App.Host.linux-loongarch64.9.0.0-rc.1.24414.5.nupkg
_masquerade_dev_version() {
    local filename="$1"
    local target_ver="$2"

    echo "$filename" | sed -E "s/[0-9]+\.0\.0-dev/$2/"
}

# usage: _cp_with_masquerade destdir masquerade_ver source_files...
_cp_into_with_masquerade() {
    local destdir="$1"
    local masquerade_ver="$2"
    shift
    shift

    local masqueraded_filename
    for f in "$@"; do
        masqueraded_filename="$(basename "$(_masquerade_dev_version "$f" "$masquerade_ver")")"
        cp -v "$f" "$destdir"
        cp -v "$f" "$destdir/$masqueraded_filename"
    done
}

organize_runtime_artifacts() {
    local runtime_root="$1"

    group "organizing runtime artifacts"
    pushd "$runtime_root/artifacts/packages/$BUILD_CFG/Shipping" > /dev/null

    local packages_dir_sources=(
        Microsoft.NETCore.App.Host."$TARGET_RID".*.nupkg
        Microsoft.NETCore.App.Runtime."$TARGET_RID".*.nupkg
    )

    local out_dir_sources=(
        dotnet-runtime-*-"$TARGET_RID".tar.gz
        Microsoft.DotNet.ILCompiler.*.nupkg
        Microsoft.NETCore.App.Crossgen2."$TARGET_RID".*.nupkg
        Microsoft.NETCore.App.Host."$TARGET_RID".*.nupkg
        Microsoft.NETCore.App.Ref.*.nupkg
        Microsoft.NETCore.App.Runtime."$TARGET_RID".*.nupkg
        Microsoft.NETCore.ILAsm.*.nupkg
        Microsoft.NETCore.ILDAsm.*.nupkg
        runtime."$TARGET_RID".Microsoft.DotNet.ILCompiler.*.nupkg
        runtime."$TARGET_RID".Microsoft.NETCore.ILAsm.*.nupkg
        runtime."$TARGET_RID".Microsoft.NETCore.ILDAsm.*.nupkg

        # not produced for loongarch64 or net9:
        # (either may be the reason but I don't know)
        #
        #runtime."$TARGET_RID".Microsoft.NETCore.DotNetHost.*.nupkg
        #runtime."$TARGET_RID".Microsoft.NETCore.DotNetHostPolicy.*.nupkg
        #runtime."$TARGET_RID".Microsoft.NETCore.DotNetHostResolver.*.nupkg
    )

    local download_runtime_dir_sources=(
        dotnet-runtime-*-"$TARGET_RID".tar.gz
    )

    local download_runtime_dir="${DOWNLOADS_DIR}/Runtime/${DOTNET_RUNTIME_REQUESTED_VERSION}"

    mkdir -p "$download_runtime_dir"
    mkdir -p "$OUT_DIR"
    mkdir -p "$PACKAGES_DIR"

    _cp_into_with_masquerade "$PACKAGES_DIR" "$DOTNET_RUNTIME_REQUESTED_VERSION" "${packages_dir_sources[@]}"
    _cp_into_with_masquerade "$download_runtime_dir" "$DOTNET_RUNTIME_REQUESTED_VERSION" "${download_runtime_dir_sources[@]}"
    _cp_into_with_masquerade "$OUT_DIR" "$DOTNET_RUNTIME_REQUESTED_VERSION" "${out_dir_sources[@]}"

    popd > /dev/null
    endgroup
}

build_aspnetcore() {
    local aspnetcore_root="$1"

    group "building aspnetcore"
    pushd "$aspnetcore_root" > /dev/null

    sed -i "s|\$(BaseIntermediateOutputPath)\$(DotNetRuntimeArchiveFileName)|${DOWNLOADS_DIR}/Runtime/${DOTNET_RUNTIME_REQUESTED_VERSION}/dotnet-runtime-${DOTNET_RUNTIME_REQUESTED_VERSION}-${TARGET_RID}.tar.gz|" src/Framework/App.Runtime/src/Microsoft.AspNetCore.App.Runtime.csproj

    local args=(
        --pack
        -c "$BUILD_CFG"
        --arch "$TARGET_ARCH"
        --no-build-nodejs
        --no-test
        /p:DotNetAssetRootUrl="file://${DOWNLOADS_DIR}/"
    )

    ./eng/build.sh "${args[@]}"
    popd > /dev/null
    endgroup
}

organize_aspnetcore_artifacts() {
    local aspnetcore_root="$1"

    group "organizing aspnetcore artifacts"
    pushd "$aspnetcore_root/artifacts" > /dev/null

    local pkg="packages/$BUILD_CFG/Shipping"
    local ins="installers/$BUILD_CFG"
    local packages_dir_sources=(
        "$pkg"/Microsoft.AspNetCore.App.Ref.*.nupkg
        "$pkg"/Microsoft.AspNetCore.App.Runtime."$TARGET_RID".*.nupkg
    )

    local out_dir_sources=(
        "$ins"/*
        "$pkg"/Microsoft.AspNetCore.App.Ref.*.nupkg
        "$pkg"/Microsoft.AspNetCore.App.Runtime."$TARGET_RID".*.nupkg
        "$pkg"/Microsoft.DotNet.Web.*.nupkg
    )

    local download_dir_sources=(
        "$ins"/aspnetcore-runtime-*-"$TARGET_RID".tar.gz
        "$ins"/aspnetcore-targeting-pack-*-"$TARGET_RID".tar.gz
    )

    local download_aspnetcore_dir="${DOWNLOADS_DIR}/aspnetcore/Runtime/${DOTNET_ASPNETCORE_REQUESTED_VERSION}"

    mkdir -p "$download_aspnetcore_dir"
    mkdir -p "$OUT_DIR"
    mkdir -p "$PACKAGES_DIR"

    _cp_into_with_masquerade "$PACKAGES_DIR" "$DOTNET_ASPNETCORE_REQUESTED_VERSION" "${packages_dir_sources[@]}"
    _cp_into_with_masquerade "$OUT_DIR" "$DOTNET_ASPNETCORE_REQUESTED_VERSION" "${out_dir_sources[@]}"
    _cp_into_with_masquerade "$download_aspnetcore_dir" "$DOTNET_ASPNETCORE_REQUESTED_VERSION" "${download_dir_sources[@]}"
    cp -v "$ins"/aspnetcore_base_runtime.version "$download_aspnetcore_dir/"

    popd > /dev/null
    endgroup
}

build_sdk() {
    local sdk_root="$1"

    group "building sdk"
    pushd "$sdk_root" > /dev/null

    sed -i s"|<clear />|<clear />\n<add key=\"local\" value=\"${PACKAGES_DIR}\" />|" NuGet.config

    local args=(
        --pack
        -c "$BUILD_CFG"
        /p:Architecture="$TARGET_ARCH"
        /p:HostRid=linux-x64
        /p:PublicBaseURL="file://${DOWNLOADS_DIR}/"
    )

    ./build.sh "${args[@]}"
    popd > /dev/null
    endgroup
}

organize_sdk_artifacts() {
    local sdk_root="$1"

    group "organizing sdk artifacts"
    pushd "$sdk_root/artifacts/packages/$BUILD_CFG/Shipping" > /dev/null

    local out_dir_sources=(
        dotnet-sdk-*-"${TARGET_RID}".tar.*
    )

    mkdir -p "$OUT_DIR"

    cp "${out_dir_sources[@]}" "$OUT_DIR"

    popd > /dev/null
    endgroup
}

main() {
    dump_config
    provision_loong_rootfs "$ROOTFS_IMAGE_TAG" "$ROOTFS_DIR"
    prepare_sources
    build_runtime "$DOTNET_RUNTIME_CHECKOUT"
    organize_runtime_artifacts "$DOTNET_RUNTIME_CHECKOUT"
    build_aspnetcore "$DOTNET_ASPNETCORE_CHECKOUT"
    organize_aspnetcore_artifacts "$DOTNET_ASPNETCORE_CHECKOUT"
    build_sdk "$DOTNET_SDK_CHECKOUT"
    organize_sdk_artifacts "$DOTNET_SDK_CHECKOUT"
}

main
