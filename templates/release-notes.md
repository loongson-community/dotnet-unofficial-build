## 平台兼容性说明 / Notes on platform compatibility

本服务提供的 .NET SDK 仅适用于 LoongArch 新世界（“ABI2.0”）。如您有 LoongArch 旧世界（“ABI1.0”）开发需求，请移步[龙芯公司 .NET 发布页面][loongnix-dotnet]。您可阅读[《新世界与旧世界》一文][awly-old-and-new-worlds]获知更多关于LoongArch“新旧世界”情况的细节。

.NET SDK 的个别组件是以 C/C++ 写作的，架构相关的二进制。我们采用 **LoongArch64 v1.00** 作为 LoongArch 的二进制兼容基准，遵循[《LoongArch 软件开发与构建约定》v0.1][la-softdev-convention]（目前仅提供英文版）。这意味着本服务提供的 .NET SDK 可以兼容所有支持 LSX 的 LoongArch 硬件、操作系统组合。

> [!NOTE]
> 这同时也意味着**本 SDK 无法在不提供 LSX 的平台上工作**，主要涉及那些龙芯等厂商将其归属于“嵌入式”或“工控”场景的型号，包括但不限于龙芯 1 系、2K1000LA、2K0500、2K0300 等。
>
> 如您有需要在这些平台上使用本 SDK，请在[工单系统][issue-tracker]上表明需求，但我们不一定有能力在短期内支持。

The .NET SDKs provided by this service conforms to the LoongArch new world ("ABI2.0") only. If you need to develop for the old world ("ABI1.0"), please consult [the Loongson .NET release page][loongnix-dotnet] for details. You can read more about the LoongArch "old and new worlds" situation in the [*The Old World and the New World*][awly-old-and-new-worlds] essay (only available in Chinese for now).

Some components of .NET SDK are written in C/C++ and architecture-dependent. We adopt **LoongArch64 v1.00** as the baseline of binary compatibility for LoongArch, and follow the [*Software Development and Build Convention for LoongArch™ Architectures* v0.1][la-softdev-convention]. This means the .NET SDKs provided by this service are compatible with any hardware and OS combination that supports LSX.

> [!NOTE]
> This also means *our SDKs will not work on platforms without LSX*, that mainly involve models deemed for "embedded" or "industrial controls" use cases by Loongson and other vendors, including but not limited to the Loongson 1 series, 2K1000LA, 2K0500, and 2K0300.
>
> If you need to deploy our SDKs on such platforms, please post on [the issue tracker][issue-tracker], although we may not be able to implement such support in the short term.

[loongnix-dotnet]: http://www.loongnix.cn/zh/api/dotnet/
[awly-old-and-new-worlds]: https://areweloongyet.com/docs/old-and-new-worlds/
[la-softdev-convention]: https://github.com/loongson/la-softdev-convention/blob/v0.1/la-softdev-convention.adoc
[issue-tracker]: https://github.com/loongson-community/dotnet-unofficial-build/issues

## 内容介绍 / Contents

### RID `linux-loongarch64`

这些构建产物适用于以 **glibc** 为 C 运行时库的 LoongArch64 Linux 发行版，也就是大多数发行版。所需的最低 glibc 版本为 **2.40**。

These artifacts are suitable for use on LoongArch64 Linux distributions with **glibc** as the C runtime library, which include most distributions out there. A minimum glibc version of **2.40** is needed.

| 二进制包 / Binaries | 校验和 / Checksums |
|---|---|
$rid_linux_loongarch64

### RID `linux-musl-loongarch64`

这些构建产物适用于以 **musl** 为 C 运行时库的 LoongArch64 Linux 发行版，如 Alpine Linux 等。所需的最低 musl 版本为 **1.2.5**。

These artifacts are suitable for use on LoongArch64 Linux distributions with **musl** as the C runtime library, such as Alpine Linux. A minimum musl version of **1.2.5** is needed.

> [!NOTE]
> 在运行时，还需要一些额外依赖。以 Alpine Linux 的包名列举如下，至少需要这些：
>
> Additional dependencies are needed at runtime. At least the below are needed, in terms of Alpine Linux package names:
>
> * `libgcc`
> * `libstdc++`
> * `icu-libs`

| 二进制包 / Binaries | 校验和 / Checksums |
|---|---|
$rid_linux_musl_loongarch64

### RID `linux-x64`

这是适用于 x86\_64 Linux 系统的“第一阶段”（Stage 1）构建产物，与官方出品的区别在于包含了支持 LoongArch 平台所需的额外改动。可供需要在 x86\_64 系统上做实验或交叉编译的人员便捷取用。

These artifacts are "Stage 1" builds for x86\_64 Linux systems, different from the official product in that extra changes for LoongArch support are integrated. These are suitable for your experimentation or cross-compilation convenience on x86\_64 systems.

| 二进制包 / Binaries | 校验和 / Checksums |
|---|---|
$rid_linux_x64

### 其他：面向开发者与镜像源管理员 / Others: for developers and mirror admins

对于常规用途，仅需下载 `dotnet-sdk-*.tar.gz` 即可。

形如 `Private.SourceBuilt.Artifacts.*` 的压缩包，用于从源码构建 .NET SDK 本身，就像本项目所做的一样。如果您是 .NET 贡献者，您应该就已经明白如何利用它们了。

希望自行搭建 .NET 更新源（例如适合用于 `dotnet-install.sh` 脚本的 `--azure-feed` 选项的下载服务）的开发者，可基于所提供的 `sdk-feed-stage*.tar` 文件开展工作。

For general usage, only downloading `dotnet-sdk-*.tar.gz` would be enough.

The `Private.SourceBuilt.Artifacts.*` archives are used to build .NET SDK itself from source, just like this project does. You should already know how to make use of these if you are a .NET contributor.

Developers who wish to self-host their .NET update feed (for example a download service suitable for the `--azure-feed` option of `dotnet-install.sh`) can start from the `sdk-feed-stage*.tar` files provided.

| 二进制包 / Binaries | 校验和 / Checksums |
|---|---|
$misc
