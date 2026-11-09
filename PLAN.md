# PullRead 开发计划与协作边界

> 本文件由项目主责 agent（opencode / deepseek-v4.1-flash-free）维护，用来公开当前
> 优先级、正在改的文件和合并规则。**其他 agent 动手前请先读这一节**，避免两边同时
> 改同一批文件、或把未验收的方案直接推进 `main`。
>
> 更新规则：主责 agent 在任务开始 / 结束时改「进行中」；其他 agent 如需接手队列
> 里的任务，先开 issue 或在 PR 里改本文件的「进行中」表，再动代码。

## 1. 协作约定

- `main` 只接受 PR 或主责 agent 的 merge commit；其他 agent **不要直接 push `main`**，
  也不要 `git push --force`。
- 分支从最新 `origin/main` 拉出，命名 `feat/<topic>` / `fix/<topic>`；开 PR 前先
  `git rebase origin/main`，保持单一主题、原子提交（英文 Conventional Commits）。
- 「进行中」表里列出的文件视为有主：需要同时修改时先在这里登记，或等对方合并。
- 不要对 `home_page.dart` / `repo_page.dart` / `markdown_viewer.dart` 等历史文件整体
  `dart format`，只格式化改动片段，避免几百行无关 diff。
- 改 Git 层（`lib/src/git/`）必须先在本文件登记，并说明数据安全分析；只读原则不变。
- 新增依赖、修改 `AGENTS.md` 中的硬约束，同样先登记。
- 本机没有 Android 真机、没有 macOS：涉及手势 / SAF 写回 / 图标切换 / 音量键的改动
  只能靠 analyze + 测试，真机验收项集中在第 5 节。

## 2. 当前状态（2026-11-08）

- 最新发布：`v1.12.0-rc4`（prerelease，arm64 APK）；`main` 又合入设置页视觉统一、
  透明应用内 logo 源文件与 PR #5。`v1.12.0-rc5` 待发布。
- CI：`analyze-and-test` 正常；`build-apk` 偶尔因 Gradle 发行包 504 失败，属基础设施
  抖动，重跑即可，不要为此改构建配置。
- 待真机验收：行选区高亮、设置页两级导航与恢复默认、SAF 写回、图标切换、音量键翻页。
- 设置页视觉已与首页/书签/标签/更新收件箱统一：扁平列表、20 dp 单色图标、
  去掉卡片与 tonal 圆形图标。

## 3. 进行中（主责 agent 占用文件）

| 任务 | 状态 | 涉及文件 |
| --- | --- | --- |
| issue #4-2：仓库切换分支 | 本地开发，待提交 | `lib/src/git/sync_service.dart`、`lib/src/git/repo_meta.dart`、`lib/src/ui/repo_page.dart`、`test/switch_branch_test.dart` |

## 4. 队列（按优先级）

1. **文内查找同章节精确滚动**：给懒加载正文块记录源码行范围，命中后滚到具体块；
   需要真机手感验证，暂缓到设备可用。
2. **UTF-16 文本支持**：`decodeTextBytes` 增加 BOM 检测；本地编辑器保存时保留原编码。
3. **`.mdx` 渲染增强**：当前按 Markdown 渲染，JSX 组件以文本降级展示；后续评估是否
   隐藏 import/export 行。
4. **设置搜索与别名目录**（`docs/settings-redesign.md` 阶段三，可选）。

## 5. 真机验收清单（设备可用后）

- [ ] 代码页长按选区：高亮行与手指位置一致，跨几十行不累积偏移。
- [ ] 设置页：两级导航、滑杆松手才落盘、「恢复本页默认」、320 dp + 2.0 字号不溢出。
- [ ] 本地文件夹：SAF 授权写权限、编辑保存回原文件夹、失败进待写回列表。
- [ ] 图标切换（仅 release 包）：五个 alias 切换后桌面图标与启动背景正确。
- [ ] 音量键翻页。
- [ ] mermaid 长按保存/分享：相册有图、分享面板能发出、深色主题下底色正确。
- [ ] 切换分支：列表正确、切换后目录/正文更新、切回原分支阅读进度仍在、离线可用。

## 6. 最近完成

- PR #3 表格公式竖线修复；P0 克隆/删除路径越界加固。
- 设置页两级重构合并；行选区行高按 `TextPainter` 实测。
- 首页收藏/最近阅读覆盖本地文件夹；全局搜索覆盖本地来源。
- 搜索只搜阅读页真正渲染的正文（剥 front matter、归一化 HTML 图片）。
- 首页过滤已删除文件（幽灵卡片）；`.mdx` 统一按 Markdown 阅读。
- 移除遗留 `repro_two_repos_test`，真实网络克隆测试对瞬时网络错误重试一次。
- issue #4-1：mermaid 图表可长按/全屏分享保存为 PNG（`0a2b86c`）。
- issue #4-2：仓库页可切换远端分支（只读 checkout，保留阅读进度/收藏）。
- 设置页去掉卡片/圆形图标，改为与全站一致的扁平列表；「恢复默认」改为 AppBar
  文字按钮。
