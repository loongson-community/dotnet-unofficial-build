#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source-path=SCRIPTDIR
. "$MY_DIR"/scripts/_utils.sh
. "$MY_DIR"/_functions.sh

: "${BUILD_CONFIG:=$1}"
: "${BUILD_CONFIG:=$MY_DIR/_config.sh}"

echo "sourcing build config from $(_term green)${BUILD_CONFIG}$(_term reset)"
# shellcheck source=_config.sh
. "$BUILD_CONFIG"
echo

: "${OUT_DIR:?OUT_DIR must be set}"

if [[ -n $ROOTFS_GLIBC_DIR ]]; then
    : "${ROOTFS_GLIBC_IMAGE_TAG:?ROOTFS_GLIBC_IMAGE_TAG must be set when ROOTFS_GLIBC_DIR is specified}"
fi

if [[ -n $ROOTFS_MUSL_DIR ]]; then
    : "${ROOTFS_MUSL_IMAGE_TAG:?ROOTFS_MUSL_IMAGE_TAG must be set when ROOTFS_MUSL_DIR is specified}"
fi

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
: "${BUILD_CFG:=Release}"

: "${TARGET_ARCH:=loongarch64}"

if [[ -n $ROOTFS_GLIBC_DIR ]]; then
    : "${TARGET_GLIBC_RID:=linux-$TARGET_ARCH}"
fi

if [[ -n $ROOTFS_MUSL_DIR ]]; then
    : "${TARGET_MUSL_RID:=linux-musl-$TARGET_ARCH}"
fi

# used by build-locally.sh to also finalize artifacts in this invocation
: "${ALSO_FINALIZE:=false}"

# disable Microsoft dotnet telemetry by default
: "${DOTNET_CLI_TELEMETRY_OPTOUT:=1}"
export DOTNET_CLI_TELEMETRY_OPTOUT

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

    ensure_git_safety
    dump_config
    init_source_epoch

    if [[ -n $ROOTFS_GLIBC_DIR ]]; then
        provision_loong_rootfs "$ROOTFS_GLIBC_IMAGE_TAG" "$ROOTFS_GLIBC_DIR"
    fi

    if [[ -n $ROOTFS_MUSL_DIR ]]; then
        provision_loong_rootfs "$ROOTFS_MUSL_IMAGE_TAG" "$ROOTFS_MUSL_DIR"
    fi

    prepare_sources

    prepare_vmr_stage1 "$DOTNET_VMR_CHECKOUT"
    maybe_dump_ccache_stats
    setup_flags 1
    build_vmr_stage1 "$DOTNET_VMR_CHECKOUT"
    maybe_dump_ccache_stats

    unpack_sb_artifacts

    if [[ -n $ROOTFS_GLIBC_DIR ]]; then
        export ROOTFS_DIR="$ROOTFS_GLIBC_DIR"
        # stage2 wants to run crossgen2 but it's for $TARGET_ARCH instead of
        # $BUILD_ARCH
        export QEMU_LD_PREFIX="$ROOTFS_DIR"
        prepare_vmr_stage2 "$DOTNET_VMR_CHECKOUT"
        setup_flags 2
        build_vmr_stage2 "$DOTNET_VMR_CHECKOUT" "$TARGET_GLIBC_RID"
        maybe_dump_ccache_stats
    fi

    if [[ -n $ROOTFS_MUSL_DIR ]]; then
        export ROOTFS_DIR="$ROOTFS_MUSL_DIR"
        export QEMU_LD_PREFIX="$ROOTFS_MUSL_DIR"
        prepare_vmr_stage2 "$DOTNET_VMR_CHECKOUT"
        setup_flags 2
        build_vmr_stage2 "$DOTNET_VMR_CHECKOUT" "$TARGET_MUSL_RID"
        maybe_dump_ccache_stats
    fi

    if "$ALSO_FINALIZE"; then
        "$MY_DIR"/finalize-output.sh "$@"
    fi
}

main "$@"
