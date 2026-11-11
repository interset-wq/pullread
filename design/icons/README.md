# 图标设计源文件（SVG）

PullRead 全部品牌图标的矢量源，任何尺寸/底色变体都从这里的 SVG 无损渲染，
禁止用 Pillow 等像素工具在 PNG 上做处理（会损失画质）。

## 三套文件

| 前缀 | 用途 | 构成 |
| --- | --- | --- |
| `appicon-*.svg` | 桌面图标完整版（圆角纸感底 + mark） | 256×256，`<rect rx=56 fill=#E3D6BC>` + `translate(28.16 28.16) scale(0.78)` 的 `#1F6F54` mark |
| `fg-*.svg` | Android 自适应图标前景（透明底，系统自己加背景） | 同 mark，透明底；对应 `drawable-xxxhdpi/ic_launcher_fg_*.png`（432px，mark 占 50%） |
| `icon_*_transparent.svg` | 应用内 logo（透明底，mark 放大到 0.984 居中） | `translate(2 2) scale(0.984)`；对应 `assets/icon/app_logo*.png`（192px） |

五个款式：`book`（默认摊开书）/ `page`（页即箭）/ `arrow`（抽页成箭）/
`converge`（汇页箭）/ `tray`（页堆箭）。

## 渲染方法

用任意保留 alpha 的 SVG 渲染器即可（本仓库使用 logo-design skill 的 headless
chrome 脚本，路径按本机环境替换）：

```bash
python <render_png.py> design/icons/appicon-book.svg \
  --out-dir temp/icon-design/render --size 1024
```

- 应用内 logo 输出 192px；桌面图标源用 1024px（flutter_launcher_icons 输入）
- 图标底色 `#E3D6BC` 比闪屏纸白 `#FBFAF6` 深一档，保证 iPad Dock / 浅色桌面上
  图标轮廓可辨；Android 自适应图标背景对应 `@color/brand_icon_paper`，不要再
  改回 `brand_paper`
- 跑完 `flutter_launcher_icons` 后必须检查 `AndroidManifest.xml`：该工具会把五个
  `activity-alias` 的 `android:icon` 全部改成 `@mipmap/ic_launcher`，并覆盖
  `mipmap-anydpi-v26/ic_launcher.xml`；这两处要还原为按款式区分的配置，否则
  「设置 → 图标」切换失效
- **注意**：该脚本 `--padding` 参数在 chrome 后端下会静默输出全空 PNG——
  自适应图标前景不要加 padding 渲染
- 深色底变体：直接改 SVG 的 `fill` 即可，不要事后抠色
