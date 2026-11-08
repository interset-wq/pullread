# Agent 操作日志

> 本仓库由多个 agent 协作维护（不同机器/系统，如 Windows 与 Ubuntu 26），
> 此文件记录**非主责 agent** 的操作，便于主责 agent 判断改动来源、避免相互干扰。
>
> - 用途：只记录操作轨迹，不承载项目文档
> - 写法：在文件末尾追加条目，尽量不改动他人条目，减少合并冲突
> - 格式：`## YYYY-MM-DD HH:mm` + 操作人/模型 + 操作内容 + 涉及文件/命令 + 结果
> - 纯问答、未触动仓库的操作无需记录

---

## 2026-11-06 会话初始化

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：读取 `temp/` 目录清单、检查 `.gitignore` 中的 `temp/` 规则（只读）
- 涉及文件：无修改
- 结果：确认 `temp/` 已被忽略；未对仓库代码做任何改动

## 2026-11-06 建立跨机器操作日志

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：将操作日志从 `temp/` 迁到版本控制的仓库根目录，供其他机器上的 agent 查看
- 涉及文件：新增 `AGENT_OPS_LOG.md`，删除 `temp/agent-ops-log.md`
- 结果：日志纳入 git

## 2026-11-06 统一 Markdown Raw 与代码查看器渲染

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：修复 Raw 模式与代码文件查看器两套独立实现导致的渲染/交互不一致
- 涉及文件：
  - 新增 `lib/src/ui/code_view.dart`（共用 `CodeView` / `CodeViewController`）
  - 改写 `lib/src/ui/code_viewer.dart`（改为复用 `CodeView`，读文件统一 `decodeTextBytes`）
  - 修改 `lib/src/ui/markdown_viewer.dart`（Raw 模式复用 `CodeView`，独立滚动、固定字号、默认不换行、大纲/查找/换行工具条）
  - 新增 `test/raw_code_view_test.dart`，补充 `test/code_viewer_test.dart` 的 GBK 用例
  - 同步更新 `AGENTS.md` 的代码查看章节
- 验证：`flutter analyze` 无问题；相关测试通过（`raw_code_view_test` / `code_viewer_test` / `reader_find_test` / `lazy_body_test`）
- 已知与本次无关：`test/widget_test.dart` 在基线提交上同样失败（停在 `BrandSplash`），非本次改动引入

## 2026-11-06 新增 Prerelease 发版支持

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：`release.yml` 在 tag 带 SemVer 预发布后缀（如 `v1.12.0-rc1`）时创建 GitHub Prerelease；正式 tag 行为不变
- 涉及文件：`.github/workflows/release.yml`（版本校验支持 `-rc1` 后缀、`prerelease` 按 tag 名判断）、`AGENTS.md`（发版约定）
- 验证：未推送/未实际触发 workflow；YAML 仅文本修改

## 2026-11-06 新增设置页重设计建议书

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：调研设置页、偏好层与入口，输出两级信息架构、视觉规范、交互修正与实施顺序；未改业务代码
- 涉及文件：`docs/settings-redesign.md`（新增）、`AGENT_OPS_LOG.md`
- 验证：文档审阅；无代码改动，未运行测试
- 遗留：建议稿尚未实现，未提交

## 2026-11-07 09:32 新增用户视角体验审计报告

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：按 Markdown 笔记用户视角审计阅读、检索、导航、本地文件夹与同步体验，输出带代码位置的 P0/P1/P2 问题、功能建议、实施顺序与验收要求
- 涉及文件：`docs/user-feedback.md`（新增）、`AGENT_OPS_LOG.md`
- 验证：静态代码审计；P0 克隆尾斜杠路径已按代码逻辑确认，未在真实数据目录复现；未改业务代码
- 遗留：报告与日志均未提交

## 2026-11-07 09:35 删除错误的 Prerelease

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：按用户要求删除 2026-11-06 发布的 `v1.12.0-rc1` GitHub Prerelease 及对应 tag（原因：包名不正确）
- 命令：`gh release delete v1.12.0-rc1 --yes --cleanup-tag`
- 结果：Release 与远端 tag 均已删除；本地 tag 已不存在；未改动代码与版本号
- 遗留：本次日志与 `docs/user-feedback.md` 尚未提交

## 2026-11-07 09:50 修复发布包名并重发 Prerelease

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：删除 `android/app/build.gradle.kts` 中误提交的临时 `applicationIdSuffix`（debug `.devtest`、release `.reltest`），恢复发布包名为 `com.intersetwq.pullread`；版本升至 `1.12.0-rc2+22`
- 提交：`0cae733 fix(android): remove temporary application id suffixes`、`442355a chore: bump version to 1.12.0-rc2+22`
- 发布：创建并推送 tag `v1.12.0-rc2`；Release workflow `42325757730` 成功（5m52s），GitHub Prerelease `v1.12.0-rc2`
- 验证：`flutter analyze` 无问题；`flutter test` 188 通过、1 失败（既有 `widget_test.dart` 首页仍停在 `BrandSplash`）；本地构建 APK 与下载的 Release APK 均为 `package name='com.intersetwq.pullread' versionName='1.12.0-rc2'`
- 遗留：`docs/user-feedback.md` 与本日志条目尚未提交

## 2026-11-07 10:38 修复行选区高亮行高误差

- 操作人：opencode / deepseek-v4.1-flash-free（Ubuntu）
- 问题：代码 / Raw 模式的行选区高亮高度按 `fontSize × height`（13 × 1.5 = 19.5）硬算，但 JetBrains Mono 在 Flutter 里实际渲染 20.0/行；每行差 0.5px，选中多行后高亮逐行偏移
- 操作：
  - `lib/src/ui/code_view.dart`：新增 `_measureLineHeight()`（用与 HighlightView 相同的字体/字号/`TextScaler.noScaling` 交给 `TextPainter` 实测），`_lineHeight` 改为运行时字段；选区高亮、`_lineAt`、`_onScroll`、`_jumpToLine` 全部改用实测值
  - 行号 `Text` 加 `textScaler: TextScaler.noScaling`，与 HighlightView 的 RichText 保持一致（旧实现行号会跟随系统字体缩放而正文不会）
  - 新增回归测试 `test/code_selection_test.dart`（加载真实 JetBrains Mono，长按+点选后把高亮矩形与 RenderParagraph 的实际行框对比；旧实现会得到 117 vs 120 而失败）
  - `AGENTS.md`：更新代码查看章节的行高与大纲跳转说明
  - 修复既有失败测试 `test/widget_test.dart`：注入 fake `PathProviderPlatform`（临时目录），避免测试真的在 `~/Documents` 下建 `repos`、也避免真实 IO 在 fake async 里等不到；`pubspec.yaml` 增加 dev 依赖 `path_provider_platform_interface` / `plugin_platform_interface`
- 验证：`flutter analyze --fatal-infos` 通过；全量 `flutter test` 通过
- 备注：本机未连真机复验，UI 变化靠 widget 测试覆盖；提交未 push

## 2026-11-07 10:54 Rewrite AGENTS.md as the English engineering contract

- 操作人：opencode / deepseek-v4.1-flash-free（Ubuntu，项目主责 agent）
- 操作：领导要求重写 `AGENTS.md`（原文件由能力较弱的 agent 创建，部分内容已过时）。
  按当前代码事实重建为英文工程契约：产品边界、技术栈与包名、模块地图、
  10 条跨模块不变量、git/同步层约束、渲染与阅读链路、平台与启动、开发/验收/
  发布流程、测试注意事项。
- 顺带修正的过时描述：
  - Android TLS 初始化顺序不再是「`runApp` 之前」，而是 `main()` 立即 `runApp`，
    顺序在 `_bootstrap()` 内保持 `Libgit2.version` → `AndroidSSLHelper.initialize()`
    → `Libgit2.setSSLCertLocations(file:)`
  - 启动链路补充状态栏/导航栏纸白 + `windowLightStatusBar`（否则顶部出现灰带）
  - 图标 alias 明确为五个（`MainActivityBook/Page/Arrow/Converge/Tray`），
    修正清单注释里「三个」的旧说法（未改注释，仅文档描述以实际清单为准）
  - 新增「路径/删除安全」约束：仓库名从 `Uri.pathSegments` 取、禁止删除 repos 根/
    `.meta`/镜像根/文档根（对应 `docs/user-feedback.md` 的 P0，待修）
- 涉及文件：`AGENTS.md`
- 验证：纯文档改动，未运行代码检查；下一步按新文档第 5.1 节修 P0

## 2026-11-07 11:10 Fix clone path data-loss risk (P0)

- 操作人：opencode / deepseek-v4.1-flash-free（Ubuntu，项目主责 agent）
- 问题：`home_page` 用 `url.split('/').last.replaceAll('.git', '')` 取仓库名，
  尾斜杠 URL 得到空名字，`GitSyncService.clone` 的目标路径退化成 repos 根目录，
  `_prepareTarget` 随后递归删除整个 repos 根（含 `.meta` 的进度/书签/收藏）
- 操作：
  - 新增 `lib/src/platforms/repo_url.dart`：`parseRepoUrl`（`Uri.pathSegments` +
    仅去尾部 `.git`，校验单级安全名）、`isSafeRepoName`（拒绝空名、`.`/`..`、
    点开头、路径分隔符、Windows 非法字符/保留名）、`isDirectChildPath`
    （规范化后比较路径段）、`pathBaseName`
  - `home_page`：克隆信息改用 `parseRepoUrl`，解析失败直接提示并中止
  - `sync_service`：`clone()` 在 `waitForCleanup`/`_prepareTarget` 之前校验
    仓库名与目标边界；`_prepareTarget` 增加「必须是 repos 根直接子目录」护栏；
    `deleteRepo` 改为必须传 `reposRoot` 并做同样的边界校验
  - `home_page` / `repo_page`：删除与重新克隆路径补传 `reposRoot`
  - 新增 `test/clone_safety_test.dart`：覆盖尾斜杠、`.`/`..`/`.meta`、百分号
    编码、`my.git.repo`、Windows 非法名、路径越界，以及 clone/delete 的护栏
    （只使用临时目录，不触碰真实用户数据）
- 验证：`flutter analyze --fatal-infos` 通过；`clone_safety_test` 11 项通过

## 2026-11-07 Separate branch for issue #2

- 执行人：opencode / deepseek-v4.1-flash-free（Windows）。
- 分支：`fix/table-math-pipes`，基于 `origin/main`（`8c6aa14`）。
- 提交：`f7aa681 fix(render): keep math pipes intact in tables`（cherry-pick 自 `009dc95`）。
- 验证：`flutter analyze --fatal-infos` 通过；`test/table_math_test.dart` 4 项通过。
- 已知：本地全量 `flutter test` 为 204 通过 / 1 失败，失败项 `clone_safety_test` 是 `main` 上既存的 Windows `cmd.exe rmdir` 路径问题；对应修复 `a780d33` 在 `feat/settings-redesign`，与本 PR 无关。
- 推送：`git push -u origin fix/table-math-pipes` 成功。
- PR：https://github.com/interset-wq/pullread/pull/3

## 2026-11-08 Merge PR #3 and land the P1 reading-batch

- 执行人：opencode / deepseek-v4.1-flash-free（Ubuntu，项目主责 agent）。
- PR #3 `fix(render): keep math pipes intact in tables`：本地复核
  `flutter analyze --fatal-infos` 通过、`table_math_test` 4 项通过；全量测试
  204 通过 / 1 失败，失败项 `sync_service_test`（真实网络 clone）单独重跑通过，
  判定为网络抖动。已用 merge commit `4817ff0` 合入 `main` 并删除远端分支。
- P1 阅读主链路（本机无真机，以下均以单元 / widget 测试验证）：
  - 首页聚合接入本地镜像：`home_feed.dart` 新增收藏 / 最近阅读的跨来源合并；
    `RepoMeta.pushRecent` 增加时间戳与 `recentsRoot`，镜像统一写
    `<docs>/local/.meta/recents.json`，旧记录无时间戳仍可读；首页「继续阅读」、
    收藏、最近阅读、搜索入口都同时覆盖仓库与本地文件夹
  - 全局搜索 `GlobalSearchPage` 接受 `locals`，本地来源显示为「本地 · 名称」，
    结果跳转统一走 `openNoteFile`
  - 阅读页同目录上一篇/下一篇只列 Markdown；正文里的本地文件链接改走
    `openNoteFile`（图片进图库、代码进代码页，并清除更新标记）
  - 编辑器按原始编码打开并写回（`isUtf8Bytes` / `encodeTextBytes`），GBK 笔记
    保存后仍是 GBK
  - 行内公式拒绝把 `$100 到 $200` 这类范围金额当公式
  - 代码查看器超过 5 MB 只读前 5 MB 并提示，避免整文件高亮卡死
  - 清空阅读历史同时清理 `repos` 与 `local` 两个来源根目录；
    `clearAllStars` 改为按来源根 `.meta/*.json` 清理，本地镜像收藏不再遗漏
- 新增/扩展测试：`home_feed_test`、`repo_meta_recents_test`、
  `global_search_test`（本地镜像与重名）、`text_encoding_test`、
  `markdown_editor_test`（GBK 往返）、`math_render_test`（金额边界）。
- 待处理：`feat/settings-redesign`（另一 agent，含设置两级重构与 Windows
  `deleteRepo` 路径修复）尚未合并；其删除了旧 `settings_page.dart`，合并时需把
  「清空阅读历史也清 local 根」搬到新的 `settings/data_settings_page.dart`。
