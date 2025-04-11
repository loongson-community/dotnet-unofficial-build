# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM alpine:3.21 AS build

ARG ARCADE_COMMIT
ARG BUILD_TIMESTAMP

RUN <<EOF
apk update
apk add git bash alpine-keys

git clone https://github.com/dotnet/dotnet-arcade.git /arcade
cd /arcade && git checkout "$ARCADE_COMMIT"
EOF

RUN <<EOF
mkdir /rootfs
/arcade/eng/common/cross/build-rootfs.sh loongarch64 alpine3.21 --skipsigcheck --rootfsdir /rootfs || exit 1

cat > /rootfs/README.txt <<READMEEOF
# loongson-community/docker-unofficial-build artifact
ARCADE_COMMIT: $ARCADE_COMMIT
BUILD_TIMESTAMP: $BUILD_TIMESTAMP
READMEEOF
EOF

FROM scratch
COPY --from=build /rootfs /
