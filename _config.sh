[[ -e .envrc ]] && . .envrc

ROOTFS_IMAGE_TAG="ghcr.io/loongson-community/dotnet-unofficial-build-rootfs:e0a68f5b86f8-20240904T171513Z"

DOTNET_RUNTIME_REQUESTED_VERSION="9.0.0-rc.1.24414.5"
DOTNET_ASPNETCORE_REQUESTED_VERSION="9.0.0-rc.1.24414.4"

DOTNET_ASPNETCORE_BRANCH="release/9.0-rc1"
DOTNET_ASPNETCORE_REPO=https://github.com/dotnet/aspnetcore.git
DOTNET_RUNTIME_BRANCH="v9.0.0-preview.7.24405.7"
DOTNET_RUNTIME_REPO=https://github.com/dotnet/runtime.git
DOTNET_SDK_BRANCH="v9.0.100-preview.7.24407.12"
DOTNET_SDK_REPO=https://github.com/dotnet/sdk.git
