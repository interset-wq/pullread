# UI 设计交付目录（docs/ui/）

设计师（agent）的专属交付区：**只产出设计规范与设计板，不写实现代码**。
实现由开发侧依据本目录的规范落地；实现改动设计时，设计师同步更新对应文档。

> 状态（2026-11-14）：现有主题均已实现（截至 v1.14）。PNG 设计板已删除，
> 只保留 HTML 与规范文档；新增页面必须先读 [`global-style.md`](global-style.md)。

## 目录结构

```text
docs/ui/
├── README.md            # 本说明：职责边界与交付约定
├── global-style.md      # 全局样式基准（配色/Header/卡片/层级/新页面清单）★契约
├── home-redesign.md     # 首页改版规范
├── reader-redesign.md   # 阅读页改版规范
├── code-redesign.md     # 代码查看页改版规范
├── settings-redesign.md # 设置页改版规范
├── inbox-favorites.md   # 更新收件箱与收藏页规范
└── <topic>/             # 每个主题的设计 HTML（phone.html / tablet.html）
```

## 交付约定

1. **全局基准唯一**：跨页面配色、Header、卡片、文字层级、圆角与间距以
   [`global-style.md`](global-style.md) 为准；各主题文档不得另立近似色值。
2. **主题子目录**：每个 UI 改版主题一个子目录，存放 `phone.html` 与 `tablet.html`；
   规范文档写在 `docs/ui/<topic>.md`。
3. **只入库 HTML**（2026-11-14 起）：HTML 设计稿是正式交付物；PNG 渲染图不入库，
   需要查看时用浏览器打开 HTML。过程稿留在 `temp/`，不入库。
4. **手机 / 平板分文件**：每个主题至少提供 `phone.html` 与 `tablet.html` 两套，
   不得混在同一文件里；平板帧缺失时先补板再定稿。
5. **规范即契约**：结构、token、交互规则、验收清单写在规范文档里，实现方照此
   落地；token 变更必须先改 `global-style.md`。
6. **设计稿仅供参考**：HTML 设计板是方向参考，不是逐像素契约；实现时发现设计稿
   不合理（实现代价过高、与已有 UI 冲突、体验更差）应**及时汇报**，由用户决定
   取舍，不得默默偏离或默默照做。
7. **品牌约束**：纯白底 `#FFFFFF` × 松绿 `#1F6F54`；深浅色成对给值。旧纸白
   `#FBFAF6` 已弃用。
8. **v2 新主题**：电子书模式与分屏阅读按里程碑新增 `book-reader.md` /
   `split-reader.md` 及对应 HTML 子目录，先补规范再实现。

## 主题状态

| 主题 | 规范 | 状态 |
| --- | --- | --- |
| 首页 | `home-redesign.md` | 已实现 |
| 阅读页 | `reader-redesign.md` | 已实现 |
| 代码查看 | `code-redesign.md` | 已实现 |
| 设置页 | `settings-redesign.md` | 已实现 |
| 收件箱/收藏 | `inbox-favorites.md` | 已实现 |
| 搜索页 | 仅 HTML（`search-redesign/`） | 已实现 |
| 目录树 | 仅 HTML（`tree-redesign/`） | 已实现 |
| 电子书模式 | 待新增 | v2 M1–M2 |
| 分屏阅读 | 待新增 | v2 M3 |
