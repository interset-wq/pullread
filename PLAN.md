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
- 本机 Ubuntu 无法构建/验收 iOS 与 Windows：涉及手势 / SAF 写回 / 图标切换 /
  音量键的改动只能靠 analyze + 测试，真机验收项集中在第 5 节；iPad 由其他 agent
  按 `docs/ios-test-plan.md` 执行。

## 2. 当前状态（2026-11-10）

- 最新发布：`v1.12.0`（正式版，arm64 APK）；包含设置页视觉统一、透明应用内
  logo、分支切换、mermaid 导出、跨平台 README 与第三方许可证页。
- 定位升级为跨平台、移动优先：Android 主要发布，iPadOS/iOS 源码构建并等待真机验收，
  Windows 为次级桌面目标；Linux/macOS 尚未接入。
- 许可证：`THIRD_PARTY_NOTICES.md` + `LICENSES/` 覆盖 125 个 pub 包、libgit2
  （GPL-2.0 + linking exception）、JetBrains Mono（OFL-1.1）；关于页接入
  `showLicensePage`。升级依赖时必须同步清单。
- iOS：`.github/workflows/ios.yml` 已在 macOS runner 构建成功，产出未签名
  `PullRead-unsigned.ipa`；issue #6 的 libgit2 符号与 #10 的 CA 初始化已修复，
  本地文件夹改为原生目录选择器 + security-scoped bookmark。iPad 真机验收由其他
  agent 按 `docs/ios-test-plan.md` 执行。
- 设置页定稿视觉升级已合并（PR #14）：松绿品牌种子、tint 图标章、白卡输入框、
  chips 隐藏规则、≥1000 dp 双栏；设置搜索与锚点保留。
- 应用图标已按 issue #8 调整：mark 0.7 → 0.78，图标底色 #FBFAF6 → #E3D6BC，
  Android 自适应图标使用 `brand_icon_paper`，闪屏纸白不变。
- Android 真机（DIO-AN00 / Android 12）：设置/许可证、切换分支、mermaid 导出
  已通过；其余手势与写回项待测。
- CI：`analyze-and-test` 正常；`build-apk` 偶尔因 Gradle 发行包 504 失败，属基础设施
  抖动，重跑即可，不要为此改构建配置。
- 待真机验收：行选区高亮、设置页滑杆落盘与 320 dp 字号、SAF 写回、图标切换、
  音量键翻页。

## 3. 进行中（主责 agent 占用文件）

当前无进行中任务。其他 agent 可接手第 4 节队列；开始前先在本节登记任务与文件。

| 任务 | 状态 | 涉及文件 |
| --- | --- | --- |
| — | — | — |

## 4. 队列（按优先级）

1. **文内查找同章节精确滚动**：给懒加载正文块记录源码行范围，命中后滚到具体块；
   需要真机手感验证，暂缓到设备可用。
2. **设置搜索后续增强**：实时预览卡、阅读字号迁入 `AppPrefs`
   （见 `docs/settings-redesign.md` 阶段三剩余项；平板双栏已完成）。

## 5. 真机验收清单（设备可用后）

### Android（DIO-AN00 / Android 12）

- [x] 设置页：扁平列表、两级导航、关于页许可证入口（2026-11-09 通过）。
- [x] 切换分支：列表、切换、切回后进度/书签保留（2026-11-09 通过）。
- [x] mermaid 长按保存/分享：相册有图、深色主题底色正确（2026-11-09 通过）。
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
- 跨平台定位：README 重写为主 slogan「克隆一次，常读常新」+ 核心
  clone→read→pull 循环 + Android/iPadOS/Windows 平台矩阵。
- 第三方许可证：新增 `THIRD_PARTY_NOTICES.md` 与 `LICENSES/`，关于页可查看全部
  依赖许可证原文。
- 设置页定稿视觉升级（PR #14）：松绿 seed、tint 图标章、白卡输入框、双栏布局。
- 应用图标对比度与 mark 占比（issue #8）：0.78 比例 + `#E3D6BC` 纸色。
- iOS 本地文件夹：`UIDocumentPickerViewController` + security-scoped bookmark，
  重启后仍可同步与写回；授权失效时保留旧镜像（issue #7）。
- 文本编码：新增 UTF-16 LE/BE（含 BOM）识别；本地编辑器保存时保留 UTF-8 BOM /
  UTF-16 编码，不再只区分 UTF-8 与 GBK。
- `.mdx` 阅读增强：隐藏顶层 import/export 与 MDX 注释，代码块与源码视图保留；
  全文检索同步使用同一段正文。
- 设置搜索：根页搜索图标、别名目录与面包屑结果，进入子页后自动滚到目标设置行。
