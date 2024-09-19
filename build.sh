#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$MY_DIR"/scripts/_utils.sh

: "${BUILD_CONFIG:=$1}"
: "${BUILD_CONFIG:=$MY_DIR/_config.sh}"

echo "sourcing build config from $(_term green)${BUILD_CONFIG}$(_term reset)"
. "$BUILD_CONFIG"
echo

: "${OUT_DIR:?OUT_DIR must be set}"
: "${ROOTFS_DIR:?ROOTFS_DIR must be set}"
: "${ROOTFS_IMAGE_TAG:?ROOTFS_IMAGE_TAG must be set}"

: "${DOTNET_VMR_BRANCH:?DOTNET_VMR_BRANCH must be set}"
: "${DOTNET_VMR_REPO:=https://github.com/dotnet/dotnet.git}"

: "${DOTNET_VMR_CHECKED_OUT:=false}"
if "$DOTNET_VMR_CHECKED_OUT"; then
    : "${DOTNET_VMR_CHECKOUT:?DOTNET_VMR_CHECKOUT must be set if DOTNET_VMR_CHECKED_OUT=true}"
else
    : "${DOTNET_VMR_CHECKOUT:=/tmp/vmr}"
fi

# TODO: probe with uname
: "${BUILD_RID:=linux-x64}"

: "${TARGET_ARCH:=loongarch64}"
: "${TARGET_RID:=linux-$TARGET_ARCH}"
: "${BUILD_CFG:=Release}"

# used by build-locally.sh to also finalize artifacts in this invocation
: "${ALSO_FINALIZE:=false}"

_SB_ARTIFACTS_DIR=
_cleanup() {
    group "cleaning up"
    if [[ -n $_SB_ARTIFACTS_DIR ]]; then
        echo "removing $_SB_ARTIFACTS_DIR"
        rm -rf "$_SB_ARTIFACTS_DIR" || true
    fi
    endgroup
}
trap _cleanup EXIT

dump_config() {
    group "build config dump"
    echo_kv BUILD_RID "$BUILD_RID"
    echo_kv TARGET_ARCH "$TARGET_ARCH"
    echo_kv TARGET_RID "$TARGET_RID"
    echo_kv BUILD_CFG "$BUILD_CFG"
    echo
    echo_kv OUT_DIR "$OUT_DIR"
    echo_kv ROOTFS_DIR "$ROOTFS_DIR"
    echo_kv ROOTFS_IMAGE_TAG "$ROOTFS_IMAGE_TAG"
    endgroup

    group "source versions"
    echo "$(_term bold yellow)dotnet/dotnet:$(_term reset)"
    echo_kv "  repo" "$DOTNET_VMR_REPO"
    echo_kv "  branch" "$DOTNET_VMR_BRANCH"
    echo_kv "  checkout" "$DOTNET_VMR_CHECKOUT"
    echo
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

    local git_clone_args=(
        --depth 1
        --recurse-submodules
        --shallow-submodules
        -b "$branch"
        "$repo"
        "$dest"
    )
    git clone "${git_clone_args[@]}"
}

prepare_sources() {
    group "preparing sources"
    _do_checkout "$DOTNET_VMR_REPO" "$DOTNET_VMR_BRANCH" "$DOTNET_VMR_CHECKOUT" "$DOTNET_VMR_CHECKED_OUT"
    endgroup
}

prepare_vmr_stage1() {
    local vmr_root="$1"

    group "preparing VMR for stage1 build"
    pushd "$vmr_root" > /dev/null
    ./prep-source-build.sh
    popd > /dev/null
    endgroup
}

_BUILT_VERSION=

build_vmr_stage1() {
    local vmr_root="$1"

    group "building stage1"
    pushd "$vmr_root" > /dev/null

    local args=(
        -so
        --clean-while-building
        -c "$BUILD_CFG"
        -v detailed
        /p:PortableBuild=true
    )
    ./build.sh "${args[@]}"

    _detect_built_version artifacts/assets/Release
    mv artifacts/assets/Release/*.tar.* "$OUT_DIR"/

    popd > /dev/null
    endgroup
}

_detect_built_version() {
    local dir="$1"

    # record the version of produced artifacts so we don't have to pull it out
    # manually with shell
    _BUILT_VERSION="$(cd "$dir" && echo Private.SourceBuilt.Artifacts.*.${BUILD_RID}.tar.*)"
    _BUILT_VERSION="${_BUILT_VERSION#Private.SourceBuilt.Artifacts.}"
    _BUILT_VERSION="${_BUILT_VERSION%.${BUILD_RID}.tar.*}"
}

unpack_sb_artifacts() {
    group "unpacking source build artifacts from stage1"

    [[ -z $_BUILT_VERSION ]] && _detect_built_version "$OUT_DIR"
    if [[ -z $_BUILT_VERSION ]]; then
        echo "fatal: artifact version not detected" >&2
        exit 1
    fi
    echo "artifact version detected as $_BUILT_VERSION"

    _SB_ARTIFACTS_DIR="$(mktemp --tmpdir -d sb-artifacts.XXXXXXXX)"
    pushd "$_SB_ARTIFACTS_DIR" > /dev/null
    mkdir pkg sdk

    pushd pkg > /dev/null
    tar xf "$OUT_DIR"/Private.SourceBuilt.Artifacts."$_BUILT_VERSION"."$BUILD_RID".tar.*
    popd > /dev/null

    pushd sdk > /dev/null
    tar xf "$OUT_DIR"/dotnet-sdk-"$_BUILT_VERSION"-"$BUILD_RID".tar.*
    popd > /dev/null

    popd > /dev/null
    endgroup
}

prepare_vmr_stage2() {
    local vmr_root="$1"
    local version="$2"

    group "preparing VMR for stage2 build"
    pushd "$vmr_root" > /dev/null

    git checkout -- .
    git clean -dfx

    local args=(
        --no-bootstrap
        --no-sdk
        --no-artifacts
        --with-sdk "$_SB_ARTIFACTS_DIR"/sdk
        --with-packages "$_SB_ARTIFACTS_DIR"/pkg
    )
    ./prep-source-build.sh "${args[@]}"

    popd > /dev/null
    endgroup
}

build_vmr_stage2() {
    local vmr_root="$1"

    group "building stage2"
    pushd "$vmr_root" > /dev/null

    local args=(
        -so
        --clean-while-building
        -c "$BUILD_CFG"
        -v detailed
        --with-sdk "$_SB_ARTIFACTS_DIR"/sdk
        --with-packages "$_SB_ARTIFACTS_DIR"/pkg
        --target-rid "$TARGET_RID"
        /p:PortableBuild=true
        /p:HostRid="$TARGET_RID"
        /p:PortableRid="$TARGET_RID"
        /p:TargetArchitecture="$TARGET_ARCH"
    )
    ./build.sh "${args[@]}"

    mv artifacts/assets/Release/*.tar.* "$OUT_DIR"/

    popd > /dev/null
    endgroup
}

main() {
    mkdir -p "$OUT_DIR"

    dump_config
    provision_loong_rootfs "$ROOTFS_IMAGE_TAG" "$ROOTFS_DIR"

    # stage2 wants to run crossgen2 but it's for $TARGET_ARCH instead of
    # $BUILD_ARCH
    : "${QEMU_LD_PREFIX:=$ROOTFS_DIR}"
    export QEMU_LD_PREFIX

    prepare_sources
    prepare_vmr_stage1 "$DOTNET_VMR_CHECKOUT"
    build_vmr_stage1 "$DOTNET_VMR_CHECKOUT"
    unpack_sb_artifacts
    prepare_vmr_stage2 "$DOTNET_VMR_CHECKOUT" "$_BUILT_VERSION"
    build_vmr_stage2 "$DOTNET_VMR_CHECKOUT"

    if "$ALSO_FINALIZE"; then
        "$MY_DIR"/finalize-output.sh "$@"
    fi
}

main "$@"
