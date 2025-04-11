# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS build

ARG ARCADE_COMMIT
ARG BUILD_TIMESTAMP

RUN <<EOF
apt-get update
apt-get install -y git debootstrap debian-ports-archive-keyring

git clone https://github.com/dotnet/dotnet-arcade.git /arcade
cd /arcade && git checkout "$ARCADE_COMMIT"
EOF

RUN <<EOF
mkdir /rootfs
/arcade/eng/common/cross/build-rootfs.sh loongarch64 sid --rootfsdir /rootfs || exit 1

cat > /rootfs/README.txt <<READMEEOF
# loongson-community/docker-unofficial-build artifact
ARCADE_COMMIT: $ARCADE_COMMIT
BUILD_TIMESTAMP: $BUILD_TIMESTAMP
READMEEOF
EOF

FROM scratch
COPY --from=build /rootfs /
