#!/bin/bash

set -e

PACKAGES=(
    build-essential
    ca-certificates
    g++-loongarch64-linux-gnu  # for lack of crossbuild-essential-loong64
    wget

    # llvm/clang utils
    clang-19
    lld-19
    llvm-19

    # PowerShell install deps
    apt-transport-https
    software-properties-common

    # host build deps
    azure-cli
    cmake
    curl
    file  # required by prep-source-build binary tool
    gdb
    git
    iputils-ping
    locales
    locales-all
    lttng-tools
    python3-dev
    python3-pip
    sudo
    tzdata

    # this is mostly the same as, and should stay sync with those of cross
    # rootfs
    libcurl4-openssl-dev
    libicu-dev
    libkrb5-dev
    liblldb-dev
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
    docker-cli
    pigz  # to decompress gzip faster
    sccache  # to enable potential caching with object storage backend
    zstd  # to repack the tarballs for smaller size
)

apt-get update
apt-get install -y --no-install-recommends "${PACKAGES[@]}"
locale-gen en_US.UTF-8
localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# we might not refresh nodejs-built artifacts in our process, but having it
# in place is more future-proof
apt-get autoremove -y nodejs
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# install powershell
#
# from https://github.com/dotnet/dotnet-buildtools-prereqs-docker/blob/8bb52e2a2cc565f932ca7fb76abd9a64d0c78018/src/debian/12/gcc14/amd64/Dockerfile:
#
# > Specifically use deb 11 PMC because 12 doesn't have it yet.
curl -sL https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb -o packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
apt-get update
apt-get install -y powershell

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
