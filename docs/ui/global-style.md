# PullRead 全局 UI 样式基准

> 2026-11-14 从 `docs/ui/` 各主题规范收敛。**新增页面、组件、弹层一律以此为准**，
> 避免 v2 的电子书/分屏页面另立一套视觉。
>
> 代码侧唯一事实来源：
> - 基础色与首页 token：`HomeTokens`（`lib/src/ui/home_feed.dart`）
> - 品牌种子：`#1F6F54`（`lib/main.dart`）
> - 阅读面纸色：`ReadingPaper`（`lib/src/theme/reading_paper.dart`）
> - 设置图标章：`settingsTonePalette`（`lib/src/ui/settings/settings_components.dart`）
>
> 主题 HTML 设计稿只是方向参考，不是逐像素契约；与本文冲突时以本文和实现为准。

## 1. 基础色（深浅成对）

| Token | Light | Dark | 用途 |
| --- | --- | --- | --- |
| paper | `#FFFFFF` | `#141512` | 页面/Scaffold 底色 |
| card | `#FFFFFF` | `#1D1F1B` | 卡片、弹层、输入框底 |
| border | `#E5E2D8` | `#34362F` | 卡片/输入框 1px 描边 |
| divider | `#F2F0E8` | `#2A2C26` | 列表分隔线 |
| heroDivider | `#EFEDE5` | `#2A2C26` | 大卡下沿等强调分隔 |
| green | `#1F6F54` | `#74C7A4` | 品牌主色、选中、进度、FAB |
| greenTint | `#EDF5F0` | `#22352C` | 绿色图标章底、选中行底 |
| title | `#26241E` | `#F2F0E8` | 标题 |
| secondary | `#3A382F` | `#D8D5C9` | 正文/次级文字 |
| meta | `#A5A296` | `#8F8C82` | 元信息、时间、副标题 |
| section | `#8A887E` | `#9A978C` | 分组标题、节头 |
| icon | `#4A4840` | `#D8D5C9` | 常规图标 |
| chevron | `#B8B5AA` | `#6E6B62` | 箭头、弱提示 |
| segment | `#ECEAE2` | `#24261F` | 分段控件轨道 |
| pin | `#C99A2E` | `#D8AD4E` | 置顶 |
| red | `#E5443B` | `#F06B62` | 危险操作、角标 |

约束：

- 不引入第二种强调色；橙色只用于「松橙」图标章（见 §4），不做主操作色。
- 不再使用旧纸白 `#FBFAF6`。
- 浅色模式禁止黑色浮层/黑色工具条。
- 新增色值必须先加到 token 源，再在本文登记；页面里禁止散落硬编码十六进制。

## 2. Header / AppBar

- 高度 56dp（`kToolbarHeight`），与页面底色同色（paper），无 tint。
- 静止时无阴影；内容滚到 Header 下方时允许主题统一的 3dp scrolled-under 阴影
  （`scrolledUnderElevation: 3`），页面不要各自另设。
- 左侧返回/标识，标题单行截断；右侧最多 3 个图标动作，超出进 `⋮`。
- 标题使用主题 `titleLarge`，颜色 `title`；不要在每个页面重设字号。
- 阅读页/代码页的 AppBar 跟随 `ReadingPaper.appBar`（见 §6），除此之外保持品牌纸底。
- 分隔不靠阴影：需要时用 `divider` 1px 或留白。

## 3. 页面、卡片与列表

| 元素 | 规格 |
| --- | --- |
| 卡片 | 底 `card`，1px `border`，圆角 16 |
| 卡片内边距 | 16；卡间距 10；行内边距 11 |
| 列表行 | 最小高度 48；设置/书签类常用 56；行间用 `divider` |
| 页面左右边距 | 手机 16；平板内容带居中限宽（600–1000dp 约 560–640dp） |
| 空状态 | 52×52 圆角 18 的 `greenTint` 图标章 + 13.5px `meta` 文案 |
| 危险操作 | `red` 图标/文字，独立分组，二次确认 |

断点统一沿用三档：`<600` 手机、`600–1000` 平板竖屏、`≥1000` 平板横屏/桌面。

## 4. 图标章

| Tone | Light 底/前景 | Dark 底/前景 |
| --- | --- | --- |
| pine | `#EDF5F0` / `#1F6F54` | `#1A3A2E` / `#7BC7A5` |
| neutral | `#F1EFE7` / `#5A5850` | `#2A2924` / `#B5B2A6` |
| amber | `#FDF6E7` / `#B0762A` | `#3A2E1C` / `#D9A05B` |

- 尺寸 40×40，圆角 12；子页可 38–40。
- 同一页面最多两种 tone；主功能 pine，中性/危险用 neutral/red。
- 不用无底色裸图标充当入口章。

## 5. 文字层级

| 角色 | 颜色 | 建议字号/字重 |
| --- | --- | --- |
| 页面大标题 | title | 24–28 / 700 |
| 卡片/行标题 | title | 14–15 / 600 |
| 正文 | secondary | 跟随阅读设置或 14–15 / 400 |
| 副标题 | meta | 12–12.5 / 400，单行截断 |
| 分组标题 | section | 12.5 / 700，字距 .06em，可大写 |
| 当前值 | section 或 green | 13 / 400；强调值用 green 700 |

一个页面最多三档文字大小（标题、正文、元信息）；不要为单个组件新造字号。

## 6. 阅读面纸色（仅阅读相关页面）

`ReadingPaper` 只覆盖阅读页、代码页、编辑器与书内正文；首页、设置、书架保持品牌纸底。

| 模式 | 背景 | AppBar | 前景 | 分隔 |
| --- | --- | --- | --- | --- |
| 白纸（默认） | 主题 surface | 同背景 | 主题 onSurface | 主题 outlineVariant |
| sepia | `#F6EFE0` | 同背景 | `#3A3225` | `#DDD2BC` |
| 柔和暗（默认暗色） | 主题 surface | 同背景 | 主题 onSurface | 主题 outlineVariant |
| OLED 纯黑 | `#000000` | 同背景 | `#E8E6E1` | `#2C2A26` |

阅读页内部控件：

- TOC 主钮 48×48 圆形白底 + `border` 描边 + green 图标；副钮 36×36。
- 阅读进度条 2.5px：轨 `#EFEDE5`（暗色用 divider），进度 green。
- 表格卡：`border` 描边、圆角 12，表头底 `greenTint`，行分隔 `divider`。
- 菜单：`card` 底、圆角 16、宽约 264dp；分组标题 11px `meta`，行高 40。

## 7. 控件

- **开关**：on 用 green；off 浅色 `#D9D6CB`，暗色用 `border`。
- **滑杆**：轨 4px 圆角 2；已过段 green，未过段 `#D9D6CB`（暗色 `border`）；滑块 22–24px。
- **分段控件**：轨道 `segment`；选中项 `card` 底 + green 文字或 green 实底白字。
- **Chip**：底 `#F1EFE7`（暗色 `#2A2924`），文字 secondary；状态 chip 用 `greenTint` + green。
- **选中行/块**：`greenTint` 底 + 左缘或右缘 3px green 指示条。
- **书签/更新角标**：red 底白字，圆角 9；置顶用 pin 色小图钉，不放大图标。

## 8. 新页面检查清单

新增页面前逐条确认：

- [ ] Scaffold 与 AppBar 用 paper 同色，Header 56dp，无 tint，阴影走主题统一设置。
- [ ] 颜色全部来自 `HomeTokens` / `ReadingPaper` / 图标章 palette，无硬编码。
- [ ] 卡片圆角 16、1px border、内边距 16；列表分隔用 divider。
- [ ] 标题/正文/元信息只用 §5 的三档层级。
- [ ] 入口图标使用图标章，尺寸 40×40、圆角 12。
- [ ] 手机 / 平板竖屏 / 平板横屏三档都走查；≥1000dp 优先侧栏而非浮动钮。
- [ ] 深色模式成对走查，不出现纯白卡片压在暗底上。
- [ ] 危险操作独立分组、red、二次确认。
- [ ] 空状态使用 tint 图标章 + meta 文案，不出现裸文字大空白。
- [ ] 若参考主题 HTML，先对照本文；冲突时先问用户，不默默偏离。
