# ForumFlow

> 一个面向多论坛场景的 Discourse 客户端：在一个应用里浏览、登录并切换不同社区。

[![Android Nightly](https://github.com/SinXXD/ForumFlow/actions/workflows/android-nightly.yaml/badge.svg)](https://github.com/SinXXD/ForumFlow/actions/workflows/android-nightly.yaml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![GitHub Releases](https://img.shields.io/github/v/release/SinXXD/ForumFlow?style=flat-square&logo=github)](https://github.com/SinXXD/ForumFlow/releases)

## 项目定位

ForumFlow 是一个基于 Flutter 的移动端和桌面端 Discourse 客户端，重点解决多论坛用户的日常切换问题：每个论坛拥有独立的登录态、Cookie、API key、CSRF 凭证和本地内容缓存，切换论坛不会覆盖其他论坛的数据。

当前预置论坛包括：

- [LinuxDO](https://linux.do/)
- [IDCFlare](https://idcflare.com/)
- [NodeLoc](https://www.nodeloc.com/)
- [小众软件](https://meta.appinn.net/)

ForumFlow 是论坛的第三方客户端，不代表上述论坛，也不属于 Discourse 官方客户端。

## 二次开发声明

本仓库是基于 [Lingyan000/fluxdo](https://github.com/Lingyan000/fluxdo) 的公开源代码进行的二次开发版本，当前维护仓库为 [SinXXD/ForumFlow](https://github.com/SinXXD/ForumFlow)。

在保留原项目主体能力的基础上，本版本主要进行了以下工作：

- 增加多论坛管理与无确认快速切换；
- 为不同论坛隔离登录状态、会话凭证、Cookie、草稿、书签和本地缓存；
- 支持游客模式浏览，并保留论坛级别的站点定制；

原项目的作者、贡献者和许可证义务仍然受到尊重。遇到与原始实现相关的问题时，也请优先参考[上游仓库](https://github.com/Lingyan000/fluxdo)的历史和文档。

## 主要功能

### 多论坛能力

- 设置页和个人主页提供论坛切换入口；
- 论坛切换无需确认，适合频繁切换；
- 每个论坛独立保存登录态和本地数据；
- 支持游客进入论坛，不要求先登录；
- 可探测并添加其他 Discourse 站点；
- 站点配置保存后可随时切回，不把自定义地址当作原论坛替换。

### 论坛功能

- 浏览话题、发帖、回复、搜索和通知；
- 书签、浏览历史、关注列表和徽章；
- Markdown 编辑与预览；
- 图片、音频和视频内容处理；
- 投票、聊天、分享图片和深色模式；
- Android、iOS、Windows、macOS、Linux 和 Web 支持。

### 工程能力

- Material Design 3 与动态主题；
- Rust DOH（DNS over HTTPS）代理；
- 图片缓存、懒加载和代码高亮；
- MessageBus 实时通知；
- HTML 分块渲染与 WebView 会话管理。

## 下载与构建

正式版本和预发布版本发布在 [GitHub Releases](https://github.com/SinXXD/ForumFlow/releases)。Android nightly workflow 位于 [GitHub Actions](https://github.com/SinXXD/ForumFlow/actions/workflows/android-nightly.yaml)，当前只发布 `arm64-v8a` APK。

### 环境要求

- Flutter SDK `^3.10.4`；
- Rust 工具链，用于编译 DOH 代理；
- Android Studio / Xcode，用于移动端开发；
- `melos` 和 `just`，用于 workspace 初始化及常用命令。

### 初始化

```bash
git clone https://github.com/SinXXD/ForumFlow.git
cd ForumFlow
melos bootstrap
just sync
```

也可以不安装全局 `just`，直接执行：

```bash
dart run tool/project_prep.dart app
dart run tool/flutterw.dart pub get
```

### Android arm64 构建

```bash
dart run tool/flutterw.dart build apk \
  --release \
  --target-platform android-arm64 \
  --dart-define=cronetHttpNoPlay=true \
  --split-debug-info=build/symbols
```

## 项目结构

```text
ForumFlow/
├── lib/
│   ├── config/       # ForumFlow 与多论坛配置
│   ├── models/       # 话题、用户、通知等模型
│   ├── modules/      # 功能模块
│   ├── pages/        # 页面
│   ├── providers/    # Riverpod 状态管理
│   ├── services/     # 业务服务与网络层
│   └── widgets/      # 可复用组件
├── core/doh_proxy/   # Rust DOH 代理
├── packages/         # 本地 workspace 依赖
├── scripts/          # 构建与开发脚本
└── pubspec.yaml
```

开发环境与日常命令见 [docs/development.md](docs/development.md)，发布说明见 [docs/release.md](docs/release.md)。

## 许可证与再发布

本项目继续使用原仓库的 **GNU General Public License v3.0（GPL-3.0）**，完整文本见 [`LICENSE`](LICENSE)。本二开版本没有在 GPL-3.0 之外增加额外的使用限制：在遵守 GPL-3.0 的前提下，可以自由使用、研究、修改、复制、再发布本项目，也可以用于商业用途。

本仓库中的第三方依赖、字体、图标和其他外部资源仍可能受各自许可证约束，应以其随附的许可证文件为准。ForumFlow、FluxDO、Linux.do 以及相关站点名称和标志的商标权归其各自权利人所有。

## 致谢与反馈

感谢 [Lingyan000/fluxdo](https://github.com/Lingyan000/fluxdo) 的原始实现，以及 Discourse 社区和所有贡献者提供的开源工作。

问题反馈和二开版本相关建议请提交到 [本仓库 Issues](https://github.com/SinXXD/ForumFlow/issues)。
