#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$MY_DIR"/scripts/_utils.sh
. "$MY_DIR"/_functions.sh

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

# disable Microsoft dotnet telemetry by default
: "${DOTNET_CLI_TELEMETRY_OPTOUT:=1}"

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
