以下的可下载文件列表中，RID 为 `linux-x64` 的那些是 Stage 1
构建产物，可供需要做实验或交叉编译的人员便捷取用。大多数人取用 Stage 2
`linux-loongarch64` 产物即可。只要您的 LoongArch64 Linux 发行版提供的
glibc 版本在 2.40 或更高，那么本 SDK 就应当能正常工作。

对于正常开发用途，仅需下载 `dotnet-sdk-*.tar.gz` 即可。其余内容主要用于开发
.NET SDK 本身，而非直面用户的应用。

希望自行搭建 .NET 更新源（例如适合用于 `dotnet-install.sh` 脚本的
`--azure-feed` 选项的下载服务）的开发者可基于所提供的 `sdk-feed-stage*.tar`
文件开展工作。

本服务提供的 .NET SDK 仅适用于 LoongArch 新世界（“ABI2.0”）。如您有
LoongArch 旧世界（“ABI1.0”）开发需求，请移步[龙芯公司 .NET 发布页面][loongnix-dotnet]。
您可阅读[《新世界与旧世界》一文][awly-old-and-new-worlds]获知更多关于LoongArch“新旧世界”情况的细节。

In the list of downloadable assets below, Stage 1 artifacts are those
with an RID of `linux-x64`, and are provided for your experimentation
or cross-compilation convenience. Most people will want the Stage 2
`linux-loongarch64` artifacts instead. The SDK should work on any LoongArch64
Linux distribution with glibc 2.40 or greater.

For normal development purposes, only downloading `dotnet-sdk-*.tar.gz`
would be enough. The others are mostly useful for development of .NET
SDK itself, not for user-facing applications.

Developers who wish to self-host their .NET update feed (for example a
download service suitable for the `--azure-feed` option of `dotnet-install.sh`)
can start from the `sdk-feed-stage*.tar` files provided.

The .NET SDKs provided by this service conforms to the LoongArch new
world ("ABI2.0") only. If you need to develop for the old world
("ABI1.0"), please consult [the Loongson .NET release page][loongnix-dotnet]
for details. You can read more about the LoongArch "old and new worlds"
situation in the [*The Old World and the New World*][awly-old-and-new-worlds]
essay (only available in Chinese for now).

[loongnix-dotnet]: http://www.loongnix.cn/zh/api/dotnet/
[awly-old-and-new-worlds]: https://areweloongyet.com/docs/old-and-new-worlds/
