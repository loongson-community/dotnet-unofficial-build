[[ -e .envrc ]] && . .envrc

ROOTFS_IMAGE_TAG="ghcr.io/loongson-community/dotnet-unofficial-build-rootfs:e0a68f5b86f8-20240904T171513Z"

DOTNET_RUNTIME_REQUESTED_VERSION="9.0.0-rc.1.24431.7"
DOTNET_ASPNETCORE_REQUESTED_VERSION="9.0.0-rc.1.24452.1"

DOTNET_ASPNETCORE_BRANCH="release/9.0-rc1"
DOTNET_ASPNETCORE_REPO=https://github.com/dotnet/aspnetcore.git
DOTNET_RUNTIME_BRANCH="release/9.0-rc1-loong"
DOTNET_RUNTIME_REPO=https://github.com/loongson-community/dotnet-runtime.git
DOTNET_SDK_BRANCH="release/9.0.1xx-rc1-loong"
DOTNET_SDK_REPO=https://github.com/loongson-community/dotnet-sdk.git
