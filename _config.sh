[[ -e .envrc ]] && . .envrc

ROOTFS_IMAGE_TAG="ghcr.io/loongson-community/dotnet-unofficial-build-rootfs:e0a68f5b86f8-20240904T171513Z"

DOTNET_VMR_BRANCH="main-9.x-loong"
DOTNET_VMR_REPO=https://github.com/loongson-community/dotnet.git

# it may be better to align with dotnet upstream that still sticks with gzip
# so far
# the size savings are not very significant anyway with today's network
# bandwidth
REPACK_TARBALLS=false
