# 第三方许可证与归属声明

PullRead 本体以 [MIT](../LICENSE) 发布。本文件列出随应用一起分发或参与构建的
第三方组件及其许可证，便于分发、审计和二次开发。

> 本清单由 `pubspec.lock` 生成（Flutter 3.47 / Dart 3）。升级依赖后请同步更新：
> 新增、删除或更换许可证的包必须反映在这里。
> 应用内「设置 → 关于 PullRead → 开源许可证」会显示 Flutter 自动收集的完整
> 许可证原文；本文件是仓库内的可审计清单。

## 1. 运行时直接依赖

| 包 | 版本 | 许可证 | 用途 |
| --- | --- | --- | --- |
| [`git2dart`](https://pub.dev/packages/git2dart) | 0.5.6 | MIT | libgit2 的 Dart FFI 绑定（clone / fetch / pull / checkout） |
| [`git2dart_binaries`](https://pub.dev/packages/git2dart_binaries) | 1.14.0 | MIT | 各平台 libgit2 二进制与 CA 证书初始化 |
| [`flutter_math_fork`](https://pub.dev/packages/flutter_math_fork) | 0.7.4 | Apache-2.0 | KaTeX 数学公式渲染 |
| [`markdown`](https://pub.dev/packages/markdown) | 7.3.1 | BSD-3-Clause | Markdown 解析 |
| [`markdown_widget`](https://pub.dev/packages/markdown_widget) | 2.3.2+8 | MIT | Markdown 组件渲染 |
| [`mermaid_flutter`](https://pub.dev/packages/mermaid_flutter) | 0.3.2 | MIT | Mermaid 图表（纯 Dart 绘制） |
| [`flutter_highlight`](https://pub.dev/packages/flutter_highlight) | 0.7.0 | MIT | highlight.js 代码高亮绑定 |
| [`flutter_svg`](https://pub.dev/packages/flutter_svg) | 2.3.2 | MIT | SVG 图片渲染 |
| [`archive`](https://pub.dev/packages/archive) | 4.5.2 | MIT | 压缩包/归档处理 |
| [`fast_gbk`](https://pub.dev/packages/fast_gbk) | 1.0.0 | BSD-3-Clause | GBK 文本解码 |
| [`http`](https://pub.dev/packages/http) | 1.6.0 | BSD-3-Clause | 图片缓存与条件请求 |
| [`path_provider`](https://pub.dev/packages/path_provider) | 2.1.6 | BSD-3-Clause | 应用文档/缓存目录 |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | 2.3.2 | BSD-3-Clause | 轻量偏好存储 |
| [`shared_preferences_android`](https://pub.dev/packages/shared_preferences_android) | 2.3.2 | BSD-3-Clause | Android 偏好实现 |
| [`saf`](https://pub.dev/packages/saf) | 2.1.2 | MIT | Android SAF 目录授权 |
| [`file_selector`](https://pub.dev/packages/file_selector) | 1.1.0 | BSD-3-Clause | 桌面端目录选择 |
| [`share_plus`](https://pub.dev/packages/share_plus) | 13.3.1 | BSD-3-Clause | 图片/文件分享 |
| [`gal`](https://pub.dev/packages/gal) | 2.3.3 | BSD-3-Clause | 保存图片到相册 |
| [`url_launcher`](https://pub.dev/packages/url_launcher) | 6.3.3 | BSD-3-Clause | 打开外部链接 |
| [`wakelock_plus`](https://pub.dev/packages/wakelock_plus) | 1.8.2 | BSD-3-Clause | 阅读时屏幕常亮 |
| [`scroll_to_index`](https://pub.dev/packages/scroll_to_index) | 3.0.1 | MIT | 长文档定位滚动 |

## 2. 随应用打包的原生组件与资源

| 组件 | 版本/来源 | 许可证 | 说明 |
| --- | --- | --- | --- |
| Flutter SDK / Dart SDK | Flutter 3.47+ | BSD-3-Clause | 应用框架与引擎，构建产物内附 NOTICES |
| libgit2 | 由 `git2dart_binaries` 1.14.0 提供 | GPL-2.0 **with linking exception** | 本地 Git 实现；例外条款允许与 PullRead 组合分发。全文见 [`LICENSES/libgit2-COPYING.txt`](../LICENSES/libgit2-COPYING.txt)，源码：<https://github.com/libgit2/libgit2> |
| CA 证书包 | `git2dart_binaries` 内置 `cacert.pem`（源自 curl / Mozilla） | MPL-2.0 | 仅用于 HTTPS 证书校验；未修改 |
| JetBrains Mono | 2.211 | SIL OFL-1.1 | 代码字体；全文见 [`LICENSES/JetBrainsMono-OFL.txt`](../LICENSES/JetBrainsMono-OFL.txt) |
| Material Icons | Flutter 内置 | Apache-2.0 | 界面图标 |
| 应用图标与 Logo | 本项目 | MIT | `assets/icons/`、`assets/icon/`、`design/icons/` |

### 关于 libgit2 的 GPL 例外

libgit2 采用 GPL-2.0 + linking exception：把**未修改的** libgit2 链接进其他程序
并分发时，不要求该程序整体按 GPL 授权。PullRead 不修改 libgit2 源码，只通过
`git2dart_binaries` 使用其预编译产物；若替换或修改 libgit2，必须继续遵守 GPL-2.0。

## 3. 完整依赖清单

下表包含 `pubspec.lock` 中全部 124 个 hosted 包（不含 Flutter/Dart SDK 自带包）。
「传递」表示由直接依赖间接引入，实际同样随应用打包；「开发」仅用于构建、图标生成
和测试，不进入应用包。

| 包 | 版本 | 许可证 | 使用 |
| --- | --- | --- | --- |
| [`archive`](https://pub.dev/packages/archive) | 4.5.2 | MIT | 运行时 |
| [`fast_gbk`](https://pub.dev/packages/fast_gbk) | 1.0.0 | BSD-3-Clause | 运行时 |
| [`file_selector`](https://pub.dev/packages/file_selector) | 1.1.0 | BSD-3-Clause | 运行时 |
| [`flutter_highlight`](https://pub.dev/packages/flutter_highlight) | 0.7.0 | MIT | 运行时 |
| [`flutter_math_fork`](https://pub.dev/packages/flutter_math_fork) | 0.7.4 | Apache-2.0 | 运行时 |
| [`flutter_svg`](https://pub.dev/packages/flutter_svg) | 2.3.2 | MIT | 运行时 |
| [`gal`](https://pub.dev/packages/gal) | 2.3.3 | BSD-3-Clause | 运行时 |
| [`git2dart`](https://pub.dev/packages/git2dart) | 0.5.6 | MIT | 运行时 |
| [`git2dart_binaries`](https://pub.dev/packages/git2dart_binaries) | 1.14.0 | MIT | 运行时 |
| [`http`](https://pub.dev/packages/http) | 1.6.0 | BSD-3-Clause | 运行时 |
| [`markdown`](https://pub.dev/packages/markdown) | 7.3.1 | BSD-3-Clause | 运行时 |
| [`markdown_widget`](https://pub.dev/packages/markdown_widget) | 2.3.2+8 | MIT | 运行时 |
| [`mermaid_flutter`](https://pub.dev/packages/mermaid_flutter) | 0.3.2 | MIT | 运行时 |
| [`path_provider`](https://pub.dev/packages/path_provider) | 2.1.6 | BSD-3-Clause | 运行时 |
| [`saf`](https://pub.dev/packages/saf) | 2.1.2 | MIT | 运行时 |
| [`scroll_to_index`](https://pub.dev/packages/scroll_to_index) | 3.0.1 | MIT | 运行时 |
| [`share_plus`](https://pub.dev/packages/share_plus) | 13.3.1 | BSD-3-Clause | 运行时 |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | 2.3.2 | BSD-3-Clause | 运行时 |
| [`shared_preferences_android`](https://pub.dev/packages/shared_preferences_android) | 2.3.2 | BSD-3-Clause | 运行时 |
| [`url_launcher`](https://pub.dev/packages/url_launcher) | 6.3.3 | BSD-3-Clause | 运行时 |
| [`wakelock_plus`](https://pub.dev/packages/wakelock_plus) | 1.8.2 | BSD-3-Clause | 运行时 |
| [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) | 0.14.4 | MIT | 开发 |
| [`flutter_lints`](https://pub.dev/packages/flutter_lints) | 6.0.0 | BSD-3-Clause | 开发 |
| [`path_provider_platform_interface`](https://pub.dev/packages/path_provider_platform_interface) | 2.1.3 | BSD-3-Clause | 开发 |
| [`plugin_platform_interface`](https://pub.dev/packages/plugin_platform_interface) | 2.1.8 | BSD-3-Clause | 开发 |
| [`args`](https://pub.dev/packages/args) | 2.7.0 | BSD-3-Clause | 传递 |
| [`async`](https://pub.dev/packages/async) | 2.13.1 | BSD-3-Clause | 传递 |
| [`boolean_selector`](https://pub.dev/packages/boolean_selector) | 2.1.2 | BSD-3-Clause | 传递 |
| [`characters`](https://pub.dev/packages/characters) | 1.4.1 | BSD-3-Clause | 传递 |
| [`checked_yaml`](https://pub.dev/packages/checked_yaml) | 2.0.4 | BSD-3-Clause | 传递 |
| [`cli_util`](https://pub.dev/packages/cli_util) | 0.4.2 | BSD-3-Clause | 传递 |
| [`clock`](https://pub.dev/packages/clock) | 1.1.3 | Apache-2.0 | 传递 |
| [`code_assets`](https://pub.dev/packages/code_assets) | 2.1.0 | BSD-3-Clause | 传递 |
| [`collection`](https://pub.dev/packages/collection) | 1.19.1 | BSD-3-Clause | 传递 |
| [`cross_file`](https://pub.dev/packages/cross_file) | 0.3.5+5 | BSD-3-Clause | 传递 |
| [`crypto`](https://pub.dev/packages/crypto) | 3.0.8 | BSD-3-Clause | 传递 |
| [`dbus`](https://pub.dev/packages/dbus) | 0.8.0 | MPL-2.0 | 传递 |
| [`elk`](https://pub.dev/packages/elk) | 0.2.1 | MIT | 传递 |
| [`equatable`](https://pub.dev/packages/equatable) | 2.1.0 | MIT | 传递 |
| [`fake_async`](https://pub.dev/packages/fake_async) | 1.3.3 | Apache-2.0 | 传递 |
| [`ffi`](https://pub.dev/packages/ffi) | 2.2.0 | BSD-3-Clause | 传递 |
| [`ffi_leak_tracker`](https://pub.dev/packages/ffi_leak_tracker) | 0.1.2 | BSD-3-Clause | 传递 |
| [`file`](https://pub.dev/packages/file) | 7.0.1 | BSD-3-Clause | 传递 |
| [`file_selector_android`](https://pub.dev/packages/file_selector_android) | 0.5.2+11 | BSD-3-Clause | 传递 |
| [`file_selector_ios`](https://pub.dev/packages/file_selector_ios) | 0.5.3+7 | BSD-3-Clause | 传递 |
| [`file_selector_linux`](https://pub.dev/packages/file_selector_linux) | 0.9.4+1 | BSD-3-Clause | 传递 |
| [`file_selector_macos`](https://pub.dev/packages/file_selector_macos) | 0.9.5+2 | BSD-3-Clause | 传递 |
| [`file_selector_platform_interface`](https://pub.dev/packages/file_selector_platform_interface) | 2.7.0 | BSD-3-Clause | 传递 |
| [`file_selector_web`](https://pub.dev/packages/file_selector_web) | 0.9.5 | BSD-3-Clause | 传递 |
| [`file_selector_windows`](https://pub.dev/packages/file_selector_windows) | 0.9.3+6 | BSD-3-Clause | 传递 |
| [`fixnum`](https://pub.dev/packages/fixnum) | 1.1.1 | BSD-3-Clause | 传递 |
| [`highlight`](https://pub.dev/packages/highlight) | 0.7.0 | MIT | 传递 |
| [`hooks`](https://pub.dev/packages/hooks) | 2.2.0 | BSD-3-Clause | 传递 |
| [`http_parser`](https://pub.dev/packages/http_parser) | 4.1.2 | BSD-3-Clause | 传递 |
| [`image`](https://pub.dev/packages/image) | 4.12.0 | MIT | 传递 |
| [`jni`](https://pub.dev/packages/jni) | 1.1.1 | BSD-3-Clause | 传递 |
| [`jni_flutter`](https://pub.dev/packages/jni_flutter) | 1.0.4+1 | BSD-3-Clause | 传递 |
| [`jni_util`](https://pub.dev/packages/jni_util) | 1.0.0 | BSD-3-Clause | 传递 |
| [`json_annotation`](https://pub.dev/packages/json_annotation) | 4.12.0 | BSD-3-Clause | 传递 |
| [`katex_dart`](https://pub.dev/packages/katex_dart) | 0.1.1 | MIT | 传递 |
| [`leak_tracker`](https://pub.dev/packages/leak_tracker) | 11.0.2 | BSD-3-Clause | 传递 |
| [`leak_tracker_flutter_testing`](https://pub.dev/packages/leak_tracker_flutter_testing) | 3.0.10 | BSD-3-Clause | 传递 |
| [`leak_tracker_testing`](https://pub.dev/packages/leak_tracker_testing) | 3.0.2 | BSD-3-Clause | 传递 |
| [`lints`](https://pub.dev/packages/lints) | 6.1.0 | BSD-3-Clause | 传递 |
| [`logging`](https://pub.dev/packages/logging) | 1.3.0 | BSD-3-Clause | 传递 |
| [`matcher`](https://pub.dev/packages/matcher) | 0.12.20 | BSD-3-Clause | 传递 |
| [`material_color_utilities`](https://pub.dev/packages/material_color_utilities) | 0.13.0 | Apache-2.0 | 传递 |
| [`mermaid_core`](https://pub.dev/packages/mermaid_core) | 0.3.2 | MIT | 传递 |
| [`meta`](https://pub.dev/packages/meta) | 1.19.0 | BSD-3-Clause | 传递 |
| [`mime`](https://pub.dev/packages/mime) | 2.1.0 | BSD-3-Clause | 传递 |
| [`nested`](https://pub.dev/packages/nested) | 1.0.0 | MIT | 传递 |
| [`objective_c`](https://pub.dev/packages/objective_c) | 9.6.2 | BSD-3-Clause | 传递 |
| [`package_config`](https://pub.dev/packages/package_config) | 3.0.0 | BSD-3-Clause | 传递 |
| [`package_info_plus`](https://pub.dev/packages/package_info_plus) | 10.2.2 | BSD-3-Clause | 传递 |
| [`package_info_plus_platform_interface`](https://pub.dev/packages/package_info_plus_platform_interface) | 4.1.0 | BSD-3-Clause | 传递 |
| [`path`](https://pub.dev/packages/path) | 1.9.1 | BSD-3-Clause | 传递 |
| [`path_parsing`](https://pub.dev/packages/path_parsing) | 1.1.0 | MIT | 传递 |
| [`path_provider_android`](https://pub.dev/packages/path_provider_android) | 2.3.1 | BSD-3-Clause | 传递 |
| [`path_provider_foundation`](https://pub.dev/packages/path_provider_foundation) | 2.6.0 | BSD-3-Clause | 传递 |
| [`path_provider_linux`](https://pub.dev/packages/path_provider_linux) | 2.2.2 | BSD-3-Clause | 传递 |
| [`path_provider_windows`](https://pub.dev/packages/path_provider_windows) | 2.3.0 | BSD-3-Clause | 传递 |
| [`petitparser`](https://pub.dev/packages/petitparser) | 7.1.0 | MIT | 传递 |
| [`platform`](https://pub.dev/packages/platform) | 3.2.0 | BSD-3-Clause | 传递 |
| [`posix`](https://pub.dev/packages/posix) | 6.5.4 | MIT | 传递 |
| [`process`](https://pub.dev/packages/process) | 5.0.6 | BSD-3-Clause | 传递 |
| [`provider`](https://pub.dev/packages/provider) | 6.1.5+1 | MIT | 传递 |
| [`pub_semver`](https://pub.dev/packages/pub_semver) | 2.2.1 | BSD-3-Clause | 传递 |
| [`record_use`](https://pub.dev/packages/record_use) | 1.1.1 | BSD-3-Clause | 传递 |
| [`share_plus_platform_interface`](https://pub.dev/packages/share_plus_platform_interface) | 7.2.0 | BSD-3-Clause | 传递 |
| [`shared_preferences_foundation`](https://pub.dev/packages/shared_preferences_foundation) | 2.6.1 | BSD-3-Clause | 传递 |
| [`shared_preferences_linux`](https://pub.dev/packages/shared_preferences_linux) | 2.4.1 | BSD-3-Clause | 传递 |
| [`shared_preferences_platform_interface`](https://pub.dev/packages/shared_preferences_platform_interface) | 2.4.2 | BSD-3-Clause | 传递 |
| [`shared_preferences_web`](https://pub.dev/packages/shared_preferences_web) | 2.4.3 | BSD-3-Clause | 传递 |
| [`shared_preferences_windows`](https://pub.dev/packages/shared_preferences_windows) | 2.4.1 | BSD-3-Clause | 传递 |
| [`source_span`](https://pub.dev/packages/source_span) | 1.10.2 | BSD-3-Clause | 传递 |
| [`stack_trace`](https://pub.dev/packages/stack_trace) | 1.12.2 | BSD-3-Clause | 传递 |
| [`stream_channel`](https://pub.dev/packages/stream_channel) | 2.1.4 | BSD-3-Clause | 传递 |
| [`string_scanner`](https://pub.dev/packages/string_scanner) | 1.4.1 | BSD-3-Clause | 传递 |
| [`sync_http`](https://pub.dev/packages/sync_http) | 0.3.1 | BSD-3-Clause | 传递 |
| [`term_glyph`](https://pub.dev/packages/term_glyph) | 1.2.2 | BSD-3-Clause | 传递 |
| [`test_api`](https://pub.dev/packages/test_api) | 0.7.12 | BSD-3-Clause | 传递 |
| [`tuple`](https://pub.dev/packages/tuple) | 2.0.2 | BSD-2-Clause | 传递 |
| [`typed_data`](https://pub.dev/packages/typed_data) | 1.4.0 | BSD-3-Clause | 传递 |
| [`url_launcher_android`](https://pub.dev/packages/url_launcher_android) | 6.3.33 | BSD-3-Clause | 传递 |
| [`url_launcher_ios`](https://pub.dev/packages/url_launcher_ios) | 6.4.2 | BSD-3-Clause | 传递 |
| [`url_launcher_linux`](https://pub.dev/packages/url_launcher_linux) | 3.2.3 | BSD-3-Clause | 传递 |
| [`url_launcher_macos`](https://pub.dev/packages/url_launcher_macos) | 3.2.6 | BSD-3-Clause | 传递 |
| [`url_launcher_platform_interface`](https://pub.dev/packages/url_launcher_platform_interface) | 2.3.2 | BSD-3-Clause | 传递 |
| [`url_launcher_web`](https://pub.dev/packages/url_launcher_web) | 2.4.3 | BSD-3-Clause | 传递 |
| [`url_launcher_windows`](https://pub.dev/packages/url_launcher_windows) | 3.1.6 | BSD-3-Clause | 传递 |
| [`uuid`](https://pub.dev/packages/uuid) | 4.6.0 | MIT | 传递 |
| [`vector_graphics`](https://pub.dev/packages/vector_graphics) | 1.2.4 | BSD-3-Clause | 传递 |
| [`vector_graphics_codec`](https://pub.dev/packages/vector_graphics_codec) | 1.1.13 | BSD-3-Clause | 传递 |
| [`vector_graphics_compiler`](https://pub.dev/packages/vector_graphics_compiler) | 1.3.3 | BSD-3-Clause | 传递 |
| [`vector_math`](https://pub.dev/packages/vector_math) | 2.4.4 | BSD-3-Clause | 传递 |
| [`visibility_detector`](https://pub.dev/packages/visibility_detector) | 0.4.0+2 | BSD-3-Clause | 传递 |
| [`vm_service`](https://pub.dev/packages/vm_service) | 15.4.0 | BSD-3-Clause | 传递 |
| [`wakelock_plus_platform_interface`](https://pub.dev/packages/wakelock_plus_platform_interface) | 1.7.0 | BSD-3-Clause | 传递 |
| [`web`](https://pub.dev/packages/web) | 1.1.2 | BSD-3-Clause | 传递 |
| [`webdriver`](https://pub.dev/packages/webdriver) | 3.2.0 | Apache-2.0 | 传递 |
| [`win32`](https://pub.dev/packages/win32) | 6.4.0 | BSD-3-Clause | 传递 |
| [`xdg_directories`](https://pub.dev/packages/xdg_directories) | 1.1.0 | BSD-3-Clause | 传递 |
| [`xml`](https://pub.dev/packages/xml) | 7.0.1 | MIT | 传递 |
| [`yaml`](https://pub.dev/packages/yaml) | 3.1.4 | MIT | 传递 |

### 许可证分布

- BSD-3-Clause：93 个（多数为 Flutter 官方插件与 `package:test` 生态）
- MIT：24 个
- Apache-2.0：5 个（含 `clock`、`fake_async`、`material_color_utilities`）
- BSD-2-Clause：1 个
- MPL-2.0：1 个（`dbus`，桌面端插件依赖）

上述许可证均允许商业使用、修改与再分发；MIT / BSD / Apache-2.0 要求保留版权
声明与许可证文本，MPL-2.0 要求修改过的 MPL 文件继续以 MPL 发布（本项目未修改）。

## 4. 应用内查看完整许可证

「设置 → 关于 PullRead → 开源许可证」使用 Flutter 的 `LicenseRegistry`：

- Flutter 构建时会自动把每个 pub 包的 `LICENSE` 收集进 `NOTICES` 资源；
- `lib/main.dart` 额外注册 libgit2 与 JetBrains Mono 两份许可证，保证原生组件和
  字体在应用内也能查到全文。

## 5. 维护

```bash
flutter pub get
flutter pub deps --style=compact   # 查看依赖树
```

升级依赖后：

1. 重新生成第 3 节表格（版本、许可证可能变化）；
2. 若新增原生二进制、字体或静态资源，补充第 2 节与应用内注册；
3. 若引入 GPL/LGPL/MPL 等 copyleft 依赖，先评估分发方式再合并。
