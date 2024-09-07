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

    liblttng-ust-dev
    zlib1g-dev

    # for dotnet-unofficial-build self use (pulling back the rootfs image)
    docker.io
)

apt-get update
apt-get install -y --no-install-recommends "${PACKAGES[@]}"
locale-gen en_US.UTF-8

apt-get autoremove -y nodejs
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

apt-get clean

cat > /README.txt <<READMEEOF
# loongson-community/dotnet-unofficial-build builder image
BUILD_TIMESTAMP=$BUILD_TIMESTAMP
READMEEOF
