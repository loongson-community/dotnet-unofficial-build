#!/bin/bash

set -e

PACKAGES=(
    build-essential
    ca-certificates
    git
    g++-loongarch64-linux-gnu  # for lack of crossbuild-essential-loong64
    cmake
    curl
    locales
    python3
    python3-libxml2
    wget

    # llvm/clang utils
    clang-18
    lld-18
    llvm-18

    # host build deps
    # this is mostly the same as, and should stay sync with those of cross
    # rootfs
    libcurl4-openssl-dev
    libicu-dev
    libkrb5-dev
    liblttng-ust-dev
    libnuma-dev
    libomp5
    libomp-dev
    libssl-dev
    libunwind8-dev
    zlib1g-dev

    # optional deps
    ninja-build

    # for dotnet-unofficial-build self use
    ccache  # to enable local build caches
    docker.io  # to pull back the rootfs image in container form
    sccache  # to enable potential caching with object storage backend
    sudo  # to enable unprivileged builds
)

apt-get update
apt-get install -y --no-install-recommends "${PACKAGES[@]}"
locale-gen en_US.UTF-8

# we might not refresh nodejs-built artifacts in our process, but having it
# in place is more future-proof
apt-get autoremove -y nodejs
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

apt-get clean

cat > /README.txt <<READMEEOF
# loongson-community/dotnet-unofficial-build builder image
BUILD_TIMESTAMP=$BUILD_TIMESTAMP
BUILDER_UID=$BUILDER_UID
BUILDER_USER=$BUILDER_USER
READMEEOF

useradd -m -u "$BUILDER_UID" -U "$BUILDER_USER"
echo "$BUILDER_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
chmod 0640 /etc/sudoers.d/builder

rm "${BASH_SOURCE[0]}" || true
