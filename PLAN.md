# PullRead 开发计划与协作边界

> v2 执行板。v2 的范围、已定决策与阶段出口见 [`docs/v2-roadmap.md`](docs/v2-roadmap.md)。
> 本文件只记录当前状态、进行中任务、队列与真机验收，避免和路线文档重复。
>
> 更新规则：任务开始 / 结束时改「进行中」；其他 agent 接手队列任务前，先在本文件
> 登记任务与文件，再动代码。

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
- 本机无法构建/验收 iOS 与 Windows：涉及手势 / SAF 写回 / 图标切换 / 音量键的改动
  只能靠 analyze + 测试，真机验收项集中在第 5 节；iPad 由其他 agent 按
  `docs/ios-test-plan.md` 执行。

## 2. 当前状态（2026-11-14）

- 最新预发布：`v1.14.0-rc2`；最后一个稳定版：`v1.13.0`。v1 功能面已基本完成。
- v1.14 已落地：纸感阅读主题（白纸/sepia、柔和暗/OLED）、文内查找精确跳转、
  TOC 筛选与层级编号、标签深链、不支持格式提示、HTML 长尾表单兼容。
- v2 主轴为**阅读体验深化**，两条主线：电子书模式、多开阅读；共同底座是阅读内核
  抽取。范围与非目标见 `docs/v2-roadmap.md`。
- 许可证：`THIRD_PARTY_NOTICES.md` + `LICENSES/` 覆盖 pub 包、libgit2
  （GPL-2.0 + linking exception）、JetBrains Mono（OFL-1.1）；关于页接入
  `showLicensePage`。升级依赖时必须同步清单。
- 平台：Android 主要发布；Windows 11 已通过键鼠/窗口/本地写回验收；iOS/iPadOS
  由源码构建，真机验收仍未完成（见第 5 节）。
- 文档：v1 的一次性计划与审计快照已清理；常青技术文档与 `docs/ui/`（含 HTML
  设计稿，PNG 已删除）保留；v2 详细设计按里程碑补 `docs/ui/<topic>.md`。

## 3. v2 里程碑

| 里程碑 | 内容 | 状态 |
| --- | --- | --- |
| M0 | 阅读内核抽取（`ReaderController` / `ReaderPane`），无用户可见变化 | 已完成：`ReaderController` / `ReaderPane` 均已拆出；待真机回归 |
| M1 | 书单与书根：大纲解析、自动推断、书单缓存 | 已完成：解析/发现/推断/`.meta` 书单缓存均已落地；待真机验收 |
| M2 | 电子书阅读 MVP：入口、书级目录、章间衔接、书级进度 | MVP 已完成：入口/书单/书根切换/章节翻页/书级进度/宽屏书目录 + 窄屏弹层；待真机验收 |
| M3 | 多开阅读：双栏壳、手机切换器、跨来源会话 | 已完成：双栏壳/窄屏切换器/跨来源选择/手动分屏开关/书单章节入栏均已落地；待旋转缩放与真机手势验收 |
| M4 | 联调、设置项、文档与 `2.0.0-rc1` 发布 | 未开始 |

## 4. 进行中（主责 agent 占用文件）

v2 阅读内核 / 电子书 MVP 正在本分支推进；以下文件暂由本任务占用。

| 任务 | 状态 | 涉及文件 |
| --- | --- | --- |
| M0 阅读内核 + M2 电子书 + M3 多开 | 进行中 | `lib/src/ui/reader/reader_pane.dart`、`lib/src/ui/reader/book_reader_page.dart`、`lib/src/ui/reader/split_reader_page.dart`、`lib/src/ui/reader/reader_session.dart`、`lib/src/ui/home_page.dart`、`lib/src/ui/markdown_viewer.dart`、`lib/src/books/`、`lib/src/git/repo_meta.dart`、`lib/src/ui/repo_page.dart` |

## 5. 真机验收清单（v1 收尾，不阻塞 v2）

### Android（DIO-AN00 / Android 12）

- [x] 设置页：扁平列表、两级导航、关于页许可证入口（2026-11-09 通过）。
- [x] 切换分支：列表、切换、切回后进度/书签保留（2026-11-09 通过）。
- [x] mermaid 长按保存/分享：相册有图、深色主题底色正确（2026-11-09 通过）。
- [ ] 文内查找同章节精确跳转：长章节多命中时滚到具体块，不偏移。
- [ ] 代码页长按选区：高亮行与手指位置一致，跨几十行不累积偏移。
- [ ] 设置页：滑杆松手才落盘、320 dp + 2.0 字号不溢出。
- [ ] 设置页双栏：≥1000 dp（平板横屏）左类别栏 + 右内容，切换类别与子页返回正常。
- [ ] 应用图标：浅色桌面/Dock 上轮廓清晰，五种图标切换后比例一致。
- [ ] 本地文件夹：SAF 授权写权限、编辑保存回原文件夹、失败进待写回列表。
- [ ] 图标切换（仅 release 包）：五个 alias 切换后桌面图标与启动背景正确。
- [ ] 音量键翻页。

### iOS / iPadOS（iPad 第 5 代，由其他 agent 执行）

清单见 `docs/ios-test-plan.md`。重点是安装/重签、许可证页、分支切换、
mermaid 保存、本地文件夹持久授权、分屏与安全区、音量键翻页。
CI 产物为未签名 IPA，需用 Apple ID 重签后安装。

## 6. 队列（v1 遗留 backlog，按价值排序）

这些项不属于 v2 主线，完成 v2 里程碑或有人认领时再做；与 v2 特性冲突时以路线文档为准。

1. **搜索分页**：内容搜索最多返回 60 个命中文件且无分页；增加分页或按需加载。
2. **Front matter 增强**：支持 YAML 块状 `tags`；展示 `date` / `author` /
   `description` / `cover` 等常见字段；标签扫描与阅读页统一使用 `decodeTextBytes`
   （GBK 中文标签不乱码）。
3. **Obsidian 兼容**：可选支持 `[[note]]`、`![[image]]` 与 inline `#tag`。
4. **渲染兼容**：Notebook stdout/stderr 清理 ANSI 转义；不支持输出显示占位；
   HTML `<a href>` 转为 Markdown 链接而不是剥离。
5. **断链检查**：支持 reference-style 链接与页内锚点校验。
6. **本地笔记工作流**：新建/重命名笔记（镜像 + SAF 源文件夹）；编辑器查找替换与
   语法高亮。
7. **仓库能力说明**：clone 分支选择、submodule 未初始化提示、LFS 指针提示。

## 7. 最近完成

- v1.14：纸感阅读主题（白纸/sepia、柔和暗/OLED），Scaffold/AppBar/TOC 侧栏跟随；
  文内查找按标题槽位精确跳转；TOC 关键词筛选与层级编号；标签深链；
  不支持格式提示；HTML 长尾表单兼容。
- v1.13：首页改版（继续阅读/最近阅读去重、仓库/本地互斥、平板三档布局）；
  更新收件箱；搜索历史只在实际打开结果时写入；单字查询放开。
- v1.12：设置页两级重构与视觉统一；分支切换；mermaid 导出；许可证页；
  iOS 本地文件夹持久授权；UTF-16 识别；`.mdx` 统一按 Markdown 阅读。
- 安全与数据：克隆/删除路径越界加固；幽灵卡片过滤；表格公式竖线修复；
  行选区行高按 `TextPainter` 实测。
