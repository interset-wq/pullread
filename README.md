<div align="center">

<img src="assets/icons/icon_book.png" width="128" alt="PullRead logo"/>

# PullRead 拉读

**克隆一次，常读常新。**

*Clone once. Read, pull, repeat.*

跨平台原生笔记仓库阅读器 · Android / iPadOS / Windows

[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iPadOS%20%7C%20Windows-4c8f56)](#-平台支持)
[![Flutter](https://img.shields.io/badge/Flutter-3.47%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Release](https://img.shields.io/github/v/release/interset-wq/pullread?include_prereleases&sort=semver&label=release&color=f5b301)](https://github.com/interset-wq/pullread/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

PullRead 把任意公开 Git 笔记仓库克隆到设备，用原生界面阅读 Markdown、Jupyter
Notebook 和代码。没有后端、没有构建步骤、没有托管服务；仓库是唯一数据源，
`pull` 一下，内容继续生长，阅读体验不变。

移动端是当前开发与发布的核心；同一套代码同时维护 Windows 桌面端，并提供
iPadOS / iOS 的源码构建路径。

## 🔁 核心工作流

```text
clone ──▶ read ──▶ pull ──▶ read ──▶ pull ──▶ …
```

- **clone**：把一个完整仓库放到本机，目录结构原样保留。
- **read**：离线阅读，渲染、搜索、书签、进度、图片导出都在本地完成。
- **pull**：只拉取增量提交，新文件/更新文件在列表中打标。
- **repeat**：仓库继续更新，阅读进度与收藏继续有效。

这是 PullRead 和「把文章复制到阅读器」的区别：你维护的仍然是 Git 仓库，
PullRead 只是给它一个舒服的阅读界面。

| | 传统在线阅读 | PullRead |
| --- | --- | --- |
| 内容组织 | 复制、导出、再排版 | 仓库原目录结构，不扁平化 |
| 更新方式 | 手动搬运 | `pull` 增量更新，更新有标记 |
| 网络依赖 | 每次打开都要联网 | 克隆后离线可读 |
| 数据归属 | 平台账号 | 仓库与 `.meta` 都在本机 |
| 阅读体验 | 通用网页排版 | Markdown / ipynb / 代码原生渲染 |

## 💻 平台支持

| 平台 | 状态 | 获取方式 |
| --- | --- | --- |
| **Android** | 主要发布平台，已提供 arm64 APK | [GitHub Releases](https://github.com/interset-wq/pullread/releases) |
| **iPadOS / iOS** | 同一代码库，源码构建；iPad 大屏适配与真机验收进行中 | 在 macOS + Xcode 上 `flutter build ios`（暂无签名安装包） |
| **Windows** | 次级桌面目标，源码构建；桌面目录选择、键盘/鼠标操作可用 | 在 Windows + Visual Studio 上 `flutter build windows` |
| **Linux / macOS** | 尚未接入平台目录与构建流程 | 欢迎贡献 |

> 每个设备的克隆副本、阅读进度和收藏都保存在本机（`<应用文档目录>/repos` 与
> `.meta/`），**不提供跨设备同步**。同一仓库可以在多台设备分别 clone。

## ✨ 功能特性

### 📄 Markdown / GFM 渲染
- **GFM 告警框**：`> [!NOTE]` / `[!TIP]` / `[!IMPORTANT]` / `[!WARNING]` / `[!CAUTION]` 渲染为彩色提示卡
- **表格**：平铺（按内容自然宽度横向滚动）与换行（限两倍屏宽均分列宽）双档，每个表格右上角独立切换
- **折叠块**：`<details>/<summary>` 渲染为可点击卡片，内部代码块/表格/列表正常渲染，`open` 属性生效
- **代码高亮**：190+ 种语言，一键复制、行号、长代码自动折叠
- **Mermaid 图表**：流程图、时序图、类图、状态图、ER 图、甘特图、饼图、gitgraph、思维导图、时间线、桑基图等原生渲染；超宽自动缩放，点按进全屏缩放查看，长按可保存为 PNG 或分享
- **数学公式**：KaTeX 行内 `$...$` 与块级 `$$...$$`，金额（`$100`）等场景不误判
- **Jupyter Notebook**：`.ipynb` 直接转 Markdown 渲染
- **HTML 兼容**：内联/块级 HTML 标签自动转换；未知标签保持惰性文本，不执行脚本
- **SVG 图片**：本地与网络 SVG 按 viewBox 等比渲染，保存到相册或分享时自动栅格化为 PNG

### 📡 克隆、分支与同步
- 只依赖仓库完整 URL：GitHub / Gitee / GitCode / GitLab 与自建 Gitea 等公开仓库都能加；平台枚举只用于来源展示和短地址拼接，不调用任何平台 REST API
- 整仓克隆；启动时可选择后台自动拉取（默认关闭），仓库页支持下拉刷新与按钮同步
- 克隆有对象数/体积进度且可取消；取消或超时会清理半成品目录，重试不会撞上「目录已存在」
- **切换分支**：仓库页「更多 → 切换分支」列出本地 `origin/*` 引用，离线可用；本地分支缺失时自动创建并设置 upstream。只读检出，不做 commit/push；阅读进度和收藏按路径保留
- **同步可感知**：仓库卡显示上次同步时间；「检查远端更新」先告知落后提交数；拉取后新增/更新的文件打角标，打开即清除
- **更新收件箱**：把所有仓库与本地镜像的未读更新聚到一页，按来源分组，可逐条读或一键全部已读
- 仓库页文件行显示阅读状态（读到 N% / 已读完），工具栏可「仅看未读」
- 远端改写历史导致无法 fast-forward 时提示重新克隆，不覆盖本地阅读进度与收藏
- 只读定位：不含任何仓库编辑 / commit / push 功能；当前仅支持公开仓库

### 🗂 目录浏览
- 按原目录结构浏览（目录树不扁平化），支持逐级进入与快速回根
- 文件列表可按名称或最近修改排序
- 非 Markdown 文件用语法高亮只读查看，代码行号同步滚动、右侧贴边滚动条
- 代码查看支持**大纲跳转**（class/function 等符号）、文内查找与自动换行

### 📁 本地文件夹
- 不经过 git 也能读：Android 使用 SAF 授权任意文件夹（一次授权持久生效），桌面端直接选择目录
- 授权后**增量镜像**到应用私有目录，复用与仓库相同的浏览、渲染、搜索、进度和导出管线
- 支持 md / ipynb / 代码 / 图片；`.txt` 自动识别 UTF-8 与 GBK 编码
- 本地 Markdown 可直接编辑：源码 + 预览切换、手动保存、未保存离开提醒；保存时同时写回镜像与原文件夹
- 写回失败会记账并在下次同步时自动重试（「设置 → 存储与数据 → 未写回的修改」可查看/重试/强制覆盖），不会用旧源文件覆盖新编辑
- 边界不变：不做 git 提交；仓库内文件只读，只有本地文件夹可以写回

### 🔍 检索
- **仓库内搜索**：文件名 / 正文双模式；正文按文件分组，显示命中次数与上下文高亮摘要
- 多词查询按 **AND** 匹配；路径命中优先；搜索的是阅读页真正渲染的正文（剥离 front matter、归一化 HTML 图片）
- **跨仓库搜索**：一次检索所有仓库与本地来源，结果分组展示；支持搜索历史（最多 12 条）、来源多选、「正文 / 仅标题」模式
- **标签**：聚合各来源 front-matter 的 `tags`，多标签按 AND 跨仓库筛选；可开启「目录名隐式标签」
- **断链检查**：列出失效的相对链接/图片，并可复制清单

### 🧭 阅读体验
- 文章目录（TOC）浮动按钮 + 回顶/回底按钮
- 文首面包屑：`仓库 / 目录 / 子目录` 逐级可点
- 底部常驻翻页条；文末另有「上级目录 / 仓库首页」按钮
- 阅读进度按文件保存并自动恢复；「从头读」一键撤销
- 搜索结果直达：从正文搜索点进文章会自动打开查找条并定位到第一处命中
- 文内查找：命中计数 + 上一处/下一处，按所属章节定位
- 段落书签：阅读页菜单添加，首页横滑条与书签页可跨仓库直达
- 收藏文章 / 最近阅读 / 继续阅读：首页聚合展示，点击直达
- 图片操作：长按正文图片或图库菜单保存到相册、分享、复制地址；网络图优先复用磁盘缓存
- 屏幕常亮：设置内开关，阅读页内生效，离开自动释放

### 🎨 外观与设置
- 深色模式：跟随系统 + 手动切换
- 代码字体可选（JetBrains Mono / Consolas），默认关闭连字
- Android 桌面图标五选一（应用内切换）
- 阅读排版可调：正文行距、页边距、字号五档
- 两级设置页；滑杆松手才写盘；设置行与首页、书签、标签等页面使用同一套扁平列表样式；危险操作独立分组并二次确认

### 💾 数据与存储
- 远程图片磁盘缓存：命中即出图（离线可读），总量上限 200MB 按最久未用淘汰；超 7 天后台用 ETag / Last-Modified 条件请求静默刷新
- 存储占用页：分别统计仓库 / 本地镜像 / 图片缓存 / 元数据体积，图片缓存可一键清理
- 阅读进度、收藏、最近阅读、更新标记存放在仓库旁的 `.meta/` 目录，不污染仓库内容，pull 不会触碰

## 📸 截图预览

| | |
|---|---|
| ![首页](docs/screenshots/01_home.png) | ![目录树](docs/screenshots/02_tree.png) |
| *首页：最近阅读、收藏与仓库管理* | *目录树：按原结构浏览* |
| ![阅读页](docs/screenshots/03_reading.png) | ![折叠块](docs/screenshots/04_details.png) |
| *阅读页：表格与 TOC* | *折叠块：点击展开答案* |
| ![Mermaid 流程图](docs/screenshots/06_mermaid_flowchart.png) | ![Mermaid 时序图](docs/screenshots/07_mermaid_sequence.png) |
| *Mermaid 流程图* | *Mermaid 时序图* |

## 📥 下载与安装

### Android（主要发布形态）

前往 [Releases](https://github.com/interset-wq/pullread/releases) 下载
`app-arm64-v8a-release.apk`（arm64-v8a，约 32 MB，覆盖主流机型）。
带 `-rc*` 后缀的版本是预发布版，表示尚未完成真机验收；稳定版没有后缀。

官方 APK 与本地构建使用不同签名；本地安装出现
`INSTALL_FAILED_UPDATE_INCOMPATIBLE` 时，先卸载旧包或使用临时
`applicationIdSuffix`，不要提交签名改动。

### iPadOS / iOS（源码构建）

需要 macOS、Xcode 与 CocoaPods：

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release
```

当前没有 App Store 或 TestFlight 签名包；iPad 大屏布局、分屏和手势仍属于
真机验收项。Bundle id 为 `com.intersetwq.pullread`。

### Windows（桌面端源码构建）

需要 Windows 10/11、Visual Studio 2022（Desktop development with C++）、
Flutter SDK：

```powershell
flutter pub get
flutter build windows --release
```

产物在 `build\windows\x64\runner\Release\`。桌面端复用移动端的阅读管线，
支持本地目录选择、键鼠滚动和窗口缩放；键盘快捷键、多窗口等桌面原生体验仍在完善。
Linux / macOS 尚未配置平台目录。

## 🚀 从源码运行

```bash
git clone https://github.com/interset-wq/pullread.git
cd pullread
flutter pub get

flutter run                  # 连接设备/模拟器后运行
flutter analyze --fatal-infos
flutter test

# Android release APK（仅 arm64）
flutter build apk --split-per-abi --target-platform android-arm64

# Windows release（在 Windows 主机上执行）
flutter build windows --release
```

- Android 真机/模拟器：`flutter devices` 查看设备 id，必要时 `flutter run -d <id>`。
- x86_64 模拟器装不了 arm64 release APK，请使用 debug 构建。
- 测试只触碰临时目录或 mock 的 `PathProvider`，不会读写真实用户数据目录。

## 🧱 技术架构

- **框架**：Flutter / Dart 3（Flutter 3.47+）；Android 与 iOS/iPadOS 为主要目标，
  Windows 为次级桌面目标，共享同一套 UI 与业务代码。
- **git 层**：libgit2 FFI（`git2dart`），只使用 clone / fetch / pull / checkout 等只读能力；
  Git 操作在后台 isolate 执行，原生错误在跨 isolate 前转成普通异常。
- **渲染**：`markdown_widget` + `flutter_math_fork`（KaTeX）+ `mermaid_flutter`
  （纯 Dart 绘制，不依赖 WebView）。
- **本地能力**：`saf`（Android SAF）、`file_selector`（桌面目录选择）、
  `path_provider`、`shared_preferences`、`gal` / `share_plus`（图片保存与分享）。
- **存储**：偏好设置走 `shared_preferences`；阅读进度、收藏、最近阅读和更新标记
  以 JSON 存于仓库旁 `.meta/`，无数据库、无后端。

```text
lib/
├── main.dart               # 入口（libgit2 / CA 初始化顺序见 AGENTS.md）
└── src/
    ├── git/                # clone / pull / 分支切换、仓库元数据（.meta/）
    ├── platforms/          # 平台识别与仓库来源展示
    ├── notes/              # 扫描、TOC、GFM、ipynb、数学、Mermaid、标签、断链
    ├── local/              # SAF / 桌面目录授权、增量镜像、写回待办
    ├── search/             # 仓库内与跨仓库正文检索
    ├── ui/                 # 首页、仓库页、阅读页、编辑器、代码查看、设置
    ├── theme/              # 主题与 AppPrefs
    └── utils/              # 排序、文本编码、目录体积等
```

## 🧭 设计约束

- **本地优先**：没有账号系统、没有服务端，仓库和元数据都在设备上。
- **仓库只读**：clone / pull / 切换分支可以，commit / push / 改写历史永远不做。
- **渲染优先**：长文档懒布局，表格/公式/Mermaid/代码块不能比博客更差。
- **内容不执行**：未知 HTML/JSX 只作为文本展示，Notebook 图片不写回 Markdown 源码。
- **每台设备独立**：不做跨设备同步；换设备是重新 clone，而不是「续读接力」。

## 🗺 路线图

- [x] 仓库切换分支（只读 checkout，保留进度/收藏）
- [x] Mermaid 图表导出为 PNG
- [x] 设置页信息架构与全站视觉统一
- [ ] iPad 大屏阅读布局、分屏与手势验收
- [ ] Windows 桌面打包与键鼠体验完善
- [ ] Linux / macOS 平台接入（待评估）
- [ ] 文内查找按章节精确滚动、UTF-16 文本支持

明确不做：私有仓库鉴权、协作、双链/图谱、TTS、PDF、阅读统计、静态站点生成、
平台 REST API 依赖。

## 📚 文档与协作

| 文档 | 内容 |
| --- | --- |
| [`AGENTS.md`](AGENTS.md) | 工程契约、红线规则、开发与发布流程 |
| [`PLAN.md`](PLAN.md) | 当前优先级、文件占用与真机验收清单 |
| [`docs/git-sync.md`](docs/git-sync.md) | Git 层、路径安全、分支切换 |
| [`docs/rendering.md`](docs/rendering.md) | Markdown / Notebook / 数学 / Mermaid / 代码查看 |
| [`docs/reading.md`](docs/reading.md) | 阅读流程、搜索、索引、标签、存储、设置 |
| [`docs/local-folders.md`](docs/local-folders.md) | SAF、桌面目录、增量镜像与写回 |
| [`docs/platform.md`](docs/platform.md) | 平台适配、启动链、图标与 Android 构建 |
| [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) | 第三方依赖与原生组件许可证清单 |

参与开发前请先读 `AGENTS.md` 和 `PLAN.md`；`main` 只接受 PR 或维护者 merge
commit，分支请从最新 `origin/main` 拉出并保持单一主题。

## 📦 发布流程

1. 更新 `pubspec.yaml` 的 `version`（例如 `1.12.0-rc5+25`）。
2. 提交后打同名 tag（`v1.12.0-rc5`）并推送。
3. GitHub Actions 校验 tag 与 pubspec 版本一致，构建 arm64 APK 并创建 Release。
4. 带 SemVer 预发布后缀的 tag 会标记为 prerelease；稳定版没有后缀。

官方 Release 目前只包含 Android APK；iOS/iPadOS 与 Windows 由源码构建，
不提供手动上传的二进制，避免与 tag 源码不一致。

## 📄 许可证

PullRead 本体以 [MIT](LICENSE) 发布，Copyright © 2026 interset-wq。

项目使用大量第三方依赖，完整清单见
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)：

- **pub 依赖**：124 个 direct / transitive 包，以 BSD-3-Clause、MIT、Apache-2.0
  为主，另有 1 个 BSD-2-Clause（`tuple`）和 1 个 MPL-2.0（`dbus`，桌面插件依赖）。
- **libgit2**：通过 `git2dart_binaries` 打包，采用 GPL-2.0 + linking exception；
  PullRead 不修改其源码，例外条款允许与 MIT 应用组合分发，全文见
  [`LICENSES/libgit2-COPYING.txt`](LICENSES/libgit2-COPYING.txt)。
- **JetBrains Mono**：SIL OFL-1.1，全文见
  [`LICENSES/JetBrainsMono-OFL.txt`](LICENSES/JetBrainsMono-OFL.txt)。
- **Flutter / Dart SDK、Material Icons**：BSD-3-Clause / Apache-2.0。

应用内「设置 → 关于 PullRead → 开源许可证」可直接查看所有包的许可证原文
（Flutter 构建时生成的 `NOTICES`，外加手动注册的 libgit2 与字体许可证）。
第三方组件保留各自版权与许可证；MIT 只覆盖 PullRead 自己的代码与设计资源。
